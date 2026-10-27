#!/usr/bin/env python3
"""Bounded, receive-only capture around the explicitly authorized Flash boot."""
import argparse
import datetime
import os
from pathlib import Path
import subprocess
import sys
import time
from zoneinfo import ZoneInfo

import serial

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PORT = '/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', default=DEFAULT_PORT)
    parser.add_argument('--seconds', type=float, default=120)
    parser.add_argument('--output', type=Path, default=ROOT / 'TEST/stress/build/diagnostic_flash_boot.log')
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600:
        parser.error('--seconds must be 1..600')
    if not Path(args.port).exists():
        parser.error(f'UART device missing: {args.port}')
    # Do not compete with a terminal already receiving the user's UART data.
    probe = subprocess.run(['fuser', os.path.realpath(args.port)], capture_output=True, text=True)
    if probe.stdout.strip():
        parser.error(f'UART already open by process(es): {probe.stdout.strip()}')
    port = serial.Serial(port=None, baudrate=115200, timeout=0.2, exclusive=True)
    port.dtr = False
    port.rts = False
    port.port = args.port
    port.open()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    boot_log = ROOT / 'VIVADO/diagnostic_build/flash_boot_console.log'
    started = time.time()
    deadline = time.monotonic() + args.seconds
    finished = None
    try:
        with args.output.open('wb') as output:
            stamp = datetime.datetime.now(ZoneInfo('Asia/Shanghai')).isoformat()
            output.write(f'# diagnostic boot capture {stamp} 115200 8N1\n'.encode())
            output.flush()
            print(f'CAPTURE READY: {args.port} -> {args.output}', flush=True)
            while time.monotonic() < deadline:
                data = port.read(4096)
                if data:
                    output.write(data)
                    output.flush()
                    print(repr(data), flush=True)
                if boot_log.exists() and boot_log.stat().st_mtime >= started:
                    text = boot_log.read_text(errors='replace')
                    if 'DIAGNOSTIC BOOT REQUEST COMPLETED' in text or 'DIAGNOSTIC BOOT FAILED:' in text:
                        if finished is None:
                            finished = time.monotonic()
                        elif time.monotonic() - finished > 20:
                            break
    finally:
        port.close()
    print(f'CAPTURE FINISHED: {args.output.stat().st_size} bytes', flush=True)


if __name__ == '__main__':
    main()
