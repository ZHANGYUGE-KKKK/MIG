#!/usr/bin/env python3
"""Verify dual-QSPI Intel HEX, build reports and preserved baseline; write manifest."""
import hashlib
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'VIVADO/stress_build'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def check_mcs(path):
    base = 0
    end = 0
    count = 0
    eof = False
    with path.open() as f:
        for number, line in enumerate(f, 1):
            assert line.startswith(':') and not eof, (path, number, 'bad record/after EOF')
            record = bytes.fromhex(line[1:])
            assert len(record) == record[0] + 5 and sum(record) % 256 == 0, (path, number, 'length/checksum')
            n, addr, kind = record[0], int.from_bytes(record[1:3], 'big'), record[3]
            data = record[4:-1]
            if kind == 0:
                absolute = base + addr
                assert absolute == end and absolute + n <= 128 * 1024 * 1024, (path, number, 'gap/overlap/capacity')
                end = absolute + n
                count += n
            elif kind == 4:
                assert n == 2 and addr == 0
                base = int.from_bytes(data, 'big') << 16
            elif kind == 1:
                assert n == 0 and addr == 0
                eof = True
            else:
                raise AssertionError((path, number, 'unexpected record type', kind))
    assert eof and count > 0
    return {'file_bytes': path.stat().st_size, 'data_bytes': count,
            'end_address_inclusive': hex(end - 1), 'sha256': sha(path)}


def main():
    timing = (OUT / 'timing_summary.rpt').read_text()
    assert 'All user specified timing constraints are met.' in timing
    assert 'VIOLATED' not in (OUT / 'bus_skew.rpt').read_text()
    assert 'BUILD PASSED: bitstream' in (OUT / 'build.log').read_text()
    # Verify baseline files against the manifests created before stress work.
    old = ROOT / 'VIVADO/build'
    baseline = json.loads((old / 'build_manifest.json').read_text())
    assert sha(old / 'ddr3_loopback.bit') == baseline['bitstream_sha256']
    for name, digest in baseline['sources'].items():
        assert sha(ROOT / name) == digest, ('baseline source changed', name)
    for manifest_name in ['compressed_flash_manifest.json', 'flash_manifest.json']:
        for name, info in json.loads((old / manifest_name).read_text()).items():
            assert sha(old / name) == info['sha256'], ('baseline flash artifact changed', name)
    manifest = {'created': datetime.now().astimezone().isoformat(), 'vivado': '2022.2',
                'part': 'xcvu9p-flga2104-2L-e', 'capacity_bytes_per_flash': 128 * 1024 * 1024,
                'hardware_stress_test': 'not performed', 'baseline_preserved': True, 'files': {}, 'sources': {}, 'simulation': {}}
    for name in ['ddr3_stress_primary.mcs', 'ddr3_stress_secondary.mcs']:
        manifest['files'][name] = check_mcs(OUT / name)
    entries = list(manifest['files'].values())
    assert entries[0]['data_bytes'] == entries[1]['data_bytes']
    for name in ['ddr3_stress.bit', 'timing_summary.rpt', 'drc.rpt', 'bus_skew.rpt', 'route_status.rpt', 'flash_settings.rpt']:
        path = OUT / name
        manifest['files'][name] = {'file_bytes': path.stat().st_size, 'sha256': sha(path)}
    for tb, marker in [('engine_tb', 'ALL ENGINE TESTS PASSED'),
                       ('telemetry_tb', 'ALL TELEMETRY TESTS PASSED'),
                       ('address_tb', 'ALL PRODUCTION ADDRESS BOUNDARY TESTS PASSED')]:
        path = ROOT / 'TEST/stress/build' / (tb + '.log')
        assert marker in path.read_text(), ('missing simulation pass', tb)
        manifest['simulation'][tb] = {'log': str(path.relative_to(ROOT)), 'sha256': sha(path)}
    sources = list((ROOT / 'VIVADO/stress').rglob('*.sv')) + list((ROOT / 'VIVADO/stress').rglob('*.v'))
    sources += [ROOT / p for p in ['VIVADO/rtl/uart_tx.v', 'VIVADO/ip/ddr3_config.tcl',
                                   'VIVADO/constraints/vcu118.xdc', 'VIVADO/stress/flash_config.xdc',
                                   'VIVADO/scripts/build_stress.tcl', 'VIVADO/scripts/generate_stress_flash.tcl']]
    sources += list((ROOT / 'TEST/stress').glob('*.sv'))
    sources += list((ROOT / 'TEST/stress').glob('*.py')) + [ROOT / 'TEST/stress/run_sim.sh']
    manifest['sources'] = {str(p.relative_to(ROOT)): sha(p) for p in sorted(sources)}
    output = OUT / 'build_manifest.json'
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: v for k, v in manifest.items() if k != 'sources'}, indent=2))
    print(f'ARTIFACT CHECK PASSED: {output}')


if __name__ == '__main__':
    main()
