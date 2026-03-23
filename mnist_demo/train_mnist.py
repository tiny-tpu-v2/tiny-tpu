# ABOUTME: Trains and exports a quantization-aware MNIST classifier for the DE1-SoC Tiny-TPU demo.
# ABOUTME: Uses PyTorch, AdamW, bounded threshold sweeps, augmentation-strength schedules, and exact Q8.8 eval.

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys

import numpy as np
from sklearn.datasets import fetch_openml
import torch
from torch import nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torch.utils.data import Dataset

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
Q8_8_MIN = -128.0
Q8_8_MAX = 32767.0 / 256.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hidden-size", type=int, default=64)
    parser.add_argument("--tile-width", type=int, default=2)
    parser.add_argument("--train-limit", type=int, default=20000)
    parser.add_argument("--test-limit", type=int, default=2000)
    parser.add_argument("--max-iter", type=int, default=20)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--augment-copies", type=int, default=0)
    parser.add_argument("--augment-levels", type=int, default=2)
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
    parser.add_argument("--learning-rate", type=float, default=5e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-2)
    parser.add_argument("--batch-size", type=int, default=256)
    parser.add_argument("--pixel-threshold", type=float, default=None)
    parser.add_argument("--threshold-min-raw", type=int, default=0)
    parser.add_argument("--threshold-max-raw", type=int, default=75)
    parser.add_argument("--threshold-step-raw", type=int, default=25)
    parser.add_argument("--eval-threshold-raw", type=int, default=50)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("generated_model"),
    )
    return parser.parse_args()


def summarize_class_counts(labels: np.ndarray, num_classes: int) -> dict[str, int]:
    counts = np.bincount(labels, minlength=num_classes)
    return {str(index): int(counts[index]) for index in range(num_classes)}


def scale_class_counts(counts: dict[str, int], factor: int) -> dict[str, int]:
    return {key: int(value * factor) for key, value in counts.items()}


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


def load_mnist_grayscale(
    train_limit: int,
    test_limit: int,
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
    features = (features.astype(np.float32) / 255.0).clip(0.0, 1.0)
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
    strength: float,
) -> np.ndarray:
    if flat_bits.shape[0] != IMAGE_PIXELS:
        raise ValueError(f"expected {IMAGE_PIXELS} pixels, got {flat_bits.shape[0]}")
    if strength <= 0.0 or mode == "none":
        return flat_bits.astype(np.float32, copy=True)

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
    max_angle *= strength
    scale_span_low = (1.0 - scale_min) * strength
    scale_span_high = (scale_max - 1.0) * strength
    scale_min = 1.0 - scale_span_low
    scale_max = 1.0 + scale_span_high
    max_shear *= strength
    max_translate *= strength
    max_slant = int(round(max_slant * strength))
    max_holes = int(round(max_holes * strength))
    max_hole_size = max(1, int(round(max_hole_size * max(strength, 0.25)))) if max_holes > 0 else 0
    max_blobs = int(round(max_blobs * strength))
    max_blob_size = max(1, int(round(max_blob_size * max(strength, 0.25)))) if max_blobs > 0 else 0
    drop_max *= strength
    salt_max *= strength
    pepper_max *= strength

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

    if max_slant > 0:
        slant = int(rng.integers(-max_slant, max_slant + 1))
        image = apply_row_slant(image, slant)

    if rng.random() < (0.90 * strength):
        dilation_radius = max(1, int(rng.integers(1, 3)))
        image = dilate_binary_image(image, dilation_radius)
    if rng.random() < (0.30 * strength):
        erosion_radius = max(1, int(rng.integers(1, 3)))
        image = erode_binary_image(image, erosion_radius)

    if max_holes > 0 and max_hole_size > 0:
        image = carve_random_holes(
            image=image,
            rng=rng,
            max_holes=max_holes,
            max_size=max_hole_size,
        )
    if max_blobs > 0 and max_blob_size > 0:
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


