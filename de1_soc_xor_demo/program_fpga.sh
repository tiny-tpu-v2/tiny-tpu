# ABOUTME: Programs the DE1-SoC tiny-tpu XOR bitstream onto the FPGA over JTAG.
# ABOUTME: It uses the staged Windows build output so Quartus runs on a native Windows path.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_xor_demo"
SOF_FILE="$STAGING_PROJECT_DIR/output_files/de1_soc_tiny_tpu_xor.sof"
CABLE_NAME=${QUARTUS_CABLE:-"DE-SoC [USB-1]"}
BYPASS_DEVICE=${QUARTUS_BYPASS_DEVICE:-"SOCVHPS"}
FPGA_DEVICE_INDEX=${QUARTUS_FPGA_DEVICE_INDEX:-2}
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/c/altera_lite/25.1std/quartus/bin64}
JTAGCONFIG="$QUARTUS_BIN/jtagconfig.exe"
QUARTUS_PGM="$QUARTUS_BIN/quartus_pgm.exe"

if [ ! -f "$SOF_FILE" ]; then
    echo "missing bitstream: $SOF_FILE" >&2
    echo "run build_quartus.sh first" >&2
    exit 1
fi

SOF_FILE_WIN=$(wslpath -w "$SOF_FILE")

"$JTAGCONFIG"
"$QUARTUS_PGM" -m JTAG -c "$CABLE_NAME" \
    -o "s;$BYPASS_DEVICE@1" \
    -o "p;$SOF_FILE_WIN@$FPGA_DEVICE_INDEX"
