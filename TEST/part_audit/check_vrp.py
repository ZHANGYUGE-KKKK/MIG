#!/usr/bin/env python3
"""Validate generated VRP geometry/timings, implementation, and dual QSPI images."""
import argparse
import hashlib
import importlib.util
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'TEST/stress'))
from check_artifacts import check_mcs, sha


def generated(rate):
    out = ROOT / f'VIVADO/vrp_{rate}_build'
    params = json.loads((out / 'project/ddr3_pair.srcs/sources_1/ip/ddr3_mig/ddr3_mig.xci').read_text(), strict=False)['ip_inst']['parameters']
    c = {k: v[0]['value'] for k, v in params['component_parameters'].items()}
    m = {k: v[0]['value'] for k, v in params['model_parameters'].items()}
    period = 2500 if rate == 800 else 1250
    cl, cwl = (6, 5) if rate == 800 else (11, 8)
    expected_c = {'TimePeriod': period, 'InputClockPeriod': 4000, 'CasLatency': cl,
                  'CasWriteLatency': cwl, 'DataWidth': 16}
    for k, v in expected_c.items():
        assert int(c['C0.DDR3_' + k]) == v, (rate, k, c['C0.DDR3_' + k], v)
    assert c['C0.DDR3_isCustom'] == 'true'
    assert c['C0.DDR3_MemoryPart'] == f'VRP107_{rate}_DIE'
    assert c['C0.DDR3_MemoryVoltage'] == '1.5V'
    assert c['C0.DDR3_OnDieTermination'] == 'RZQ/6'
    assert c['C0.DDR3_OutputDriverImpedenceControl'] == 'RZQ/7'
    expected_m = {'MEM_SIZE': 1073741824, 'ROW_WIDTH': 16, 'COLUMN_WIDTH': 10,
                  'BANK_WIDTH': 3, 'DQ_WIDTH': 16, 'DQS_WIDTH': 2, 'DM_WIDTH': 2,
                  'RANK_WIDTH': 1, 'CS_WIDTH': 1, 'CKE_WIDTH': 1, 'ODT_WIDTH': 1,
                  'CK_WIDTH': 1, 'MEM_COMP_WIDTH': 8, 'MEM_DEVICE_WIDTH': 8,
                  'tCK': period, 'UI_CLOCK': rate * 125000}
    for k, v in expected_m.items():
        assert int(m['C0.DDR3_' + k]) == v, (rate, k, m['C0.DDR3_' + k], v)
    assert m['C0.DDR3_COMP_DENSITY'] == '4Gb'
    assert m['C0.DDR3_MEM_DENSITY'] == '4Gb'
    # These controller parameters are DDR clock cycles; confirm the final generated
    # wrapper too, since IP processing can impose minimum cycle counts after XCI.
    sv = (out / 'project/ddr3_pair.gen/sources_1/ip/ddr3_mig/rtl/ip_top/ddr3_mig_ddr3.sv').read_text()
    timing_ns = {'tFAW': 40, 'tRFC': 260, 'tRAS': 35, 'tRCD': 15,
                 'tRP': 15, 'tRRD': 10, 'tRTP': 10, 'tWR': 15, 'tWTR': 10}
    actual = {}
    for k, ns in timing_ns.items():
        n = int(re.search(r'parameter\s+(?:integer\s+)?' + k + r'\s*=\s*(\d+)', sv)[1])
        assert n == math.ceil(ns * 1000 / period), (rate, k, n, ns)
        actual[k] = {'ddr_cycles': n, 'ns': n * period / 1000}
    for k in ('tRRD', 'tRTP', 'tWTR'):
        assert actual[k]['ddr_cycles'] >= 4
    assert actual['tRAS']['ns'] + actual['tRP']['ns'] >= 48.75
    # Check the generated initialization words, rather than treating GUI strings
    # or unused zero-valued XCI model placeholders as the programmed latency.
    mr = {k: int(re.search(r'parameter\s+' + k + r"\s*=\s*13'b([01]+)", sv)[1], 2)
          for k in ('MR0', 'MR1', 'MR2')}
    cl_encoded = ((mr['MR0'] >> 4) & 7) + (12 if mr['MR0'] & 4 else 4)
    assert cl_encoded == cl and 5 + ((mr['MR2'] >> 3) & 7) == cwl
    wr = {0: 16, 1: 5, 2: 6, 3: 7, 4: 8, 5: 10, 6: 12, 7: 14}[(mr['MR0'] >> 9) & 7]
    assert wr * period >= 15000
    assert mr['MR0'] & 3 == 0  # Fixed BL8, sequential burst (A3 also zero).
    assert not mr['MR0'] & 8 and not mr['MR1'] & 1  # DLL enabled.
    rtt = ((mr['MR1'] >> 7) & 4) | ((mr['MR1'] >> 5) & 2) | ((mr['MR1'] >> 2) & 1)
    assert rtt == 3  # RZQ/6 nominal ODT, 40 ohms.
    drive = ((mr['MR1'] >> 4) & 2) | ((mr['MR1'] >> 1) & 1)
    assert drive == 0  # Generated initial MR1 selects 40 ohms despite GUI RZQ/7.
    assert int(m['C0.DDR3_tREFI']) * period == 7800000
    assert int(re.search(r'parameter\s+tZQCS\s*=\s*(\d+)', sv)[1]) == 64
    # Initialization delays in this generated core use fabric/UI cycles (4 CK).
    assert int(m['C0.DDR3_tXPR']) * 4 * period >= 270000
    assert int(m['C0.DDR3_tZQINIT']) * 4 >= 512
    return {'part': 'MT41K512M16VRP-107 IT:P', 'logical_profile': c['C0.DDR3_MemoryPart'],
            'model': '2 x 4Gb x8 die, one rank, x16 bus', 'capacity_bytes': 1073741824,
            'rate_mtps': rate, 'ddr_clock_mhz': rate / 2, 'ui_hz': rate * 125000,
            'cl': cl, 'cwl': cwl, 'timings': actual, 'tREFI_ns': 7800,
            'initial_mode_registers': {k: hex(v) for k, v in mr.items()},
            'initial_output_drive_ohms': 40, 'initial_nominal_odt_ohms': 40,
            'temperature_limit_c': 85, 'xci_sha256': sha(out / 'project/ddr3_pair.srcs/sources_1/ip/ddr3_mig/ddr3_mig.xci')}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--rate', type=int, choices=(800, 1600), default=800)
    p.add_argument('--parameters-only', action='store_true')
    a = p.parse_args()
    out = ROOT / f'VIVADO/vrp_{a.rate}_build'
    settings = generated(a.rate)
    (out / 'parameter_validation.json').write_text(json.dumps(settings, indent=2) + '\n')
    if a.parameters_only:
        print('VRP GENERATED PARAMETERS PASSED', a.rate)
        return
    assert 'BUILD PASSED: bitstream' in (out / 'build.log').read_text()
    assert 'All user specified timing constraints are met.' in (out / 'timing_summary.rpt').read_text()
    assert 'VIOLATED' not in (out / 'bus_skew.rpt').read_text()
    assert re.search(r'nets with routing errors\.+\s*: *0', (out / 'route_status.rpt').read_text())
    assert 'PAIRED FLASH GENERATION PASSED' in (out / 'flash_generation.log').read_text()
    spec = importlib.util.spec_from_file_location('paired_checks', ROOT / 'TEST/paired/check_artifacts.py')
    paired = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(paired)
    notes = paired.preserved()
    # Old runtime sources and already generated images must remain reproducible.
    for rate in (800, 1600):
        old = ROOT / f'VIVADO/paired_{rate}_build'
        manifest = json.loads((old / 'build_manifest.json').read_text())
        for n, info in manifest['files'].items():
            assert sha(old / n) == info['sha256'], ('old paired artifact changed', rate, n)
        for n, digest in manifest['sources'].items():
            assert sha(ROOT / n) == digest, ('old paired source changed', n)
    prefix = f'ddr3_vrp_pair_{a.rate}'
    files = {prefix + suffix: check_mcs(out / (prefix + suffix))
             for suffix in ('_primary.mcs', '_secondary.mcs')}
    assert len({info['data_bytes'] for info in files.values()}) == 1
    for n in (prefix + '.bit', 'parameter_validation.json', 'timing_summary.rpt', 'drc.rpt',
              'bus_skew.rpt', 'route_status.rpt', 'clocks.rpt', 'io.rpt', 'flash_settings.rpt',
              'reset_stage_0.rpt', 'reset_stage_1.rpt', 'reset_output.rpt'):
        files[n] = {'bytes': (out / n).stat().st_size, 'sha256': sha(out / n)}
    sim = ROOT / f'TEST/part_audit/engine_{a.rate * 125000}.log'
    assert 'PAIRED SIMULATION PASSED' in sim.read_text()
    uart = ROOT / f'TEST/part_audit/uart_{a.rate * 125000}.log'
    assert 'UART SERIALIZATION PASSED' in uart.read_text()
    decoder = ROOT / 'TEST/part_audit/decoder.log'
    assert 'PAIRED DECODER PASSED' in decoder.read_text()
    synth = (out / 'project/ddr3_pair.runs/synth_1/runme.log').read_text()
    sources = list((ROOT / 'VIVADO/vrp').glob('*')) + list((ROOT / 'VIVADO/paired/rtl').glob('*'))
    sources += [ROOT / ('VIVADO/scripts/' + n + ext)
                for n in ('build_vrp', 'generate_vrp_flash') for ext in ('.sh', '.tcl')]
    sources += [ROOT / n for n in ('TEST/part_audit/check_vrp.py', 'VIVADO/rtl/uart_tx.v',
                'VIVADO/probe/rtl/probe_uart.sv', 'VIVADO/constraints/vcu118.xdc',
                'VIVADO/stress/flash_config.xdc', 'VIVADO/diagnostic/reset_cdc.xdc')]
    manifest = {'created': datetime.now().astimezone().isoformat(), 'settings': settings,
                'files': files, 'sources': {str(s.relative_to(ROOT)): sha(s) for s in sorted(sources)},
                'simulation': {'engine': sha(sim), 'uart': sha(uart), 'decoder': sha(decoder),
                               'external_ddr_phy_model': False},
                'old_artifacts_preserved': True, 'legacy_notes': notes,
                'synthesis_warnings': [l for l in synth.splitlines() if 'WARNING:' in l],
                'hardware_test': 'not performed; files only requested'}
    (out / 'build_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('VRP ARTIFACTS PASSED', a.rate, 'MT/s; flash data bytes', sum(i.get('data_bytes', 0) for i in files.values()))


if __name__ == '__main__':
    main()
