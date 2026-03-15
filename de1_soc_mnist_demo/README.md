# ABOUTME: Documents the self-contained DE1-SoC MNIST Tiny-TPU demo, including build, program, and bring-up steps.
# ABOUTME: Explains the final architecture, the original starting point, the key bugs found, and the changes made to finish it.

# DE1-SoC MNIST Tiny-TPU Demo

This folder is the self-contained MNIST demo project for the DE1-SoC.

It includes:

- the final FPGA RTL in [rtl](rtl)
- the top-level board wrapper in [de1_soc_mnist_serial_top.v](de1_soc_mnist_serial_top.v)
- the JTAG MMIO board wrapper in [de1_soc_mnist_jtag_top.v](de1_soc_mnist_jtag_top.v)
- the Quartus project in [de1_soc_mnist_serial_top.qpf](de1_soc_mnist_serial_top.qpf)
- the Quartus JTAG project in [de1_soc_mnist_jtag_top.qpf](de1_soc_mnist_jtag_top.qpf)
- the Arduino touchscreen sender in [arduino_touch_sender.ino](arduino_touch_sender/arduino_touch_sender.ino)
- the training/export flow in [train_mnist.py](train_mnist.py)
- the one-command startup wrapper in [start_mnist_demo.sh](start_mnist_demo.sh)
- the ModelSim regressions in [sim](sim)
- the generated model in [model](model)
- the captured Quartus outputs in [artifacts](artifacts)
- the captured JTAG-top Quartus outputs in [artifacts_jtag](artifacts_jtag)
- the synthetic hand-drawn benchmark artifacts in [synthetic_handdrawn_benchmark](synthetic_handdrawn_benchmark)
- the WSL Arduino attach note in [ARDUINO_WSL_SETUP.md](ARDUINO_WSL_SETUP.md)
- the Arduino smoke-test sketch in [arduino-blink.ino](arduino-blink/arduino-blink.ino)
- the no-wire JTAG feasibility report in [JTAG_FEASIBILITY_REPORT.md](JTAG_FEASIBILITY_REPORT.md)
- the JTAG memory map in [JTAG_MNIST_MEMORY_MAP.md](JTAG_MNIST_MEMORY_MAP.md)
- the JTAG workflow in [JTAG_MNIST_WORKFLOW.md](JTAG_MNIST_WORKFLOW.md)
- the JTAG verification and bring-up checklist in [JTAG_TEST_PLAN.md](JTAG_TEST_PLAN.md)
- the full project journey and engineering log in [START_TO_FINISH_MNIST_JTAG.md](START_TO_FINISH_MNIST_JTAG.md)
- the latest retrain/reflash report in [RETRAIN_REFLASH_REPORT_2026-03-15.md](RETRAIN_REFLASH_REPORT_2026-03-15.md)

The finished runtime path is:

```text
Arduino Uno + 3.5" resistive touchscreen shield
  -> packed 28x28 binary frame over UART on D1/TX
  -> resistor divider
  -> DE1-SoC GPIO_0[0]
  -> UART frame receiver
  -> frame buffer
  -> tiled MNIST classifier
  -> Tiny-TPU datapath
  -> predicted digit on HEX0
```

The alternate no-wire runtime path is:

```text
Arduino Uno + 3.5" resistive touchscreen shield
  -> packed 28x28 frame over USB serial to PC
  -> host parser + checksum validation
  -> System Console MMIO writes over USB-Blaster II JTAG
  -> JTAG Avalon master bridge in FPGA
  -> MMIO image buffer + control register start pulse
  -> tiled MNIST classifier
  -> predicted digit on HEX0 and host readback
```

## Final Status

This project is complete enough to run end-to-end on hardware:

- the Arduino drawing tool works
- the FPGA accepts frames over the wired UART link
- the FPGA runs inference and latches a digit on the seven-segment display
- the Quartus project builds successfully on the DE1-SoC target
- the generated `.sof` is stored in [de1_soc_mnist_serial_top.sof](artifacts/de1_soc_mnist_serial_top.sof)

Key build facts from the captured reports:

- target device: `5CSEMA5F31C6`
- timing target: `50 MHz`
- timing status: passing
- worst-case setup slack after the final timing fix: `+7.147 ns`

