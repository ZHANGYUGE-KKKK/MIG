#!/usr/bin/env python3
"""Self-contained BD/clock/IO/test and dual-QSPI artifact verification."""
import hashlib,json,re
from datetime import datetime
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
OUT=BASE/'build'
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()
def mcs(path):
    base=end=count=0;eof=False
    for number,line in enumerate(path.read_text().splitlines(),1):
        assert line.startswith(':') and not eof,(path,number)
        r=bytes.fromhex(line[1:]);assert len(r)==r[0]+5 and sum(r)%256==0,(path,number,'checksum')
        n,addr,kind=r[0],int.from_bytes(r[1:3],'big'),r[3]
        if kind==0:
            absolute=base+addr;assert absolute==end and absolute+n<=128*1024*1024
            end=absolute+n;count+=n
        elif kind==4:
            assert n==2 and addr==0;base=int.from_bytes(r[4:-1],'big')<<16
        elif kind==1:assert n==0 and addr==0;eof=True
        else:raise AssertionError(('unknown record',kind))
    assert eof and count>0
    return dict(file_bytes=path.stat().st_size,data_bytes=count,end_address_inclusive=hex(end-1),sha256=sha(path))
def ip_params(path):
    data=json.loads(path.read_text(),strict=False)['ip_inst']['parameters']['component_parameters']
    return {k:v[0]['value'] for k,v in data.items()}
def io_pins(path):
    d={}
    for line in path.read_text().splitlines():
        if not line.startswith('|'):continue
        c=[x.strip() for x in line.split('|')]
        if len(c)>8 and (c[2].startswith('C0_DDR3_0_') or c[2] in ('GPIO_LED7','tx','sys_rst','BADJ_CLK_clk_p','BADJ_CLK_clk_n')):d[c[2]]=[c[1],c[7]]
    return d

