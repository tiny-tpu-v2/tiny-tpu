#!/usr/bin/env bash
# ABOUTME: Runs serial-ingress and JTAG-ingress full regressions and compares predicted digits.
# ABOUTME: Provides a quick parity gate that transport changes did not alter functional inference output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/modelsim_mnist_jtag_parity"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

SERIAL_LOG="$WORK_DIR/serial_full.log"
JTAG_LOG="$WORK_DIR/jtag_full.log"

bash "$SCRIPT_DIR/run_mnist_serial_classifier_full_tb.sh" | tee "$SERIAL_LOG"
bash "$SCRIPT_DIR/run_mnist_jtag_classifier_tb.sh" | tee "$JTAG_LOG"

serial_digit=$(grep -Eo 'expected digit [0-9]+' "$SERIAL_LOG" | tail -n1 | awk '{print $3}')
jtag_digit=$(grep -Eo 'expected digit [0-9]+' "$JTAG_LOG" | tail -n1 | awk '{print $3}')

if [[ -z "$serial_digit" || -z "$jtag_digit" ]]; then
    echo "failed to parse prediction from regression logs" >&2
    exit 1
fi

if [[ "$serial_digit" != "$jtag_digit" ]]; then
    echo "parity mismatch: serial=$serial_digit jtag=$jtag_digit" >&2
    exit 1
fi

echo "PASS: parity regression matched prediction digit $serial_digit"
