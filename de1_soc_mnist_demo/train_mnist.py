# ABOUTME: Trains and exports a quantized MNIST classifier for the DE1-SoC Tiny-TPU demo.
# ABOUTME: Produces tile-ordered Q8.8 memory files that match the planned 2-lane TPU scheduler.

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np
from sklearn.datasets import fetch_openml
from sklearn.neural_network import MLPClassifier

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from de1_soc_mnist_demo.mnist_tools import flatten_weights_for_tiles
from de1_soc_mnist_demo.mnist_tools import pack_binary_image
from de1_soc_mnist_demo.mnist_tools import quantize_q8_8
from de1_soc_mnist_demo.mnist_tools import to_u16_hex


MNIST_TRAIN_SAMPLES = 60000
MNIST_TEST_SAMPLES = 10000


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hidden-size", type=int, default=64)
    parser.add_argument("--tile-width", type=int, default=2)
    parser.add_argument("--train-limit", type=int, default=20000)
    parser.add_argument("--test-limit", type=int, default=2000)
    parser.add_argument("--max-iter", type=int, default=20)
    parser.add_argument("--pixel-threshold", type=float, default=0.0)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("de1_soc_mnist_demo/generated_model"),
    )
    return parser.parse_args()


def load_binarized_mnist(
    train_limit: int,
    test_limit: int,
    pixel_threshold: float,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    features, labels = fetch_openml(
        "mnist_784",
        version=1,
        as_frame=False,
        return_X_y=True,
        parser="liac-arff",
    )
    features = (features > pixel_threshold).astype(np.float32)
    labels = labels.astype(np.int64)

    if train_limit <= 0 or train_limit > MNIST_TRAIN_SAMPLES:
        raise ValueError("train_limit must be in 1..60000")
    if test_limit <= 0 or test_limit > MNIST_TEST_SAMPLES:
        raise ValueError("test_limit must be in 1..10000")

    train_x = features[:train_limit]
    train_y = labels[:train_limit]
    test_x = features[MNIST_TRAIN_SAMPLES:MNIST_TRAIN_SAMPLES + test_limit]
    test_y = labels[MNIST_TRAIN_SAMPLES:MNIST_TRAIN_SAMPLES + test_limit]
    return train_x, train_y, test_x, test_y


def quantize_matrix(matrix: np.ndarray) -> list[list[int]]:
    return [
        [quantize_q8_8(float(value)) for value in row]
        for row in matrix.tolist()
    ]


def quantize_vector(vector: np.ndarray) -> list[int]:
    return [quantize_q8_8(float(value)) for value in vector.tolist()]


def write_memh(path: Path, values: list[int]) -> None:
    lines = [to_u16_hex(value) for value in values]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def write_summary(path: Path, payload: dict[str, object]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="ascii")


def export_model(
    model: MLPClassifier,
    output_dir: Path,
    tile_width: int,
    sample_bits: list[int],
    sample_label: int,
    accuracy: float,
    train_limit: int,
    test_limit: int,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    w1 = quantize_matrix(model.coefs_[0])
    b1 = quantize_vector(model.intercepts_[0])
    w2 = quantize_matrix(model.coefs_[1])
    b2 = quantize_vector(model.intercepts_[1])

    write_memh(output_dir / "w1_tiled_q8_8.memh", flatten_weights_for_tiles(w1, tile_width))
    write_memh(output_dir / "b1_q8_8.memh", b1)
    write_memh(output_dir / "w2_tiled_q8_8.memh", flatten_weights_for_tiles(w2, tile_width))
    write_memh(output_dir / "b2_q8_8.memh", b2)

    (output_dir / "sample_image_0.bin").write_bytes(pack_binary_image(sample_bits))
    (output_dir / "sample_label_0.txt").write_text(f"{sample_label}\n", encoding="ascii")

    write_summary(
        output_dir / "summary.json",
        {
            "accuracy": accuracy,
            "hidden_size": len(b1),
            "input_size": len(w1),
            "output_size": len(b2),
            "test_limit": test_limit,
            "tile_width": tile_width,
            "train_limit": train_limit,
        },
    )


def main() -> None:
    args = parse_args()

    train_x, train_y, test_x, test_y = load_binarized_mnist(
        train_limit=args.train_limit,
        test_limit=args.test_limit,
        pixel_threshold=args.pixel_threshold,
    )

    model = MLPClassifier(
        hidden_layer_sizes=(args.hidden_size,),
        activation="relu",
        solver="adam",
        alpha=1e-4,
        batch_size=128,
        learning_rate_init=1e-3,
        max_iter=args.max_iter,
        random_state=args.seed,
    )
    model.fit(train_x, train_y)

    accuracy = float(model.score(test_x, test_y))
    sample_bits = [int(value) for value in test_x[0].tolist()]
    sample_label = int(test_y[0])

    export_model(
        model=model,
        output_dir=args.output_dir,
        tile_width=args.tile_width,
        sample_bits=sample_bits,
        sample_label=sample_label,
        accuracy=accuracy,
        train_limit=args.train_limit,
        test_limit=args.test_limit,
    )

    print(
        json.dumps(
            {
                "accuracy": accuracy,
                "hidden_size": args.hidden_size,
                "output_dir": str(args.output_dir),
                "test_limit": args.test_limit,
                "tile_width": args.tile_width,
                "train_limit": args.train_limit,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
