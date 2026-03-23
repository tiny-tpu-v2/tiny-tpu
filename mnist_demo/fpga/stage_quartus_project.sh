# ABOUTME: Stages the DE1-SoC MNIST project onto a Windows-visible build path.
# ABOUTME: It copies this self-contained project tree into the disposable Quartus staging directory.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
STAGING_ROOT=${QUARTUS_BUILD_ROOT:-/mnt/c/fpga_builds/tiny-tpu-fpga-staging}
STAGING_PROJECT_DIR="$STAGING_ROOT/de1_soc_mnist_demo"

if ! command -v rsync >/dev/null 2>&1; then
    echo "rsync is required to stage the Quartus build tree" >&2
    exit 1
fi

mkdir -p "$STAGING_ROOT"

rsync -a --delete \
    --exclude db \
    --exclude incremental_db \
    --exclude fpga/serial/output_files \
    --exclude fpga/jtag/output_files_jtag \
    "$PROJECT_DIR/" "$STAGING_PROJECT_DIR/"
