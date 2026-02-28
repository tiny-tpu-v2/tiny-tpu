# Memory

## Working Rules

- Address the user as Jesse.
- Use this file as the journal for this workspace.
- Ignore existing uncommitted changes unless Jesse says otherwise.
- Treat `/home/surya/tiny-tpu` as the working directory for upcoming prompts.

## Environment Facts

- Windows Quartus install in active use: `/mnt/c/altera_lite/25.1std`
- Older ModelSim install: `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem`
- The older ModelSim `10.5b` batch flow works from WSL for plain Verilog.
- The newer Questa install compiles from WSL, but runtime simulation is blocked by SALT licensing.
- The entire `tiny-tpu-hardened` Verilog RTL compiles cleanly under ModelSim 18.1 from WSL.
- The original `tiny-tpu-original/src/*.sv` SystemVerilog RTL does not compile under ModelSim 18.1 here; `vlog -sv` fails with repeated `Could not find the package (std)` errors.
- `tiny-tpu-original/docs/training_results.txt` contains a valid XOR-capable trained weight set with outputs effectively `0, 1, 1, 0`.
- `tiny-tpu-original/docs/single_pass_results.txt` and the constants in `test/test_tpu.py` are not sufficient for a correct XOR classifier by themselves.

## Mistakes

- I initially stopped on the dirty git state before Jesse explicitly allowed me to ignore uncommitted changes.
- I ran `vlib` and `vlog` in parallel once even though the compile depended on the library being initialized first. For simulator checks, run setup steps sequentially.

## Critical Findings

- The existing cocotb tests in `tiny-tpu-original/test` are weak as regressions. Many of the intended assertions are commented out, so they do not reliably prove functional correctness.
- `tiny-tpu-hardened/unified_buffer.v` has a confirmed dual-write bug: if both host write valids are high in one cycle, both writes target the same `wr_ptr` address and `wr_ptr` advances only once.
- A one-off ModelSim checkbench confirmed the bug: after a two-lane host write, `mem0=2222 mem1=0000 wr_ptr=1` instead of storing two distinct words.
- The unified buffer uses the same shared-pointer update pattern in its read paths, so multi-lane reads also need to be treated as suspect until proven otherwise.
- The new self-checking ModelSim regression in `tiny-tpu-hardened/sim/unified_buffer_regression.v` exposed a second root-cause issue: each read-path start pulse is overwritten in the same clock cycle by that path's inactive-state reset logic, so read transactions never latch at all in the current RTL.
- After the UB repair, `tiny-tpu-hardened/sim/run_unified_buffer_regression.sh` passes, the full hardened TPU still compiles cleanly in ModelSim, and Quartus analysis for `unified_buffer` and `tpu` remains successful with fewer warnings than before the patch.