The current trained model summary is in [summary.json](model/summary.json):

- input size: `784`
- hidden size: `64`
- output size: `10`
- tile width: `2`
- split mode: `balanced` (equal per-class counts for train/test subsets)
- augmentation mode: `extreme`
- augmentation copies per source sample: `1`
- effective train sample count: `100000`
- recorded software-side test accuracy: `0.954375` on the exported training run

## Original Starting Point

The original codebase did **not** contain a working DE1-SoC MNIST touchscreen demo.

What existed originally:

- a small Tiny-TPU RTL implementation intended around a 2x2 compute fabric
- a `unified_buffer`-based datapath
- testbench code and Python tests centered around the original TPU flow
- no Arduino touchscreen input path
- no UART ingress path for 28x28 images
- no DE1-SoC MNIST top-level wrapper
- no trained, exported `784 -> hidden -> 10` model tied to the board demo

The immediate known-good hardware baseline before the MNIST work was the XOR flow:

- the Tiny-TPU path had already been repaired and proven on the DE1-SoC for XOR
- the DE1-SoC toolchain, JTAG programming, and the Windows-from-WSL Quartus flow were already known-good

That XOR baseline mattered because it proved:

- the FPGA toolchain path was real
- the board programming loop was real
- the Tiny-TPU datapath could be trusted after the earlier RTL fixes

## First-Principles Design Decisions

The MNIST work started from the hardware and RTL constraints, not from an assumption that the original TPU could simply be scaled up.

### 1. Keep the real TPU datapath

The goal was to preserve the actual Tiny-TPU structure, not replace it with a fake direct classifier.

So the design kept:

- the Tiny-TPU-style compute path
- the `unified_buffer`
- the systolic/VPU path

and built a tiled scheduler around that.

### 2. Do not widen the compute fabric first

The compute fabric is still fundamentally a hard-coded `2x2` array in [systolic.v](rtl/systolic.v).

Trying to widen it first would have required a much larger rewrite across:

- the systolic array
- the `unified_buffer`
- the VPU
- the control schedule

So the correct engineering choice was:

- keep the `2x2` datapath
- tile the matrix multiplies

### 3. Keep the full 28x28 input

The user requirement was explicit: no downsampling.

So the chosen model input is:

- `28 x 28 = 784` binary pixels

That made the transport and scheduler more demanding, but it preserved the intended user experience.

### 4. Use one-way UART from the Arduino

The practical direct link is:

- Arduino `D1/TX` only
- no `D0/RX`
- common ground

This avoids fighting the Uno USB serial bridge while the Uno remains attached to the laptop for programming and power.

### 5. Use a resistor divider on the Arduino TX line

The Arduino Uno TX line is `5V`, while the FPGA GPIO is a `3.3V` domain.

The safe signal path is:

```text
Arduino D1/TX -> 2.0k -> RX node -> DE1-SoC GPIO_0[0]
                           |
                          3.3k
                           |
                          GND
```

Only two electrical connections are required between boards:

- the divided TX signal
- ground

## Final Hardware Wiring

### Arduino side

- use `D1/TX`
- do not use `D0/RX`
- tap a ground point

### DE1-SoC side

The final FPGA input pin is:

