#!/usr/bin/env bash
# ABOUTME: One-command startup wrapper for the DE1-SoC MNIST JTAG demo.
# ABOUTME: Delegates to quickstart_jtag_demo.sh with optional passthrough flags.
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

usage() {
    cat <<'EOF'
Usage:
  bash start_mnist_demo.sh [quickstart args...]

No-arg behavior:
  Runs the full plug-in startup flow:
  - auto USB attach (if usbipd is available)
  - FPGA program
  - MMIO health + one-shot check
  - continuous Arduino frame inference loop

Common examples:
  bash start_mnist_demo.sh
  bash start_mnist_demo.sh --build
  bash start_mnist_demo.sh --no-loop
  bash start_mnist_demo.sh --no-verify-writeback

For all supported flags:
  bash quickstart_jtag_demo.sh --help
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

printf '[start] launching quickstart_jtag_demo.sh %s\n' "$*"
exec bash "$SCRIPT_DIR/quickstart_jtag_demo.sh" "$@"
