#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec bash "$SCRIPT_DIR/de1_soc_mnist_demo/start_mnist_demo.sh" "$@"
