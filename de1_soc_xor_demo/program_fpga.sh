# ABOUTME: Programs the DE1-SoC tiny-tpu XOR bitstream onto the FPGA over JTAG.
# ABOUTME: It uses the staged Windows build output so Quartus runs on a native Windows path.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_xor_demo"
SOF_FILE="$STAGING_PROJECT_DIR/output_files/de1_soc_tiny_tpu_xor.sof"
CABLE_NAME=${QUARTUS_CABLE:-"DE-SoC [USB-1]"}
JTAGCONFIG="/mnt/c/altera_lite/25.1std/quartus/bin64/jtagconfig.exe"
QUARTUS_PGM="/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_pgm.exe"

if [ ! -f "$SOF_FILE" ]; then
    echo "missing bitstream: $SOF_FILE" >&2
    echo "run build_quartus.sh first" >&2
    exit 1
fi

"$JTAGCONFIG"
"$QUARTUS_PGM" -m JTAG -c "$CABLE_NAME" -o "p;$SOF_FILE"
