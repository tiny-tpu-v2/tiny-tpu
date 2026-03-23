# ABOUTME: Exports 28x28 binary mask files into viewable bitmap previews for MNIST debug.
# ABOUTME: Supports runtime .bits frames and packed .bin frames, then writes an HTML index.

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import html
import struct
import sys
import zlib


IMAGE_SIZE = 28
PIXELS = IMAGE_SIZE * IMAGE_SIZE
PACKED_BYTES = PIXELS // 8
SCALE = 12
PROJECT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_DIR / "artifacts" / "previews" / "bitmask"


@dataclass(frozen=True)
class SourceFrame:
    label: str
    path: Path
    kind: str  # "bits" or "bin"


def read_bits_file(path: Path) -> list[int]:
    values: list[int] = []
    for line in path.read_text(encoding="ascii").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped not in {"0", "1"}:
            raise ValueError(f"invalid value in {path}: {stripped!r}")
        values.append(int(stripped))
    if len(values) != PIXELS:
        raise ValueError(f"{path} has {len(values)} bits, expected {PIXELS}")
    return values


def read_bin_file(path: Path) -> list[int]:
    payload = path.read_bytes()
    if len(payload) != PACKED_BYTES:
        raise ValueError(f"{path} has {len(payload)} bytes, expected {PACKED_BYTES}")
    bits: list[int] = []
    for byte in payload:
        for shift in range(8):
            bits.append((byte >> shift) & 1)
    return bits


def safe_name(label: str) -> str:
    chars = []
    for ch in label:
        if ch.isalnum() or ch in {"_", "-"}:
            chars.append(ch)
        else:
            chars.append("_")
    return "".join(chars)


def write_bmp(path: Path, bits: list[int], scale: int = SCALE) -> None:
    width = IMAGE_SIZE * scale
    height = IMAGE_SIZE * scale
    row_stride = ((width * 3) + 3) & ~3
    pixel_data_size = row_stride * height
    file_size = 14 + 40 + pixel_data_size

    with path.open("wb") as f:
        f.write(b"BM")
        f.write(struct.pack("<I", file_size))
        f.write(struct.pack("<HH", 0, 0))
        f.write(struct.pack("<I", 14 + 40))

        f.write(struct.pack("<I", 40))
        f.write(struct.pack("<i", width))
        f.write(struct.pack("<i", height))
        f.write(struct.pack("<H", 1))
        f.write(struct.pack("<H", 24))
        f.write(struct.pack("<I", 0))
        f.write(struct.pack("<I", pixel_data_size))
        f.write(struct.pack("<i", 2835))
        f.write(struct.pack("<i", 2835))
        f.write(struct.pack("<I", 0))
        f.write(struct.pack("<I", 0))

        padding = b"\x00" * (row_stride - (width * 3))

        for out_y in range(height - 1, -1, -1):
            src_y = out_y // scale
            row = bytearray()
            for out_x in range(width):
                src_x = out_x // scale
                pixel = bits[(src_y * IMAGE_SIZE) + src_x]
                if pixel:
                    row.extend((0, 0, 0))
                else:
                    row.extend((255, 255, 255))
            row.extend(padding)
            f.write(row)


def write_png(path: Path, bits: list[int], scale: int = SCALE) -> None:
    width = IMAGE_SIZE * scale
    height = IMAGE_SIZE * scale

    raw = bytearray()
    for out_y in range(height):
        raw.append(0)
        src_y = out_y // scale
        for out_x in range(width):
            src_x = out_x // scale
            pixel = bits[(src_y * IMAGE_SIZE) + src_x]
            raw.append(0 if pixel else 255)

    def chunk(chunk_type: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        return (
            struct.pack(">I", len(payload))
            + chunk_type
            + payload
            + struct.pack(">I", crc)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)

    with path.open("wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def write_ascii_preview(path: Path, bits: list[int]) -> None:
    lines: list[str] = []
    for row in range(IMAGE_SIZE):
        line = []
        for col in range(IMAGE_SIZE):
            line.append("#" if bits[(row * IMAGE_SIZE) + col] else ".")
        lines.append("".join(line))
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def build_index(entries: list[tuple[str, str, int]]) -> str:
    cards = []
    for label, image_name, ones_count in entries:
        cards.append(
            "<div class='card'>"
            f"<h3>{html.escape(label)}</h3>"
            f"<img src='{html.escape(image_name)}' alt='{html.escape(label)}' />"
            f"<p>ones: {ones_count} / {PIXELS}</p>"
            "</div>"
        )
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>MNIST Bitmask Previews</title>"
        "<style>"
        "body{font-family:Arial,sans-serif;background:#f2f2f2;margin:24px;}"
        ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px;}"
        ".card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:12px;}"
        "h1{margin-top:0;}h3{font-size:16px;margin:0 0 8px;}p{margin:8px 0 0;color:#333;}"
        "img{width:100%;height:auto;border:1px solid #ddd;image-rendering:pixelated;}"
        "</style></head><body>"
        "<h1>MNIST Bitmask Previews</h1>"
        "<p>Black pixels are bit value 1, white pixels are bit value 0.</p>"
        f"<div class='grid'>{''.join(cards)}</div>"
        "</body></html>"
    )


def collect_sources() -> list[SourceFrame]:
    return [
        SourceFrame(
            "runtime_current_frame_bits",
            PROJECT_DIR / "artifacts" / "runtime" / "jtag_host" / "current_frame.bits",
            "bits",
        ),
        SourceFrame(
            "runtime_sample_frame_bits",
            PROJECT_DIR / "artifacts" / "runtime" / "jtag_host" / "sample_image_0.bits",
            "bits",
        ),
        SourceFrame("model_sample_image_bin", PROJECT_DIR / "data" / "model" / "reference" / "sample_image_0.bin", "bin"),
        SourceFrame("generated_model_sample_image_bin", PROJECT_DIR / "data" / "model" / "generated" / "sample_image_0.bin", "bin"),
    ]


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    entries: list[tuple[str, str, int]] = []
    missing: list[Path] = []

    for source in collect_sources():
        if not source.path.exists():
            missing.append(source.path)
            continue

        if source.kind == "bits":
            bits = read_bits_file(source.path)
        elif source.kind == "bin":
            bits = read_bin_file(source.path)
        else:
            raise ValueError(f"unsupported source kind: {source.kind}")

        name = safe_name(source.label)
        png_name = f"{name}.png"
        bmp_name = f"{name}.bmp"
        txt_name = f"{name}.txt"

        write_png(OUTPUT_DIR / png_name, bits)
        write_bmp(OUTPUT_DIR / bmp_name, bits)
        write_ascii_preview(OUTPUT_DIR / txt_name, bits)
        entries.append((source.label, png_name, sum(bits)))

    index_path = OUTPUT_DIR / "index.html"
    index_path.write_text(build_index(entries), encoding="utf-8")

    print(f"wrote {len(entries)} preview(s) to {OUTPUT_DIR}")
    print(f"index: {index_path}")
    if missing:
        print("missing sources:")
        for path in missing:
            print(f"  - {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
