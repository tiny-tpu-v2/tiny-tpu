# ModelSim 18.1 From WSL

This is the practical guide for using the older standalone ModelSim install from WSL.

## Verified Install

The installer you referenced is present:

- `/mnt/c/Users/surya/Downloads/ModelSimSetup-18.1.0.625-windows.exe`

The installed simulator matches it:

- install root: `C:\intelFPGA\18.1`
- WSL path: `/mnt/c/intelFPGA/18.1`

Verified simulator version:

- `Model Technology ModelSim ALTERA STARTER EDITION vsim 10.5b Simulator 2016.10 Oct 5 2016`

## What Works Right Now

The following binaries are installed and callable from WSL:

- `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/modelsim.exe`
- `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlib.exe`
- `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlog.exe`
- `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vmap.exe`
- `/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vsim.exe`

I verified a real batch smoke test from WSL:

- `vlib.exe work` succeeded
- `vlog.exe` compiled a plain-Verilog DUT and testbench with `0` errors
- `vsim.exe -c ... -do "run -all; quit -f"` ran successfully
- the testbench printed `PASS: legacy smoke testbench completed`

So this older ModelSim is a usable WSL-driven verification path.

## Important Language Caveat

In this environment, the `10.5b` install compiled plain Verilog successfully, but a simple SystemVerilog `.sv` testbench failed with:

- `Could not find the package (std)`

Practical implication:

- plain Verilog verification is reliable now
- SystemVerilog support in this older install is likely too brittle for your main workflow

For a SystemVerilog-heavy design, use one of these approaches:

- keep ModelSim 10.5b for plain Verilog modules and legacy testbenches
- convert selected SystemVerilog modules to Verilog for simulation if needed
- use the newer Questa install once its licensing is fixed, if you want better SystemVerilog coverage

## Recommended Project Location

Keep the active project on the Windows filesystem so the Windows simulator sees a native path:

- Windows: `C:\fpga\tiny-tpu`
- WSL: `/mnt/c/fpga/tiny-tpu`

Do not run the Windows simulator against a `\\wsl$...` path.

## Recommended File Layout

Use a simple split between design and simulation files:

```text
/mnt/c/fpga/tiny-tpu/
  rtl/
    top.v
    submodule_a.v
    submodule_b.v
  sim/
    tb/
      tb_top.v
    do/
      run.do
```

For this older ModelSim, prefer:

- `.v` for DUT files if possible
- `.v` for testbenches unless you know the exact SystemVerilog subset you are using is safe

## Minimal Batch Workflow From WSL

From WSL:

```bash
cd /mnt/c/fpga/tiny-tpu/sim
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlib.exe' work
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlog.exe' ../rtl/top.v tb/tb_top.v
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vsim.exe' -c work.tb_top -do "run -all; quit -f"
```

If you have multiple Verilog files:

```bash
cd /mnt/c/fpga/tiny-tpu/sim
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlib.exe' work
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vlog.exe' \
  ../rtl/submodule_a.v \
  ../rtl/submodule_b.v \
  ../rtl/top.v \
  tb/tb_top.v
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vsim.exe' -c work.tb_top -do "run -all; quit -f"
```

## Recommended `run.do`

Put this in `sim/do/run.do`:

```tcl
run -all
quit -f
```

Then run:

```bash
cd /mnt/c/fpga/tiny-tpu/sim
'/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem/vsim.exe' -c work.tb_top -do do/run.do
```

## Proper Testbench Structure

For FPGA logic verification, keep the testbench self-checking:

- generate clock and reset explicitly
- drive inputs in a controlled sequence
- compare outputs automatically
- print a clear pass/fail message
- include a timeout if the design can hang

This keeps the feedback loop fast:

1. edit RTL in WSL
2. run `vlog.exe`
3. run `vsim.exe`
4. fix logic
5. repeat

## If Your Design Starts In SystemVerilog

Since your design begins in SystemVerilog, the safe workflow with this older ModelSim is:

- first try to simulate only the plain-Verilog subset
- if a module uses SystemVerilog features, either simplify it or convert it before relying on this simulator
- keep the real Quartus synthesis flow separate, since Quartus may accept more SystemVerilog than this old ModelSim does

This matters because:

- simulation compatibility and synthesis compatibility are not the same
- a design may synthesize in Quartus but still be awkward to simulate in ModelSim 10.5b

## When To Prefer Newer Questa Instead

Use the newer Questa install instead of this old ModelSim if you need:

- better SystemVerilog support
- richer testbench constructs
- more modern simulator behavior

But today, the newer Questa path on this machine is blocked by runtime licensing. The old ModelSim path is the one that is actually usable right now from WSL.

## Bottom Line

`ModelSimSetup-18.1.0.625-windows.exe` matches the installed `C:\intelFPGA\18.1` ModelSim environment.

From WSL, the `18.1 / 10.5b` ModelSim flow is usable now for plain-Verilog verification:

- compile with `vlog.exe`
- run with `vsim.exe`
- use Windows-native project paths via `/mnt/c/...`

For your project, this is a workable immediate verification path, but it is best treated as a Verilog-first simulator rather than a robust SystemVerilog simulator.
