#!/usr/bin/env bash
# ABOUTME: Builds and runs the toy tiled-classifier regression in ModelSim from WSL.
# ABOUTME: Uses the real Tiny-TPU RTL plus the MNIST classifier scheduler under test.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TPU_DIR="$PROJECT_DIR/rtl"
MODELSIM_DIR="${MODELSIM_DIR:-/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem}"
WORK_DIR="$SCRIPT_DIR/modelsim_mnist_tpu_tiled_classifier"

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
  "$(wslpath -w "$PROJECT_DIR/rtl/tpu_mnist.v")" \
  "$(wslpath -w "$PROJECT_DIR/rtl/mnist_classifier_core.v")" \
  "$(wslpath -w "$SCRIPT_DIR/tb_mnist_tpu_tiled_classifier.v")"
"$MODELSIM_DIR/vsim.exe" \
  -c \
  -do "run -all; quit -f" \
  work.tb_mnist_tpu_tiled_classifier
