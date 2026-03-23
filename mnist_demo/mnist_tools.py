# ABOUTME: Defines the packed image, fixed-point, and tile-size helpers for the MNIST demo flow.
# ABOUTME: These helpers are shared by the trainer, Arduino packet format, and FPGA memory planner.

from __future__ import annotations


IMAGE_PIXELS = 28 * 28
PACKED_IMAGE_BYTES = IMAGE_PIXELS // 8
FRAME_HEADER = bytes([0xA5, 0x5A])
FRAME_BYTES = len(FRAME_HEADER) + PACKED_IMAGE_BYTES + 1


def pack_binary_image(bits: list[int] | list[bool]) -> bytes:
    if len(bits) != IMAGE_PIXELS:
        raise ValueError(f"expected {IMAGE_PIXELS} pixels, got {len(bits)}")

    packed = bytearray(PACKED_IMAGE_BYTES)
    for index, bit in enumerate(bits):
        if int(bit):
            packed[index // 8] |= 1 << (index % 8)
    return bytes(packed)


def unpack_binary_image(payload: bytes) -> list[int]:
    if len(payload) != PACKED_IMAGE_BYTES:
        raise ValueError(f"expected {PACKED_IMAGE_BYTES} bytes, got {len(payload)}")

    bits: list[int] = []
    for byte in payload:
        for shift in range(8):
            bits.append((byte >> shift) & 1)
    return bits


def build_uart_frame(bits: list[int] | list[bool]) -> bytes:
    payload = pack_binary_image(bits)
    checksum = 0
    for byte in payload:
        checksum ^= byte
    return FRAME_HEADER + payload + bytes([checksum])


def parse_uart_frame(frame: bytes) -> list[int]:
    if len(frame) != FRAME_BYTES:
        raise ValueError(f"expected {FRAME_BYTES} bytes, got {len(frame)}")
    if frame[: len(FRAME_HEADER)] != FRAME_HEADER:
        raise ValueError("invalid frame header")

    payload = frame[len(FRAME_HEADER):-1]
    checksum = 0
    for byte in payload:
        checksum ^= byte
    if checksum != frame[-1]:
        raise ValueError("invalid frame checksum")
    return unpack_binary_image(payload)


def quantize_q8_8(value: float) -> int:
    scaled = int(round(value * 256.0))
    if scaled > 0x7FFF:
        return 0x7FFF
    if scaled < -0x8000:
        return -0x8000
    return scaled


def to_u16_hex(value: int) -> str:
    return f"{value & 0xFFFF:04x}"


def flatten_weights_for_tiles(
    matrix: list[list[int]],
    tile_width: int,
) -> list[int]:
    if not matrix:
        return []
    if tile_width <= 0:
        raise ValueError("tile_width must be positive")

    input_size = len(matrix)
    output_size = len(matrix[0])
    for row in matrix:
        if len(row) != output_size:
            raise ValueError("matrix rows must have equal length")

    flattened: list[int] = []
    for tile_start in range(0, output_size, tile_width):
        tile_stop = min(tile_start + tile_width, output_size)
        for input_index in range(input_size):
            for output_index in range(tile_start, tile_stop):
                flattened.append(matrix[input_index][output_index])
    return flattened


def compute_tile_words(
    input_size: int,
    output_tile_width: int,
    include_outputs: int,
) -> int:
    if input_size <= 0:
        raise ValueError("input_size must be positive")
    if output_tile_width <= 0:
        raise ValueError("output_tile_width must be positive")
    if include_outputs < 0:
        raise ValueError("include_outputs must be non-negative")

    return input_size + (input_size * output_tile_width) + output_tile_width + include_outputs
