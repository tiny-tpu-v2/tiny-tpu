# Tiny TPU Hardened

This folder isolates the hardened TPU implementation from the main development tree and keeps the ASIC flow inputs separate from the FPGA demos.

## Layout

- `rtl/`: Hardened Verilog sources used by OpenLane and the local regressions.
- `openlane/config.json`: OpenLane entry point for the hardened `tpu` design.
- `openlane/runs/`: Existing OpenLane run outputs and checkpoints.
- `sim/`: Focused ModelSim regressions for fixed-point arithmetic, unified buffer behavior, and XOR forward-pass coverage.

## Common Entry Points

- `tiny-tpu-hardened/openlane/config.json`: primary OpenLane design configuration.
- `bash sim/run_fixedpoint_simple_regression.sh`
- `bash sim/run_unified_buffer_regression.sh`
- `bash sim/run_tpu_xor_forward_regression.sh`

Treat `openlane/runs/` as generated flow output and keep new collateral contained there.
