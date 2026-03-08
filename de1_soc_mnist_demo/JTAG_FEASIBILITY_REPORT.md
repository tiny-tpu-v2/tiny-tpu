# JTAG MNIST Feasibility Report

Date: 2026-03-07  
Workspace: `~/tiny-tpu/de1_soc_mnist_demo`

## Scope

Goal: replace direct Arduino-to-FPGA UART/GPIO transport with:

- Arduino -> USB serial -> PC
- PC -> USB-Blaster II JTAG -> DE1-SoC FPGA
- Host MMIO writes/reads over JTAG into a memory-mapped image/control interface

## Definite (Verified Here)

1. Quartus Lite 25.1 tooling is callable from WSL via Windows executables.
- Verified commands:
  - `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sh.exe --version`
  - `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_pgm.exe --help`

2. USB-Blaster II cable discovery works in this environment.
- Verified command:
  - `/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe`
- Detected chain includes the DE-SoC cable and FPGA device.

3. System Console Tcl is present and supports master read/write commands.
- Verified executable:
  - `/mnt/c/altera_lite/25.1std/quartus/sopc_builder/bin/system-console.exe`
- Verified service commands available in Tcl:
  - `master_read_32`, `master_write_32`, etc.

4. JTAG-to-Avalon master IP is available in this Lite install.
- Verified by generating `mnist_jtag_bridge.qsys` and synthesis output under:
  - `jtag_ip/mnist_jtag_bridge/`

5. JTAG MMIO RTL path is functionally valid in simulation.
- Passing tests:
  - `bash sim/run_mnist_jtag_mmio_tb.sh`
  - `bash sim/run_mnist_jtag_classifier_tb.sh`
  - `bash sim/run_mnist_jtag_parity_regression.sh`

## Likely (Based On Build Evidence)

1. The full JTAG top-level compiles through Analysis & Synthesis.
- `quartus_map` completes successfully for `de1_soc_mnist_jtag_top`.
- Resource report is within Cyclone V budget.

2. End-to-end host control loop is viable.
- Implemented scripts exist for:
  - MMIO health/read/write/predict via System Console Tcl
  - Arduino frame ingest + reconnect/retry + predict loop in Python

## Uncertain / Operational Caveats

1. Native Linux Quartus inside WSL is not installed in this environment.
- Current workflow is hybrid: WSL orchestration + Windows Quartus executables.

2. `quartus_fit.exe` launched from WSL can appear quiet for long periods.
- `quartus_map` is confirmed.
- In this session, map + partition merge completed and were captured in `artifacts_jtag`, while fitter did not reach a completed report from the WSL-invoked loop.
- If fitter progress visibility is poor, use:
  - Quartus GUI on Windows for compile steps, or
  - run the same revision from Windows shell directly.

3. System Console `master` service requires a bitstream that includes `mnist_jtag_bridge`.
- If the current FPGA image does not include the bridge, `health` reports no master service.

## Conclusion

The no-wire architecture is feasible and implemented as a concrete, scriptable path in this repository:

- FPGA side: JTAG bridge + MMIO image/control interface + classifier integration
- Host side: System Console MMIO commands + Arduino serial ingestion loop
- Verification side: ModelSim checks for MMIO behavior, end-to-end prediction, and serial-vs-JTAG parity
