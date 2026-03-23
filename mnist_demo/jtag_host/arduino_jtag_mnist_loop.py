# ABOUTME: Bridges Arduino USB drawing frames into JTAG MMIO writes for on-board MNIST inference.
# ABOUTME: Handles serial/JTAG reconnect loops, frame validation, and repeated predict polling from WSL.

from __future__ import annotations

import argparse
import queue
import subprocess
import sys
import threading
import time
from collections.abc import Callable
import os
from pathlib import Path

try:
    import serial  # type: ignore
    from serial import SerialException  # type: ignore
except ImportError as import_error:  # pragma: no cover
    serial = None
    SerialException = Exception
    SERIAL_IMPORT_ERROR = import_error
else:
    SERIAL_IMPORT_ERROR = None


PROJECT_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = PROJECT_DIR.parent
DEFAULT_SYSTEM_CONSOLE = "/mnt/c/altera_lite/25.1std/quartus/sopc_builder/bin/system-console.exe"
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from de1_soc_mnist_demo.mnist_tools import FRAME_BYTES
from de1_soc_mnist_demo.mnist_tools import FRAME_HEADER
from de1_soc_mnist_demo.mnist_tools import parse_uart_frame


def discover_serial_port() -> str | None:
    for pattern in ("/dev/ttyACM*", "/dev/ttyUSB*"):
        matches = sorted(Path("/").glob(pattern.lstrip("/")))
        if matches:
            return str(matches[0])
    return None


def open_serial(port: str, baud: int, timeout_s: float = 0.1) -> serial.Serial:
    return serial.Serial(port=port, baudrate=baud, timeout=timeout_s)


def pop_next_frame(buffer: bytearray) -> list[int] | None:
    while True:
        header_index = buffer.find(FRAME_HEADER)
        if header_index < 0:
            if len(buffer) > len(FRAME_HEADER):
                del buffer[:-len(FRAME_HEADER)]
            return None

        if header_index > 0:
            del buffer[:header_index]

        if len(buffer) < FRAME_BYTES:
            return None

        frame = bytes(buffer[:FRAME_BYTES])
        del buffer[:FRAME_BYTES]
        try:
            return parse_uart_frame(frame)
        except ValueError:
            del buffer[:1]


def write_bits_file(bits: list[int], path: Path) -> None:
    lines = [str(int(bit)) for bit in bits]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def run_command(command: list[str], timeout_s: float | None = None) -> tuple[int, str, str]:
    result = subprocess.run(
        command,
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
        timeout=timeout_s,
        check=False,
    )
    return result.returncode, result.stdout, result.stderr


def to_windows_path(path: Path) -> str:
    code, stdout, stderr = run_command(["wslpath", "-w", str(path)], timeout_s=5.0)
    if code != 0:
        raise RuntimeError(
            f"wslpath failed for {path}\n"
            f"stdout:\n{stdout}\n"
            f"stderr:\n{stderr}"
        )
    return stdout.strip()


def run_mmio_command(args: argparse.Namespace, mmio_args: list[str]) -> tuple[int, str, str]:
    command = [
        "bash",
        str(PROJECT_DIR / "jtag_host" / "run_system_console_mmio.sh"),
        *mmio_args,
    ]
    return run_command(command, timeout_s=args.mmio_timeout_s)


def normalize_console_line(line: str) -> str:
    stripped = line.strip()
    if stripped.startswith("%"):
        return stripped[1:].lstrip()
    return stripped


