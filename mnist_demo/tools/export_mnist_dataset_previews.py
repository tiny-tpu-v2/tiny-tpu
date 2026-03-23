# ABOUTME: Exports labeled MNIST training/test datapoints as PNG previews for dataset quality inspection.
# ABOUTME: Uses the same OpenML dataset and binary thresholding convention as the training pipeline.

from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import struct
import zlib

import numpy as np
from sklearn.datasets import fetch_openml


IMAGE_SIZE = 28
PIXELS = IMAGE_SIZE * IMAGE_SIZE
MNIST_TRAIN_SAMPLES = 60000
MNIST_TEST_SAMPLES = 10000
DEFAULT_SCALE = 12

PROJECT_DIR = Path(__file__).resolve().parents[1]
MODEL_SUMMARY_PATH = PROJECT_DIR / "data" / "model" / "reference" / "summary.json"
OUTPUT_DIR_DEFAULT = PROJECT_DIR / "artifacts" / "previews" / "dataset"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR_DEFAULT)
    parser.add_argument("--per-digit-train", type=int, default=5)
    parser.add_argument("--per-digit-test", type=int, default=3)
    parser.add_argument("--scale", type=int, default=DEFAULT_SCALE)
    parser.add_argument("--pixel-threshold", type=float, default=0.0)
    parser.add_argument("--train-limit", type=int, default=0)
    parser.add_argument("--test-limit", type=int, default=0)
    return parser.parse_args()


def chunk(chunk_type: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
    return (
        struct.pack(">I", len(payload))
        + chunk_type
        + payload
        + struct.pack(">I", crc)
    )


def write_png_from_u8(
    path: Path,
    pixels_28x28: np.ndarray,
    scale: int,
) -> None:
    if pixels_28x28.shape != (IMAGE_SIZE, IMAGE_SIZE):
        raise ValueError(f"expected shape (28, 28), got {pixels_28x28.shape}")
    if scale <= 0:
        raise ValueError("scale must be positive")

    width = IMAGE_SIZE * scale
    height = IMAGE_SIZE * scale

    raw = bytearray()
    for out_y in range(height):
        raw.append(0)
        src_y = out_y // scale
        for out_x in range(width):
            src_x = out_x // scale
            raw.append(int(pixels_28x28[src_y, src_x]))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)

    with path.open("wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def load_train_test_limits(args: argparse.Namespace) -> tuple[int, int]:
    train_limit = args.train_limit
    test_limit = args.test_limit

    if (train_limit <= 0 or test_limit <= 0) and MODEL_SUMMARY_PATH.exists():
        summary = json.loads(MODEL_SUMMARY_PATH.read_text(encoding="ascii"))
        if train_limit <= 0:
            train_limit = int(summary.get("train_limit", 10000))
        if test_limit <= 0:
            test_limit = int(summary.get("test_limit", 2000))

    if train_limit <= 0:
        train_limit = 10000
    if test_limit <= 0:
        test_limit = 2000

    if train_limit > MNIST_TRAIN_SAMPLES:
        raise ValueError("train_limit exceeds 60000")
    if test_limit > MNIST_TEST_SAMPLES:
        raise ValueError("test_limit exceeds 10000")

    return train_limit, test_limit


def fetch_mnist() -> tuple[np.ndarray, np.ndarray]:
    features, labels = fetch_openml(
        "mnist_784",
        version=1,
        as_frame=False,
        return_X_y=True,
        parser="liac-arff",
    )
    labels = labels.astype(np.int64)
    return features, labels


def select_examples(
    labels: np.ndarray,
    start: int,
    stop: int,
    per_digit: int,
) -> list[int]:
    counts = [0] * 10
    selected: list[int] = []
    for index in range(start, stop):
        label = int(labels[index])
        if counts[label] >= per_digit:
            continue
        selected.append(index)
        counts[label] += 1
        if all(count >= per_digit for count in counts):
            break
    return selected


def build_index(entries: list[dict[str, object]]) -> str:
    cards: list[str] = []
    for entry in entries:
        split = str(entry["split"])
        label = int(entry["label"])
        index = int(entry["global_index"])
        rel = int(entry["relative_index"])
        ones = int(entry["ones_count"])
        gray = str(entry["gray_png"])
        binary = str(entry["binary_png"])
        cards.append(
            "<div class='card'>"
            f"<h3>{html.escape(split)} idx={rel} label={label}</h3>"
            "<div class='row'>"
            f"<div><img src='{html.escape(gray)}' alt='gray' /><p>grayscale</p></div>"
            f"<div><img src='{html.escape(binary)}' alt='binary' /><p>binary ones={ones}</p></div>"
            "</div>"
            f"<p>global index: {index}</p>"
            "</div>"
        )

    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>MNIST Dataset Previews</title>"
        "<style>"
        "body{font-family:Arial,sans-serif;background:#f2f2f2;margin:24px;}"
        ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(520px,1fr));gap:16px;}"
        ".card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:12px;}"
        ".row{display:flex;gap:12px;}"
        ".row div{flex:1;}"
        "img{width:100%;height:auto;border:1px solid #ddd;image-rendering:pixelated;}"
        "h1{margin-top:0;}h3{margin:0 0 10px;font-size:16px;}p{margin:8px 0 0;color:#333;}"
        "</style></head><body>"
        "<h1>MNIST Dataset Previews</h1>"
        "<p>Left image is grayscale (inverted to black-strokes-on-white). Right image is the binary mask used by training.</p>"
        f"<div class='grid'>{''.join(cards)}</div>"
        "</body></html>"
    )


