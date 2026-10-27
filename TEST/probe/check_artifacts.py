#!/usr/bin/env python3
"""Validate reports and both SPIx8 halves; preserve earlier source/artifact checksums."""
import sys,json
from pathlib import Path
from datetime import datetime
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'TEST/stress'))
from check_artifacts import sha,check_mcs
OUT=ROOT/'VIVADO/probe_build'
assert 'All user specified timing constraints are met.' in (OUT/'timing_summary.rpt').read_text()
assert 'VIOLATED' not in (OUT/'bus_skew.rpt').read_text()
assert 'BUILD PASSED: bitstream' in (OUT/'build.log').read_text()
assert 'PROBE SIMULATION PASSED' in (ROOT/'TEST/probe/build/engine.log').read_text()
assert 'UART SERIALIZATION PASSED' in (ROOT/'TEST/probe/build/uart.log').read_text()
assert not (ROOT/'TEST/probe/build/lint.log').read_text().strip()
for earlier in ('stress_build','diagnostic_build'):
    old=ROOT/'VIVADO'/earlier;manifest=json.loads((old/'build_manifest.json').read_text())
    for name,info in manifest['files'].items():
        assert sha(old/name)==info['sha256'],f'earlier artifact changed {earlier}/{name}'
    for name,info in manifest.get('sources',{}).items():
        assert sha(ROOT/name)==info,f'earlier source changed {name}'
files={}
for name in ('ddr3_probe_primary.mcs','ddr3_probe_secondary.mcs'):
    files[name]=check_mcs(OUT/name)
assert files['ddr3_probe_primary.mcs']['data_bytes']==files['ddr3_probe_secondary.mcs']['data_bytes']
for name in ('ddr3_probe.bit','timing_summary.rpt','drc.rpt','bus_skew.rpt','route_status.rpt',
             'flash_settings.rpt','reset_stage_0.rpt','reset_stage_1.rpt','reset_output.rpt'):
    p=OUT/name;files[name]={'file_bytes':p.stat().st_size,'sha256':sha(p)}
sources=list((ROOT/'VIVADO/probe/rtl').glob('*'))
sources += [ROOT/p for p in ('VIVADO/rtl/uart_tx.v','VIVADO/constraints/vcu118.xdc',
            'VIVADO/ip/ddr3_config.tcl','VIVADO/diagnostic/reset_cdc.xdc','VIVADO/stress/flash_config.xdc',
            'VIVADO/scripts/build_probe.tcl','VIVADO/scripts/build_probe.sh','VIVADO/scripts/generate_probe_flash.tcl','VIVADO/scripts/generate_probe_flash.sh',
            'VIVADO/scripts/download_probe.tcl','VIVADO/scripts/program_probe_flash.tcl','VIVADO/scripts/boot_probe.tcl','VIVADO/scripts/read_probe_margins.tcl')]
sources+=list((ROOT/'TEST/probe').glob('*.sv'))+list((ROOT/'TEST/probe').glob('*.py'))+[ROOT/'TEST/probe/run_sim.sh']
manifest={'created':datetime.now().astimezone().isoformat(),'ddr_mtps':1600,'ui_hz':200000000,
          'expected_fifo_depth':32,'jobs':372,'earlier_artifacts_preserved':True,'files':files,
          'sources':{str(p.relative_to(ROOT)):sha(p) for p in sorted(sources)},
          'simulation':{str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'TEST/probe/build'/n for n in ('engine.log','uart.log','lint.log','compile.log','uart_compile.log')]}}
(OUT/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PROBE ARTIFACTS PASSED; total flash bytes',sum(files[n]['data_bytes'] for n in files if n.endswith('.mcs')))