def main():
    assert 'BD BUILD PASSED' in (OUT/'build.log').read_text()
    assert 'BD FLASH GENERATION PASSED (FILES ONLY)' in (OUT/'flash_generation.log').read_text()
    assert 'All user specified timing constraints are met.' in (OUT/'timing_summary.rpt').read_text()
    assert 'VIOLATED' not in (OUT/'bus_skew.rpt').read_text()
    assert re.search(r'nets with routing errors\.+\s*: *0',(OUT/'route_status.rpt').read_text())
    assert 'Command \'if\' is not supported' not in (OUT/'build.log').read_text()
    reference=json.loads((BASE/'config/reference_vrp800.json').read_text())
    ip_path=OUT/'project/wiring_bd.srcs/sources_1/bd/wiring/ip/wiring_mig_0/wiring_mig_0.xci'
    actual=ip_params(ip_path)
    allowed={'C0.DDR3_AxiSelection','C0.DDR3_AxiDataWidth','C0.DDR3_AxiAddressWidth','C0.DDR3_AxiIDWidth','C0.DDR3_CustomParts'}
    diffs={}
    for key,value in reference.items():
        if key.startswith('C0.') or key in ('System_Clock','Debug_Signal'):
            if actual.get(key)!=value:
                assert key in allowed,('Unexpected DDR parameter change',key,value,actual.get(key))
                diffs[key]=dict(reference=value,current=actual.get(key))
    for key,value in {'C0.DDR3_AxiSelection':'true','C0.DDR3_AxiDataWidth':'128','C0.DDR3_AxiAddressWidth':'30','C0.DDR3_AxiIDWidth':'1','C0.DDR3_TimePeriod':'2500','C0.DDR3_DataWidth':'16','C0.DDR3_MemoryPart':'VRP107_800_DIE'}.items():assert actual[key]==value,(key,actual[key])
    assert actual['C0.DDR3_AxiNarrowBurst']=='false'
    pins=io_pins(OUT/'io.rpt');assert len(pins)==55 and pins==json.loads((BASE/'config/reference_io.json').read_text()),'Pin map/IO standard changed'
    assert pins['GPIO_LED7']==['BA37','LVCMOS12']
    for local,info in json.loads((BASE/'config/provenance.json').read_text()).items():assert sha(BASE/local)==info['sha256'],('Copied reference changed',local)
    bd_path=OUT/'project/wiring_bd.srcs/sources_1/bd/wiring/wiring.bd'
    bd=json.loads(bd_path.read_text())['design']
    assert set(bd['components'])=={'mig','clocks_resets','test_engine','uart','native_axi'},'Unexpected BD blocks'
    assert bd['components']['mig']['vlnv']=='xilinx.com:ip:ddr3:1.4'
    # Check actual saved connectivity, including the direct AXI bus and calibrate LED.
    nets=bd['nets'];all_pin_sets=[set(n.get('pins',[]))|set(n.get('ports',[])) for n in nets.values()]
    def linked(*pins):assert any(set(pins)<=n for n in all_pin_sets),('BD net missing',pins)
    linked('mig/c0_init_calib_complete','test_engine/calib_complete','GPIO_LED7')
    linked('mig/c0_ddr3_ui_clk','test_engine/clk','uart/clk','native_axi/clk','clocks_resets/ui_clk')
    linked('clocks_resets/ref_clk','mig/c0_sys_clk_i')
    linked('clocks_resets/app_reset','test_engine/rst','uart/rst','native_axi/rst')
    linked('native_axi/axi_aresetn','mig/c0_ddr3_aresetn')
    for name in ('addr','cmd','en','rdy','wdf_data','wdf_mask','wdf_wren','wdf_end','wdf_rdy','rd_data','rd_data_valid','rd_data_end'):linked('test_engine/app_'+name,'native_axi/app_'+name)
    for name in ('record_data','record_valid','record_ready'):linked('test_engine/'+name,'uart/'+name)
    seg=bd['addressing']['/native_axi']['address_spaces']['M_AXI']['segments']['SEG_mig_C0_DDR3_ADDRESS_BLOCK']
    assert seg['offset']=='0x00000000' and seg['range']=='1G'
    intf_sets=[set(n.get('interface_ports',[])) for n in bd['interface_nets'].values()]
    assert any({'native_axi/M_AXI','mig/C0_DDR3_S_AXI'}<=n for n in intf_sets)
    simulations={}
    for stem,marker in [('mode_','DATABIT SIM PASSED'),('axi_','AXI BRIDGE PASSED')]:
        for mode in range(10):
            path=BASE/f'tests/build/{stem}{mode}.log';assert marker in path.read_text(),path
            if stem=='axi_' and mode in (0,8,9):assert 'AW=8320 W=8320 B=8320 AR=8320 R=8320' in path.read_text()
            simulations[path.name]=sha(path)
    for name,marker in (('board.log','BOARD CONTROL PASSED'),('uart.log','UART SERIALIZATION PASSED'),('decoder.log','DATABIT DECODER PASSED')):
        path=BASE/'tests/build'/name;assert marker in path.read_text();simulations[name]=sha(path)
    for name in ('lint.log','axi_lint.log','block_lint.log'):assert not (BASE/'tests/build'/name).read_text().strip()
    files={f'wiring_bd_800{suffix}':mcs(OUT/f'wiring_bd_800{suffix}') for suffix in ('_primary.mcs','_secondary.mcs')}
    assert files['wiring_bd_800_primary.mcs']['data_bytes']==files['wiring_bd_800_secondary.mcs']['data_bytes']
    for name in ('wiring_bd_800.bit','timing_summary.rpt','drc.rpt','bus_skew.rpt','route_status.rpt','io.rpt','clocks.rpt','flash_settings.rpt','reset_stage_0.rpt','reset_stage_1.rpt','reset_output.rpt','wiring_export.tcl','wiring.svg','wiring.png'):
        p=OUT/name
        if name in ('wiring.svg','wiring.png') and not p.exists():continue
        files[name]=dict(file_bytes=p.stat().st_size,sha256=sha(p))
    sources=[]
    for directory in ('rtl','constraints','config','scripts','tests'):
        sources += [p for p in (BASE/directory).iterdir() if p.is_file()]
    sources+=[BASE/'README.md']
    data=dict(created=datetime.now().astimezone().isoformat(),project='wiring_bd',top='wiring_wrapper',design='Block Design / IP Integrator',part='xcvu9p-flga2104-2L-e',rate_mtps=800,ui_hz=100000000,read_outstanding=1,extra_gap_ns=1000,patterns=260,addresses=32,writes=8320,reads=8320,
              differences_from_native_reference=diffs,capacity_bytes_per_flash=128*1024*1024,files=files,sources={str(p.relative_to(BASE)):sha(p) for p in sorted(sources)},bd_sha256=sha(bd_path),simulation=simulations,external_ddr_phy_simulation=False,
              full_capacity_test=False,dm_test=False,hardware_action='none; user requested Flash files only',hardware_ddr_test='not performed',limits='Data-bit roundtrip only; no DM/full-capacity verification and no exclusion of reversible pin permutations')
    (OUT/'build_manifest.json').write_text(json.dumps(data,indent=2)+'\n')
    print('VIVADO2 ARTIFACTS PASSED; dual Flash data bytes',sum(v.get('data_bytes',0) for v in files.values()))
if __name__=='__main__':main()
