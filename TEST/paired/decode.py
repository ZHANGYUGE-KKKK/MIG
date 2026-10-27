#!/usr/bin/env python3
"""Decode one complete paired run, including exact per-address counters; no hardware access."""
import argparse,json
from pathlib import Path

def decode(path):
    raw=path.read_bytes();marker=b'D 0000000950414952 '
    start=raw.find(marker);jobs={};groups={};header=None;done=None;fatal=None;bad=[];bits=[0]*128
    if start<0:return {'complete':False,'data_pass':False,'malformed':['No PAIR image header'],'jobs':{},'groups':{}}
    for number,line in enumerate(raw[start:].decode('ascii',errors='replace').splitlines(),1):
        if not line.startswith('D '):continue
        try:
            words=line.split()[1:];assert len(words)==8 and all(len(w)==16 for w in words)
            f=[int(w,16) for w in words];kind=f[0]>>32;j=f[0]&0xffffffff
            if kind==9:
                assert header is None and j==0x50414952 and f[1]==1
                assert f[2] in (100000000,200000000) and f[3]==f[2]//3125000
                assert 128<=f[4]<=65536 and f[4]&(f[4]-1)==0 and 3<=f[5]<=15 and f[5]%2==1
                assert f[6]==18 and f[7]==18*f[5]
                header=dict(version=f[1],ui_clock_hz=f[2],sparse_gap_cycles=f[3],region_bursts=f[4],legs=f[5],groups=f[6],jobs=f[7])
            elif kind==1:
                assert header and j not in jobs and j==len(jobs)
                group=j//header['legs'];leg=j%header['legs'];pattern=(0,4,5)[group//6]
                assert f[1]==(group<<32)|leg and f[2]==pattern
                assert f[3]==(header['region_bursts'] if leg==0 else 0) and f[4]==header['region_bursts']
                assert f[5]==(1,4,32)[group%3] and f[6]==(1,32)[(group//3)%2]
                assert f[7]==(header['sparse_gap_cycles'] if leg%2 else 0)
                jobs[j]=dict(group=group,leg=leg,pattern=pattern,expected_writes=f[3],expected_reads=f[4],read_limit=f[5],write_limit=f[6],read_gap=f[7],samples=[],bit_flips={})
                if leg==0:groups[group]=dict(addresses={},chunks=[],pattern=pattern,read_limit=f[5],write_limit=f[6])
            elif kind==2:
                d=jobs[j];assert 'reads' not in d
                assert f[1]==f[2]==d['expected_writes'] and f[3]==f[4]==d['expected_reads']
                assert f[5]<=f[4] and f[6]<=f[4] and (d['leg']!=0 or f[6]==0)
                d.update(write_commands=f[1],write_data=f[2],read_commands=f[3],reads=f[4],errors=f[5],changed_from_previous=f[6])
            elif kind==3:
                d=jobs[j];exp=(f[2]<<64)|f[3];got=(f[4]<<64)|f[5]
                assert exp!=got and f[1]%8==0 and f[1]//8<header['region_bursts'] and f[6]==f[1]//8
                d['samples'].append(dict(native_addr=f[1],byte_base=f[1]*2,read_index=f[6],expected=f'{exp:032X}',actual=f'{got:032X}',xor=f'{exp^got:032X}'))
            elif kind==4:
                assert 0<=f[1]<128 and 0<f[2]<=jobs[j]['reads'] and f[1] not in jobs[j]['bit_flips']
                jobs[j]['bit_flips'][f[1]]=f[2];bits[f[1]]+=f[2]
            elif kind==7:
                d=jobs[j];group=d['group'];assert d['leg']==header['legs']-1
                g=groups[group];assert f[1]>>32==group;base=f[1]&0xffffffff
                assert base%48==0 and base<header['region_bursts'] and base not in g['chunks']
                g['chunks'].append(base);payload=b''.join(n.to_bytes(8,'big') for n in f[2:]);assert any(payload)
                for offset,count in enumerate(payload):
                    index=base+offset;errors=count&15;changes=count>>4
                    if index>=header['region_bursts']:assert count==0;continue
                    assert errors<=header['legs'] and changes<header['legs']
                    assert changes<=2*errors and (not (0<errors<header['legs']) or changes>0)
                    if count:g['addresses'][index]=dict(native_addr=index*8,byte_base=index*16,errors=errors,changes=changes)
            elif kind==8:
                d=jobs[j];g=groups[d['group']];assert 'errors' not in g
                assert d['leg']==header['legs']-1 and f[1]==d['group'] and f[5]==header['region_bursts']
                ds=[q for q in jobs.values() if q['group']==d['group']]
                assert len(ds)==header['legs'] and all('reads' in q for q in ds)
                assert f[2]==sum(q['errors'] for q in ds)==sum(q['errors'] for q in g['addresses'].values())
                assert f[3]==sum(q['changed_from_previous'] for q in ds)==sum(q['changes'] for q in g['addresses'].values())
                assert f[4]==len(g['chunks'])
                g.update(errors=f[2],changes=f[3],chunks_sent=f[4],
                         stable_wrong_addresses=sum(a['errors']==header['legs'] and a['changes']==0 for a in g['addresses'].values()),
                         variable_addresses=sum(a['changes']>0 for a in g['addresses'].values()),
                         intermittent_addresses=sum(0<a['errors']<header['legs'] for a in g['addresses'].values()))
            elif kind==5:
                assert header and j==header['jobs']-1
                done=dict(last_job=j,errors=f[1]);break
            elif kind==6:
                fatal=dict(job=j,code=f[1],state=f[2],write_commands=f[3],write_data=f[4],read_commands=f[5],reads=f[6],total_errors=f[7]);break
            else:raise ValueError('Unknown record type')
        except (AssertionError,ValueError,KeyError) as e:bad.append(dict(line=number,reason=str(e),text=line))
    complete=bool(header and done and not fatal and not bad and set(jobs)==set(range(header['jobs'])) and set(groups)==set(range(18)))
    if complete:
        complete=all('reads' in d and len(d['samples'])==min(4,d['errors']) and (d['errors']==0 or d['bit_flips']) for d in jobs.values())
        complete=complete and all('errors' in g for g in groups.values()) and sum(d['errors'] for d in jobs.values())==done['errors']
    dq=[0]*16;beat=[0]*8;lane=[0]*2
    for bit,count in enumerate(bits):
        lane[bit//64]+=count;beat[(bit%64)//8]+=count;dq[(bit//64)*8+bit%8]+=count
    return dict(complete=bool(complete),data_pass=bool(complete and done['errors']==0),header=header,done=done,fatal=fatal,malformed=bad,ignored_prefix_bytes=start,jobs=jobs,groups=groups,ui_bit_flips=bits,dq_bit_flips=dq,beat_bit_flips=beat,lane_bit_flips=lane)

def report(result,path):
    lines=['# 写一次、交替读取诊断结果','',f"完整覆盖：{result['complete']}；数据通过：{result['data_pass']}。",'']
    if result.get('header'):lines += [f"UI时钟配置：{result['header']['ui_clock_hz']} Hz；每组{result['header']['legs']}遍读取。",'']
    if result.get('fatal'):lines += [f"致命故障：`{result['fatal']}`。",'']
    lines+=['| 组 | 模式 | 写队列 | 读上限 | 密集错突发 | 稀疏错突发 | 实际值变化 | 有错/变化的地址数 | 恒错且不变的地址 | 返回值变化的地址 |','| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for group,g in result.get('groups',{}).items():
        ds=[d for d in result['jobs'].values() if d['group']==group and 'reads' in d]
        dense=sum(d['errors'] for d in ds if d['read_gap']==0);sparse=sum(d['errors'] for d in ds if d['read_gap']!=0)
        changes=sum(d['changed_from_previous'] for d in ds)
        lines.append(f"| {group} | {g['pattern']} | {g['write_limit']} | {g['read_limit']} | {dense} | {sparse} | {changes} | {len(g['addresses'])} | {g.get('stable_wrong_addresses','-')} | {g.get('variable_addresses','-')} |")
    lines+=['','每个组只在第0遍前写一次。密集与稀疏读取次数不同，应按各自实际读数比较错误率。逐地址计数和每遍样本在同名JSON中；未输出地址的计数为0。',
            '同一内容返回值变化，是读取路径或内容稳定性的线索，不能单凭此排除存储单元/保持或应用逻辑问题。稳定错误也不能单独证明为写错误。',
            '800/1600需要不同MIG/物理实现，不能当成只改变时钟的完全隔离实验。','']
    path.write_text('\n'.join(lines))

def main():
    p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
    result=decode(a.log);out=a.output or a.log.with_suffix('.json');out.write_text(json.dumps(result,indent=2)+'\n');report(result,out.with_suffix('.md'))
    print(json.dumps({k:v for k,v in result.items() if k not in ('jobs','groups','ui_bit_flips')},indent=2));print('SAVED',out)
    return 0 if result['complete'] else 2
if __name__=='__main__':raise SystemExit(main())
