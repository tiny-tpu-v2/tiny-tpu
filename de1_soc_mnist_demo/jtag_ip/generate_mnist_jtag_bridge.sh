#!/usr/bin/env bash
# ABOUTME: Generates the Platform Designer JTAG-to-Avalon bridge used by the JTAG-driven MNIST demo.
# ABOUTME: Runs qsys-script and qsys-generate from WSL through the Windows Quartus Lite install.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOPC_BIN=${SOPC_BIN:-/mnt/c/altera_lite/25.1std/quartus/sopc_builder/bin}
SEARCH_PATH=${SEARCH_PATH:-/mnt/c/altera_lite/25.1std/ip,$}

QSYS_SCRIPT="$SOPC_BIN/qsys-script.exe"
QSYS_GENERATE="$SOPC_BIN/qsys-generate.exe"

if [[ ! -x "$QSYS_SCRIPT" || ! -x "$QSYS_GENERATE" ]]; then
    echo "qsys tools were not found in $SOPC_BIN" >&2
    exit 1
fi

cd "$SCRIPT_DIR"

"$QSYS_SCRIPT" \
    --search-path="$SEARCH_PATH" \
    --script=mnist_jtag_bridge.tcl

"$QSYS_GENERATE" \
    mnist_jtag_bridge.qsys \
    --search-path="$SEARCH_PATH" \
    --synthesis=VERILOG \
    --output-directory=.
