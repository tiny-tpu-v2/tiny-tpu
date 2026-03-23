# MNIST Demo

This folder packages the DE1-SoC MNIST demo into a single, predictable layout for FPGA builds, host-side JTAG tooling, model assets, and generated outputs.

## Layout

- `fpga/`: Quartus build, staging, programming, and bring-up scripts, plus the `serial/` and `jtag/` project revisions.
- `rtl/`: MNIST-specific RTL and shared TPU datapath modules used by simulation and FPGA builds.
- `host/jtag/`: Python host utilities for MMIO checks, inference requests, and the continuous Arduino/JTAG loop.
- `firmware/arduino/`: Arduino sketches used to feed handwritten input into the demo.
- `data/model/reference/`: Checked-in quantized weights, sample inputs, and reference metadata.
- `data/model/generated/`: Regenerated training outputs from `train_mnist.py`.
- `tools/`: Data export and benchmarking helpers.
- `sim/`: ModelSim runners and testbenches.
- `tests/`: Python and shell regression coverage for the local tooling.
- `artifacts/`: Generated Quartus outputs, simulation work products, previews, benchmarks, and runtime captures.

## Common Entry Points

- `bash fpga/start_mnist_demo.sh`: full JTAG demo startup flow.
- `bash fpga/build_quartus.sh`: build the serial Quartus revision.
- `bash fpga/build_quartus_jtag.sh`: build the JTAG-driven Quartus revision.
- `python3 train_mnist.py`: regenerate quantized MNIST model files into `data/model/generated/`.

Generated outputs should stay under `artifacts/` so the source tree remains readable.
