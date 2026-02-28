# DE1-SoC Tiny-TPU XOR Demo

This directory contains the working DE1-SoC FPGA port of the tiny-tpu XOR demo.

This final deliverable folder is self-contained for normal use: it includes the top-level design, the final RTL dependency set, the simulation script, the Quartus project, the build/program helpers, and a captured artifact bundle.

The only external requirements are the tool installations and the board hardware:

- Quartus Prime Lite for build/program
- ModelSim/Questa Intel Edition for simulation
- a DE1-SoC board with USB-Blaster access

The scripts are override-friendly:

- `QUARTUS_BIN` can point at a different Quartus `bin64` directory
- `MODELSIM_DIR` can point at a different ModelSim directory
- `QUARTUS_BUILD_ROOT` can move the disposable Windows staging tree

The end result is a deterministic, press-to-run XOR inference on real hardware:

- `SW[1:0]` selects the two XOR inputs.
- `KEY[0]` triggers exactly one inference run.
- `HEX0` latches the result (`0` or `1`) and does not change again until the next button press.

## Final Working Artifacts

- Top-level FPGA wrapper: `de1_soc_tiny_tpu_xor_top.v`
- Final RTL snapshot used by the demo: `rtl/`
- Quartus project: `de1_soc_tiny_tpu_xor.qpf`, `de1_soc_tiny_tpu_xor.qsf`, `de1_soc_tiny_tpu_xor.sdc`
- WSL-to-Windows staging helper: `stage_quartus_project.sh`
- WSL CLI build helper: `build_quartus.sh`
- WSL CLI programming helper: `program_fpga.sh`
- Board-level ModelSim testbench: `sim/de1_soc_tiny_tpu_xor_top_tb.v`
- Captured Quartus build outputs: `artifacts/`

## What The Original Design Was

The original tiny-tpu design was not a board-ready FPGA demo. It was a TPU-style RTL core with:

- a host write interface
- a `unified_buffer` memory block
- a `systolic` compute array
- a `vpu` post-processing block

The original verification intent lived in `tiny-tpu-original/test/test_tpu.py`. That file describes the expected host transaction flow:

- write inputs, weights, and biases into the TPU-visible memory map
- trigger the same read paths the TPU expects
- observe forward-pass outputs

The original source tree in `tiny-tpu-original/src` was SystemVerilog. In this environment, that source was not the practical implementation base because the available ModelSim 18.1 flow failed on the original SV files with package resolution issues.

The OpenLane-safe Verilog copy in `tiny-tpu-hardened/` was used as the real implementation base. That preserved the intended architecture while making the local ModelSim and Quartus flows workable.

## What Changed From The Original Implementation

The core architecture was preserved. The finished design still uses the real:

- `tpu`
- `unified_buffer`
- `systolic`
- `vpu`

The main changes were:

- repaired functional bugs in the hardened RTL that prevented the original host transaction model from working correctly
- added self-checking regression testbenches around those fixes
- added a DE1-SoC top-level wrapper that turns switches and a pushbutton into the existing host-style TPU transaction sequence
- added WSL scripts for staging, building, and programming through the Windows Quartus install

The FPGA wrapper does not bypass the TPU. It drives the real TPU interface and replays a verified forward-only XOR sequence through the existing memory and compute path.

## How To Run It From WSL

### 1. Run The Self-Contained ModelSim Check

From `/home/surya/tiny-tpu/de1_soc_xor_demo`:

```bash
bash sim/run_de1_soc_tiny_tpu_xor_top_tb.sh
```

This runs the final board-level regression using only files in this folder. It checks:

- board wrapper behavior, including one-press execution and latched display behavior
- the local `rtl/` snapshot wired into the real TPU path

The lower-level development regressions used during bring-up still exist elsewhere in the repo history, but they are not required for the final day-to-day demo flow.

### 2. Stage The Quartus Project Onto Windows

This folder is the canonical source for the final demo, but Quartus should compile from a real Windows path.

Run:

```bash
bash /home/surya/tiny-tpu/de1_soc_xor_demo/stage_quartus_project.sh
```

This copies the project into:

```text
/mnt/c/fpga_builds/tiny-tpu-fpga-staging/de1_soc_xor_demo
```

That directory is the disposable Quartus staging tree. The canonical source remains this WSL project folder:

```text
/home/surya/tiny-tpu/de1_soc_xor_demo
```

If you change the WSL source, rerun the staging script before using Quartus again.

### 3. Build From WSL Using The CLI

Run:

```bash
bash /home/surya/tiny-tpu/de1_soc_xor_demo/build_quartus.sh
```

This does:

- stage the current WSL source into `C:\fpga_builds\tiny-tpu-fpga-staging`
- run `quartus_map`
- run `quartus_fit`
- run `quartus_asm`