def build_threshold_schedule(args: argparse.Namespace) -> tuple[list[float], float]:
    if args.pixel_threshold is not None:
        threshold = float(args.pixel_threshold)
        return [threshold], threshold

    threshold_min_raw = int(args.threshold_min_raw)
    threshold_max_raw = int(args.threshold_max_raw)
    threshold_step_raw = int(args.threshold_step_raw)
    eval_threshold_raw = int(args.eval_threshold_raw)

    for name, value in (
        ("threshold_min_raw", threshold_min_raw),
        ("threshold_max_raw", threshold_max_raw),
        ("eval_threshold_raw", eval_threshold_raw),
    ):
        if value < 0 or value > 255:
            raise ValueError(f"{name} must be in [0, 255]")
    if threshold_step_raw <= 0:
        raise ValueError("threshold_step_raw must be positive")
    if threshold_min_raw > threshold_max_raw:
        raise ValueError("threshold_min_raw must be <= threshold_max_raw")
    if eval_threshold_raw < threshold_min_raw or eval_threshold_raw > threshold_max_raw:
        raise ValueError("eval_threshold_raw must fall inside the bounded threshold sweep")

    threshold_values_raw = list(range(threshold_min_raw, threshold_max_raw + 1, threshold_step_raw))
    if threshold_values_raw[-1] != threshold_max_raw:
        threshold_values_raw.append(threshold_max_raw)
    threshold_values = [float(value) / 255.0 for value in threshold_values_raw]
    return threshold_values, float(eval_threshold_raw) / 255.0


def build_augmentation_strengths(args: argparse.Namespace) -> list[float]:
    if args.augment_mode == "none":
        return [0.0]
    if args.augment_levels <= 1:
        return [0.0, 1.0]

    levels = int(args.augment_levels)
    return [float(value) for value in np.linspace(0.0, 1.0, num=levels)]


def binarize_grayscale(flat_pixels: np.ndarray, threshold: float) -> np.ndarray:
    if flat_pixels.shape[0] != IMAGE_PIXELS:
        raise ValueError(f"expected {IMAGE_PIXELS} pixels, got {flat_pixels.shape[0]}")
    clipped_threshold = min(max(float(threshold), 0.0), 1.0)
    return (flat_pixels > clipped_threshold).astype(np.float32)


class SpectrumBinaryMnistDataset(Dataset[tuple[torch.Tensor, torch.Tensor]]):
    def __init__(
        self,
        raw_x: np.ndarray,
        raw_y: np.ndarray,
        *,
        training: bool,
        augment_copies: int,
        augment_mode: str,
        threshold_values: list[float],
        augment_strengths: list[float],
        seed: int,
    ) -> None:
        if raw_x.ndim != 2 or raw_x.shape[1] != IMAGE_PIXELS:
            raise ValueError(f"expected [N, {IMAGE_PIXELS}] grayscale inputs")
        if raw_y.ndim != 1 or raw_y.shape[0] != raw_x.shape[0]:
            raise ValueError("labels must align with raw_x")
        if augment_copies < 0:
            raise ValueError("augment_copies must be non-negative")
        if not threshold_values:
            raise ValueError("threshold_values must be non-empty")
        if not augment_strengths:
            raise ValueError("augment_strengths must be non-empty")

        self.raw_x = raw_x
        self.raw_y = raw_y
        self.training = training
        self.augment_copies = augment_copies
        self.augment_mode = augment_mode
        self.threshold_values = [float(value) for value in threshold_values]
        self.augment_strengths = [float(value) for value in augment_strengths]
        self.seed = seed
        self.epoch = 0
        self.threshold_count = len(self.threshold_values)
        self.augment_count = len(self.augment_strengths)
        self.replica_count = (augment_copies + 1) if training else 1

    def set_epoch(self, epoch: int) -> None:
        self.epoch = max(0, int(epoch))

    def __len__(self) -> int:
        return int(self.raw_y.shape[0] * self.threshold_count * self.augment_count * self.replica_count)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        base_count = int(self.raw_y.shape[0])
        sample_index = index % base_count
        combo_index = index // base_count
        threshold_index = combo_index % self.threshold_count
        combo_index //= self.threshold_count
        strength_index = combo_index % self.augment_count
        replica_index = combo_index // self.augment_count

        rng_seed = self.seed + (self.epoch * max(1, len(self))) + index
        rng = np.random.default_rng(rng_seed)

        threshold = self.threshold_values[threshold_index]
        strength = self.augment_strengths[strength_index]

        bits = binarize_grayscale(self.raw_x[sample_index], threshold)

        if self.training and self.augment_mode != "none" and strength > 0.0:
            bits = random_binary_augmentation(bits, rng=rng, mode=self.augment_mode, strength=strength)
        elif self.training and replica_index > 0 and self.augment_mode != "none" and strength == 0.0:
            bits = bits.copy()

        return (
            torch.from_numpy(bits.astype(np.float32, copy=False)),
            torch.tensor(int(self.raw_y[sample_index]), dtype=torch.long),
        )


