#!/usr/bin/env python3
import tempfile
from pathlib import Path
from decode import decode

def rec(kind,job,*fields):
    f=[(kind<<32)|job,*fields];f += [0]*(8-len(f));return 'D '+' '.join(f'{n:016X}' for n in f)+'\r\n'

def fixture(hz,inject):
    text=rec(9,0x50414952,1,hz,hz//3125000,65536,11,18,198)
    for group in range(18):
        for leg in range(11):
            job=group*11+leg;errors=(3 if leg%2 else 4) if inject else 0;changes=2 if inject and leg else 0
            writes=65536 if leg==0 else 0
            text+=rec(1,job,(group<<32)|leg,(0,4,5)[group//6],writes,65536,(1,4,32)[group%3],(1,32)[(group//3)%2],hz//3125000 if leg%2 else 0)
            text+=rec(2,job,writes,writes,65536,65536,errors,changes)
            if inject:
                addresses=[9,17,65535]+([5] if leg%2==0 else [])
                for a in addresses:text+=rec(3,job,a*8,0,0,0,1,a)
                text+=rec(4,job,0,errors)
        job=group*11+10
        if inject:
            for base,items in ((0,{5:0xA6,9:0x0B,17:0xAB}),(65520,{15:0x0B})):
                data=bytearray(48)
                for index,value in items.items():data[index]=value
                fields=[int.from_bytes(data[i:i+8],'big') for i in range(0,48,8)]
                text+=rec(7,job,(group<<32)|base,*fields)
        text+=rec(8,job,group,39 if inject else 0,20 if inject else 0,2 if inject else 0,65536)
    return text+rec(5,197,702 if inject else 0)

with tempfile.TemporaryDirectory() as directory:
    p=Path(directory)/'log.txt'
    for hz in (100000000,200000000):
        for inject in (False,True):
            text=fixture(hz,inject);p.write_bytes(b'\x00\xff'+text.encode());r=decode(p)
            assert r['complete'] and r['data_pass']==(not inject) and r['ignored_prefix_bytes']==2
            if inject:
                assert r['groups'][0]['stable_wrong_addresses']==2 and r['groups'][0]['variable_addresses']==2
                assert r['groups'][0]['intermittent_addresses']==1
                assert r['groups'][0]['addresses'][5]['changes']==10
                assert r['groups'][0]['addresses'][9]['changes']==0
                assert r['groups'][0]['addresses'][65535]['errors']==11
    text=fixture(200000000,True)
    p.write_text(text.replace(rec(8,10,0,39,20,2,65536),''));assert not decode(p)['complete']
    p.write_text(text.replace(rec(4,0,0,4),''));assert not decode(p)['complete']
    p.write_text(text.replace(rec(2,1,0,0,65536,65536,3,2),''));assert not decode(p)['complete']
    # A missing address chunk is detected by its reported count and cumulative totals.
    lines=text.splitlines(True);p.write_text(''.join(l for l in lines if not l.startswith('D 000000070000000A ')));assert not decode(p)['complete']
    p.write_text(rec(9,0x50414952,1,200000000,64,65536,11,18,198)+rec(6,0,1));assert decode(p)['fatal']['code']==1
print('PAIRED DECODER PASSED: both clocks, full coverage, stable/transient corruption, address tails, missing records, fatal')