def main() -> int:
    args = parse_args()
    train_limit, test_limit = load_train_test_limits(args)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    features, labels = fetch_mnist()

    train_selected = select_examples(labels, 0, train_limit, args.per_digit_train)
    test_start = MNIST_TRAIN_SAMPLES
    test_selected = select_examples(labels, test_start, test_start + test_limit, args.per_digit_test)

    entries: list[dict[str, object]] = []

    for split, indices in (("train", train_selected), ("test", test_selected)):
        for global_index in indices:
            label = int(labels[global_index])
            if split == "train":
                relative_index = global_index
            else:
                relative_index = global_index - MNIST_TRAIN_SAMPLES

            sample = features[global_index].reshape(IMAGE_SIZE, IMAGE_SIZE)
            sample_u8 = np.clip(sample, 0, 255).astype(np.uint8)
            gray_inverted = (255 - sample_u8).astype(np.uint8)
            binary = (sample > args.pixel_threshold).astype(np.uint8)
            binary_u8 = np.where(binary == 1, 0, 255).astype(np.uint8)

            stem = f"{split}_idx_{relative_index:05d}_label_{label}"
            gray_name = f"{stem}_gray.png"
            binary_name = f"{stem}_binary.png"

            write_png_from_u8(args.output_dir / gray_name, gray_inverted, args.scale)
            write_png_from_u8(args.output_dir / binary_name, binary_u8, args.scale)

            entries.append(
                {
                    "split": split,
                    "label": label,
                    "global_index": int(global_index),
                    "relative_index": int(relative_index),
                    "ones_count": int(binary.sum()),
                    "gray_png": gray_name,
                    "binary_png": binary_name,
                }
            )

    metadata = {
        "train_limit": train_limit,
        "test_limit": test_limit,
        "pixel_threshold": args.pixel_threshold,
        "per_digit_train": args.per_digit_train,
        "per_digit_test": args.per_digit_test,
        "entries": entries,
    }
    (args.output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (args.output_dir / "index.html").write_text(build_index(entries), encoding="utf-8")

    print(f"wrote {len(entries)} samples to {args.output_dir}")
    print(f"index: {args.output_dir / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
