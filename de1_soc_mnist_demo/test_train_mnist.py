# ABOUTME: Verifies the training script defaults remain self-contained inside this project folder.
# ABOUTME: Locks the default output path so the script still works when this folder is used alone.

from __future__ import annotations

import unittest
from pathlib import Path
from unittest import mock

from de1_soc_mnist_demo import train_mnist


class TrainMnistTest(unittest.TestCase):
    def test_default_output_dir_is_local_folder(self) -> None:
        with mock.patch("sys.argv", ["train_mnist.py"]):
            args = train_mnist.parse_args()
        self.assertEqual(args.output_dir, Path("generated_model"))


if __name__ == "__main__":
    unittest.main()