def fake_quantize_q8_8_tensor(tensor: torch.Tensor) -> torch.Tensor:
    clamped = torch.clamp(tensor, Q8_8_MIN, Q8_8_MAX)
    quantized = torch.round(clamped * 256.0) / 256.0
    return clamped + (quantized - clamped).detach()


class QuantizedMnistMLP(nn.Module):
    def __init__(self, input_size: int, hidden_size: int, output_size: int) -> None:
        super().__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.fc2 = nn.Linear(hidden_size, output_size)

    def forward(self, inputs: torch.Tensor) -> torch.Tensor:
        x = fake_quantize_q8_8_tensor(inputs)

        w1 = fake_quantize_q8_8_tensor(self.fc1.weight)
        b1 = fake_quantize_q8_8_tensor(self.fc1.bias)
        x = F.linear(x, w1, b1)
        x = fake_quantize_q8_8_tensor(x)
        x = F.relu(x)
        x = fake_quantize_q8_8_tensor(x)

        w2 = fake_quantize_q8_8_tensor(self.fc2.weight)
        b2 = fake_quantize_q8_8_tensor(self.fc2.bias)
        x = F.linear(x, w2, b2)
        x = fake_quantize_q8_8_tensor(x)
        return x


def quantize_tensor_to_q8_8_int(tensor: torch.Tensor) -> torch.Tensor:
    quantized = torch.round(torch.clamp(tensor, Q8_8_MIN, Q8_8_MAX) * 256.0).to(torch.int32)
    return torch.clamp(quantized, min=-0x8000, max=0x7FFF)


def wrap_s16_tensor(tensor: torch.Tensor) -> torch.Tensor:
    wrapped = torch.bitwise_and(tensor, 0xFFFF)
    return torch.where(wrapped >= 0x8000, wrapped - 0x10000, wrapped)


def sat_add_tensor(left: torch.Tensor, right: torch.Tensor) -> torch.Tensor:
    return torch.clamp(left + right, min=-0x8000, max=0x7FFF)


