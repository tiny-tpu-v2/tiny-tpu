# ABOUTME: Verifies program_fpga.sh can fall back to the local artifact bitstream when no staged build exists.
# ABOUTME: Replaces Quartus tools with test doubles so the path selection can be checked without hardware access.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEST_ROOT=$(mktemp -d)
FAKE_BIN="$TEST_ROOT/bin"
LOG_FILE="$TEST_ROOT/invocations.log"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/jtagconfig.exe" <<EOF
#!/bin/sh
printf '%s\n' "jtagconfig \$*" >>"$LOG_FILE"
EOF

cat >"$FAKE_BIN/quartus_pgm.exe" <<EOF
#!/bin/sh
printf '%s\n' "quartus_pgm \$*" >>"$LOG_FILE"
EOF

chmod 755 "$FAKE_BIN/jtagconfig.exe" "$FAKE_BIN/quartus_pgm.exe"

QUARTUS_BUILD_ROOT="$TEST_ROOT/missing_staging" \
QUARTUS_BIN="$FAKE_BIN" \
QUARTUS_CABLE="TEST_CABLE" \
QUARTUS_BYPASS_DEVICE="TEST_BYPASS" \
QUARTUS_FPGA_DEVICE_INDEX=2 \
bash "$SCRIPT_DIR/program_fpga.sh"

grep -q "artifacts\\\\de1_soc_mnist_serial_top.sof@2" "$LOG_FILE"