- `UART_RX_IN`
- mapped to `GPIO_0[0]`
- constrained in [de1_soc_mnist_serial_top.qsf](de1_soc_mnist_serial_top.qsf#L44)
- Quartus ball: `PIN_AC18`

On the `GPIO_0` 2x20 header:

- `pin 1` = `GPIO_0[0]` = UART RX input
- `pin 12` = `GND`

Use:

- resistor-divider RX node -> `GPIO_0 pin 1`
- Arduino ground -> `GPIO_0 pin 12`

Do not connect:

- `D0`
- `GPIO_0 pin 11` (`5V`)
- `GPIO_0 pin 29` (`3.3V`)

## How To Run From WSL (CLI)

This is the primary, known-good workflow.

### 0. Fast plug-in bootstrap (automated)

If both boards are plugged in and you want the fastest repeatable bring-up path, run:

```bash
bash start_mnist_demo.sh
```

This wrapper calls:

```bash
bash quickstart_jtag_demo.sh
```

This single command performs:

- Arduino USB attach to WSL through `usbipd` (if available)
- serial-port detection
- FPGA programming with the JTAG `.sof`
- JTAG MMIO `health` check
- one-shot `predict_bits` sanity check
- continuous Arduino-to-JTAG inference loop

The continuous loop keeps a persistent System Console session open, so per-frame inference does not pay process startup cost each time.
Typical observed per-frame latency on this machine:

- with writeback verify on: roughly `0.45s` to `0.60s`
- with writeback verify off: roughly `0.24s` to `0.35s`

Useful variants:

```bash
# setup + smoke test only (no continuous loop)
bash start_mnist_demo.sh --no-loop

# include a fresh JTAG Quartus build before programming
bash start_mnist_demo.sh --build

# fastest per-frame loop (skip readback verify)
bash start_mnist_demo.sh --no-verify-writeback
```

For wrapper help:

```bash
bash start_mnist_demo.sh --help
```

### 1. Arduino: compile and upload the touchscreen sketch

The Arduino sketch is:

- [arduino_touch_sender.ino](arduino_touch_sender/arduino_touch_sender.ino)

Typical upload flow from WSL:

```bash
arduino-cli board list
arduino-cli compile --fqbn arduino:avr:uno arduino_touch_sender
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno arduino_touch_sender
```

If the Uno is not visible in WSL, follow the machine setup note in [ARDUINO_WSL_SETUP.md](ARDUINO_WSL_SETUP.md).

On this machine, the common recovery step is to reattach the Uno from Windows:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' list
& 'C:\Program Files\usbipd-win\usbipd.exe' attach --wsl --busid <BUSID>
```

Then verify again in WSL:

```bash
arduino-cli board list
```

### 2. FPGA: run the ModelSim regressions

The verification flow is CLI-first and ModelSim-first.

Useful regressions:

```bash
bash sim/run_uart_rx_tb.sh
bash sim/run_uart_frame_receiver_tb.sh
bash sim/run_mnist_frame_buffer_tb.sh
bash sim/run_mnist_uart_ingress_tb.sh
bash sim/run_mnist_tpu_tiled_classifier_tb.sh
bash sim/run_mnist_serial_classifier_full_tb.sh
bash sim/run_de1_soc_mnist_serial_top_tb.sh
```

### 3. FPGA: stage and build the Quartus project

The project stages itself from WSL into a Windows-visible path before building.

Stage only:

```bash
bash stage_quartus_project.sh
```

Stage and build:

```bash
bash build_quartus.sh
```

By default this uses:

- Quartus binaries at `/mnt/c/altera_lite/25.1std/quartus/bin64`
- staging root at `/mnt/c/fpga_builds/tiny-tpu-fpga-staging`

You can override them:

```bash
QUARTUS_BIN=/mnt/c/altera_lite/25.1std/quartus/bin64 \
QUARTUS_BUILD_ROOT=/mnt/c/fpga_builds/tiny-tpu-fpga-staging \
bash build_quartus.sh
```

### 4. FPGA: program the board

The programming script prefers the staged Windows build output, but it falls back to the tracked local bitstream in `artifacts/` if no staged build is present.

Run:

```bash
bash program_fpga.sh
```

The script:

- uses `jtagconfig.exe`
- then uses `quartus_pgm.exe`
- bypasses the HPS at JTAG device `@1`
- programs the Cyclone V FPGA at device `@2`

### 5. Runtime test

Board controls:

- `KEY[3]`: FPGA-side reset
- `KEY[0]`: start inference

Status LEDs:

- `LEDR[0]`: frame received and latched
- `LEDR[1]`: busy
- `LEDR[2]`: prediction valid
- `LEDR[3]`: frame error
- `LEDR[7:4]`: predicted digit in binary

Expected runtime flow:

1. Press `KEY[3]`
2. Draw a digit on the Arduino screen
3. Tap `SEND`
4. Confirm `LEDR[0]` turns on
5. Press `KEY[0]`
6. Wait for the run to finish
7. Read the digit on `HEX0`

## How To Run With The Quartus GUI

This is the correct GUI workflow. Do not open the WSL path directly in the Windows GUI.

### 1. Stage the project from WSL

```bash
bash stage_quartus_project.sh
```

That copies this self-contained folder into:

- `C:\fpga_builds\tiny-tpu-fpga-staging\de1_soc_mnist_demo`

### 2. Open the staged Windows project

Open this file in the Quartus GUI:

- `C:\fpga_builds\tiny-tpu-fpga-staging\de1_soc_mnist_demo\de1_soc_mnist_serial_top.qpf`

Use the `.qpf`, not just the `.qsf`.

### 3. Compile in the GUI

Use Quartus GUI compile as usual:

- `Processing -> Start Compilation`

This runs the staged Windows copy, not the WSL path.

### 4. Program in the GUI

Use Quartus Programmer:

- choose cable `DE-SoC [USB-1]`
- target the FPGA device at JTAG index `2`
- program the generated `.sof`

The staged GUI build output appears under:

- `C:\fpga_builds\tiny-tpu-fpga-staging\de1_soc_mnist_demo\output_files`

## Captured Build Artifacts

This folder includes the generated build outputs in [artifacts](artifacts), including:

- [de1_soc_mnist_serial_top.sof](artifacts/de1_soc_mnist_serial_top.sof)
- [de1_soc_mnist_serial_top.fit.rpt](artifacts/de1_soc_mnist_serial_top.fit.rpt)
- [de1_soc_mnist_serial_top.map.rpt](artifacts/de1_soc_mnist_serial_top.map.rpt)
- [de1_soc_mnist_serial_top.asm.rpt](artifacts/de1_soc_mnist_serial_top.asm.rpt)
- [de1_soc_mnist_serial_top.sta.rpt](artifacts/de1_soc_mnist_serial_top.sta.rpt)
- [de1_soc_mnist_serial_top.pin](artifacts/de1_soc_mnist_serial_top.pin)

These artifacts are tracked so this folder remains usable even if the staging tree is deleted.

## Training And Model Export

The model is trained and exported by [train_mnist.py](train_mnist.py).

The chosen model shape is:

- `784 -> 64 -> 10`

Why this shape:

- full `28x28` input is preserved
- the hidden layer is large enough to be useful
- the tiled scheduler can run it on the existing 2-lane TPU flow

The exported files are:

- [w1_tiled_q8_8.memh](model/w1_tiled_q8_8.memh)
- [b1_q8_8.memh](model/b1_q8_8.memh)
- [w2_tiled_q8_8.memh](model/w2_tiled_q8_8.memh)
- [b2_q8_8.memh](model/b2_q8_8.memh)

Typical training command:

```bash
source /path/to/your/venv/bin/activate
python train_mnist.py \
  --hidden-size 64 \
  --tile-width 2 \
  --train-limit 20000 \
  --test-limit 2000 \
  --max-iter 20 \
  --split-mode balanced \
  --output-dir generated_model
```

If you want to replace the shipped model, regenerate the files and then copy them into [model](model) before rebuilding Quartus.

## Verification Strategy

The implementation was done incrementally and verification-first.

### Simulation checkpoints

The main checkpoints were:

1. UART byte receiver
2. Framed packet receiver
3. Packed 28x28 frame buffer
4. Serial ingress wrapper
5. Tiled classifier core
6. Full serial classifier
7. Full DE1-SoC top-level

Each of those has a dedicated ModelSim regression in [sim](sim).

### Hardware checkpoints

The hardware bring-up was also incremental:

1. Verify the Arduino display worked
2. Verify touch calibration and pin mapping
3. Verify the UART frame was accepted (`LEDR[0]`)
4. Verify the classifier ran (`LEDR[1]`)
5. Verify the result latched (`LEDR[2]`, `HEX0`)

## Problems Encountered And How They Were Solved

This is the real engineering path, not a cleaned-up fiction.

### 1. The Arduino LCD initially showed only a white screen

Root cause:

- the display shield behaves like a write-only panel
- the sketch needed to force the correct controller ID instead of trusting the raw readback

Fix:

- treat both `0x00D3` and `0xD3D3` as the write-only case
- force `ILI9486` initialization

### 2. The touchscreen initially did not respond

Root cause:

- the first touch pin map was wrong for this actual shield
- the first calibration constants were guessed, not measured

Fix:

- load the `MCUFRIEND_kbv` calibration sketch
- read the real detected touch wiring
- use the exact reported calibration values

Final calibrated values:

- `XP=8`
- `XM=A2`
- `YP=A3`
- `YM=9`
- landscape map:
  - `LEFT=892`
  - `RIGHT=195`
  - `TOP=863`
  - `BOTTOM=199`

### 3. Thin stylus strokes hurt practical accuracy

Root cause:

- the model was trained on binarized MNIST, which is denser than single-cell sparse strokes
- the first drawing tool only turned on one cell per sample

Fix:

- add a `3x3` brush footprint
- add line interpolation between sampled touch points

That behavior is defined in:

- [brush_tools.py](brush_tools.py)
- [test_brush_tools.py](test_brush_tools.py)

### 4. The large model weights would not synthesize cleanly

Root cause:

- Quartus could not infer the large weight arrays as block memory because the original weight reads were asynchronous

Observed result:

- the compiler tried to keep too much storage in registers
- synthesis then exceeded practical device resources

Fix:

- change the large weight storage in [mnist_classifier_core.v](rtl/mnist_classifier_core.v) to synchronous ROM-style access
- add the required wait/commit states for the new read latency

### 5. The design initially failed timing

Root cause:

- the first argmax implementation created a long combinational compare chain

Observed result:

- negative setup slack in TimeQuest

Fix:

- replace the long one-cycle argmax chain with a sequential argmax scan

That changed the timing from a failing path to:

- `+7.147 ns` worst-case setup slack

## What Changed Relative To The Original TPU Implementation

The finished system is not a random rewrite. It is a structured extension of the original TPU-oriented code.

The major additions are:

- UART byte receiver: [uart_rx.v](rtl/uart_rx.v)
- framed UART packet receiver: [uart_frame_receiver.v](rtl/uart_frame_receiver.v)
- packed frame storage: [mnist_frame_buffer.v](rtl/mnist_frame_buffer.v)
- serial ingress wrapper: [mnist_uart_ingress.v](rtl/mnist_uart_ingress.v)
- tiled MNIST scheduler: [mnist_classifier_core.v](rtl/mnist_classifier_core.v)
- serial-to-classifier bridge: [mnist_serial_classifier.v](rtl/mnist_serial_classifier.v)
- board top-level: [de1_soc_mnist_serial_top.v](de1_soc_mnist_serial_top.v)

The major behavioral change is:

- instead of assuming a tiny fixed test vector like the XOR flow, the design now accepts a full `28x28` frame over UART and executes a tiled `784 -> 64 -> 10` classifier using the Tiny-TPU datapath

## Known Limitations

The system works, but these are the honest remaining limitations:

- The drawing input is still binary, not grayscale.
- The model is trained on binarized MNIST, not on true touchscreen-drawn samples.
- There is no recentering or normalization pass on the Arduino yet.
- Accuracy depends on drawing thickness, centering, and how “MNIST-like” the digit is.
- The UART path is one-way only. There is no acknowledgment path back to the Arduino.

Synthetic handwritten stress-test benchmark artifacts are committed in:

- [synthetic_handdrawn_benchmark/results.json](synthetic_handdrawn_benchmark/results.json)
- [synthetic_handdrawn_benchmark/predictions.csv](synthetic_handdrawn_benchmark/predictions.csv)
- [synthetic_handdrawn_benchmark/previews](synthetic_handdrawn_benchmark/previews)

Benchmark command used:

```bash
../.venv-mnist/bin/python tools/benchmark_synthetic_handdrawn.py \
    --samples-per-digit 120 \
    --preview-per-digit 4 \
    --seed 1234
```

Recorded stress-test result for this run:

- overall accuracy: `0.4700` (`564/1200`)
- strongest classes: `0`, `7`
- weakest classes: `6`, `8`, `4`

## Recommended Next Improvements

If you continue from this checkpoint, the highest-value next steps are:

1. Recenter and normalize the drawn digit on the Arduino before sending.
2. Retrain with augmentation that mimics the touchscreen domain.
3. Add a simple confidence or class display on more seven-segment digits or VGA.
4. Optionally add an FPGA-to-Arduino acknowledgment path only if the one-way UART link proves limiting.
