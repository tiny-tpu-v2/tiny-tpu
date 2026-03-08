# DE1-SoC + Arduino No-Wire Workflow (JTAG MMIO)

This flow keeps the Arduino and FPGA electrically separate for data transport:

- Arduino sends drawing frames to PC over USB serial.
- PC writes image/control registers into FPGA over USB-Blaster II JTAG.
- FPGA runs inference and host reads back prediction.

## 1. Build FPGA (JTAG top)

From `de1_soc_mnist_demo`:

```bash
bash jtag_ip/generate_mnist_jtag_bridge.sh
bash build_quartus_jtag.sh
```

Revision built: `de1_soc_mnist_jtag_top`

If CLI fit appears stalled, run the merge and fit steps explicitly from a Windows shell:

```powershell
cd C:\fpga_builds\tiny-tpu-fpga-staging\de1_soc_mnist_demo
C:\altera_lite\25.1std\quartus\bin64\quartus_cdb.exe de1_soc_mnist_jtag_top -c de1_soc_mnist_jtag_top --merge
C:\altera_lite\25.1std\quartus\bin64\quartus_fit.exe --read_settings_files=off --write_settings_files=off de1_soc_mnist_jtag_top -c de1_soc_mnist_jtag_top
C:\altera_lite\25.1std\quartus\bin64\quartus_asm.exe --read_settings_files=off --write_settings_files=off de1_soc_mnist_jtag_top -c de1_soc_mnist_jtag_top
```

## 2. Program FPGA

```bash
bash program_fpga_jtag.sh
```

## 3. Sanity Check JTAG MMIO Service

```bash
bash jtag_host/run_system_console_mmio.sh health
```

Expected:

- `VERSION 0x4D4E4953`
- a valid `STATUS` line

## 4. One-Shot Inference (from prepared bits file)

Create a `784`-line text file of `0/1` bits (row-major index order), then:

```bash
bash jtag_host/run_system_console_mmio.sh predict_bits <bits_file> 7000 1
```

Arguments:

- `7000`: timeout in ms
- `1`: readback-verify each written pixel

Expected output includes:

- `WRITE_BITS_OK ...`
- `PREDICTION <digit>`

## 5. Continuous Arduino -> JTAG Inference Loop

```bash
python3 jtag_host/arduino_jtag_mnist_loop.py \
  --verify-writeback \
  --auto-program
```

Behavior:

- auto-discovers `/dev/ttyACM*` or `/dev/ttyUSB*`
- parses framed Arduino packets (`A5 5A + payload + checksum`)
- writes 28x28 bits into FPGA MMIO image region
- triggers inference
- polls done and prints predicted digit
- retries on serial/JTAG disconnects

## 6. Troubleshooting

1. `no master service found`
- FPGA likely has a non-JTAG bitstream loaded.
- Re-run `bash program_fpga_jtag.sh`.

2. `jtagconfig` cable missing
- Check DE1-SoC USB-Blaster II cable and board power.
- Re-run `jtagconfig.exe`.

3. Arduino serial port missing
- Reattach USB to WSL if needed (`usbipd` flow), then re-run loop.

4. Write-readback mismatch
- Keep `--verify-writeback` enabled.
- If repeated, rerun `health`, then reprogram FPGA.

## 7. GUI Alternative

If you prefer Quartus GUI for compile/program:

- Open `de1_soc_mnist_jtag_top.qpf`.
- Compile revision `de1_soc_mnist_jtag_top`.
- Program resulting `.sof`.
- Keep runtime MMIO control from WSL with `run_system_console_mmio.sh`.
