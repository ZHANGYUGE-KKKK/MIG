#!/usr/bin/env python3
"""Validate single-read diagnostic artifacts and preserve original stress version."""
import json
import sys
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
from check_artifacts import check_mcs, sha

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'VIVADO/diagnostic_build'


def main():
    assert 'BUILD PASSED: bitstream' in (OUT / 'build.log').read_text()
    assert 'DIAGNOSTIC FLASH GENERATION PASSED' in (OUT / 'flash_generation.log').read_text()
    assert 'All user specified timing constraints are met.' in (OUT / 'timing_summary.rpt').read_text()
    assert 'VIOLATED' not in (OUT / 'bus_skew.rpt').read_text()
    log = ROOT / 'TEST/stress/build/single_read_tb.log'
    assert 'ALL SINGLE-READ DIAGNOSTIC TESTS PASSED' in log.read_text()
    assert not (ROOT / 'TEST/stress/build/single_read_lint.log').read_text().strip()

    # This is the original stress manifest, not regenerated with diagnostic sources.
    stress = ROOT / 'VIVADO/stress_build'
    baseline = json.loads((stress / 'build_manifest.json').read_text())
    for name, info in baseline['files'].items():
        assert sha(stress / name) == info['sha256'], ('stress artifact changed', name)
    for name, digest in baseline['sources'].items():
        assert sha(ROOT / name) == digest, ('stress source changed', name)

    expected_top = (ROOT / 'VIVADO/stress/rtl/ddr3_stress_top.v').read_text()
    expected_top = expected_top.replace('module ddr3_stress_top (', 'module ddr3_diag_top (')
    expected_top = expected_top.replace('    ddr_stress_system stress (',
        '    // Diagnostic changes only read concurrency; write path and DDR rate are unchanged.\n'
        '    ddr_stress_system #(.MAX_READS(1)) stress (')
    assert (ROOT / 'VIVADO/diagnostic/rtl/ddr3_diag_top.v').read_text() == expected_top

    result = {'created': datetime.now().astimezone().isoformat(), 'vivado': '2022.2',
              'part': 'xcvu9p-flga2104-2L-e', 'max_reads': 1, 'ddr_rate_mtps': 1600,
              'ui_clock_hz': 200000000, 'uart_baud': 115200,
              'write_path': 'unchanged from stress version',
              'stress_sources_and_artifacts_preserved': True,
              'diagnostic_hardware_test': 'not performed', 'files': {}, 'sources': {},
              'simulation': {'log': str(log.relative_to(ROOT)), 'sha256': sha(log)}}
    for name in ['ddr3_diag_primary.mcs', 'ddr3_diag_secondary.mcs']:
        result['files'][name] = check_mcs(OUT / name)
    assert result['files']['ddr3_diag_primary.mcs']['data_bytes'] == result['files']['ddr3_diag_secondary.mcs']['data_bytes']
    for name in ['ddr3_diag.bit', 'timing_summary.rpt', 'drc.rpt', 'bus_skew.rpt', 'route_status.rpt', 'flash_settings.rpt', 'reset_stage_0.rpt', 'reset_stage_1.rpt', 'reset_output.rpt', 'exceptions.rpt']:
        path = OUT / name
        result['files'][name] = {'file_bytes': path.stat().st_size, 'sha256': sha(path)}
    sources = list((ROOT / 'VIVADO/stress/rtl').glob('*.sv'))
    sources += [ROOT / p for p in ['VIVADO/diagnostic/rtl/ddr3_diag_top.v', 'VIVADO/diagnostic/reset_cdc.xdc',
        'VIVADO/rtl/uart_tx.v', 'VIVADO/ip/ddr3_config.tcl', 'VIVADO/constraints/vcu118.xdc',
        'VIVADO/stress/flash_config.xdc', 'VIVADO/scripts/build_diagnostic.sh',
        'VIVADO/scripts/build_diagnostic.tcl', 'VIVADO/scripts/generate_diagnostic_flash.sh',
        'VIVADO/scripts/generate_diagnostic_flash.tcl', 'TEST/stress/single_read_tb.sv',
        'TEST/stress/check_diagnostic_artifacts.py', 'TEST/stress/run_diagnostic_sim.sh']]
    result['sources'] = {str(p.relative_to(ROOT)): sha(p) for p in sorted(sources)}
    path = OUT / 'build_manifest.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'sources'}, indent=2))
    print(f'DIAGNOSTIC ARTIFACT CHECK PASSED: {path}')


if __name__ == '__main__':
    main()
