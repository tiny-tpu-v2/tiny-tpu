# Questa / ModelSim Verification Guide For DE1-SoC

This guide covers how to use the Intel-bundled simulator for DE1-SoC RTL testbench verification from WSL, using the Windows-installed toolchain.

## Current Status On This Machine

The simulator binaries are installed and callable from WSL:

- `/mnt/c/altera_lite/25.1std/questa_fse/win64/vlib.exe`
- `/mnt/c/altera_lite/25.1std/questa_fse/win64/vlog.exe`
- `/mnt/c/altera_lite/25.1std/questa_fse/win64/vsim.exe`
- `/mnt/c/altera_lite/25.1std/questa_fse/win64/vmap.exe`
- `/mnt/c/altera_lite/25.1std/questa_fse/win64/vopt.exe`

Verified directly:

- `vlog.exe -version` runs
- `vsim.exe -version` runs
- `vlib.exe work` succeeds
- `vlog.exe` successfully compiled a smoke-test Verilog DUT plus SystemVerilog testbench with `0` errors and `0` warnings

Important blocker:

- `vsim.exe` currently fails at simulation runtime with:
  - `Unable to checkout a license`
  - `Invalid license environment`

That means:

- compile-only flow is working now
- full batch simulation is not yet usable until the simulator license is configured correctly

So the answer is:

- proper testbench verification is possible with this toolchain in principle
- it is not fully operational on this machine yet because runtime simulation is blocked by licensing

## What This Simulator Can Verify

Once licensing is fixed, this is the correct tool for:

- RTL simulation of Verilog and SystemVerilog logic
- self-checking testbenches
- module-level and top-level functional verification
- gate-level or post-fit simulation flows, if you later export Quartus netlists and required simulation libraries

What it does not replace:

- physical board bring-up
- actual pin-level I/O behavior on the DE1-SoC board
- signal integrity issues
- metastability caused by real asynchronous inputs
- HPS software execution on the ARM side

For DE1-SoC work, the simulator is for FPGA fabric logic verification before programming hardware.

## Recommended Simulation File Layout

Use a clean split between synthesizable RTL and simulation-only files:

```text
tiny-tpu-hardened/
  rtl/
    top.sv
    submodule_a.sv
    submodule_b.v
  sim/
    tb/
      tb_top.sv
    do/
      run.do
    waves/
    transcript/
  quartus/
    de1_soc_top.qpf
    de1_soc_top.qsf
  constraints/
    DE1_SoC_reference.qsf
```

Recommended rules:

- keep synthesizable design files under `rtl/`
- keep testbenches under `sim/tb/`
- keep `.do` scripts under `sim/do/`
- keep Quartus project files separate from testbench files

## Minimal Batch Flow

Run the simulator from a Windows-native path, not a `\\wsl$` path.

That means the project should live in:

- Windows: `C:\fpga\de1soc_project`
- WSL: `/mnt/c/fpga/de1soc_project`

Basic compile and run flow:

```bash
cd /mnt/c/fpga/de1soc_project/sim
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vlib.exe' work
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vlog.exe' ../rtl/top.sv tb/tb_top.sv
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vsim.exe' -c work.tb_top -do "run -all; quit -f"
```

If you use multiple RTL files:

```bash
cd /mnt/c/fpga/de1soc_project/sim
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vlib.exe' work
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vlog.exe' \
  ../rtl/submodule_a.sv \
  ../rtl/submodule_b.v \
  ../rtl/top.sv \
  tb/tb_top.sv
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vsim.exe' -c work.tb_top -do "run -all; quit -f"
```

## Recommended `run.do` Script

Put this in `sim/do/run.do`:

```tcl
run -all
quit -f
```

Then run:

```bash
cd /mnt/c/fpga/de1soc_project/sim
'/mnt/c/altera_lite/25.1std/questa_fse/win64/vsim.exe' -c work.tb_top -do do/run.do
```

## How To Structure A Proper Testbench

For DE1-SoC-targeted FPGA logic, a useful testbench should:

- instantiate the real synthesizable top-level or a stable submodule boundary
- generate clocks and resets explicitly
- drive realistic stimulus sequences
- check outputs automatically with assertions or self-checking comparisons
- avoid board-only assumptions such as pushbutton bounce unless modeled intentionally

A good testbench usually includes:

- clock generator
- reset sequence
- directed stimulus
- pass/fail checks
- timeout protection so broken simulations do not hang

## If You Use Intel FPGA IP Or Primitives

If your design uses:

- PLLs
- on-chip RAM wrappers
- vendor-generated IP
- device primitives

then you may need the Intel/Altera simulation libraries compiled for Questa.

Use the Quartus-provided EDA simulation library compile flow before expecting vendor IP to simulate correctly.

Practical rule:

- plain Verilog/SystemVerilog modules usually simulate immediately
- vendor IP often needs Quartus-generated simulation models and libraries

## DE1-SoC-Specific Notes

The DE1-SoC board `.qsf` from FPGAcademy is for:

- device selection
- pin locations
- I/O assignments

It is not the main input for simulation.

For simulation, the key inputs are:

- RTL source files
- testbench files
- optional memory init files
- optional vendor simulation libraries

So the normal verification order is:

1. simulate the logic
2. fix functional bugs
3. compile in Quartus
4. merge or verify pin assignments in the `.qsf`
5. program the board

## Current Licensing Blocker

This installation is using the newer Siemens SALT licensing model.

Observed from the installed release notes:

- starting with `2025.1`, `MGLS_LICENSE_FILE` and `LM_LICENSE_FILE` are deprecated
- the expected environment variable is `SALT_LICENSE_SERVER`

The packaged readme points to Intel's licensing and installation instructions:

- `https://www.intel.com/content/www/us/en/programmable/documentation/esc1425946071433.html`

Until the simulator license is configured correctly, `vsim.exe` will not run testbenches to completion in batch mode.

## Secondary Configuration Note

During compilation, `vlog.exe` reported that it was using:

- `C:/altera/24.1std/questa_fse/win64/../modelsim.ini`

even though the active simulator binary was from:

- `C:/altera_lite/25.1std/questa_fse/...`

This did not block compilation, but it suggests an older simulator configuration file is still being picked up. After licensing is fixed, it is worth cleaning that up so the active `25.1std` install is using its own expected configuration.

## Bottom Line

The installed Questa / ModelSim-compatible toolchain is the right tool for DE1-SoC RTL testbench verification, and the compile path from WSL is already proven.

The only reason it is not fully usable today is the runtime license setup for `vsim.exe`.

Once that is fixed, the WSL-driven batch verification loop is straightforward:

- edit in WSL
- compile with `vlog.exe`
- run with `vsim.exe`
- fix issues
- rebuild in Quartus
- program the DE1-SoC
