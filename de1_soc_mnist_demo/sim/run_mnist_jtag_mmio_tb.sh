#!/usr/bin/env bash
# ABOUTME: Compiles and runs the JTAG MMIO unit testbench in ModelSim from WSL.
# ABOUTME: Validates register map semantics and image/readback behavior for the host interface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELSIM_DIR="${MODELSIM_DIR:-/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem}"
WORK_DIR="$SCRIPT_DIR/modelsim_mnist_jtag_mmio"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"
"$MODELSIM_DIR/vlib.exe" "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vmap.exe" work "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vlog.exe" \
  -work work \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_jtag_mmio.v")" \
  "$(wslpath -w "$SCRIPT_DIR/tb_mnist_jtag_mmio.v")"
"$MODELSIM_DIR/vsim.exe" \
  -c \
  -do "run -all; quit -f" \
  work.tb_mnist_jtag_mmio
