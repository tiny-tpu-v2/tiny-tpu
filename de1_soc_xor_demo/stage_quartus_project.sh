# ABOUTME: Stages the DE1-SoC tiny-tpu XOR project onto a Windows-visible build path.
# ABOUTME: It copies the WSL source tree into the disposable Quartus staging directory.
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
