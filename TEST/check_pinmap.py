#!/usr/bin/env python3
"""Check adopted adapter mapping against this project's DDR3 package constraints."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
mapping = json.loads((root / 'EDA/pinmap.json').read_text())
xdc = (root / 'VIVADO/constraints/vcu118.xdc').read_text()
actual = dict((port, pin) for pin, port in re.findall(
    r'^set_property PACKAGE_PIN (\w+) \[get_ports \{(C0_DDR3_0_[^}]+)\}\]', xdc, re.M))
expected = {signal['top_port']: signal['fpga_pin'] for signal in mapping['signals']}
if len(expected) != 50 or actual != expected or len(set(actual.values())) != 50:
    raise SystemExit('FAIL: DDR3 pin mapping differs from adopted adapter mapping')
if not re.search(r'^set_property PACKAGE_PIN BA37 \[get_ports GPIO_LED7\]$', xdc, re.M):
    raise SystemExit('FAIL: LED 7 must use BA37')
print('PASS: all 50 DDR3 signal pins match adopted adapter mapping; LED 7 = BA37')