class PersistentSystemConsole:
    def __init__(self, args: argparse.Namespace) -> None:
        self._args = args
        self._process: subprocess.Popen[str] | None = None
        self._reader_thread: threading.Thread | None = None
        self._output_queue: queue.Queue[str | None] = queue.Queue()
        self._recent_lines: list[str] = []
        self._tcl_script_win = to_windows_path(PROJECT_DIR / "jtag_host" / "mnist_jtag_mmio.tcl")
        self._bits_windows_path_cache: dict[Path, str] = {}

    def _remember_line(self, line: str) -> None:
        self._recent_lines.append(line)
        if len(self._recent_lines) > 200:
            self._recent_lines = self._recent_lines[-200:]

    def _reader_loop(self) -> None:
        assert self._process is not None
        assert self._process.stdout is not None
        for raw_line in self._process.stdout:
            line = normalize_console_line(raw_line.rstrip("\r\n"))
            self._output_queue.put(line)
            self._remember_line(line)
        self._output_queue.put(None)

    def is_alive(self) -> bool:
        return self._process is not None and self._process.poll() is None

    def _drain_queue(self) -> None:
        while True:
            try:
                self._output_queue.get_nowait()
            except queue.Empty:
                return

    def _wait_for_line(self, predicate: Callable[[str], bool], timeout_s: float, description: str) -> str:
        deadline = time.monotonic() + timeout_s
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                recent = "\n".join(self._recent_lines[-40:])
                raise RuntimeError(
                    f"timeout waiting for {description}\nrecent system-console output:\n{recent}"
                )
            try:
                line = self._output_queue.get(timeout=remaining)
            except queue.Empty as exc:
                raise RuntimeError(f"timeout waiting for {description}") from exc
            if line is None:
                recent = "\n".join(self._recent_lines[-40:])
                raise RuntimeError(f"system-console exited while waiting for {description}\n{recent}")
            if predicate(line):
                return line

    def start(self) -> None:
        self.stop()
        self._drain_queue()
        self._recent_lines = []

        system_console = self._args.system_console
        command = [system_console, "-cli", f"--script={self._tcl_script_win}", "server"]

        self._process = subprocess.Popen(
            command,
            cwd=PROJECT_DIR,
            text=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=1,
        )
        self._reader_thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._reader_thread.start()
        self._wait_for_line(
            lambda line: line.strip() == "SERVER_READY",
            timeout_s=self._args.mmio_timeout_s,
            description="SERVER_READY",
        )

    def stop(self) -> None:
        process = self._process
        if process is None:
            return

        try:
            if process.poll() is None and process.stdin is not None:
                process.stdin.write("QUIT\n")
                process.stdin.flush()
        except Exception:
            pass

        try:
            process.wait(timeout=1.0)
        except subprocess.TimeoutExpired:
            try:
                process.terminate()
                process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=1.0)

        self._process = None
        self._drain_queue()

    def _send_line(self, line: str) -> None:
        if not self.is_alive():
            recent = "\n".join(self._recent_lines[-40:])
            raise RuntimeError(f"system-console server is not running\n{recent}")
        assert self._process is not None
        assert self._process.stdin is not None
        self._process.stdin.write(line + "\n")
        self._process.stdin.flush()

    def _request(self, op: str, fields: list[str], timeout_s: float) -> list[str]:
        op_upper = op.upper()
        begin_token = f"BEGIN {op_upper}"
        end_token = f"END {op_upper}"
        command_line = "\t".join([op_upper, *fields]) if fields else op_upper
        self._send_line(command_line)

        deadline = time.monotonic() + timeout_s
        in_block = False
        payload: list[str] = []

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                recent = "\n".join(self._recent_lines[-40:])
                raise RuntimeError(
                    f"timeout waiting for response to {op_upper}\nrecent system-console output:\n{recent}"
                )
            try:
                line = self._output_queue.get(timeout=remaining)
            except queue.Empty as exc:
                raise RuntimeError(f"timeout waiting for response to {op_upper}") from exc
            if line is None:
                recent = "\n".join(self._recent_lines[-40:])
                raise RuntimeError(f"system-console exited during {op_upper}\n{recent}")

            if not in_block:
                if line.strip() == begin_token:
                    in_block = True
                continue

            if line.strip() == end_token:
                break
            payload.append(line)

        for line in payload:
            if line.startswith("ERROR "):
                raise RuntimeError(f"{op_upper} failed: {line[6:]}")
        if "OK" not in payload:
            raise RuntimeError(f"{op_upper} response missing OK marker: {payload}")
        return [line for line in payload if line != "OK"]

    def health(self) -> tuple[str, str]:
        response = self._request("HEALTH", [], timeout_s=self._args.mmio_timeout_s)
        version_line = ""
        status_line = ""
        for line in response:
            stripped = line.strip()
            if stripped.startswith("VERSION "):
                version_line = stripped
            if stripped.startswith("STATUS "):
                status_line = stripped
        if "VERSION 0x4D4E4953" not in version_line:
            raise RuntimeError(f"unexpected health version: {response}")
        if not status_line:
            raise RuntimeError(f"missing STATUS line in health response: {response}")
        return version_line, status_line

    def _windows_bits_path(self, bits_file: Path) -> str:
        resolved = bits_file.resolve()
        if resolved not in self._bits_windows_path_cache:
            self._bits_windows_path_cache[resolved] = to_windows_path(resolved)
        return self._bits_windows_path_cache[resolved]

    def predict_bits(self, bits_file: Path, infer_timeout_ms: int, verify_writeback: bool) -> int:
        verify_flag = "1" if verify_writeback else "0"
        bits_path = self._windows_bits_path(bits_file)
        timeout_s = max(self._args.mmio_timeout_s, (infer_timeout_ms / 1000.0) + 2.0)
        response = self._request(
            "PREDICT_BITS",
            [bits_path, str(infer_timeout_ms), verify_flag],
            timeout_s=timeout_s,
        )

        prediction = None
        for line in response:
            stripped = line.strip()
            if stripped.startswith("PREDICTION "):
                prediction = int(stripped.split()[1])
                break
        if prediction is None:
            raise RuntimeError(f"missing PREDICTION line in response: {response}")
        return prediction


def maybe_program_fpga(args: argparse.Namespace) -> None:
    if not args.auto_program:
        return
    command = ["bash", str(PROJECT_DIR / "program_fpga_jtag.sh")]
    code, stdout, stderr = run_command(command, timeout_s=args.program_timeout_s)
    if code != 0:
        raise RuntimeError(
            "program_fpga_jtag.sh failed\n"
            f"stdout:\n{stdout}\n"
            f"stderr:\n{stderr}"
        )


