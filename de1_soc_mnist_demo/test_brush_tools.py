# ABOUTME: Verifies the brush footprint and stroke interpolation used by the Arduino drawing tool.
# ABOUTME: Defines the expected 3x3 brush behavior before the firmware applies it.

from __future__ import annotations

import unittest

from de1_soc_mnist_demo.brush_tools import stroke_cells


class BrushToolsTest(unittest.TestCase):
    def test_single_touch_expands_to_3x3(self) -> None:
        cells = stroke_cells((10, 10), (10, 10), rows=28, cols=28, radius=1)
        self.assertEqual(len(cells), 9)
        self.assertIn((10, 10), cells)
        self.assertIn((9, 9), cells)
        self.assertIn((11, 11), cells)

    def test_edge_touch_clips_to_canvas(self) -> None:
        cells = stroke_cells((0, 0), (0, 0), rows=28, cols=28, radius=1)
        self.assertEqual(cells, {(0, 0), (0, 1), (1, 0), (1, 1)})

    def test_horizontal_drag_fills_gap(self) -> None:
        cells = stroke_cells((5, 5), (5, 7), rows=28, cols=28, radius=0)
        self.assertEqual(cells, {(5, 5), (5, 6), (5, 7)})


if __name__ == "__main__":
    unittest.main()
