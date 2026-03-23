#!/usr/bin/env bash
# ABOUTME: Compiles and runs the full JTAG MMIO plus classifier regression in ModelSim.
# ABOUTME: Checks that host-style image writes produce the expected tracked-sample prediction.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELSIM_DIR="${MODELSIM_DIR:-/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem}"
WORK_DIR="$SCRIPT_DIR/modelsim_mnist_jtag_classifier"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"
"$MODELSIM_DIR/vlib.exe" "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vmap.exe" work "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vlog.exe" \
  -work work \
  "$(wslpath -w "$PROJECT_DIR/rtl/fixedpoint_simple.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/unified_buffer.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/systolic.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/vpu.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/bias_child.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/bias_parent.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/leaky_relu_child.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/leaky_relu_parent.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/leaky_relu_derivative_child.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/leaky_relu_derivative_parent.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/loss_child.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/loss_parent.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/gradient_descent.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/pe.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/tpu_mnist.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_classifier_core.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_jtag_mmio.v")" \
  "$(wslpath -w "$SCRIPT_DIR/tb_mnist_jtag_classifier.v")"
"$MODELSIM_DIR/vsim.exe" \
  -c \
  -do "run -all; quit -f" \
  work.tb_mnist_jtag_classifier
