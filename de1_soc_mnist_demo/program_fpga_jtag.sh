#!/usr/bin/env bash
# ABOUTME: Programs the JTAG-driven MNIST FPGA image onto the DE1-SoC over USB-Blaster II.
# ABOUTME: Prefers staged build outputs and falls back to checked-in artifacts when available.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_mnist_demo"
SOF_FILE="$STAGING_PROJECT_DIR/output_files_jtag/de1_soc_mnist_jtag_top.sof"
FALLBACK_SOF_FILE="$SCRIPT_DIR/artifacts_jtag/de1_soc_mnist_jtag_top.sof"
LEGACY_FALLBACK_SOF_FILE="$SCRIPT_DIR/artifacts/de1_soc_mnist_jtag_top.sof"
CABLE_NAME=${QUARTUS_CABLE:-"DE-SoC [USB-1]"}
BYPASS_DEVICE=${QUARTUS_BYPASS_DEVICE:-"SOCVHPS"}
FPGA_DEVICE_INDEX=${QUARTUS_FPGA_DEVICE_INDEX:-2}
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/c/altera_lite/25.1std/quartus/bin64}
JTAGCONFIG="$QUARTUS_BIN/jtagconfig.exe"
QUARTUS_PGM="$QUARTUS_BIN/quartus_pgm.exe"

if [ ! -f "$SOF_FILE" ]; then
    if [ -f "$FALLBACK_SOF_FILE" ]; then
        SOF_FILE="$FALLBACK_SOF_FILE"
    elif [ -f "$LEGACY_FALLBACK_SOF_FILE" ]; then
        SOF_FILE="$LEGACY_FALLBACK_SOF_FILE"
    else
        echo "missing bitstream: $SOF_FILE" >&2
        echo "fallback not found: $FALLBACK_SOF_FILE" >&2
        echo "run build_quartus_jtag.sh first" >&2
        exit 1
    fi
fi

SOF_FILE_WIN=$(wslpath -w "$SOF_FILE")

"$JTAGCONFIG"
"$QUARTUS_PGM" -m JTAG -c "$CABLE_NAME" \
    -o "s;$BYPASS_DEVICE@1" \
    -o "p;$SOF_FILE_WIN@$FPGA_DEVICE_INDEX"
