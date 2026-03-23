#!/usr/bin/env bash
# ABOUTME: Invokes the MNIST JTAG MMIO Tcl commands through Intel System Console from WSL.
# ABOUTME: Wraps path conversion and command forwarding so host scripts can call a stable entry point.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_CONSOLE=${SYSTEM_CONSOLE:-/mnt/c/altera_lite/25.1std/quartus/sopc_builder/bin/system-console.exe}
TCL_SCRIPT="$SCRIPT_DIR/mnist_jtag_mmio.tcl"

if [[ ! -x "$SYSTEM_CONSOLE" ]]; then
    echo "system-console executable not found: $SYSTEM_CONSOLE" >&2
    exit 1
fi

if [[ ! -f "$TCL_SCRIPT" ]]; then
    echo "missing Tcl script: $TCL_SCRIPT" >&2
    exit 1
fi

TCL_SCRIPT_WIN=$(wslpath -w "$TCL_SCRIPT")

ARGS=("$@")
if [[ ${#ARGS[@]} -ge 2 ]]; then
    case "${ARGS[0]}" in
        write_bits|predict_bits)
            if [[ -f "${ARGS[1]}" ]]; then
                ARGS[1]=$(wslpath -w "${ARGS[1]}")
            fi
            ;;
    esac
fi

"$SYSTEM_CONSOLE" -cli --script="$TCL_SCRIPT_WIN" "${ARGS[@]}"
