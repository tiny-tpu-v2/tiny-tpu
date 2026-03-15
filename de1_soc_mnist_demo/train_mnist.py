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
Q8_8_SHIFT = 8
IMAGE_SIDE = 28
IMAGE_PIXELS = IMAGE_SIDE * IMAGE_SIDE


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hidden-size", type=int, default=64)
    parser.add_argument("--tile-width", type=int, default=2)
    parser.add_argument("--train-limit", type=int, default=20000)
    parser.add_argument("--test-limit", type=int, default=2000)
    parser.add_argument("--max-iter", type=int, default=20)
    parser.add_argument("--pixel-threshold", type=float, default=0.0)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--augment-copies", type=int, default=0)
    parser.add_argument(
        "--augment-mode",
        choices=["none", "strong", "extreme"],
        default="none",
    )
    parser.add_argument(
        "--split-mode",
        choices=["balanced", "contiguous"],
        default="balanced",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("generated_model"),
    )
    return parser.parse_args()


def summarize_class_counts(labels: np.ndarray, num_classes: int) -> dict[str, int]:
    counts = np.bincount(labels, minlength=num_classes)
    return {str(index): int(counts[index]) for index in range(num_classes)}


def select_balanced_subset(
    features: np.ndarray,
    labels: np.ndarray,
    limit: int,
    num_classes: int,
    seed: int,
) -> tuple[np.ndarray, np.ndarray, dict[str, int]]:
    if limit <= 0 or limit > labels.shape[0]:
        raise ValueError("limit must be in 1..len(labels)")
    if num_classes <= 0:
        raise ValueError("num_classes must be positive")

    rng = np.random.default_rng(seed)
    target_counts = np.full(num_classes, limit // num_classes, dtype=np.int64)
    remainder = limit % num_classes
    if remainder:
        class_order = np.arange(num_classes, dtype=np.int64)
        rng.shuffle(class_order)
        target_counts[class_order[:remainder]] += 1

    selected_indices: list[np.ndarray] = []
    for class_id in range(num_classes):
        class_indices = np.flatnonzero(labels == class_id)
        if class_indices.shape[0] < target_counts[class_id]:
            raise ValueError(
                f"class {class_id} has {class_indices.shape[0]} samples, "
                f"needs {target_counts[class_id]}"
            )
        chosen = rng.choice(
            class_indices,
            size=int(target_counts[class_id]),
            replace=False,
        )
        selected_indices.append(chosen)

    merged_indices = np.concatenate(selected_indices, axis=0)
    rng.shuffle(merged_indices)
    subset_x = features[merged_indices]
    subset_y = labels[merged_indices]
    return subset_x, subset_y, summarize_class_counts(subset_y, num_classes)


def load_binarized_mnist(
    train_limit: int,
    test_limit: int,
    pixel_threshold: float,
    seed: int,
    split_mode: str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, dict[str, int], dict[str, int]]:
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

    full_train_x = features[:MNIST_TRAIN_SAMPLES]
    full_train_y = labels[:MNIST_TRAIN_SAMPLES]
    full_test_x = features[MNIST_TRAIN_SAMPLES:MNIST_TRAIN_SAMPLES + MNIST_TEST_SAMPLES]
    full_test_y = labels[MNIST_TRAIN_SAMPLES:MNIST_TRAIN_SAMPLES + MNIST_TEST_SAMPLES]

    if split_mode == "balanced":
        train_x, train_y, train_counts = select_balanced_subset(
            features=full_train_x,
            labels=full_train_y,
            limit=train_limit,
            num_classes=10,
            seed=seed,
        )
        test_x, test_y, test_counts = select_balanced_subset(
            features=full_test_x,
            labels=full_test_y,
            limit=test_limit,
            num_classes=10,
            seed=seed + 1,
        )
    elif split_mode == "contiguous":
        train_x = full_train_x[:train_limit]
        train_y = full_train_y[:train_limit]
        test_x = full_test_x[:test_limit]
        test_y = full_test_y[:test_limit]
        train_counts = summarize_class_counts(train_y, 10)
        test_counts = summarize_class_counts(test_y, 10)
    else:
        raise ValueError(f"unsupported split_mode: {split_mode}")

    return train_x, train_y, test_x, test_y, train_counts, test_counts


def shift_binary_image(image: np.ndarray, row_shift: int, col_shift: int) -> np.ndarray:
    shifted = np.zeros_like(image)
    src_row_start = max(0, -row_shift)
    src_row_stop = IMAGE_SIDE - max(0, row_shift)
    src_col_start = max(0, -col_shift)
    src_col_stop = IMAGE_SIDE - max(0, col_shift)
    dst_row_start = max(0, row_shift)
    dst_row_stop = IMAGE_SIDE - max(0, -row_shift)
    dst_col_start = max(0, col_shift)
    dst_col_stop = IMAGE_SIDE - max(0, -col_shift)

    if src_row_start < src_row_stop and src_col_start < src_col_stop:
        shifted[dst_row_start:dst_row_stop, dst_col_start:dst_col_stop] = image[
            src_row_start:src_row_stop,
            src_col_start:src_col_stop,
        ]
    return shifted


def dilate_binary_image(image: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return image.copy()

    dilated = np.zeros_like(image)
    for row_delta in range(-radius, radius + 1):
        for col_delta in range(-radius, radius + 1):
            dilated = np.maximum(dilated, shift_binary_image(image, row_delta, col_delta))
    return dilated


def erode_binary_image(image: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return image.copy()
    return 1.0 - dilate_binary_image(1.0 - image, radius)


def apply_affine_nearest(
    image: np.ndarray,
    transform: np.ndarray,
    row_shift: float,
    col_shift: float,
) -> np.ndarray:
    center = (IMAGE_SIDE - 1) / 2.0
    dst_rows, dst_cols = np.indices((IMAGE_SIDE, IMAGE_SIDE), dtype=np.float32)
    centered_cols = dst_cols.ravel() - center - col_shift
    centered_rows = dst_rows.ravel() - center - row_shift
    dst_points = np.stack([centered_cols, centered_rows], axis=0)

    try:
        inverse_transform = np.linalg.inv(transform)
    except np.linalg.LinAlgError:
        return image.copy()

    src_points = inverse_transform @ dst_points
    src_cols = np.rint(src_points[0] + center).astype(np.int64)
    src_rows = np.rint(src_points[1] + center).astype(np.int64)
    valid = (
        (src_rows >= 0)
        & (src_rows < IMAGE_SIDE)
        & (src_cols >= 0)
        & (src_cols < IMAGE_SIDE)
    )

    output = np.zeros_like(image)
    output_flat = output.ravel()
    valid_positions = np.flatnonzero(valid)
    output_flat[valid_positions] = image[src_rows[valid], src_cols[valid]]
    return output


def apply_row_slant(image: np.ndarray, slant: int) -> np.ndarray:
    if slant == 0:
        return image.copy()

    center = (IMAGE_SIDE - 1) / 2.0
    slanted = np.zeros_like(image)
    for row in range(IMAGE_SIDE):
        row_from_center = row - center
        row_ratio = row_from_center / center if center != 0 else 0.0
        row_shift = int(round(row_ratio * slant))
        if row_shift >= 0:
            slanted[row, row_shift:] = image[row, : IMAGE_SIDE - row_shift]
        else:
            slanted[row, : IMAGE_SIDE + row_shift] = image[row, -row_shift:]
    return slanted


def carve_random_holes(
    image: np.ndarray,
    rng: np.random.Generator,
    max_holes: int,
    max_size: int,
) -> np.ndarray:
    carved = image.copy()
    holes = int(rng.integers(0, max_holes + 1))
    for _ in range(holes):
        hole_height = int(rng.integers(1, max_size + 1))
        hole_width = int(rng.integers(1, max_size + 1))
        row_start = int(rng.integers(0, IMAGE_SIDE - hole_height + 1))
        col_start = int(rng.integers(0, IMAGE_SIDE - hole_width + 1))
        carved[row_start:row_start + hole_height, col_start:col_start + hole_width] = 0.0
    return carved


def add_random_blobs(
    image: np.ndarray,
    rng: np.random.Generator,
    max_blobs: int,
    max_size: int,
) -> np.ndarray:
    blobbed = image.copy()
    blobs = int(rng.integers(0, max_blobs + 1))
    for _ in range(blobs):
        blob_height = int(rng.integers(1, max_size + 1))
        blob_width = int(rng.integers(1, max_size + 1))
        row_start = int(rng.integers(0, IMAGE_SIDE - blob_height + 1))
        col_start = int(rng.integers(0, IMAGE_SIDE - blob_width + 1))
        blobbed[row_start:row_start + blob_height, col_start:col_start + blob_width] = 1.0
    return blobbed


def random_binary_augmentation(
    flat_bits: np.ndarray,
    rng: np.random.Generator,
    mode: str,
) -> np.ndarray:
    if flat_bits.shape[0] != IMAGE_PIXELS:
        raise ValueError(f"expected {IMAGE_PIXELS} pixels, got {flat_bits.shape[0]}")

    image = flat_bits.reshape(IMAGE_SIDE, IMAGE_SIDE).astype(np.float32, copy=True)
    original = image.copy()

    if mode == "strong":
        max_angle = 15.0
        scale_min = 0.80
        scale_max = 1.20
        max_shear = 0.18
        max_translate = 3.5
        max_slant = 3
        max_holes = 2
        max_hole_size = 4
        max_blobs = 1
        max_blob_size = 2
        drop_max = 0.08
        salt_max = 0.015
        pepper_max = 0.025
    elif mode == "extreme":
        max_angle = 25.0
        scale_min = 0.70
        scale_max = 1.30
        max_shear = 0.30
        max_translate = 5.0
        max_slant = 5
        max_holes = 3
        max_hole_size = 6
        max_blobs = 2
        max_blob_size = 3
        drop_max = 0.18
        salt_max = 0.03
        pepper_max = 0.05
    else:
        return flat_bits.astype(np.float32, copy=True)

    # Occasional recentering keeps the source shape aligned before heavy jitter.
    if rng.random() < 0.35:
        nonzero = np.argwhere(image > 0.5)
        if nonzero.size > 0:
            center_row = float(np.mean(nonzero[:, 0]))
            center_col = float(np.mean(nonzero[:, 1]))
            row_shift = int(round(((IMAGE_SIDE - 1) / 2.0) - center_row))
            col_shift = int(round(((IMAGE_SIDE - 1) / 2.0) - center_col))
            image = shift_binary_image(image, row_shift, col_shift)

    angle = float(rng.uniform(-max_angle, max_angle))
    angle_rad = np.deg2rad(angle)
    scale_x = float(rng.uniform(scale_min, scale_max))
    scale_y = float(rng.uniform(scale_min, scale_max))
    shear_x = float(rng.uniform(-max_shear, max_shear))
    shear_y = float(rng.uniform(-max_shear, max_shear))
    row_shift_f = float(rng.uniform(-max_translate, max_translate))
    col_shift_f = float(rng.uniform(-max_translate, max_translate))

    rotation = np.array(
        [
            [np.cos(angle_rad), -np.sin(angle_rad)],
            [np.sin(angle_rad), np.cos(angle_rad)],
        ],
        dtype=np.float32,
    )
    shear = np.array(
        [
            [1.0, shear_x],
            [shear_y, 1.0],
        ],
        dtype=np.float32,
    )
    scale = np.array(
        [
            [scale_x, 0.0],
            [0.0, scale_y],
        ],
        dtype=np.float32,
    )
    transform = rotation @ shear @ scale
    image = apply_affine_nearest(
        image=image,
        transform=transform,
        row_shift=row_shift_f,
        col_shift=col_shift_f,
    )

    slant = int(rng.integers(-max_slant, max_slant + 1))
    image = apply_row_slant(image, slant)

    if rng.random() < 0.90:
        dilation_radius = int(rng.integers(1, 3))
        image = dilate_binary_image(image, dilation_radius)
    if rng.random() < 0.30:
        erosion_radius = int(rng.integers(1, 3))
        image = erode_binary_image(image, erosion_radius)

    image = carve_random_holes(
        image=image,
        rng=rng,
        max_holes=max_holes,
        max_size=max_hole_size,
    )
    image = add_random_blobs(
        image=image,
        rng=rng,
        max_blobs=max_blobs,
        max_size=max_blob_size,
    )

    active_drop_prob = float(rng.uniform(0.0, drop_max))
    salt_prob = float(rng.uniform(0.0, salt_max))
    pepper_prob = float(rng.uniform(0.0, pepper_max))

    active_mask = image > 0.5
    if active_drop_prob > 0:
        drop_mask = (rng.random(image.shape) < active_drop_prob) & active_mask
        image[drop_mask] = 0.0
    if salt_prob > 0:
        image[rng.random(image.shape) < salt_prob] = 1.0
    if pepper_prob > 0:
        image[rng.random(image.shape) < pepper_prob] = 0.0

    image = (image > 0.5).astype(np.float32)
    if not np.any(image):
        image = original

    return image.reshape(IMAGE_PIXELS)


def augment_training_set(
    train_x: np.ndarray,
    train_y: np.ndarray,
    copies: int,
    mode: str,
    seed: int,
) -> tuple[np.ndarray, np.ndarray]:
    if copies <= 0 or mode == "none":
        return train_x, train_y

    if train_x.shape[1] != IMAGE_PIXELS:
        raise ValueError(f"expected flattened 28x28 inputs, got shape {train_x.shape}")

    rng = np.random.default_rng(seed)
    base_count = train_x.shape[0]
    total_count = base_count * (copies + 1)

    augmented_x = np.empty((total_count, train_x.shape[1]), dtype=np.float32)
    augmented_y = np.empty((total_count,), dtype=train_y.dtype)

    augmented_x[:base_count] = train_x
    augmented_y[:base_count] = train_y
    write_index = base_count

    for sample_index in range(base_count):
        sample_bits = train_x[sample_index]
        sample_label = train_y[sample_index]
        for _ in range(copies):
            augmented_x[write_index] = random_binary_augmentation(
                flat_bits=sample_bits,
                rng=rng,
                mode=mode,
            )
            augmented_y[write_index] = sample_label
            write_index += 1

    permutation = rng.permutation(total_count)
    return augmented_x[permutation], augmented_y[permutation]


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


def write_byte_memh(path: Path, values: list[int]) -> None:
    lines = [f"{value & 0xFF:02X}" for value in values]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def write_summary(path: Path, payload: dict[str, object]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="ascii")


def wrap_s16(value: int) -> int:
    wrapped = value & 0xFFFF
    if wrapped >= 0x8000:
        return wrapped - 0x10000
    return wrapped


def sat_add16(left: int, right: int) -> int:
    result = left + right
    if result > 0x7FFF:
        return 0x7FFF
    if result < -0x8000:
        return -0x8000
    return result


def q8_8_mul(left: int, right: int) -> int:
    return wrap_s16((left * right) >> Q8_8_SHIFT)


def run_quantized_inference(
    bits: list[int],
    w1: list[list[int]],
    b1: list[int],
    w2: list[list[int]],
    b2: list[int],
) -> tuple[list[int], list[int], int]:
    q8_inputs = [0x0100 if bit else 0x0000 for bit in bits]

    hidden_values: list[int] = []
    for hidden_index in range(len(b1)):
        acc = 0
        for input_index in range(len(q8_inputs)):
            product = q8_8_mul(q8_inputs[input_index], w1[input_index][hidden_index])
            acc = sat_add16(acc, product)
        biased = sat_add16(acc, b1[hidden_index])
        hidden_values.append(max(0, biased))

    logits: list[int] = []
    for output_index in range(len(b2)):
        acc = 0
        for hidden_index in range(len(hidden_values)):
            product = q8_8_mul(hidden_values[hidden_index], w2[hidden_index][output_index])
            acc = sat_add16(acc, product)
        logits.append(sat_add16(acc, b2[output_index]))

    prediction = int(np.argmax(np.array(logits, dtype=np.int64)))
    return hidden_values, logits, prediction


def export_model(
    model: MLPClassifier,
    output_dir: Path,
    tile_width: int,
    sample_bits: list[int],
    sample_label: int,
    accuracy: float,
    train_limit: int,
    test_limit: int,
    split_mode: str,
    train_class_counts: dict[str, int],
    test_class_counts: dict[str, int],
    augment_mode: str,
    augment_copies: int,
    effective_train_samples: int,
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

    sample_bytes = list(pack_binary_image(sample_bits))
    (output_dir / "sample_image_0.bin").write_bytes(bytes(sample_bytes))
    write_byte_memh(output_dir / "sample_image_0.memh", sample_bytes)

    hidden_values, logits, prediction = run_quantized_inference(
        bits=sample_bits,
        w1=w1,
        b1=b1,
        w2=w2,
        b2=b2,
    )
    write_memh(output_dir / "sample_expected_hidden_0_q8_8.memh", hidden_values)
    write_memh(output_dir / "sample_expected_logits_0_q8_8.memh", logits)
    (output_dir / "sample_expected_prediction_0.txt").write_text(f"{prediction}\n", encoding="ascii")

    (output_dir / "sample_label_0.txt").write_text(f"{sample_label}\n", encoding="ascii")

    write_summary(
        output_dir / "summary.json",
        {
            "accuracy": accuracy,
            "hidden_size": len(b1),
            "input_size": len(w1),
            "output_size": len(b2),
            "split_mode": split_mode,
            "test_limit": test_limit,
            "test_class_counts": test_class_counts,
            "tile_width": tile_width,
            "train_limit": train_limit,
            "train_class_counts": train_class_counts,
            "augment_mode": augment_mode,
            "augment_copies": augment_copies,
            "effective_train_samples": effective_train_samples,
        },
    )


def main() -> None:
    args = parse_args()

    train_x, train_y, test_x, test_y, train_counts, test_counts = load_binarized_mnist(
        train_limit=args.train_limit,
        test_limit=args.test_limit,
        pixel_threshold=args.pixel_threshold,
        seed=args.seed,
        split_mode=args.split_mode,
    )

    train_x, train_y = augment_training_set(
        train_x=train_x,
        train_y=train_y,
        copies=args.augment_copies,
        mode=args.augment_mode,
        seed=args.seed + 101,
    )
    train_counts = summarize_class_counts(train_y, 10)

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
        split_mode=args.split_mode,
        train_class_counts=train_counts,
        test_class_counts=test_counts,
        augment_mode=args.augment_mode,
        augment_copies=args.augment_copies,
        effective_train_samples=int(train_x.shape[0]),
    )

    print(
        json.dumps(
            {
                "accuracy": accuracy,
                "hidden_size": args.hidden_size,
                "output_dir": str(args.output_dir),
                "split_mode": args.split_mode,
                "test_limit": args.test_limit,
                "test_class_counts": test_counts,
                "tile_width": args.tile_width,
                "train_limit": args.train_limit,
                "train_class_counts": train_counts,
                "augment_mode": args.augment_mode,
                "augment_copies": args.augment_copies,
                "effective_train_samples": int(train_x.shape[0]),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
