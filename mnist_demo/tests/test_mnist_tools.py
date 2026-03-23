# ABOUTME: Verifies the deterministic data-format and quantization helpers for the MNIST demo.
# ABOUTME: Keeps the binary packing and fixed-point conventions stable before RTL integration.

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from mnist_demo.mnist_tools import build_uart_frame
from mnist_demo.mnist_tools import compute_tile_words
from mnist_demo.mnist_tools import flatten_weights_for_tiles
from mnist_demo.mnist_tools import parse_uart_frame
from mnist_demo.mnist_tools import pack_binary_image
from mnist_demo.mnist_tools import quantize_q8_8
from mnist_demo.mnist_tools import to_u16_hex
from mnist_demo.mnist_tools import unpack_binary_image


class MnistToolsTest(unittest.TestCase):
    def test_pack_binary_image_round_trip(self) -> None:
        bits = [(index % 3) == 0 for index in range(28 * 28)]

        packed = pack_binary_image(bits)
        unpacked = unpack_binary_image(packed)

        self.assertEqual(len(packed), 98)
        self.assertEqual(unpacked, [int(bit) for bit in bits])

    def test_pack_binary_image_rejects_wrong_length(self) -> None:
        with self.assertRaises(ValueError):
            pack_binary_image([0] * 783)

    def test_quantize_q8_8_clips_and_rounds(self) -> None:
        self.assertEqual(quantize_q8_8(1.0), 0x0100)
        self.assertEqual(quantize_q8_8(-1.0), -0x0100)
        self.assertEqual(quantize_q8_8(0.5), 0x0080)
        self.assertEqual(quantize_q8_8(200.0), 0x7FFF)
        self.assertEqual(quantize_q8_8(-200.0), -0x8000)

    def test_to_u16_hex_uses_twos_complement(self) -> None:
        self.assertEqual(to_u16_hex(0), "0000")
        self.assertEqual(to_u16_hex(0x0100), "0100")
        self.assertEqual(to_u16_hex(-0x0100), "ff00")
        self.assertEqual(to_u16_hex(-1), "ffff")

    def test_compute_tile_words_for_first_layer_tile(self) -> None:
        self.assertEqual(
            compute_tile_words(
                input_size=784,
                output_tile_width=2,
                include_outputs=0,
            ),
            2354,
        )

    def test_flatten_weights_for_two_wide_tiles(self) -> None:
        matrix = [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
        ]

        self.assertEqual(
            flatten_weights_for_tiles(matrix, tile_width=2),
            [1, 2, 5, 6, 9, 10, 3, 4, 7, 8, 11, 12],
        )

    def test_uart_frame_round_trip(self) -> None:
        bits = [index & 1 for index in range(28 * 28)]

        frame = build_uart_frame(bits)

        self.assertEqual(len(frame), 101)
        self.assertEqual(frame[:2], bytes([0xA5, 0x5A]))
        self.assertEqual(parse_uart_frame(frame), bits)

    def test_uart_frame_rejects_bad_checksum(self) -> None:
        bits = [0] * (28 * 28)
        frame = bytearray(build_uart_frame(bits))
        frame[-1] ^= 0x01

        with self.assertRaises(ValueError):
            parse_uart_frame(bytes(frame))


if __name__ == "__main__":
    unittest.main()
