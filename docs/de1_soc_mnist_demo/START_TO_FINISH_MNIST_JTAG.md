# ABOUTME: Captures the full engineering journey from initial Tiny-TPU MNIST bring-up to the final DE1-SoC JTAG workflow.
# ABOUTME: Explains first-principles reasoning, failures encountered, design changes, and the final repeatable operation.

# Start-to-Finish: Tiny-TPU MNIST on DE1-SoC with Arduino Drawing Tool and JTAG Injection

## 1) Start Point and Constraints

The starting point was a working DE1-SoC FPGA + Tiny-TPU infrastructure for earlier demos, then a larger MNIST objective:

- keep full `28x28` input (no downsampling)
- keep Tiny-TPU intent (not replace with a fake direct classifier)
- integrate Arduino touchscreen as drawing source
- preserve deterministic hardware behavior
- provide a repeatable WSL + Quartus + ModelSim workflow

Original practical limitations:

- original Tiny-TPU fabric is effectively `2x2` compute, not a large matrix engine
- direct Arduino->FPGA UART/GPIO link was functional but less robust in practice
- JTAG host access existed conceptually but needed a full end-to-end implementation and automation

## 2) First-Principles Reasoning and Architecture Decisions

### 2.1 Keep TPU shape, tile matmuls

Instead of widening the TPU fabric first, the project kept the existing core and tiled work over `K=2` chunks.  
This was the smallest change that preserved original hardware intent.

### 2.2 Preserve full input size

Input remained `784` binary pixels (`28x28`) end-to-end:

- drawing tool emits packed binary frame
- FPGA unpacks into classifier input format
- no host-side resize/downsample hacks

### 2.3 Move to no-wire data plane for reliability

Final runtime data path:

- Arduino -> USB serial -> PC/WSL
- PC/WSL -> USB-Blaster II JTAG -> FPGA MMIO
- FPGA MMIO image buffer -> classifier core

This removes Arduino<->FPGA wire reliability issues while keeping the same inference core.

## 3) What Was Built

### 3.1 FPGA JTAG MMIO path

Added:

- [de1_soc_mnist_jtag_top.v](de1_soc_mnist_jtag_top.v)
- [rtl/mnist_jtag_mmio.v](rtl/mnist_jtag_mmio.v)
- JTAG Avalon bridge generation under [jtag_ip](jtag_ip)

MMIO map and host controls documented in:

- [JTAG_MNIST_MEMORY_MAP.md](JTAG_MNIST_MEMORY_MAP.md)

### 3.2 Host control path

Added:

- [jtag_host/mnist_jtag_mmio.tcl](jtag_host/mnist_jtag_mmio.tcl)
- [jtag_host/run_system_console_mmio.sh](jtag_host/run_system_console_mmio.sh)
- [jtag_host/arduino_jtag_mnist_loop.py](jtag_host/arduino_jtag_mnist_loop.py)

These provide:

- health check
- image write
- start/poll/read result
- continuous Arduino frame ingest
- reconnect/retry behavior

### 3.3 Build/program automation

Added:

- [build_quartus_jtag.sh](build_quartus_jtag.sh)
- [program_fpga_jtag.sh](program_fpga_jtag.sh)
- [quickstart_jtag_demo.sh](quickstart_jtag_demo.sh)
- root quick commands in [../commands.txt](../commands.txt)

### 3.4 Verification

Added/used:

- JTAG MMIO testbench + classifier integration test
- parity regression script comparing transport paths
- Python/RTL parity checks for tracked sample tensors

Key simulation scripts:

- [sim/run_mnist_jtag_mmio_tb.sh](sim/run_mnist_jtag_mmio_tb.sh)
- [sim/run_mnist_jtag_classifier_tb.sh](sim/run_mnist_jtag_classifier_tb.sh)
- [sim/run_mnist_jtag_parity_regression.sh](sim/run_mnist_jtag_parity_regression.sh)

## 4) Problems Encountered and Fixes

### 4.1 Model + datapath ordering mismatch

Early full-size regression exposed mismatches between expected and observed hidden/logit values.  
Root cause was weight packing/order interaction with the tiled datapath.  
Fix was explicit chunk ordering alignment in the classifier scheduling path.

### 4.2 Quartus synthesis/resource pressure

Large model memories initially caused synthesis issues if inferred incorrectly.  
Solution was moving model storage to ROM-friendly inference style that Quartus maps into device RAM/ROM resources.

### 4.3 WSL/Windows tool boundary issues

Needed stable path conversions and staged Windows builds from WSL.  
Implemented and documented scriptable staging/build/program flow.

### 4.4 Arduino reconnect and permissions

After unplug/replug, `/dev/ttyACM*` visibility and permissions can change.  
Quickstart now handles:

- `usbipd` re-attach
- serial detection retries
- optional permission fix

### 4.5 5-10 second latency

Measured root cause:

- inference compute is only a few milliseconds
- dominant delay came from launching `system-console.exe` per frame

Fix:

- added persistent System Console mode in Tcl + Python host loop
- one process stays open across frames

Observed per-frame latency after fix:

- verify on: ~`0.45s` to `0.60s`
- verify off: ~`0.24s` to `0.35s`

## 5) Final Operational State

### 5.1 What the drawing tool does

- user draws on `28x28` UI
- `SEND` emits one binary frame packet over USB serial

### 5.2 What the FPGA/host pipeline does

- host validates frame
- host writes frame to FPGA MMIO over JTAG
- host triggers one inference
- host polls done and reads prediction
- FPGA latches/display result (`HEX0`, LEDs)

This repeats indefinitely frame-by-frame without reprogramming each time.

## 6) Artifacts Saved

Final JTAG build outputs are saved under:

- [artifacts_jtag](artifacts_jtag)

Including:

- `de1_soc_mnist_jtag_top.sof`
- `*.fit.rpt`, `*.map.rpt`, `*.asm.rpt`, `*.flow.rpt`
- `*.summary`, `*.pin`, `*.sld`, `*.jdi`

## 7) Recommended Run Commands

From `~/tiny-tpu`:

```bash
bash de1_soc_mnist_demo/quickstart_jtag_demo.sh
```

Lowest latency mode:

```bash
bash de1_soc_mnist_demo/quickstart_jtag_demo.sh --no-verify-writeback
```

If boards were unplugged/replugged, rerun the same command (retry logic is built in).
