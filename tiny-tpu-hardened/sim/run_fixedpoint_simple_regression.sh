# ABOUTME: Runs the simplified fixed-point regression in ModelSim 18.1 from WSL.
# ABOUTME: It fails unless the Q8.8 arithmetic testbench prints REGRESSION PASS.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RTL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MODELSIM_DIR="/mnt/c/intelFPGA/18.1/modelsim_ase/win32aloem"
WORK_DIR="/tmp/tiny_tpu_fixedpoint_regression_$$"
LOG_FILE="$WORK_DIR/vsim.log"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

"$MODELSIM_DIR/vlib.exe" work >/dev/null
"$MODELSIM_DIR/vlog.exe" \
    "$RTL_DIR/fixedpoint_simple.v" \
    "$SCRIPT_DIR/fixedpoint_simple_regression.v" >/dev/null

"$MODELSIM_DIR/vsim.exe" -c work.fixedpoint_simple_regression -do "run -all; quit -f" >"$LOG_FILE"
cat "$LOG_FILE"

if ! grep -q "REGRESSION PASS" "$LOG_FILE"; then
    exit 1
fi
