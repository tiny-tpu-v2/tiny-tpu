# JTAG MNIST Test Plan

## Objective

Validate that the no-wire JTAG MMIO ingress path is correct, deterministic, and functionally equivalent to the existing serial ingress for the tracked sample.

## A. Simulation Tests (ModelSim)

Run from `de1_soc_mnist_demo`:

```bash
bash sim/run_mnist_jtag_mmio_tb.sh
bash sim/run_mnist_jtag_classifier_tb.sh
bash sim/run_mnist_jtag_parity_regression.sh
```

### Expected Results

1. `run_mnist_jtag_mmio_tb.sh`
- PASS on MMIO register behavior:
  - image writes/readback
  - start pulse
  - done latch
  - clear behavior
  - write-while-busy protection

2. `run_mnist_jtag_classifier_tb.sh`
- PASS with expected digit `7` on tracked sample

3. `run_mnist_jtag_parity_regression.sh`
- PASS parity check:
  - serial full-flow prediction digit equals JTAG-flow prediction digit

## B. FPGA Bring-Up Checklist

1. Program FPGA with JTAG top:
- `bash program_fpga_jtag.sh`

2. Verify JTAG master service:
- `bash jtag_host/run_system_console_mmio.sh health`

3. MMIO sanity writes:
- Write one pixel and read it back:
  - `write32 0x100 1`
  - `read32 0x100`

4. End-to-end one-shot inference:
- `predict_bits <bits_file> 7000 1`

5. Continuous loop:
- `python3 jtag_host/arduino_jtag_mnist_loop.py --verify-writeback --auto-program`

## C. Recovery Behavior To Validate

1. Arduino reconnect:
- Unplug/replug Arduino USB while loop runs.
- Expected: loop reconnects serial and continues.

2. FPGA/JTAG reconnect:
- Power-cycle DE1-SoC or replug USB-Blaster.
- Expected: health check fails, recovery path reprograms/retries, then resumes.

3. Data integrity:
- Keep write readback verification enabled.
- Any mismatch should trigger retry and explicit error output.

## D. Acceptance Criteria

System passes when:

- JTAG MMIO simulation tests pass.
- JTAG classifier predicts expected sample digit.
- Serial-vs-JTAG parity regression matches.
- On hardware, repeated drawings produce predictions without direct Arduino->FPGA data wires.
- Disconnect/reconnect events do not require manual process restart.
