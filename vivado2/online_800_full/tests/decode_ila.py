#!/usr/bin/env python3
import argparse,csv,json,re
from pathlib import Path

def decode(path):
    with Path(path).open() as f:
        table=list(csv.reader(f))
    header=table[0];rows=table[2:]
    def bus(row,stem,width):
        value=covered=0
        for i,name in enumerate(header):
            if stem not in name: continue
            m=re.search(r'\[(\d+)(?::(\d+))?\]$',name)
            hi=int(m[1]) if m else width-1
            lo=int(m[2] or m[1]) if m else 0
            mask=((1<<(hi-lo+1))-1)<<lo
            assert not covered&mask,('overlapping CSV fields',stem)
            value|=int(row[i],16)<<lo;covered|=mask
        assert covered==(1<<width)-1,('missing bus bits',stem,hex(covered))
        return value
    terminal=[r for r in rows if bus(r,'test_engine_done',1)==1]
    assert terminal,'no completed sample'
    row=terminal[-1];s=bus(row,'debug_summary',512)
    def field(lo,n):return (s>>lo)&((1<<n)-1)
    assert field(480,32)==0x41584944,'bad image signature'
    result=dict(state=field(448,32),leg=field(416,32),fatal=field(384,32),region_beats=field(352,32),legs=field(320,32),writes=field(256,64),reads=field(192,64),errors=field(128,64),read_index=field(96,32),write_index=field(64,32),sparse_gap=field(32,32),seed=f'{field(0,32):08x}',samples=len(rows))
    for stem,key in [('debug_legs','errors_per_leg'),('debug_dq','bit_flips_per_dq')]:
        v=bus(row,stem,512);result[key]=[(v>>(i*32))&0xffffffff for i in range(16)]
    v=bus(row,'debug_first',320)
    result['first_error']=None
    result['independent_requests']=bool((v>>297)&1)
    result['max_outstanding']=(v>>291)&63
    result['large_region']=bool((v>>298)&1)
    if (v>>290)&1:
        expected=(v>>128)&((1<<128)-1);actual=v&((1<<128)-1);delta=expected^actual
        result['first_error']=dict(byte_address=(v>>256)&((1<<30)-1),leg=(v>>286)&15,expected=f'{expected:032x}',actual=f'{actual:032x}',xor=f'{delta:032x}',dq=sorted({(i//64)*8+i%8 for i in range(128) if (delta>>i)&1}))
    if result['fatal']:raise ValueError(f"Protocol/calibration/timeout fault: {result}")
    assert result['state']==9 and result['legs']==16 and result['leg']==15,result
    assert result['region_beats'] in {65536,67108864} and result['writes']==result['region_beats'],result
    assert result['large_region']==(result['region_beats']==67108864),result
    assert result['reads']==result['region_beats']*result['legs'],result
    assert result['read_index']==result['write_index']==result['region_beats'],result
    assert result['sparse_gap']==100 and result['seed']=='137a5c29',result
    assert (result['first_error'] is not None)==(result['errors']!=0),result
    assert sum(result['errors_per_leg'])==result['errors'],result
    assert sum(result['bit_flips_per_dq'])>=result['errors'],result
    result['dense_errors']=sum(result['errors_per_leg'][::2]);result['sparse_errors']=sum(result['errors_per_leg'][1::2])
    assert result['independent_requests'] and 1<=result['max_outstanding']<=32,result
    result['passed']=result['errors']==0
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('csv');args=parser.parse_args()
    result=decode(args.csv)
    Path(args.csv).with_suffix('.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
