#!/usr/bin/env python3
import tempfile
from pathlib import Path
from monitor import decode,expected_config

def record(kind,j,*fields):
    words=[(kind<<32)|j,*fields]
    words+= [0]*(8-len(words))
    return 'D '+' '.join(f'{n:016X}' for n in words)+'\r\n'

def fixture(inject):
    text=''
    for j in range(372):
        stage,pat,w,r,rl,wl,turn,gap,rot,rev,target=expected_config(j)
        packed=(turn<<56)|(gap<<48)|(rot<<40)|(rev<<32)|target
        text+=record(1,j,stage,pat,w,r,rl,wl,packed)
        errors=1 if inject and j==0 else 0
        text+=record(2,j,w,w,r,r,errors,errors)
        if errors:
            text+=record(3,j,0,0xffffffffffffffff,0xffffffffffffffff,0xfffffffffffffffd,0xffffffffffffffff,1)
            text+=record(4,j,65,1)
    return text+record(5,371,int(inject))
# Each failure-relevant pattern must cover the full runtime cross product.
for pat in (0,4,5):
    configs=[expected_config(j) for j in range(48,372) if expected_config(j)[1]==pat]
    assert len(configs)==108
    assert set((d[4],d[5],d[6],d[7]) for d in configs)==set(
        (r,w,t,g) for r in (1,2,4,8,16,32) for w in (1,32) for t in (0,16,64) for g in (0,16,64))
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'uart.log'
    path.write_text(fixture(False));r=decode(path);assert r['complete'] and r['data_pass']
    path.write_text(fixture(True));r=decode(path);assert r['complete'] and not r['data_pass']
    assert r['dq_bit_flips'][9]==1 and r['lane_bit_flips'][1]==1 and r['beat_bit_flips'][0]==1
    path.write_text(fixture(True).replace(record(2,0,1,1,10000,10000,1,1),''));assert not decode(path)['complete']
    path.write_text(fixture(False).replace('0000000100000000','0000000100000001',1));assert not decode(path)['complete']
    path.write_text(record(6,5,2,4,100,100,100,99,0));assert decode(path)['fatal']['code']==2
print('DECODER TESTS PASSED: coverage, data failure, DQ/beat mapping, missing/duplicate records, fatal')
