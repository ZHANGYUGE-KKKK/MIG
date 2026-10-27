#!/usr/bin/env python3
"""Validate the first low-load data-bit test and preserve prior experiment evidence."""
import hashlib,importlib.util,json,re,sys
from pathlib import Path
from datetime import datetime
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'VIVADO/databit_800_build'
PREFIX='ddr3_databit_800'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
legacy=module('databit_legacy',ROOT/'TEST/paired/check_artifacts.py')
sha=legacy.sha

def params(path):
    d=json.loads(path.read_text(),strict=False)['ip_inst']['parameters']['component_parameters']
    return {k:v[0]['value'] for k,v in d.items()}

def main():
    notes=legacy.preserved()
    for rate in (800,1600):
        old=ROOT/f'VIVADO/vrp_{rate}_build';m=json.loads((old/'build_manifest.json').read_text())
        for name,info in m['files'].items():assert sha(old/name)==info['sha256'],('prior artifact changed',rate,name)
        for name,digest in m['sources'].items():assert sha(ROOT/name)==digest,('prior source changed',rate,name)
    settings=params(OUT/'project/ddr3_databit.srcs/sources_1/ip/ddr3_mig/ddr3_mig.xci')
    prior=params(ROOT/'VIVADO/vrp_800_build/project/ddr3_pair.srcs/sources_1/ip/ddr3_mig/ddr3_mig.xci')
    for key,value in prior.items():
        if key.startswith('C0.') or key in ('System_Clock','Debug_Signal'):
            assert settings[key]==value,('MIG profile differs from validated VRP800',key,value,settings[key])
    assert settings['C0.DDR3_MemoryPart']=='VRP107_800_DIE'
    assert settings['C0.DDR3_Mem_Add_Map']=='ROW_COLUMN_BANK'
    def io_pins(path):
        result={}
        for line in path.read_text().splitlines():
            if not line.startswith('|'):continue
            columns=[x.strip() for x in line.split('|')]
            if len(columns)>8 and (columns[2].startswith('C0_DDR3_0_') or columns[2] in ('GPIO_LED7','tx','sys_rst','BADJ_CLK_clk_p','BADJ_CLK_clk_n')):
                result[columns[2]]=(columns[1],columns[7])
        return result
    actual_io=io_pins(OUT/'io.rpt');prior_io=io_pins(ROOT/'VIVADO/vrp_800_build/io.rpt')
    assert len(actual_io)==55 and actual_io==prior_io,'Board-level pin/IO standard differs'
    assert 'PASS: all 50 DDR3 signal pins' in (ROOT/'TEST/databit/build/pinmap.log').read_text()
    assert 'BUILD PASSED: bitstream' in (OUT/'build.log').read_text()
    assert 'All user specified timing constraints are met.' in (OUT/'timing_summary.rpt').read_text()
    assert 'VIOLATED' not in (OUT/'bus_skew.rpt').read_text()
    assert re.search(r'nets with routing errors\.+\s*: *0',(OUT/'route_status.rpt').read_text())
    assert 'DATABIT FLASH GENERATION PASSED' in (OUT/'flash_generation.log').read_text()
    for name in ('lint.log','system_lint.log'):assert not (ROOT/'TEST/databit/build'/name).read_text().strip()
    logs={}
    for mode in range(10):
        p=ROOT/f'TEST/databit/build/mode_{mode}.log';assert 'DATABIT SIM PASSED' in p.read_text();logs[p.name]=sha(p)
    for name,marker in (('uart.log','UART SERIALIZATION PASSED'),('decoder.log','DATABIT DECODER PASSED')):
        p=ROOT/'TEST/databit/build'/name;assert marker in p.read_text();logs[name]=sha(p)
    files={PREFIX+suffix:legacy.check_mcs(OUT/(PREFIX+suffix)) for suffix in ('_primary.mcs','_secondary.mcs')}
    assert files[PREFIX+'_primary.mcs']['data_bytes']==files[PREFIX+'_secondary.mcs']['data_bytes']
    for name in (PREFIX+'.bit','timing_summary.rpt','drc.rpt','route_status.rpt','bus_skew.rpt','clocks.rpt','io.rpt','flash_settings.rpt','reset_stage_0.rpt','reset_stage_1.rpt','reset_output.rpt'):
        p=OUT/name;files[name]=dict(bytes=p.stat().st_size,sha256=sha(p))
    sources=list((ROOT/'VIVADO/databit/rtl').glob('*'))+list((ROOT/'TEST/databit').glob('*.py'))+list((ROOT/'TEST/databit').glob('*.sv'))
    sources+=[ROOT/n for n in ('TEST/databit/run_sim.sh','TEST/check_pinmap.py','EDA/pinmap.json','VIVADO/databit/README.md','VIVADO/scripts/build_databit.tcl','VIVADO/scripts/build_databit.sh','VIVADO/scripts/generate_databit_flash.tcl','VIVADO/scripts/generate_databit_flash.sh','VIVADO/scripts/program_databit_800_flash.tcl','VIVADO/vrp/ddr3_config.tcl','VIVADO/vrp/vrp107_800.csv','VIVADO/rtl/uart_tx.v','VIVADO/probe/rtl/probe_uart.sv','VIVADO/constraints/vcu118.xdc','VIVADO/stress/flash_config.xdc','VIVADO/diagnostic/reset_cdc.xdc')]
    m=dict(created=datetime.now().astimezone().isoformat(),experiment='DPIN v1: data-bit test only',rate_mtps=800,ui_hz=100000000,extra_gap_cycles=100,extra_gap_ns=1000,
           patterns=260,addresses=32,writes=8320,reads=8320,full_capacity_test=False,dm_test=False,external_ddr_phy_simulation=False,
           hardware_test='not performed',files=files,sources={str(p.relative_to(ROOT)):sha(p) for p in sorted(sources)},simulation=logs,previous_artifacts_preserved=True,legacy_notes=notes,
           conclusion_limit='Functional roundtrip cannot exclude reversible DQ/address permutation; physical pin identity requires netlist/continuity checks')
    (OUT/'build_manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    print('DATABIT ARTIFACT PASSED; flash data bytes',sum(v.get('data_bytes',0) for v in files.values()))
if __name__=='__main__':main()