def ensure_jtag_ready(args: argparse.Namespace) -> None:
    last_error = ""
    for attempt in range(1, args.jtag_retries + 1):
        code, stdout, stderr = run_mmio_command(args, ["health"])
        if code == 0 and "VERSION 0x4D4E4953" in stdout:
            return

        last_error = (
            f"attempt {attempt} failed\nstdout:\n{stdout}\nstderr:\n{stderr}"
        )

        if args.auto_program:
            try:
                maybe_program_fpga(args)
            except RuntimeError as program_error:
                last_error = f"{last_error}\nprogramming error: {program_error}"

        time.sleep(args.reconnect_delay_s)

    raise RuntimeError(f"JTAG health check failed after retries:\n{last_error}")


def parse_prediction(stdout: str) -> int:
    for line in stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith("PREDICTION "):
            return int(stripped.split()[1])
    raise ValueError(f"missing PREDICTION line in output:\n{stdout}")


def run_predict(
    args: argparse.Namespace,
    bits_file: Path,
    persistent_mmio: PersistentSystemConsole | None,
) -> int:
    if persistent_mmio is not None:
        return persistent_mmio.predict_bits(bits_file, args.infer_timeout_ms, args.verify_writeback)

    verify_flag = "1" if args.verify_writeback else "0"
    code, stdout, stderr = run_mmio_command(
        args,
        ["predict_bits", str(bits_file), str(args.infer_timeout_ms), verify_flag],
    )
    if code != 0:
        raise RuntimeError(f"predict_bits failed\nstdout:\n{stdout}\nstderr:\n{stderr}")
    return parse_prediction(stdout)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Arduino-to-JTAG MNIST streaming loop",
    )
    parser.add_argument("--serial-port", default="", help="Arduino serial port (/dev/ttyACM0)")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--infer-timeout-ms", type=int, default=7000)
    parser.add_argument("--mmio-timeout-s", type=float, default=30.0)
    parser.add_argument("--program-timeout-s", type=float, default=30.0)
    parser.add_argument("--system-console", default=os.environ.get("SYSTEM_CONSOLE", DEFAULT_SYSTEM_CONSOLE))
    parser.add_argument("--jtag-retries", type=int, default=5)
    parser.add_argument("--serial-retries", type=int, default=0)
    parser.add_argument("--reconnect-delay-s", type=float, default=1.0)
    parser.add_argument("--verify-writeback", action="store_true")
    parser.add_argument("--auto-program", action="store_true")
    parser.add_argument("--no-persistent-mmio", action="store_true")
    parser.add_argument("--once", action="store_true")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()

    if SERIAL_IMPORT_ERROR is not None:
        raise RuntimeError(
            "pyserial is required. Install with: pip install pyserial\n"
            f"import error: {SERIAL_IMPORT_ERROR}"
        )

    ensure_jtag_ready(args)

    persistent_mmio: PersistentSystemConsole | None = None
    if not args.no_persistent_mmio:
        persistent_mmio = PersistentSystemConsole(args)
        persistent_mmio.start()
        persistent_mmio.health()

    runtime_dir = PROJECT_DIR / "jtag_host" / "runtime"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    bits_file = runtime_dir / "current_frame.bits"

    serial_retry_count = 0
    frame_count = 0

    while True:
        port = args.serial_port or discover_serial_port()
        if not port:
            time.sleep(args.reconnect_delay_s)
            continue

        try:
            serial_link = open_serial(port, args.baud)
        except SerialException as serial_error:
            print(f"[serial] open failed on {port}: {serial_error}")
            serial_retry_count += 1
            if args.serial_retries > 0 and serial_retry_count >= args.serial_retries:
                raise
            time.sleep(args.reconnect_delay_s)
            continue

        print(f"[serial] connected {port} @ {args.baud}")
        serial_retry_count = 0
        frame_buffer = bytearray()

        try:
            while True:
                try:
                    chunk = serial_link.read(256)
                except SerialException as serial_error:
                    print(f"[serial] disconnected: {serial_error}")
                    break

                if not chunk:
                    continue

                frame_buffer.extend(chunk)

                while True:
                    bits = pop_next_frame(frame_buffer)
                    if bits is None:
                        break

                    frame_count += 1
                    write_bits_file(bits, bits_file)

                    try:
                        start_time = time.perf_counter()
                        prediction = run_predict(args, bits_file, persistent_mmio)
                        latency_ms = (time.perf_counter() - start_time) * 1000.0
                        print(f"[infer] frame={frame_count} prediction={prediction} latency_ms={latency_ms:.1f}")
                    except RuntimeError as infer_error:
                        print(f"[jtag] inference error: {infer_error}")
                        if persistent_mmio is not None:
                            persistent_mmio.stop()
                        ensure_jtag_ready(args)
                        if not args.no_persistent_mmio:
                            persistent_mmio = PersistentSystemConsole(args)
                            persistent_mmio.start()
                            persistent_mmio.health()
                        continue

                    if args.once:
                        if persistent_mmio is not None:
                            persistent_mmio.stop()
                        return 0
        finally:
            serial_link.close()

        time.sleep(args.reconnect_delay_s)

    if persistent_mmio is not None:
        persistent_mmio.stop()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
