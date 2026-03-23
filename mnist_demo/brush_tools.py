# ABOUTME: Defines the stroke expansion rules for the MNIST touchscreen drawing tool.
# ABOUTME: Provides a simple line rasterizer plus a clipped square brush footprint.

from __future__ import annotations


def _line_cells(start: tuple[int, int], stop: tuple[int, int]) -> list[tuple[int, int]]:
    row0, col0 = start
    row1, col1 = stop

    d_row = abs(row1 - row0)
    d_col = abs(col1 - col0)
    step_row = 1 if row0 < row1 else -1
    step_col = 1 if col0 < col1 else -1
    error = d_col - d_row

    cells: list[tuple[int, int]] = []
    while True:
        cells.append((row0, col0))
        if row0 == row1 and col0 == col1:
            return cells

        double_error = error * 2
        if double_error > -d_row:
            error -= d_row
            col0 += step_col
        if double_error < d_col:
            error += d_col
            row0 += step_row


def stroke_cells(
    start: tuple[int, int],
    stop: tuple[int, int],
    *,
    rows: int,
    cols: int,
    radius: int,
) -> set[tuple[int, int]]:
    if rows <= 0 or cols <= 0:
        raise ValueError("rows and cols must be positive")
    if radius < 0:
        raise ValueError("radius must be non-negative")

    cells: set[tuple[int, int]] = set()
    for row, col in _line_cells(start, stop):
        for row_delta in range(-radius, radius + 1):
            for col_delta in range(-radius, radius + 1):
                brush_row = row + row_delta
                brush_col = col + col_delta
                if 0 <= brush_row < rows and 0 <= brush_col < cols:
                    cells.add((brush_row, brush_col))
    return cells
