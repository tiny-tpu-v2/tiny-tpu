# DE1-SoC Tiny-TPU XOR Bring-Up

## Build

From `/home/surya/tiny-tpu/de1_soc_xor_demo`:

```bash
bash build_quartus.sh
```

`build_quartus.sh` stages the project onto `/mnt/c/fpga_builds/tiny-tpu-fpga-staging` and runs Quartus there so the Windows toolchain uses a native `C:\...` path.

The expected output bitstream is:

```text
/mnt/c/fpga_builds/tiny-tpu-fpga-staging/de1_soc_xor_demo/output_files/de1_soc_tiny_tpu_xor.sof
```

## Program

With the DE1-SoC connected over USB-Blaster:

```bash
bash program_fpga.sh
```

The script checks for the `.sof`, prints the detected JTAG chain, and programs the FPGA over JTAG.

## Controls

- `KEY[3]`: active-low reset
- `KEY[0]`: debounced start button
- `SW[1:0]`: XOR inputs

The design runs exactly one inference per `KEY[0]` press. `HEX0` updates only after that run finishes and keeps the previous result until the next button press.

## Expected Behavior

- `SW[1:0] = 00`, press `KEY[0]` -> `HEX0` shows `0`
- `SW[1:0] = 01`, press `KEY[0]` -> `HEX0` shows `1`
- `SW[1:0] = 10`, press `KEY[0]` -> `HEX0` shows `1`
- `SW[1:0] = 11`, press `KEY[0]` -> `HEX0` shows `0`

Changing switches without pressing `KEY[0]` must not change `HEX0`.

## Debug LEDs

- `LEDR[0]`: run in progress
- `LEDR[1]`: latched XOR result
- `LEDR[2]`: display valid
- `LEDR[3]`: start pulse
