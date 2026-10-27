#!/usr/bin/env python3
"""Receive stress UART, save unmodified lines, show hex counters as decimal."""
import argparse
import datetime
import re
import sys
from pathlib import Path

PHASES = {0: '等待校准', 1: '1 MiB 自检', 2: '64 MiB 自检', 3: '1 GiB 模式覆盖',
          4: '连续读写', 5: '全容量置换读', 6: '4 KiB 块写读切换'}
PATTERNS = {0: '全0', 1: '全1', 2: 'AA', 3: '55', 4: '地址', 5: '地址取反',
            6: '地址相关伪随机', 7: '行走1', 8: '行走0'}
STATES = {0: '等校准', 1: '设置', 2: '写', 3: '读', 4: '切换', 5: '故障停止'}
ERRORS = {1: 'CAL_TIMEOUT', 2: 'CAL_LOST', 3: 'WRITE_DATA_TIMEOUT',
          4: 'WRITE_CMD_TIMEOUT', 5: 'READ_CMD_TIMEOUT', 6: 'READ_RESPONSE_TIMEOUT',
          7: 'DATA_MISMATCH', 8: 'UI_RESET', 9: 'UNEXPECTED_READ', 10: 'READ_END_MISSING'}
DEFAULT_PORT = '/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0'


def decode(line):
    """All FPGA fields are hexadecimal, including seconds and error codes."""
    if not line.startswith(('STAT ', 'ERROR ')):
        return line
    fields = {k: int(v, 16) for k, v in re.findall(r'\b(\w+)=([0-9A-Fa-f]+)\b', line)}
    get = lambda k: fields.get(k, 0)
    if line.startswith('ERROR '):
        expected = (get('expH') << 64) | get('expL')
        actual = (get('gotH') << 64) | get('gotL')
        return (f"故障 {ERRORS.get(get('code'), get('code'))}，t={get('t')} s，"
                f"阶段={PHASES.get(get('ph'), get('ph'))}，模式={PATTERNS.get(get('pat'), get('pat'))}，"
                f"pass={get('pass')}，seed=0x{get('seed'):08X}\n"
                f"  原生地址=0x{get('addr'):08X}，字节偏移=0x{get('byte'):08X}\n"
                f"  expected={expected:032X}\n  actual  ={actual:032X}\n  xor     ={expected ^ actual:032X}")
    return (f"t={get('t')} s  pass={get('pass')}  {PHASES.get(get('ph'), get('ph'))}/"
            f"{STATES.get(get('st'), get('st'))}  {PATTERNS.get(get('pat'), get('pat'))}  "
            f"size={get('size') / 1048576:g} MiB  "
            f"W={get('W') / 1073741824:.3f} GiB R={get('R') / 1073741824:.3f} GiB  "
            f"W={get('WKiBs') / 1024:.2f} MiB/s R={get('RKiBs') / 1024:.2f} MiB/s  "
            f"err={get('err')} maxrd={get('maxrd')} cal={get('cal')} drain={get('drain')}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', default=DEFAULT_PORT)
    parser.add_argument('--log', type=Path, default=Path(__file__).parent / 'build' / 'hardware_uart.log')
    parser.add_argument('--decode-file', type=Path, help='Decode a saved UART log without accessing hardware')
    args = parser.parse_args()
    if args.decode_file:
        for line in args.decode_file.read_text().splitlines():
            print(decode(line))
        return
    try:
        import serial
    except ImportError:
        parser.error('pyserial is required for live capture')
    args.log.parent.mkdir(parents=True, exist_ok=True)
    try:
        with serial.Serial(args.port, 115200, timeout=1, exclusive=True,
                           rtscts=False, dsrdtr=False) as port, args.log.open('a', buffering=1) as log:
            log.write(f"# capture {datetime.datetime.now().astimezone().isoformat()} port={args.port}\n")
            print(f'115200 8N1，日志：{args.log}；Ctrl+C 结束采集。', flush=True)
            pending = bytearray()
            while True:
                pending.extend(port.read(port.in_waiting or 1))
                while b'\n' in pending:
                    raw, _, rest = pending.partition(b'\n')
                    pending = bytearray(rest)
                    line = raw.decode('ascii', errors='replace').rstrip('\r')
                    log.write(line + '\n')
                    print(decode(line), flush=True)
                if len(pending) > 8192:
                    log.write('# discarded unterminated data: ' + repr(bytes(pending)) + '\n')
                    pending.clear()
    except KeyboardInterrupt:
        pass
    except (OSError, serial.SerialException) as exc:
        print(f'串口采集失败：{exc}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
