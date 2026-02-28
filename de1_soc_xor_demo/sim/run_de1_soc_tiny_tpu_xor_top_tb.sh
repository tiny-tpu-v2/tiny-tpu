# ABOUTME: Runs the DE1-SoC top-level XOR demo testbench in ModelSim 18.1 from WSL.
# ABOUTME: It fails unless the board-level testbench prints REGRESSION PASS.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ROOT_DIR=$(CDPATH= cd -- "$PROJECT_DIR/.." && pwd)
MODELSIM_DIR="/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem"
WORK_DIR="/tmp/de1_soc_tiny_tpu_xor_top_tb_$$"
LOG_FILE="$WORK_DIR/vsim.log"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

"$MODELSIM_DIR/vlib.exe" work >/dev/null
"$MODELSIM_DIR/vlog.exe" \
    "$ROOT_DIR/tiny-tpu-hardened/fixedpoint_simple.v" \
    "$ROOT_DIR/tiny-tpu-hardened/control_unit.v" \
    "$ROOT_DIR/tiny-tpu-hardened/loss_child.v" \
    "$ROOT_DIR/tiny-tpu-hardened/loss_parent.v" \
    "$ROOT_DIR/tiny-tpu-hardened/leaky_relu_derivative_child.v" \
    "$ROOT_DIR/tiny-tpu-hardened/leaky_relu_derivative_parent.v" \
    "$ROOT_DIR/tiny-tpu-hardened/leaky_relu_child.v" \
    "$ROOT_DIR/tiny-tpu-hardened/leaky_relu_parent.v" \
    "$ROOT_DIR/tiny-tpu-hardened/bias_child.v" \
    "$ROOT_DIR/tiny-tpu-hardened/bias_parent.v" \
    "$ROOT_DIR/tiny-tpu-hardened/vpu.v" \
    "$ROOT_DIR/tiny-tpu-hardened/gradient_descent.v" \
    "$ROOT_DIR/tiny-tpu-hardened/unified_buffer.v" \
    "$ROOT_DIR/tiny-tpu-hardened/pe.v" \
    "$ROOT_DIR/tiny-tpu-hardened/systolic.v" \
    "$ROOT_DIR/tiny-tpu-hardened/tpu.v" \
    "$PROJECT_DIR/de1_soc_tiny_tpu_xor_top.v" \
    "$SCRIPT_DIR/de1_soc_tiny_tpu_xor_top_tb.v" >/dev/null

"$MODELSIM_DIR/vsim.exe" -c work.de1_soc_tiny_tpu_xor_top_tb -do "run -all; quit -f" >"$LOG_FILE"
cat "$LOG_FILE"

if ! grep -q "REGRESSION PASS" "$LOG_FILE"; then
    exit 1
fi
