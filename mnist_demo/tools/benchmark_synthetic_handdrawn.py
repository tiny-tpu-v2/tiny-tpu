# ABOUTME: Generates synthetic hand-drawn style 28x28 digits and benchmarks them on exported quantized weights.
# ABOUTME: Produces reproducible benchmark artifacts (JSON, CSV, PNG, and ASCII previews) for deployment tracking.

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import struct
import sys
import zlib

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from mnist_demo.brush_tools import stroke_cells
from mnist_demo.train_mnist import run_quantized_inference


IMAGE_SIDE = 28
IMAGE_PIXELS = IMAGE_SIDE * IMAGE_SIDE
PROJECT_DIR = Path(__file__).resolve().parents[1]
MODEL_DIR = PROJECT_DIR / "data" / "model" / "reference"
DEFAULT_OUTPUT_DIR = PROJECT_DIR / "artifacts" / "benchmarks" / "synthetic_handdrawn"


DIGIT_TEMPLATES: dict[int, list[list[tuple[float, float]]]] = {
    0: [[(5, 13), (6, 8), (10, 5), (16, 5), (21, 8), (22, 13), (21, 18), (16, 22), (10, 22), (6, 18), (5, 13)]],
    1: [[(7, 11), (5, 13), (22, 13)], [(22, 9), (22, 17)]],
    2: [[(6, 7), (4, 12), (5, 18), (8, 21)], [(8, 21), (13, 16), (18, 11), (22, 7)], [(22, 7), (22, 21)]],
    3: [[(6, 8), (4, 13), (5, 19), (9, 21)], [(13, 11), (13, 17)], [(15, 19), (18, 22), (22, 19), (22, 12), (20, 8)]],
    4: [[(20, 7), (8, 16)], [(5, 17), (22, 17)], [(13, 7), (13, 21)]],
    5: [[(6, 21), (6, 8), (12, 8), (12, 17)], [(12, 17), (16, 21), (21, 20), (22, 15), (21, 9), (22, 8), (22, 19)]],
    6: [[(7, 18), (6, 13), (8, 8), (13, 6), (18, 7), (22, 11), (22, 16), (19, 20), (14, 20), (11, 16), (12, 11), (16, 9)]],
    7: [[(6, 7), (6, 22)], [(6, 22), (22, 11)]],
    8: [
        [(8, 13), (6, 9), (6, 16), (9, 18), (12, 15), (12, 10), (9, 8), (8, 13)],
        [(14, 13), (12, 9), (13, 17), (17, 20), (21, 17), (22, 12), (20, 8), (16, 8), (14, 13)],
    ],
    9: [[(8, 13), (6, 9), (6, 16), (10, 19), (14, 16), (13, 10), (9, 8), (8, 13)], [(13, 16), (19, 15), (22, 11)]],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples-per-digit", type=int, default=120)
    parser.add_argument("--preview-per-digit", type=int, default=4)
    parser.add_argument("--seed", type=int, default=1234)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser.parse_args()


def write_png(path: Path, bits: list[int], scale: int = 12) -> None:
    width = IMAGE_SIDE * scale
    height = IMAGE_SIDE * scale
    raw = bytearray()

    for out_y in range(height):
        raw.append(0)
        src_y = out_y // scale
        for out_x in range(width):
            src_x = out_x // scale
            pixel = bits[(src_y * IMAGE_SIDE) + src_x]
            raw.append(0 if pixel else 255)

    def chunk(chunk_type: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        return (
            struct.pack(">I", len(payload))
            + chunk_type
            + payload
            + struct.pack(">I", crc)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)
    with path.open("wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def write_ascii(path: Path, bits: list[int]) -> None:
    lines: list[str] = []
    for row in range(IMAGE_SIDE):
        line = "".join("#" if bits[(row * IMAGE_SIDE) + col] else "." for col in range(IMAGE_SIDE))
        lines.append(line)
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def parse_s16_memh(path: Path) -> list[int]:
    values: list[int] = []
    for line in path.read_text(encoding="ascii").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        raw = int(stripped, 16) & 0xFFFF
        values.append(raw - 0x10000 if raw >= 0x8000 else raw)
    return values


def unflatten_weights_for_tiles(
    flattened: list[int],
    input_size: int,
    output_size: int,
    tile_width: int,
) -> list[list[int]]:
    matrix = [[0 for _ in range(output_size)] for _ in range(input_size)]
    index = 0
    for tile_start in range(0, output_size, tile_width):
        tile_stop = min(tile_start + tile_width, output_size)
        for input_index in range(input_size):
            for output_index in range(tile_start, tile_stop):
                matrix[input_index][output_index] = flattened[index]
                index += 1
    if index != len(flattened):
        raise ValueError(f"unexpected flattened length: consumed {index}, input has {len(flattened)}")
    return matrix


def load_quantized_model(model_dir: Path) -> tuple[list[list[int]], list[int], list[list[int]], list[int], dict[str, object]]:
    summary = json.loads((model_dir / "summary.json").read_text(encoding="ascii"))
    input_size = int(summary["input_size"])
    hidden_size = int(summary["hidden_size"])
    output_size = int(summary["output_size"])
    tile_width = int(summary["tile_width"])

    flat_w1 = parse_s16_memh(model_dir / "w1_tiled_q8_8.memh")
    b1 = parse_s16_memh(model_dir / "b1_q8_8.memh")
    flat_w2 = parse_s16_memh(model_dir / "w2_tiled_q8_8.memh")
    b2 = parse_s16_memh(model_dir / "b2_q8_8.memh")

    if len(flat_w1) != input_size * hidden_size:
        raise ValueError("w1 size mismatch against model summary")
    if len(b1) != hidden_size:
        raise ValueError("b1 size mismatch against model summary")
    if len(flat_w2) != hidden_size * output_size:
        raise ValueError("w2 size mismatch against model summary")
    if len(b2) != output_size:
        raise ValueError("b2 size mismatch against model summary")

    w1 = unflatten_weights_for_tiles(flat_w1, input_size=input_size, output_size=hidden_size, tile_width=tile_width)
    w2 = unflatten_weights_for_tiles(flat_w2, input_size=hidden_size, output_size=output_size, tile_width=tile_width)
    return w1, b1, w2, b2, summary


def transform_points(
    points: list[tuple[float, float]],
    rng: np.random.Generator,
) -> list[tuple[float, float]]:
    center = np.array([13.5, 13.5], dtype=np.float32)
    angle = float(rng.uniform(-20.0, 20.0))
    angle_rad = np.deg2rad(angle)
    scale_x = float(rng.uniform(0.78, 1.22))
    scale_y = float(rng.uniform(0.78, 1.22))
    shear = float(rng.uniform(-0.22, 0.22))
    row_shift = float(rng.uniform(-3.0, 3.0))
    col_shift = float(rng.uniform(-3.0, 3.0))
    row_slant = float(rng.uniform(-0.22, 0.22))

    rotation = np.array(
        [
            [np.cos(angle_rad), -np.sin(angle_rad)],
            [np.sin(angle_rad), np.cos(angle_rad)],
        ],
        dtype=np.float32,
    )
    affine = rotation @ np.array([[scale_x, shear], [0.0, scale_y]], dtype=np.float32)

    transformed: list[tuple[float, float]] = []
    for row, col in points:
        jittered = np.array(
            [
                row + float(rng.uniform(-1.2, 1.2)),
                col + float(rng.uniform(-1.2, 1.2)),
            ],
            dtype=np.float32,
        )
        centered = np.array([jittered[1] - center[1], jittered[0] - center[0]], dtype=np.float32)
        warped = affine @ centered
        new_col = float(warped[0] + center[1] + col_shift)
        new_row = float(warped[1] + center[0] + row_shift)
        new_col += (new_row - center[0]) * row_slant
        transformed.append((new_row, new_col))
    return transformed


def draw_digit_bits(
    digit: int,
    rng: np.random.Generator,
) -> list[int]:
    if digit not in DIGIT_TEMPLATES:
        raise ValueError(f"unsupported digit {digit}")

    brush_radius = int(rng.integers(1, 3))  # 3x3 to 5x5 footprint
    canvas = np.zeros((IMAGE_SIDE, IMAGE_SIDE), dtype=np.uint8)

    for stroke in DIGIT_TEMPLATES[digit]:
        transformed = transform_points(stroke, rng)
        for start, stop in zip(transformed[:-1], transformed[1:]):
            if rng.random() < 0.06:
                continue  # simulate pen lift/drop segment
            start_rc = (int(round(start[0])), int(round(start[1])))
            stop_rc = (int(round(stop[0])), int(round(stop[1])))
            cells = stroke_cells(start_rc, stop_rc, rows=IMAGE_SIDE, cols=IMAGE_SIDE, radius=brush_radius)
            for row, col in cells:
                canvas[row, col] = 1

    # Sparse dropout and noise to mimic touch jitter and frame imperfections.
    active = canvas == 1
    if np.any(active):
        drop_prob = float(rng.uniform(0.0, 0.08))
        drop_mask = (rng.random(canvas.shape) < drop_prob) & active
        canvas[drop_mask] = 0
    salt_prob = float(rng.uniform(0.0, 0.02))
    pepper_prob = float(rng.uniform(0.0, 0.03))
    canvas[rng.random(canvas.shape) < salt_prob] = 1
    canvas[rng.random(canvas.shape) < pepper_prob] = 0

    if not np.any(canvas):
        # Fallback to a minimally transformed redraw if aggressive noise cleared everything.
        for stroke in DIGIT_TEMPLATES[digit]:
            for start, stop in zip(stroke[:-1], stroke[1:]):
                start_rc = (int(round(start[0])), int(round(start[1])))
                stop_rc = (int(round(stop[0])), int(round(stop[1])))
                cells = stroke_cells(start_rc, stop_rc, rows=IMAGE_SIDE, cols=IMAGE_SIDE, radius=1)
                for row, col in cells:
                    canvas[row, col] = 1

    return [int(value) for value in canvas.reshape(IMAGE_PIXELS).tolist()]


def main() -> int:
    args = parse_args()
    if args.samples_per_digit <= 0:
        raise ValueError("samples_per_digit must be positive")
    if args.preview_per_digit < 0:
        raise ValueError("preview_per_digit must be non-negative")

    rng = np.random.default_rng(args.seed)
    output_dir = args.output_dir
    previews_dir = output_dir / "previews"
    output_dir.mkdir(parents=True, exist_ok=True)
    previews_dir.mkdir(parents=True, exist_ok=True)

    w1, b1, w2, b2, model_summary = load_quantized_model(MODEL_DIR)

    confusion = [[0 for _ in range(10)] for _ in range(10)]
    rows: list[dict[str, object]] = []

    for label in range(10):
        for sample_index in range(args.samples_per_digit):
            bits = draw_digit_bits(label, rng)
            _, logits, prediction = run_quantized_inference(bits=bits, w1=w1, b1=b1, w2=w2, b2=b2)
            confusion[label][prediction] += 1

            ones_count = int(sum(bits))
            rows.append(
                {
                    "label": label,
                    "sample_index": sample_index,
                    "prediction": prediction,
                    "correct": int(prediction == label),
                    "ones_count": ones_count,
                    "max_logit_q8_8": int(max(logits)),
                }
            )

            if sample_index < args.preview_per_digit:
                stem = f"digit_{label}_sample_{sample_index:03d}_pred_{prediction}"
                write_png(previews_dir / f"{stem}.png", bits)
                write_ascii(previews_dir / f"{stem}.txt", bits)

    total = len(rows)
    correct = int(sum(int(row["correct"]) for row in rows))
    per_digit = {
        str(label): {
            "correct": int(confusion[label][label]),
            "total": int(args.samples_per_digit),
            "accuracy": float(confusion[label][label] / args.samples_per_digit),
        }
        for label in range(10)
    }

    results = {
        "seed": args.seed,
        "samples_per_digit": args.samples_per_digit,
        "total_samples": total,
        "correct_samples": correct,
        "accuracy": float(correct / total),
        "confusion_matrix": confusion,
        "per_digit_accuracy": per_digit,
        "model_summary": model_summary,
    }

    (output_dir / "results.json").write_text(json.dumps(results, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with (output_dir / "predictions.csv").open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=["label", "sample_index", "prediction", "correct", "ones_count", "max_logit_q8_8"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote benchmark artifacts to {output_dir}")
    print(f"accuracy={correct / total:.4f} ({correct}/{total})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
