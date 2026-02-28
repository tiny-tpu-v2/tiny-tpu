# ABOUTME: Builds the DE1-SoC tiny-tpu XOR Quartus project from WSL.
# ABOUTME: It stages the project onto a Windows path before invoking Quartus.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_xor_demo"

if ! command -v rsync >/dev/null 2>&1; then
    echo "rsync is required to stage the Quartus build tree" >&2
    exit 1
fi

mkdir -p "$STAGING_ROOT"

rsync -a --delete \
    --exclude db \
    --exclude incremental_db \
    --exclude output_files \
    "$SCRIPT_DIR/" "$STAGING_PROJECT_DIR/"

rsync -a --delete \
    --exclude sim \
    "$ROOT_DIR/tiny-tpu-hardened/" "$STAGING_ROOT/tiny-tpu-hardened/"

cd "$STAGING_PROJECT_DIR"

"/mnt/c/altera_lite/25.1std/quartus/bin64/quartus_sh.exe" --flow compile de1_soc_tiny_tpu_xor
