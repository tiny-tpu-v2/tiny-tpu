# XOR Demo

This folder contains the smallest end-to-end FPGA demo in the repo: a DE1-SoC design that drives the TPU with XOR-oriented behavior and keeps the board files separate from the shared RTL.

## Layout

- `fpga/`: Quartus project files plus staging, build, and programming scripts.
- `rtl/`: TPU RTL used by both the FPGA project and the simulation flow.
- `sim/`: ModelSim testbench and runner for the board-level top module.
- `artifacts/quartus/`: Preserved Quartus reports and generated outputs from prior builds.

## Common Entry Points

- `bash fpga/build_quartus.sh`
- `bash fpga/program_fpga.sh`
- `bash sim/run_de1_soc_tiny_tpu_xor_top_tb.sh`

Generated Quartus outputs belong in `artifacts/` or `fpga/output_files/`, not alongside the source files.
