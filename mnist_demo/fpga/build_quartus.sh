# ABOUTME: Builds the DE1-SoC MNIST Quartus project from WSL.
# ABOUTME: It stages the project onto a Windows path before invoking Quartus.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_mnist_demo"
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/c/altera_lite/25.1std/quartus/bin64}
REVISION=de1_soc_mnist_serial_top

bash "$SCRIPT_DIR/stage_quartus_project.sh"
cd "$STAGING_PROJECT_DIR/fpga/serial"

"$QUARTUS_BIN/quartus_map.exe" \
    --read_settings_files=on \
    --write_settings_files=off \
    "$REVISION" \
    -c "$REVISION"

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
