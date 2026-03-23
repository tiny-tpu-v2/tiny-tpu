# ABOUTME: Verifies the training script defaults remain self-contained inside this project folder.
# ABOUTME: Locks the default output path so the script still works when this folder is used alone.

from __future__ import annotations

import unittest
from pathlib import Path
import sys
from unittest import mock

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from mnist_demo import train_mnist


class TrainMnistTest(unittest.TestCase):
    def test_default_output_dir_is_local_folder(self) -> None:
        with mock.patch("sys.argv", ["train_mnist.py"]):
            args = train_mnist.parse_args()
        self.assertEqual(args.output_dir, Path("data/model/generated"))

    def test_default_split_mode_is_balanced(self) -> None:
        with mock.patch("sys.argv", ["train_mnist.py"]):
            args = train_mnist.parse_args()
        self.assertEqual(args.split_mode, "balanced")

    def test_select_balanced_subset_equal_class_counts(self) -> None:
        features = np.arange(500, dtype=np.float32).reshape(50, 10)
        labels = np.array([index % 10 for index in range(50)], dtype=np.int64)

        subset_x, subset_y, class_counts = train_mnist.select_balanced_subset(
            features=features,
            labels=labels,
            limit=30,
            num_classes=10,
            seed=11,
        )

        self.assertEqual(subset_x.shape[0], 30)
        self.assertEqual(subset_y.shape[0], 30)
        for digit in range(10):
            self.assertEqual(class_counts[str(digit)], 3)
            self.assertEqual(int(np.sum(subset_y == digit)), 3)

    def test_load_binarized_mnist_balanced_split(self) -> None:
        features = np.zeros((70000, 8), dtype=np.float32)
        labels = np.array([index % 10 for index in range(70000)], dtype=np.int64)

        with mock.patch(
            "mnist_demo.train_mnist.fetch_openml",
            return_value=(features, labels),
        ):
            train_x, train_y, test_x, test_y, train_counts, test_counts = train_mnist.load_binarized_mnist(
                train_limit=2000,
                test_limit=1000,
                pixel_threshold=-1.0,
                seed=5,
                split_mode="balanced",
            )

        self.assertEqual(train_x.shape[0], 2000)
        self.assertEqual(test_x.shape[0], 1000)
        for digit in range(10):
            self.assertEqual(train_counts[str(digit)], 200)
            self.assertEqual(test_counts[str(digit)], 100)
            self.assertEqual(int(np.sum(train_y == digit)), 200)
            self.assertEqual(int(np.sum(test_y == digit)), 100)


if __name__ == "__main__":
    unittest.main()
