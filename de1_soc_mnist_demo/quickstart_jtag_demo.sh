#!/usr/bin/env bash
# ABOUTME: Automates the plug-in bring-up flow for the no-wire JTAG MNIST demo from WSL.
# ABOUTME: Attaches Arduino USB to WSL, programs FPGA, runs health/predict checks, then starts streaming inference.
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

USBIPD_EXE_DEFAULT="/mnt/c/Program Files/usbipd-win/usbipd.exe"
VERSION_MAGIC="VERSION 0x4D4E4953"

DO_BUILD=0
DO_PROGRAM=1
DO_ONESHOT=1
RUN_LOOP=1
VERIFY_WRITEBACK=1
AUTO_ATTACH=1
FIX_SERIAL_PERMS=1
LOOP_AUTO_PROGRAM=1
SERIAL_PORT=""
BITS_FILE=""
PREDICT_TIMEOUT_MS=8000
SETUP_RETRIES=10
RETRY_DELAY_S=2

log() {
    printf '[quickstart] %s\n' "$*"
}

die() {
    printf '[quickstart] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: bash quickstart_jtag_demo.sh [options]

Options:
  --build               Build JTAG bitstream before programming (slow).
  --skip-program        Skip FPGA programming.
  --skip-oneshot        Skip one-shot sample predict_bits check.
  --no-loop             Stop after setup checks (do not start continuous loop).
  --serial-port <path>  Force serial port (example: /dev/ttyACM0).
  --bits-file <path>    Use this bits file for one-shot predict_bits.
  --timeout-ms <ms>     One-shot inference timeout in milliseconds (default: 8000).
  --setup-retries <n>   Number of setup retries for unplug/replug recovery (default: 10).
  --retry-delay-s <s>   Delay between setup retries in seconds (default: 2).
  --no-verify-writeback Disable MMIO readback verification for predict_bits and loop.
  --no-auto-attach      Do not run usbipd attach for Arduino.
  --no-serial-perms     Do not attempt sudo chmod on serial device if access fails.
  --no-loop-auto-program Disable FPGA auto-program retry logic in the continuous loop.
  -h, --help            Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            DO_BUILD=1
            shift
            ;;
        --skip-program)
            DO_PROGRAM=0
            shift
            ;;
        --skip-oneshot)
            DO_ONESHOT=0
            shift
            ;;
        --no-loop)
            RUN_LOOP=0
            shift
            ;;
        --serial-port)
            [[ $# -ge 2 ]] || die "--serial-port requires a value"
            SERIAL_PORT="$2"
            shift 2
            ;;
        --bits-file)
            [[ $# -ge 2 ]] || die "--bits-file requires a value"
            BITS_FILE="$2"
            shift 2
            ;;
        --timeout-ms)
            [[ $# -ge 2 ]] || die "--timeout-ms requires a value"
            PREDICT_TIMEOUT_MS="$2"
            shift 2
            ;;
        --setup-retries)
            [[ $# -ge 2 ]] || die "--setup-retries requires a value"
            SETUP_RETRIES="$2"
            shift 2
            ;;
        --retry-delay-s)
            [[ $# -ge 2 ]] || die "--retry-delay-s requires a value"
            RETRY_DELAY_S="$2"
            shift 2
            ;;
        --no-verify-writeback)
            VERIFY_WRITEBACK=0
            shift
            ;;
        --no-auto-attach)
            AUTO_ATTACH=0
            shift
            ;;
        --no-serial-perms)
            FIX_SERIAL_PERMS=0
            shift
            ;;
        --no-loop-auto-program)
            LOOP_AUTO_PROGRAM=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

find_serial_port() {
    local candidate
    for candidate in /dev/ttyACM* /dev/ttyUSB*; do
        if [[ -e "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

maybe_attach_arduino() {
    local usbipd_exe="${USBIPD_EXE:-$USBIPD_EXE_DEFAULT}"
    local list_output=""
    local busid=""

    if [[ "$AUTO_ATTACH" -eq 0 ]]; then
        return 0
    fi

    if [[ ! -x "$usbipd_exe" ]]; then
        log "usbipd not found at '$usbipd_exe'; skipping auto-attach"
        return 0
    fi

    list_output="$("$usbipd_exe" list 2>/dev/null || true)"
    busid="$(printf '%s\n' "$list_output" | awk '/Arduino/ {print $1; exit}')"

    if [[ -z "$busid" ]]; then
        log "No Arduino device found in usbipd list; skipping auto-attach"
        return 0
    fi

    log "Attaching Arduino busid $busid to WSL"
    "$usbipd_exe" attach --wsl --busid "$busid" >/dev/null 2>&1 || true
}

ensure_serial_port_ready() {
    local attempts=30
    local port=""

    if [[ -n "$SERIAL_PORT" ]]; then
        port="$SERIAL_PORT"
        if [[ ! -e "$port" ]]; then
            log "serial port does not exist yet: $port"
            return 1
        fi
    else
        while (( attempts > 0 )); do
            if port="$(find_serial_port)"; then
                break
            fi
            sleep 1
            attempts=$((attempts - 1))
        done
        if [[ -z "$port" ]]; then
            log "no /dev/ttyACM* or /dev/ttyUSB* detected yet"
            return 1
        fi
    fi

    if [[ ! -r "$port" || ! -w "$port" ]]; then
        if [[ "$FIX_SERIAL_PERMS" -eq 0 ]]; then
            log "insufficient permissions on $port (use sudo chmod a+rw $port)"
            return 1
        fi

        log "Adjusting serial permissions on $port (may prompt for sudo password)"
        if ! sudo chmod a+rw "$port"; then
            log "failed to adjust permissions on $port"
            return 1
        fi
    fi

    SERIAL_PORT="$port"
    log "Using serial port $SERIAL_PORT"
    return 0
}

prepare_sample_bits_file() {
    local output_file="$SCRIPT_DIR/jtag_host/runtime/sample_image_0.bits"
    mkdir -p "$SCRIPT_DIR/jtag_host/runtime"

    if [[ -n "$BITS_FILE" ]]; then
        [[ -f "$BITS_FILE" ]] || die "bits file not found: $BITS_FILE"
        printf '%s\n' "$BITS_FILE"
        return 0
    fi

    python3 - "$output_file" <<'PY'
from pathlib import Path
import sys

from mnist_tools import unpack_binary_image

out_path = Path(sys.argv[1])
sample_bin = Path("model/sample_image_0.bin")
bits = unpack_binary_image(sample_bin.read_bytes())
out_path.write_text("\n".join(str(int(bit)) for bit in bits) + "\n", encoding="ascii")
print(str(out_path))
PY
}

run_health_check() {
    local output
    output="$(bash "$SCRIPT_DIR/jtag_host/run_system_console_mmio.sh" health 2>&1)" || {
        printf '%s\n' "$output"
        return 1
    }
    printf '%s\n' "$output"
    if ! printf '%s\n' "$output" | grep -q "$VERSION_MAGIC"; then
        log "unexpected MMIO health output: missing '$VERSION_MAGIC'"
        return 1
    fi
    return 0
}

run_one_shot_predict() {
    local bits_path="$1"
    local verify_flag=0

    if [[ "$VERIFY_WRITEBACK" -eq 1 ]]; then
        verify_flag=1
    fi

    bash "$SCRIPT_DIR/jtag_host/run_system_console_mmio.sh" \
        predict_bits "$bits_path" "$PREDICT_TIMEOUT_MS" "$verify_flag"
}

run_setup_with_retries() {
    local attempt=1
    local one_shot_bits=""

    while (( attempt <= SETUP_RETRIES )); do
        log "Setup attempt $attempt/$SETUP_RETRIES"

        maybe_attach_arduino
        if ! ensure_serial_port_ready; then
            log "Serial setup not ready, retrying in ${RETRY_DELAY_S}s"
            sleep "$RETRY_DELAY_S"
            attempt=$((attempt + 1))
            continue
        fi

        if [[ "$DO_PROGRAM" -eq 1 ]]; then
            log "Programming FPGA"
            if ! bash "$SCRIPT_DIR/program_fpga_jtag.sh"; then
                log "FPGA programming failed, retrying in ${RETRY_DELAY_S}s"
                sleep "$RETRY_DELAY_S"
                attempt=$((attempt + 1))
                continue
            fi
        fi

        log "Running MMIO health check"
        if ! run_health_check; then
            log "JTAG health check failed, retrying in ${RETRY_DELAY_S}s"
            sleep "$RETRY_DELAY_S"
            attempt=$((attempt + 1))
            continue
        fi

        if [[ "$DO_ONESHOT" -eq 1 ]]; then
            log "Running one-shot predict_bits"
            if ! one_shot_bits="$(prepare_sample_bits_file)"; then
                log "Failed to prepare one-shot sample bits file"
                sleep "$RETRY_DELAY_S"
                attempt=$((attempt + 1))
                continue
            fi
            if ! run_one_shot_predict "$one_shot_bits"; then
                log "One-shot predict_bits failed, retrying in ${RETRY_DELAY_S}s"
                sleep "$RETRY_DELAY_S"
                attempt=$((attempt + 1))
                continue
            fi
        fi

        return 0
    done

    return 1
}

if [[ "$DO_BUILD" -eq 1 ]]; then
    log "Building JTAG Quartus project"
    bash "$SCRIPT_DIR/build_quartus_jtag.sh"
fi

if ! run_setup_with_retries; then
    die "setup failed after ${SETUP_RETRIES} attempts (check USB cables/power and rerun)"
fi

if [[ "$RUN_LOOP" -eq 0 ]]; then
    log "Setup complete (continuous loop disabled by --no-loop)"
    exit 0
fi

log "Starting continuous Arduino->JTAG loop"
LOOP_ARGS=(--serial-port "$SERIAL_PORT")
if [[ "$VERIFY_WRITEBACK" -eq 1 ]]; then
    LOOP_ARGS+=(--verify-writeback)
fi
if [[ "$LOOP_AUTO_PROGRAM" -eq 1 ]]; then
    LOOP_ARGS+=(--auto-program)
fi

exec python3 -u "$SCRIPT_DIR/jtag_host/arduino_jtag_mnist_loop.py" "${LOOP_ARGS[@]}"