def extract_quantized_parameters(
    model: QuantizedMnistMLP,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
    with torch.no_grad():
        w1 = quantize_tensor_to_q8_8_int(model.fc1.weight.detach().cpu()).transpose(0, 1).contiguous()
        b1 = quantize_tensor_to_q8_8_int(model.fc1.bias.detach().cpu())
        w2 = quantize_tensor_to_q8_8_int(model.fc2.weight.detach().cpu()).transpose(0, 1).contiguous()
        b2 = quantize_tensor_to_q8_8_int(model.fc2.bias.detach().cpu())
    return w1, b1, w2, b2


def exact_q8_8_batch_inference(
    bits_batch: torch.Tensor,
    w1: torch.Tensor,
    b1: torch.Tensor,
    w2: torch.Tensor,
    b2: torch.Tensor,
) -> torch.Tensor:
    q_inputs = torch.where(bits_batch > 0.5, 0x0100, 0x0000).to(torch.int32)

    hidden_acc = torch.zeros((q_inputs.shape[0], w1.shape[1]), dtype=torch.int32)
    for input_index in range(q_inputs.shape[1]):
        products = wrap_s16_tensor((q_inputs[:, input_index:input_index + 1] * w1[input_index].unsqueeze(0)) >> Q8_8_SHIFT)
        hidden_acc = sat_add_tensor(hidden_acc, products)

    hidden = sat_add_tensor(hidden_acc, b1.unsqueeze(0))
    hidden = torch.clamp(hidden, min=0, max=0x7FFF)

    logits_acc = torch.zeros((hidden.shape[0], w2.shape[1]), dtype=torch.int32)
    for hidden_index in range(hidden.shape[1]):
        products = wrap_s16_tensor((hidden[:, hidden_index:hidden_index + 1] * w2[hidden_index].unsqueeze(0)) >> Q8_8_SHIFT)
        logits_acc = sat_add_tensor(logits_acc, products)

    return sat_add_tensor(logits_acc, b2.unsqueeze(0))


def evaluate_exact_q8_8_accuracy(
    model: QuantizedMnistMLP,
    data_loader: DataLoader[tuple[torch.Tensor, torch.Tensor]],
) -> float:
    w1, b1, w2, b2 = extract_quantized_parameters(model)
    correct = 0
    total = 0

    for batch_x, batch_y in data_loader:
        logits = exact_q8_8_batch_inference(batch_x, w1, b1, w2, b2)
        predictions = torch.argmax(logits, dim=1)
        correct += int((predictions == batch_y.to(torch.int64)).sum().item())
        total += int(batch_y.shape[0])

    return (correct / total) if total else 0.0


def train_model(
    model: QuantizedMnistMLP,
    train_loader: DataLoader[tuple[torch.Tensor, torch.Tensor]],
    train_dataset: SpectrumBinaryMnistDataset,
    test_loader: DataLoader[tuple[torch.Tensor, torch.Tensor]],
    *,
    epochs: int,
    learning_rate: float,
    weight_decay: float,
    device: torch.device,
) -> tuple[QuantizedMnistMLP, float]:
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=learning_rate,
        weight_decay=weight_decay,
    )
    criterion = nn.CrossEntropyLoss()
    model.to(device)

    best_accuracy = -1.0
    best_state: dict[str, torch.Tensor] | None = None

    for epoch in range(epochs):
        model.train()
        train_dataset.set_epoch(epoch)
        running_loss = 0.0
        batch_count = 0

        for batch_x, batch_y in train_loader:
            batch_x = batch_x.to(device)
            batch_y = batch_y.to(device)

            optimizer.zero_grad(set_to_none=True)
            logits = model(batch_x)
            loss = criterion(logits, batch_y)
            loss.backward()
            optimizer.step()

            running_loss += float(loss.item())
            batch_count += 1

        test_accuracy = evaluate_exact_q8_8_accuracy(model, test_loader)
        if test_accuracy > best_accuracy:
            best_accuracy = test_accuracy
            best_state = copy.deepcopy(model.state_dict())

        print(
            json.dumps(
                {
                    "epoch": epoch + 1,
                    "epochs": epochs,
                    "loss": (running_loss / batch_count) if batch_count else 0.0,
                    "test_accuracy": test_accuracy,
                },
                sort_keys=True,
            )
        )

    if best_state is None:
        raise RuntimeError("training did not produce any model state")

    model.load_state_dict(best_state)
    return model, best_accuracy


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
    model: QuantizedMnistMLP,
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
    augment_strengths: list[float],
    effective_train_samples: int,
    threshold_values: list[float],
    eval_threshold: float,
    learning_rate: float,
    weight_decay: float,
    epochs: int,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    q_w1, q_b1, q_w2, q_b2 = extract_quantized_parameters(model)
    w1 = q_w1.to(torch.int32).tolist()
    b1 = q_b1.to(torch.int32).tolist()
    w2 = q_w2.to(torch.int32).tolist()
    b2 = q_b2.to(torch.int32).tolist()

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
            "augment_copies": augment_copies,
            "augment_levels": len(augment_strengths),
            "augment_mode": augment_mode,
            "augment_strengths": augment_strengths,
            "effective_train_samples": effective_train_samples,
            "epochs": epochs,
            "eval_threshold": eval_threshold,
            "hidden_size": len(b1),
            "input_size": len(w1),
            "learning_rate": learning_rate,
            "optimizer": "adamw",
            "output_size": len(b2),
            "q8_8_aware_training": True,
            "split_mode": split_mode,
            "test_class_counts": test_class_counts,
            "test_limit": test_limit,
            "threshold_values": threshold_values,
            "tile_width": tile_width,
            "train_class_counts": train_class_counts,
            "train_limit": train_limit,
            "training_backend": "pytorch",
            "weight_decay": weight_decay,
        },
    )


