#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELSIM_DIR="${MODELSIM_DIR:-/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem}"
WORK_DIR="$PROJECT_DIR/artifacts/sim/modelsim_uart_frame_receiver"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"
"$MODELSIM_DIR/vlib.exe" "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vmap.exe" work "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vlog.exe" \
  -work work \
  "$(wslpath -w "$PROJECT_DIR/rtl/uart_rx.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/uart_frame_receiver.v")" \
  "$(wslpath -w "$SCRIPT_DIR/tb_uart_frame_receiver.v")"
"$MODELSIM_DIR/vsim.exe" \
  -c \
  -do "run -all; quit -f" \
  work.tb_uart_frame_receiver
