# JTAG MNIST Memory Map

Top-level RTL: `de1_soc_mnist_jtag_top.v`  
MMIO block: `rtl/mnist_jtag_mmio.v`

All addresses below are byte addresses on a 32-bit Avalon-MM interface.

## Register Map

| Address | Name | Access | Description |
|---|---|---|---|
| `0x0000_0000` | `CTRL` | W | Control bits (self-clearing pulse/control actions) |
| `0x0000_0004` | `STATUS` | R | Busy/done/frame/error state |
| `0x0000_0008` | `RESULT` | R | Latched predicted digit |
| `0x0000_000C` | `VERSION` | R | Constant signature `0x4D4E4953` (`"MNIS"`) |
| `0x0000_0100 + 4*i` | `IMAGE[i]` | R/W | Pixel bit for `i = 0..783` (`bit0` only) |

## CTRL (`0x0000_0000`, write)

- `bit0`: start inference pulse  
  - Only accepted when `frame_loaded=1` and `busy=0`.
- `bit1`: clear image/state  
  - Clears all 784 pixels and resets result/done/error latches.
- `bit2`: clear done latch
- `bit3`: clear write-while-busy error latch

## STATUS (`0x0000_0004`, read)

- `bit0`: `busy`
- `bit1`: `done_sticky` (latched done)
- `bit2`: `frame_loaded`
- `bit3`: `write_while_busy` (host attempted image write during busy)

## RESULT (`0x0000_0008`, read)

- `bits[3:0]`: predicted digit (`0..9`)

## IMAGE (`0x0000_0100 + 4*i`, read/write)

- Write:
  - Use `bit0` of write data (`0` or `1`).
  - One 32-bit word per pixel index.
  - Writes during `busy=1` are blocked and set `STATUS.bit3`.
- Read:
  - Returns pixel bit in `bit0`.

## Pixel-to-Core Conversion

Inside `mnist_jtag_mmio`:

- `IMAGE[i] = 0` -> classifier sees `16'h0000`
- `IMAGE[i] = 1` -> classifier sees `16'h0100` (Q8.8 representation of `1.0`)
