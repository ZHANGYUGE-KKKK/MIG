#!/usr/bin/env python3
"""Strict decoder for DPIN v1. Complete transport and data PASS are separate."""
import argparse,json,re,hashlib
from pathlib import Path
LINE=re.compile(r'D ((?:[0-9a-fA-F]{16} ){7}[0-9a-fA-F]{16})$')
MASK=(1<<128)-1

def address(slot):
    return (0,0x1fffffc0,0x10000000,0x2000)[slot//8]+(slot%8)*8

def pattern(p):
    if p<128:return 1<<p
    if p<256:return MASK^(1<<(p-128))
    return (0,MASK,int('AA'*16,16),int('55'*16,16))[p-256]

def decode(text):
    header=None;addresses=[];results=[];samples=[];hist=[];done=None;fatal=None
    notes=[];sample_count=0;sum_errors=0
    for lineno,line in enumerate(text.splitlines(),1):
        # UART break/non-ASCII prefix may precede the first record.
        start=0 if line.startswith('D ') else -1
        if start<0:
            prefix=re.search(r'D [0-9a-fA-F]{16} ',line)
            if prefix is None:continue
            start=prefix.start()
        line=line[start:].strip();m=LINE.fullmatch(line)
        if not m:
            notes.append(f'line {lineno}: malformed D record');continue
        f=[int(x,16) for x in m[1].split()];kind=f[0]>>32;pid=f[0]&0xffffffff
        try:
            assert done is None and fatal is None,'record after terminal record'
            if header is None:
                assert kind==9 and pid==0x4450494e and f[1:]==[1,100000000,100,32,260,128,800],'wrong/missing header'
                header=f;continue
            assert kind!=9,'duplicate header'
            if kind==7:
                assert not results and not samples and not hist and len(addresses)<32
                assert pid==0 and f[1]==len(addresses) and f[2]==address(len(addresses)) and f[3:]==[0]*5,'bad address table'
                addresses.append(f[2]);continue
            assert len(addresses)==32,'incomplete address table'
            if kind==3:
                assert not hist and pid==len(results) and 0<=pid<260
                assert f[1] in addresses and f[2]<<64|f[3]==pattern(pid),'sample address/expected mismatch'
                assert f[6]==addresses.index(f[1]) and f[7]==sample_count and sample_count<8,'bad sample order'
                got=f[4]<<64|f[5];xor=got^pattern(pid);assert xor,'zero error sample'
                bits=[i for i in range(128) if xor>>i&1]
                samples.append(dict(pattern=pid,native_address=hex(f[1]),byte_address=hex(f[1]*2),slot=f[6],expected=f'{pattern(pid):032X}',actual=f'{got:032X}',bits=[dict(ui_bit=i,dq=(i//64)*8+i%8,beat=(i%64)//8) for i in bits]))
                sample_count+=1
            elif kind==2:
                assert not hist and pid==len(results) and pid<260,'missing/duplicate/out of order pattern'
                assert f[1]==32 and f[2]==32 and f[3]<=32 and f[6]==100 and f[7]==0,'bad pattern counters'
                assert sample_count==min(f[3],8),'missing error samples'
                sum_errors+=f[3];assert f[4]==sum_errors,'bad cumulative errors'
                results.append(dict(pattern=pid,writes=f[1],reads=f[2],errors=f[3],cumulative_errors=f[4],cycles=f[5]));sample_count=0
            elif kind==4:
                assert pid==0 and len(results)==260 and f[1]==len(hist) and len(hist)<128 and f[3:]==[0]*5,'bad histogram sequence'
                assert f[2]<=8320,'histogram count out of range'
                hist.append(f[2])
            elif kind==5:
                assert pid==0 and len(results)==260 and len(hist)==128,'premature DONE'
                assert f[1:]==[8320,8320,sum_errors,260,32,100,0],'bad terminal counters'
                assert sum_errors<=sum(hist)<=sum_errors*128,'histogram inconsistent with errors'
                for bit in range(128):
                    observed=sum(any(b['ui_bit']==bit for b in s['bits']) for s in samples)
                    assert observed<=hist[bit],'sample exceeds histogram'
                done=f
            elif kind==6:
                assert pid==0 and f[1] in (1,2,3,4),'invalid fatal'
                fatal=dict(code=f[1],state=f[2],writes=f[3],reads=f[4],errors=f[5],pattern=f[6]>>29,native_address=hex(f[6]&((1<<29)-1)))
            else:raise AssertionError(f'unknown record type {kind}')
        except (AssertionError,IndexError) as e:
            notes.append(f'line {lineno}: {e or "invalid record"}')
    complete=done is not None and not notes
    dq_hist=[sum(hist[i] for i in range(len(hist)) if (i//64)*8+i%8==dq) for dq in range(16)]
    return dict(complete=complete,data_pass=complete and sum_errors==0,fatal=fatal,malformed=notes,
                patterns=len(results),addresses=len(addresses),writes=done[1] if done else sum(r['writes'] for r in results),reads=done[2] if done else sum(r['reads'] for r in results),
                errors=sum_errors,bit_flips=sum(hist),dq_histogram=dq_hist,ui_bit_histogram=hist,results=results,samples=samples)

def self_test():
    root=Path(__file__).resolve().parent/'build'
    for mode in range(10):
        text=(root/f'mode_{mode}.log').read_text();assert 'DATABIT SIM PASSED' in text
        d=decode(text)
        assert not d['malformed'],(mode,d['malformed'])
        if mode<=2 or mode==9:
            assert d['complete'] and d['data_pass']==(mode in (0,9)),(mode,d)
            if mode==1:assert d['errors']==8320//17 and d['dq_histogram'][9]==d['errors']
            if mode==2:assert d['errors']==8320 and all(x==65 for x in d['ui_bit_histogram'])
        else:assert not d['complete'] and d['fatal']
    text=(root/'mode_0.log').read_text();lines=text.splitlines()
    assert not decode('\n'.join(x for x in lines if not x.startswith('D 0000000500000000')))['complete']
    result=next(x for x in lines if x.startswith('D 0000000200000000'))
    assert not decode(text.replace(result+'\n','',1))['complete']
    assert not decode(text+'\n'+result)['complete']
    assert not decode(text.replace('000000094450494e','000000094450494f',1))['complete']
    assert not decode(text+'\nD bad')['complete']
    print('DATABIT DECODER PASSED: good/data-fail/fatal, truncated/missing/duplicate/wrong-header/malformed')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('log',nargs='?');p.add_argument('--output');p.add_argument('--self-test',action='store_true');a=p.parse_args()
    if a.self_test:self_test()
    else:
        if not a.log:p.error('log required')
        source=Path(a.log);raw=source.read_bytes();d=decode(raw.decode('ascii',errors='replace'));d['raw_sha256']=hashlib.sha256(raw).hexdigest()
        out=Path(a.output) if a.output else source.with_suffix('.json');out.write_text(json.dumps(d,indent=2)+'\n')
        print(json.dumps({k:v for k,v in d.items() if k not in ('results','samples','ui_bit_histogram')},ensure_ascii=False,indent=2))
        raise SystemExit(0 if d['complete'] else 2)
