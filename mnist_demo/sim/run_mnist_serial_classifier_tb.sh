#!/usr/bin/env bash
# ABOUTME: Builds and runs the end-to-end serial-ingress classifier regression in ModelSim.
# ABOUTME: Verifies a framed UART packet reaches the classifier core and produces the expected class.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TPU_DIR="$PROJECT_DIR/rtl"
MODELSIM_DIR="${MODELSIM_DIR:-/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem}"
WORK_DIR="$PROJECT_DIR/artifacts/sim/modelsim_mnist_serial_classifier"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"
"$MODELSIM_DIR/vlib.exe" "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vmap.exe" work "$(wslpath -w "$WORK_DIR/work")"
"$MODELSIM_DIR/vlog.exe" \
  -work work \
  "$(wslpath -w "$TPU_DIR/bias_child.v")" \
  "$(wslpath -w "$TPU_DIR/bias_parent.v")" \
  "$(wslpath -w "$TPU_DIR/fixedpoint_simple.v")" \
  "$(wslpath -w "$TPU_DIR/gradient_descent.v")" \
  "$(wslpath -w "$TPU_DIR/leaky_relu_child.v")" \
  "$(wslpath -w "$TPU_DIR/leaky_relu_derivative_child.v")" \
  "$(wslpath -w "$TPU_DIR/leaky_relu_derivative_parent.v")" \
  "$(wslpath -w "$TPU_DIR/leaky_relu_parent.v")" \
  "$(wslpath -w "$TPU_DIR/loss_child.v")" \
  "$(wslpath -w "$TPU_DIR/loss_parent.v")" \
  "$(wslpath -w "$TPU_DIR/pe.v")" \
  "$(wslpath -w "$TPU_DIR/systolic.v")" \
  "$(wslpath -w "$TPU_DIR/unified_buffer.v")" \
  "$(wslpath -w "$TPU_DIR/vpu.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/uart_rx.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/uart_frame_receiver.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_frame_buffer.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_uart_ingress.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/tpu_mnist.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_classifier_core.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_serial_classifier.v")" \
  "$(wslpath -w "$SCRIPT_DIR/tb_mnist_serial_classifier.v")"
"$MODELSIM_DIR/vsim.exe" \
  -c \
  -do "run -all; quit -f" \
  work.tb_mnist_serial_classifier
