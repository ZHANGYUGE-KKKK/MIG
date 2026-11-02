#!/usr/bin/env python3
"""Archive checks for the implemented full-capacity 800 MT/s burst image."""
import hashlib,json,re
from pathlib import Path
base=Path(__file__).resolve().parents[1]
root=base.parents[1]
def ports(path):
    result={}
    for line in path.read_text().splitlines():
        c=[x.strip() for x in line.split('|')]
        if len(c)>8 and re.fullmatch(r'[A-Z]+\d+',c[1]) and c[2]:
            result[c[2]]=(c[1],c[7])
    return result
p=ports(base/'build/io.rpt');ref=ports(root/'vivado2/online_1600/build/io.rpt')
assert len(p)==55 and p==ref,('IO mismatch',p,ref)
s=(base/'build/timing_summary.rpt').read_text()
assert 'All user specified timing constraints are met.' in s and 'VIOLATED' not in s
assert 'VIOLATED' not in (base/'build/bus_skew.rpt').read_text()
files=[base/'build/wiring_online_axi.bit',base/'build/wiring_online_axi.ltx',base/'build/generated_parameters.json']
files+=list((base/'rtl').glob('*'))+list((base/'config').glob('*'))+list((base/'scripts').glob('*'))
manifest=dict(rate_mt_s=800,ui_mhz=100,unique_capacity_bytes=1<<30,pins_checked=len(p),rtl_simulations=7,decoder_tests=5,sha256={str(x.relative_to(root)):hashlib.sha256(x.read_bytes()).hexdigest() for x in files if x.is_file()})
(base/'build/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k!='sha256'}))
