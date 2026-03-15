# DE1-SoC Quartus Workflow (WSL + Windows)

This workflow is set up for editing from WSL while using the Windows-installed Quartus Prime Lite tools for synthesis, timing, programming, and board-side software debug.

## Verified On This Machine

The active Quartus install is:

- Windows: `C:\altera_lite\25.1std`
- WSL: `/mnt/c/altera_lite/25.1std`

The older tree at `C:\intelFPGA_lite\18.0` is present but appears incomplete. Do not use it for new work.

The following Windows executables are present and callable from WSL:

- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sh.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_map.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_fit.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_asm.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sta.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_pgm.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe`
- `/mnt/c/altera_lite/25.1std/quartus/bin64/jtagserver.exe`

Nios V software tools are also present:

- `/mnt/c/altera_lite/25.1std/niosv/bin/niosv-app.exe`
- `/mnt/c/altera_lite/25.1std/niosv/bin/niosv-download.exe`
- `/mnt/c/altera_lite/25.1std/niosv/bin/niosv-shell.exe`

These were validated from WSL. `quartus_sh.exe --version` runs correctly. `jtagconfig.exe` runs and currently reports no attached JTAG hardware, which is expected if the board is disconnected or the cable is not enumerated yet.

## Recommended Project Layout

Keep the project in a Windows-visible path and work on it from WSL:

- Windows: `C:\fpga\de1soc_project`
- WSL: `/mnt/c/fpga/de1soc_project`

This avoids file sync issues and lets both WSL tools and Windows Quartus use the same project tree.

Suggested layout:

```text
/mnt/c/fpga/de1soc_project/
  rtl/
    top.sv
    ...
  sim/
    tb_top.sv
    ...
  constraints/
    DE1_SoC_reference.qsf
  quartus/
    de1_soc_top.qpf
    de1_soc_top.qsf
  software/
    niosv/
```

## RTL Language Guidance

Start with SystemVerilog as-is.

- Keep synthesizable files as `.sv`.
- Add them directly to Quartus.
- Only convert to plain Verilog if Quartus rejects specific constructs.

Commonly supported in synthesis:

- `logic`
- `always_ff`, `always_comb`
- packed vectors
- `enum` in many cases

Commonly problematic:

- interfaces
- classes
- dynamic arrays
- assertions intended only for simulation
- advanced testbench-only features

If conversion becomes necessary, use `sv2v` as a targeted fallback, not as the default path.

## Base Quartus Flow

### 1. Create The Project

Use the Quartus GUI once to create the project:

- Launch `C:\altera_lite\25.1std\quartus\bin64\quartus.exe`
- Create a new project in `C:\fpga\de1soc_project\quartus`
- Add your `.sv` files
- Set the top-level entity

For the DE1-SoC board, use the board reference `.qsf` from FPGAcademy as the starting point for device and pin assignments. That is the right source for the board-specific pin map.

### 2. Bring In The DE1-SoC Reference QSF

Use the DE1-SoC `.qsf` from:

- <https://fpgacademy.org/boards.html>

Recommended use:

- Keep the downloaded board file as `constraints/DE1_SoC_reference.qsf`
- Copy the relevant `set_location_assignment` and `set_instance_assignment` lines into your active project `.qsf`
- Keep your own top-level, file list, and build-specific settings in the project `.qsf`

Practical rule:

- Treat the FPGAcademy `.qsf` as the source of truth for pin assignments
- Treat your project `.qsf` as the source of truth for project structure and build settings

You can provide the exact `.qsf` contents when you are ready, and then the pin assignments can be merged cleanly against your chosen top-level ports.

### 3. Compile From WSL Using The Windows CLI

From WSL:

```bash
cd /mnt/c/fpga/de1soc_project/quartus
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sh.exe' --flow compile de1_soc_top
```

Where `de1_soc_top` is the Quartus revision/project name.

Useful individual stages:

```bash
cd /mnt/c/fpga/de1soc_project/quartus
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_map.exe' de1_soc_top
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_fit.exe' de1_soc_top
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_asm.exe' de1_soc_top
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sta.exe' de1_soc_top
```

Outputs will typically appear under `output_files/`.

### 4. Program The FPGA

First, confirm the cable is visible:

```bash
'/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe'
```

Then program the bitstream:

```bash
cd /mnt/c/fpga/de1soc_project/quartus
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_pgm.exe' \
  -m jtag \
  -o "p;output_files/de1_soc_top.sof"
```

If multiple cables or devices are present, add `-c <index>`.

## Debug And Inspection Workflow

### JTAG Hardware Detection

Use this first when programming fails:

```bash
'/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe'
```

If it reports no hardware:

- check the USB-Blaster cable
- check the board power
- check that Windows USB-Blaster drivers are installed
- check that no stale `jtagserver` instance is wedged

You can also start the server explicitly if needed:

```bash
'/mnt/c/altera_lite/25.1std/quartus/bin64/jtagserver.exe'
```

### Timing And Build Debug

Use the standard compile logs plus timing analysis:

```bash
cd /mnt/c/fpga/de1soc_project/quartus
'/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sta.exe' de1_soc_top
```

Look at:

- fitter failures
- unconstrained clocks
- setup or hold violations
- pins left unassigned

### Nios V Software Debug

If your design includes a Nios V CPU, the software-side CLI is available from WSL.

Basic app generation:

```bash
'/mnt/c/altera_lite/25.1std/niosv/bin/niosv-app.exe' --help
```

Basic download and run:

```bash
'/mnt/c/altera_lite/25.1std/niosv/bin/niosv-download.exe' --reset --go app.elf
```

Useful targeting options:

- `--cable`
- `--device`
- `--instance`

Those are important when more than one JTAG target is present.

## Optional WSL Convenience Aliases

If you want a cleaner WSL shell workflow, add aliases like these to your shell config:

```bash
alias quartus_sh_win='/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sh.exe'
alias quartus_pgm_win='/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_pgm.exe'
alias jtagconfig_win='/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe'
alias niosv_download_win='/mnt/c/altera_lite/25.1std/niosv/bin/niosv-download.exe'
```

Then:

```bash
cd /mnt/c/fpga/de1soc_project/quartus
quartus_sh_win --flow compile de1_soc_top
jtagconfig_win
quartus_pgm_win -m jtag -o "p;output_files/de1_soc_top.sof"
```

## What This Workflow Buys You

- Edit from WSL using Linux-native tools and editor workflows
- Keep one shared project tree
- Compile with the actual Windows-supported Quartus toolchain
- Program and inspect JTAG from WSL without needing to switch terminals
- Use Nios V CLI tooling for software bring-up and debug if your design includes a soft CPU

## Next Integration Step

When you have the DE1-SoC `.qsf` ready, the next step is:

- map your top-level ports to the board file
- merge the necessary pin assignments into the project `.qsf`
- run a first compile

At that point, the remaining work is mechanical: top-level naming, pin binding, clock constraints, and then first hardware bring-up.