The generated bitstream is:

```text
/mnt/c/fpga_builds/tiny-tpu-fpga-staging/de1_soc_xor_demo/output_files/de1_soc_tiny_tpu_xor.sof
```

The repo also keeps a captured copy of the most recent generated programming and report files in:

```text
/home/surya/tiny-tpu/de1_soc_xor_demo/artifacts
```

### 4. Program The FPGA From WSL

With the DE1-SoC connected and visible through USB-Blaster:

```bash
bash /home/surya/tiny-tpu/de1_soc_xor_demo/program_fpga.sh
```

The programming script:

- checks the JTAG chain
- bypasses the HPS device at JTAG index 1
- programs the Cyclone V FPGA at JTAG index 2

### 5. Expected On-Board Behavior

- `SW[1:0] = 00`, press `KEY[0]` -> `HEX0` shows `0`
- `SW[1:0] = 01`, press `KEY[0]` -> `HEX0` shows `1`
- `SW[1:0] = 10`, press `KEY[0]` -> `HEX0` shows `1`
- `SW[1:0] = 11`, press `KEY[0]` -> `HEX0` shows `0`

Changing switches without pressing `KEY[0]` must not change `HEX0`.

## How To Run It In The Quartus GUI

### 1. Refresh The Staging Tree First

From WSL:

```bash
bash /home/surya/tiny-tpu/de1_soc_xor_demo/stage_quartus_project.sh
```

This ensures the Windows-visible project matches the current WSL source.

### 2. Open The Staged Project In Quartus GUI

Open this file in the Windows Quartus GUI:

```text
C:\fpga_builds\tiny-tpu-fpga-staging\de1_soc_xor_demo\de1_soc_tiny_tpu_xor.qpf
```

Do not open the WSL copy through `\\wsl.localhost\...` for real builds. The reliable build path is the staged Windows path above.

### 3. Compile In The GUI

Use the normal Quartus GUI compile flow on the staged project.

Do not run a GUI compile at the same time as the CLI build script. They would contend for the same project database in the staging directory.

### 4. Program In The GUI

Use Quartus Programmer from the same staged project environment.

The JTAG chain on this board appears as:

- device 1: `SOCVHPS`
- device 2: `5CSE...` FPGA

When programming manually, target the FPGA device, not the HPS entry.

## Debug LEDs

The top wrapper also drives a few debug LEDs:

- `LEDR[0]`: high while a run is in progress
- `LEDR[1]`: the latched XOR result
- `LEDR[2]`: display-valid flag
- `LEDR[3]`: start pulse
- `LEDR[9:4]`: unused and forced low

## Verification Strategy

The port was done incrementally, not by jumping straight into board integration.

The rule used throughout was:

- prove behavior at the smallest useful scope first
- make one narrow RTL change
- rerun the smallest regression
- only then move upward into full-system integration

The practical regression ladder was:

1. `unified_buffer` local regression
2. fixed-point arithmetic local regression
3. full TPU forward XOR regression through the real host interface
4. board-wrapper regression
5. Quartus compile
6. JTAG program
7. real hardware check

## Problems Found And How They Were Solved

### 1. The Original SV Tree Was Not A Viable Local Base

Problem:

- the original `tiny-tpu-original/src/*.sv` source was not usable in the available ModelSim 18.1 flow here
- `vlog -sv` failed on repeated package resolution errors

Resolution:

- use the OpenLane-safe Verilog copy in `tiny-tpu-hardened/` as the implementation base
- treat `tiny-tpu-original/test/test_tpu.py` as the functional specification

### 2. The Existing Tests Were Too Weak

Problem:

- the original cocotb tests had important assertions commented out
- they were not strong enough to protect RTL edits

Resolution:

- add self-checking ModelSim regressions that fail on incorrect behavior

### 3. `unified_buffer` Had A Real Dual-Lane Pointer Bug

Problem:

- if both host write lanes were valid in one cycle, both writes used the same `wr_ptr`
- one write overwrote the other
- the pointer advanced as if only one element had been written

Why this mattered:

- the host-side TPU transaction flow in `test_tpu.py` depends on dual-lane writes
- without this fix, the TPU memory image was corrupted before compute even started

Resolution:

- compute each cycle from a stable base pointer
- assign lane addresses explicitly
- advance shared pointers once by the number of items consumed

### 4. `unified_buffer` Read Starts Were Being Cleared In The Same Cycle

Problem:

- each read-start pulse could be overwritten immediately by inactive-path reset logic in the same clocked block
- reads failed to latch correctly

Resolution:

- repair the sequencing so the active start path is not cancelled by the idle reset path in the same cycle

### 5. The Fixed-Point Multiplier Was Scaling Q8.8 Incorrectly

Problem:

