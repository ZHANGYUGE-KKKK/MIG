#!/usr/bin/env python3
"""Receive only: capture the VCU118 FPGA SCI UART during Flash boot."""
import sys,time
from pathlib import Path
import serial
root=Path(__file__).resolve().parents[1]
port='/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0'
s=serial.Serial(port=None,baudrate=115200,timeout=0.2,exclusive=True)
s.port=port
s.dtr=False
s.rts=False
s.open()
path=root/'TEST/build/uart_flash_boot.log'
path.parent.mkdir(parents=True,exist_ok=True)
print('UART receive-only capture: '+port,flush=True)
deadline=time.monotonic()+3600
finished=None
with path.open('ab') as output:
    while time.monotonic()<deadline:
        data=s.read(4096)
        if data:
            output.write(data);output.flush()
            print(repr(data),flush=True)
        log=root/'VIVADO/build/flash_program_console.log'
        text=log.read_text(errors='replace') if log.exists() else ''
        if 'FLASH HARDWARE PASSED' in text or 'FLASH HARDWARE FAILED:' in text:
            if finished is None: finished=time.monotonic()
            if time.monotonic()-finished>20: break
s.close()
print('Captured '+str(path.stat().st_size)+' bytes to '+str(path),flush=True)
