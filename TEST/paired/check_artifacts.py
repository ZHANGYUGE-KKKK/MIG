#!/usr/bin/env python3
"""Verify both rate-specific builds, source identity, timing, MCS integrity and preserved images."""
import sys,json,re,hashlib,argparse
from pathlib import Path
from datetime import datetime
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'TEST/stress'))
from check_artifacts import sha,check_mcs

def preserved():
    notes=[]
    for directory in ('stress_build','diagnostic_build','probe_build'):
        out=ROOT/'VIVADO'/directory;old=json.loads((out/'build_manifest.json').read_text())
        for name,info in old['files'].items():assert sha(out/name)==info['sha256'],('old artifact changed',directory,name)
        for name,digest in old.get('sources',{}).items():
            actual=sha(ROOT/name)
            if actual==digest:continue
            # The previous task added two shell-wrapper names after its last manifest.
            # Verify that this exact source-list-only edit explains the entire difference.
            assert directory=='probe_build' and name=='TEST/probe/check_artifacts.py',('old source changed',name)
            before=(ROOT/name).read_text().replace("'VIVADO/scripts/build_probe.tcl','VIVADO/scripts/build_probe.sh','VIVADO/scripts/generate_probe_flash.tcl','VIVADO/scripts/generate_probe_flash.sh',", "'VIVADO/scripts/build_probe.tcl','VIVADO/scripts/generate_probe_flash.tcl',")
            assert hashlib.sha256(before.encode()).hexdigest()==digest,('unexpected legacy checker change',name)
            notes.append(dict(path=name,old_manifest_sha256=digest,current_sha256=actual,reason='Previous task added wrapper scripts to source list; paired task does not edit this file'))
    return notes

def main(rates=(1600,800)):
    prior_notes=preserved();sources=list((ROOT/'VIVADO/paired/rtl').glob('*'))
    sources += [ROOT/n for n in ('VIVADO/paired/ddr3_config.tcl','VIVADO/scripts/build_paired.tcl','VIVADO/scripts/build_paired.sh','VIVADO/scripts/generate_paired_flash.tcl','VIVADO/scripts/generate_paired_flash.sh','VIVADO/rtl/uart_tx.v','VIVADO/probe/rtl/probe_uart.sv','VIVADO/constraints/vcu118.xdc','VIVADO/stress/flash_config.xdc','VIVADO/diagnostic/reset_cdc.xdc')]
    sources += list((ROOT/'TEST/paired').glob('*.sv'))+list((ROOT/'TEST/paired').glob('*.py'))+[ROOT/'TEST/paired/run_sim.sh']
    source_hashes={str(p.relative_to(ROOT)):sha(p) for p in sorted(sources)}
    for rate in rates:
        out=ROOT/'VIVADO'/f'paired_{rate}_build';prefix=f'ddr3_pair_{rate}';hz=200000000 if rate==1600 else 100000000
        assert 'BUILD PASSED: bitstream' in (out/'build.log').read_text()
        assert 'All user specified timing constraints are met.' in (out/'timing_summary.rpt').read_text()
        assert 'VIOLATED' not in (out/'bus_skew.rpt').read_text()
        assert re.search(r'nets with routing errors\.+\s*: *0', (out/'route_status.rpt').read_text())
        assert 'PAIRED FLASH GENERATION PASSED' in (out/'flash_generation.log').read_text()
        synth=(out/'project/ddr3_pair.runs/synth_1/runme.log').read_text()
        assert 'Infeasible attribute' not in synth and 'is under-pipelined' not in synth
        assert '32' in synth and 'previous_values_reg' in synth
        data=json.loads((out/'project/ddr3_pair.srcs/sources_1/ip/ddr3_mig/ddr3_mig.xci').read_text())
        params=data['ip_inst']['parameters']['component_parameters']
        settings={k:v[0]['value'] for k,v in params.items()}
        for key,value in {'C0.DDR3_TimePeriod':1250 if rate==1600 else 2500,'C0.DDR3_CasLatency':11 if rate==1600 else 6,'C0.DDR3_CasWriteLatency':8 if rate==1600 else 5,'C0.DDR3_InputClockPeriod':4000,'C0.DDR3_DataWidth':16}.items():
            assert int(settings[key])==value,(rate,key,settings[key])
        files={}
        for tail in ('_primary.mcs','_secondary.mcs'):files[prefix+tail]=check_mcs(out/(prefix+tail))
        assert files[prefix+'_primary.mcs']['data_bytes']==files[prefix+'_secondary.mcs']['data_bytes']
        for name in (prefix+'.bit','timing_summary.rpt','drc.rpt','route_status.rpt','bus_skew.rpt','clocks.rpt','flash_settings.rpt','reset_stage_0.rpt','reset_stage_1.rpt','reset_output.rpt'):
            p=out/name;files[name]=dict(bytes=p.stat().st_size,sha256=sha(p))
        simulation={}
        for name,marker in ((f'engine_{hz}.log','PAIRED SIMULATION PASSED'),(f'uart_{hz}.log','UART SERIALIZATION PASSED')):
            p=ROOT/'TEST/paired/build'/name;assert marker in p.read_text();simulation[name]=sha(p)
        assert not (ROOT/f'TEST/paired/build/lint_{hz}.log').read_text().strip()
        assert 'PAIRED DECODER PASSED' in (ROOT/'TEST/paired/build/decoder.log').read_text()
        warnings=[line for line in synth.splitlines() if 'WARNING:' in line]
        manifest=dict(created=datetime.now().astimezone().isoformat(),rate_mtps=rate,ui_hz=hz,uart_baud=115200,sparse_extra_ns=320,write_groups=18,read_legs=198,region_bytes=1048576,hardware_test='not performed; files only requested',previous_artifacts_preserved=True,prior_manifest_notes=prior_notes,files=files,sources=source_hashes,simulation=simulation,synthesis_warnings=warnings)
        (out/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        print('PAIRED ARTIFACT PASSED',rate,'MT/s; flash bytes',sum(v.get('data_bytes',0) for v in files.values()))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--rate',type=int,choices=(800,1600));args=parser.parse_args()
    main((args.rate,) if args.rate else (1600,800))
