#!/usr/bin/env bash
# ABOUTME: Builds the JTAG-driven DE1-SoC MNIST Quartus revision from WSL.
# ABOUTME: Regenerates the JTAG bridge IP, stages the project to Windows, and runs map/fit/asm.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_mnist_demo"
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/c/altera_lite/25.1std/quartus/bin64}
REVISION=de1_soc_mnist_jtag_top

bash "$SCRIPT_DIR/jtag_ip/generate_mnist_jtag_bridge.sh"
bash "$SCRIPT_DIR/stage_quartus_project.sh"
cd "$STAGING_PROJECT_DIR"

"$QUARTUS_BIN/quartus_map.exe" \
    --read_settings_files=on \
    --write_settings_files=off \
    "$REVISION" \
    -c "$REVISION"

"$QUARTUS_BIN/quartus_cdb.exe" \
    "$REVISION" \
    -c "$REVISION" \
    --merge

"$QUARTUS_BIN/quartus_fit.exe" \
    --read_settings_files=off \
    --write_settings_files=off \
    "$REVISION" \
    -c "$REVISION"

"$QUARTUS_BIN/quartus_asm.exe" \
    --read_settings_files=off \
    --write_settings_files=off \
    "$REVISION" \
    -c "$REVISION"
