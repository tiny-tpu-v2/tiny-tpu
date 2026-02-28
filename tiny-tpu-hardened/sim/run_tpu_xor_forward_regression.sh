# ABOUTME: Runs the TPU XOR forward-pass regression in ModelSim 18.1 from WSL.
# ABOUTME: It fails unless the TPU testbench prints REGRESSION PASS.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RTL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MODELSIM_DIR="/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem"
WORK_DIR="/tmp/tiny_tpu_xor_forward_regression_$$"
LOG_FILE="$WORK_DIR/vsim.log"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

"$MODELSIM_DIR/vlib.exe" work >/dev/null
"$MODELSIM_DIR/vlog.exe" \
    "$RTL_DIR/fixedpoint_simple.v" \
    "$RTL_DIR/control_unit.v" \
    "$RTL_DIR/loss_child.v" \
    "$RTL_DIR/loss_parent.v" \
    "$RTL_DIR/leaky_relu_derivative_child.v" \
    "$RTL_DIR/leaky_relu_derivative_parent.v" \
    "$RTL_DIR/leaky_relu_child.v" \
    "$RTL_DIR/leaky_relu_parent.v" \
    "$RTL_DIR/bias_child.v" \
    "$RTL_DIR/bias_parent.v" \
    "$RTL_DIR/vpu.v" \
    "$RTL_DIR/gradient_descent.v" \
    "$RTL_DIR/unified_buffer.v" \
    "$RTL_DIR/pe.v" \
    "$RTL_DIR/systolic.v" \
    "$RTL_DIR/tpu.v" \
    "$SCRIPT_DIR/tpu_xor_forward_regression.v" >/dev/null

"$MODELSIM_DIR/vsim.exe" -c work.tpu_xor_forward_regression -do "run -all; quit -f" >"$LOG_FILE"
cat "$LOG_FILE"

if ! grep -q "REGRESSION PASS" "$LOG_FILE"; then
    exit 1
fi