- `1.0 * 1.0` produced `0x0001` instead of `0x0100`
- this broke the arithmetic even after memory sequencing was fixed

Resolution:

- correct the product bit alignment in `fixedpoint_simple.v`
- verify it with a dedicated self-checking regression

### 6. The XOR Weights In The Python Test Were Not The Right Golden Model

Problem:

- the constants used directly in `test_tpu.py` did not by themselves implement a correct XOR classifier

Resolution:

- derive the working XOR weights from `tiny-tpu-original/docs/training_results.txt`
- quantize them into the same fixed-point format used by the RTL
- use those weights consistently in the TPU regression and the FPGA wrapper

### 7. The First Quartus Build Path Was Wrong

Problem:

- running Quartus directly on the WSL project path pushed Windows onto a `\\wsl.localhost\...` path
- that path is not a reliable operating mode for the Windows Quartus tools

Resolution:

- stage the project onto a real Windows path under `C:\fpga_builds\...`
- compile only from the staged copy

### 8. `quartus_sh --flow compile` Was Not Reliable In This WSL Loop

Problem:

- `quartus_sh` detached while `quartus_fit` continued running
- the script could return before the bitstream existed

Resolution:

- switch the CLI flow to explicit:
  - `quartus_map`
  - `quartus_fit`
  - `quartus_asm`

### 9. `quartus_pgm` Needed Windows Paths And Explicit Device Indexing

Problem:

- the Windows programmer could not use the WSL-style `/mnt/c/...` file path directly
- the first JTAG device in the chain was the HPS, not the FPGA

Resolution:

- convert the `.sof` path with `wslpath -w`
- bypass `SOCVHPS@1`
- program the FPGA `.sof` at device index `@2`

## What The FPGA Wrapper Actually Does

The wrapper in `de1_soc_tiny_tpu_xor_top.v` is a small board-side controller.

It does not replace the TPU.

It does this:

- debounces `KEY[0]`
- latches `SW[1:0]` only when a valid start pulse arrives
- resets the TPU for a clean, deterministic run
- writes the input values, weights, and biases into the TPU through the existing host write interface
- issues the same TPU read commands used by the verified forward-pass flow
- waits for the valid output
- classifies the result as `0` or `1`
- latches the displayed value until the next button press

Because the host write path is append-only, the wrapper resets the TPU on each button press and replays the known-good memory load sequence. That keeps the demo deterministic without inventing a new random-access write path.

## From Start To Finish: The Engineering Path

This was the actual sequence used to get from the original state to the working board demo.

1. Read `tiny-tpu-original/test/test_tpu.py` as the executable behavioral spec.
2. Confirm the original SystemVerilog tree was not the practical implementation base in the available simulator.
3. Move to the hardened Verilog copy while preserving the TPU architecture.
4. Check the existing tests and recognize they were not strong enough to protect changes.
5. Build a local regression around `unified_buffer`.
6. Prove the buffer was functionally wrong before changing it.
7. Fix the buffer sequencing and rerun the same regression.
8. Run a full TPU forward-pass regression and discover arithmetic was still wrong.
9. Isolate the fixed-point multiplier, prove the scaling bug, fix it, and rerun the local regression.
10. Rerun the full TPU forward XOR regression until the TPU path itself matched the intended XOR outputs.
11. Use the trained XOR weights from `training_results.txt` as the golden model for the actual board demo.
12. Build a DE1-SoC top wrapper that drives the real TPU interface instead of bypassing it.
13. Add a board-level ModelSim regression for one-press execution and latched output behavior.
14. Create a proper Quartus project for the DE1-SoC Cyclone V target.
15. Fix the WSL-to-Windows Quartus workflow by staging to `C:\fpga_builds\...`.
16. Replace the unreliable `quartus_sh --flow compile` path with explicit `map`, `fit`, and `asm`.
17. Build the bitstream successfully.
18. Fix the programming flow for Windows path handling and JTAG device indexing.
19. Program the board and verify the XOR demo works in hardware.

That is the complete path from the original tiny-tpu core to the working DE1-SoC demonstration.

## Commit Milestones

The main milestones in git were:

- `1a50056` `parity: repair unified buffer sequencing`
- `49bbcdf` `parity: verify xor forward path`
- `45eb044` `fpga wrap: add de1-soc xor demo top`
- `2f934db` `fpga wrap: stage quartus build and bring-up`

## Practical Maintenance Rules

- Treat `/home/surya/tiny-tpu/de1_soc_xor_demo` as the canonical source for the final demo.
- Treat `C:\fpga_builds\tiny-tpu-fpga-staging` as disposable build output.
- Rerun `stage_quartus_project.sh` after changing the WSL source and before using Quartus GUI.
- Do not edit generated `db/`, `incremental_db/`, or `output_files/`.
- Do not run GUI and CLI compiles at the same time on the same staged project.
