# ABOUTME: Builds the DE1-SoC tiny-tpu XOR Quartus project from WSL.
# ABOUTME: It stages the project onto a Windows path before invoking Quartus.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_xor_demo"
QUARTUS_BIN="/mnt/c/altera_lite/25.1std/quartus/bin64"

"$SCRIPT_DIR/stage_quartus_project.sh"
cd "$STAGING_PROJECT_DIR"

"$QUARTUS_BIN/quartus_map.exe" \
    --read_settings_files=on \
    --write_settings_files=off \
    de1_soc_tiny_tpu_xor \
    -c de1_soc_tiny_tpu_xor

"$QUARTUS_BIN/quartus_fit.exe" \
    --read_settings_files=off \
    --write_settings_files=off \
    de1_soc_tiny_tpu_xor \
    -c de1_soc_tiny_tpu_xor

"$QUARTUS_BIN/quartus_asm.exe" \
    --read_settings_files=off \
    --write_settings_files=off \
    de1_soc_tiny_tpu_xor \
    -c de1_soc_tiny_tpu_xor
