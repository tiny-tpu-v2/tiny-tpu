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
- I launched `quartus_sh.exe` once with a PTY. That left it hanging without spawning the normal compile children, so Quartus Windows CLI runs should stay non-interactive from WSL.

## Critical Findings

- The existing cocotb tests in `tiny-tpu-original/test` are weak as regressions. Many of the intended assertions are commented out, so they do not reliably prove functional correctness.
- `tiny-tpu-hardened/unified_buffer.v` has a confirmed dual-write bug: if both host write valids are high in one cycle, both writes target the same `wr_ptr` address and `wr_ptr` advances only once.
- A one-off ModelSim checkbench confirmed the bug: after a two-lane host write, `mem0=2222 mem1=0000 wr_ptr=1` instead of storing two distinct words.
- The unified buffer uses the same shared-pointer update pattern in its read paths, so multi-lane reads also need to be treated as suspect until proven otherwise.
- The new self-checking ModelSim regression in `tiny-tpu-hardened/sim/unified_buffer_regression.v` exposed a second root-cause issue: each read-path start pulse is overwritten in the same clock cycle by that path's inactive-state reset logic, so read transactions never latch at all in the current RTL.
- After the UB repair, `tiny-tpu-hardened/sim/run_unified_buffer_regression.sh` passes, the full hardened TPU still compiles cleanly in ModelSim, and Quartus analysis for `unified_buffer` and `tpu` remains successful with fewer warnings than before the patch.
- `tiny-tpu-hardened/fixedpoint_simple.v` had a real Q8.8 multiplier scaling bug: `1.0 * 1.0` produced `0x0001` instead of `0x0100`. The fix is to align the product by `WIFA + WIFB - WOF`, and the new `run_fixedpoint_simple_regression.sh` passes.
- The hardened TPU now passes a full forward-only XOR regression through the real host-write and UB-read interface in `run_tpu_xor_forward_regression.sh`, using the trained XOR weights, the quantized `0.01` leak factor (`0x0003`), and the expected final outputs `FFFF, 00FE, 00FE, FFFF` at UB addresses `29..32`.
- Running Windows Quartus against `/home/...` from WSL puts the project on a `\\wsl.localhost\...` path. That is not a reliable build path: `cmd.exe` warns that UNC paths are unsupported, and the in-place build loop becomes difficult to trust. Stage Quartus builds onto `/mnt/c/...` first.
- For the MNIST task, the current Tiny-TPU datapath is still a 2-lane machine and the default unified buffer depth is only `128` words (`2048` bits). That depth is enough for XOR but too small for a useful digit model if kept fixed.
- The clean way to preserve the chip architecture for MNIST is to keep the same TPU structure and increase unified buffer depth for the MNIST configuration instead of bypassing the buffer.
- A `2048`-word unified buffer costs about `32768` bits, roughly `4` Cyclone V M10Ks, which is a modest FPGA memory cost.
- With a `2048`-word unified buffer, realistic single-sample working sets such as `8x8 -> 16 -> 10` (`1300` words) or `7x7 -> 16 -> 10` (`1045` words) fit in one inference pass while preserving the append-only host write model used by the existing TPU flow.
- Direct Arduino Uno to DE1-SoC FPGA wiring must treat voltage levels carefully: Uno TX is `5V`, DE1-SoC FPGA GPIO is `3.3V`, so the Uno TX line must pass through a level shifter or resistor divider before entering an FPGA input.
- For full `28x28` MNIST on the existing Tiny-TPU, the correct schedule is to tile the K dimension in chunks of `2`. The unified buffer reader logic is fundamentally two-lane, so treating a `1x784` input as one long untransposed row produces incorrect accumulation.
- The corrected `mnist_classifier_core` uses the Tiny-TPU in pass-through mode for each `K=2` chunk, accumulates raw partial sums in the controller, and applies controller-side bias plus ReLU to match the trained `sklearn` model.
- The end-to-end toy serial path is now proven in ModelSim: a framed UART packet reaches `mnist_uart_ingress`, populates the packed frame buffer, and drives `mnist_serial_classifier` to the expected class result.
- The first full 784-input MNIST regression exposed the real first divergence at `hidden_buffer[0]`: expected `0x007c`, actual `0x032d`. A software sweep showed the hardware path was effectively consuming each 2x2 weight chunk in column-major order while the exported model and scheduler were row-major.
- The RTL fix in `de1_soc_mnist_demo/rtl/mnist_classifier_core.v` is to reorder each full 2x2 weight chunk on host write from `[w00, w01, w10, w11]` to `[w00, w10, w01, w11]` before it enters the unified buffer. After that change, the full serial regression matches the quantized software reference and predicts the tracked sample as `7`.
- The original toy MNIST regressions were too weak to catch the packing bug because they used symmetric/ambiguous weight patterns. They now use asymmetric first-layer weights and both active pixels in the first chunk so the hidden activations fail immediately if the packing bug returns.