def main() -> None:
    args = parse_args()
    threshold_values, eval_threshold = build_threshold_schedule(args)
    augment_strengths = build_augmentation_strengths(args)

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    train_x, train_y, test_x, test_y, train_counts, test_counts = load_mnist_grayscale(
        train_limit=args.train_limit,
        test_limit=args.test_limit,
        seed=args.seed,
        split_mode=args.split_mode,
    )

    train_dataset = SpectrumBinaryMnistDataset(
        raw_x=train_x,
        raw_y=train_y,
        training=True,
        augment_copies=args.augment_copies,
        augment_mode=args.augment_mode,
        threshold_values=threshold_values,
        augment_strengths=augment_strengths,
        seed=args.seed + 101,
    )
    test_dataset = SpectrumBinaryMnistDataset(
        raw_x=test_x,
        raw_y=test_y,
        training=False,
        augment_copies=0,
        augment_mode="none",
        threshold_values=[eval_threshold],
        augment_strengths=[0.0],
        seed=args.seed + 202,
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=0,
        drop_last=False,
    )
    test_loader = DataLoader(
        test_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
        drop_last=False,
    )

    model = QuantizedMnistMLP(
        input_size=IMAGE_PIXELS,
        hidden_size=args.hidden_size,
        output_size=10,
    )
    device = torch.device("cpu")

    model, accuracy = train_model(
        model=model,
        train_loader=train_loader,
        train_dataset=train_dataset,
        test_loader=test_loader,
        epochs=args.max_iter,
        learning_rate=args.learning_rate,
        weight_decay=args.weight_decay,
        device=device,
    )

    sample_bits = binarize_grayscale(test_x[0], eval_threshold).astype(np.int64).tolist()
    sample_label = int(test_y[0])
    effective_train_samples = int(len(train_dataset))
    effective_train_counts = scale_class_counts(
        train_counts,
        len(threshold_values) * len(augment_strengths) * (args.augment_copies + 1),
    )

    export_model(
        model=model,
        output_dir=args.output_dir,
        tile_width=args.tile_width,
        sample_bits=[int(value) for value in sample_bits],
        sample_label=sample_label,
        accuracy=float(accuracy),
        train_limit=args.train_limit,
        test_limit=args.test_limit,
        split_mode=args.split_mode,
        train_class_counts=effective_train_counts,
        test_class_counts=test_counts,
        augment_mode=args.augment_mode,
        augment_copies=args.augment_copies,
        augment_strengths=augment_strengths,
        effective_train_samples=effective_train_samples,
        threshold_values=threshold_values,
        eval_threshold=eval_threshold,
        learning_rate=args.learning_rate,
        weight_decay=args.weight_decay,
        epochs=args.max_iter,
    )

    print(
        json.dumps(
            {
                "accuracy": float(accuracy),
                "augment_copies": args.augment_copies,
                "augment_levels": len(augment_strengths),
                "augment_mode": args.augment_mode,
                "augment_strengths": augment_strengths,
                "effective_train_samples": effective_train_samples,
                "epochs": args.max_iter,
                "eval_threshold": eval_threshold,
                "hidden_size": args.hidden_size,
                "learning_rate": args.learning_rate,
                "optimizer": "adamw",
                "output_dir": str(args.output_dir),
                "q8_8_aware_training": True,
                "split_mode": args.split_mode,
                "test_class_counts": test_counts,
                "test_limit": args.test_limit,
                "threshold_values": threshold_values,
                "tile_width": args.tile_width,
                "train_class_counts": effective_train_counts,
                "train_limit": args.train_limit,
                "training_backend": "pytorch",
                "weight_decay": args.weight_decay,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
