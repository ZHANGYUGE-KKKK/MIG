#!/usr/bin/env python3
"""Readable measured results, with explicitly bounded conclusions."""
import argparse,json
from pathlib import Path
from collections import defaultdict
p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
r=json.loads(a.input.read_text());jobs=r['jobs'];lines=['# 同镜像DDR3自动诊断实测','',f'原始汇总：`{a.input}`','',
 f"完整372组覆盖：{r['complete']}；全部数据比较通过：{r['data_pass']}。",'']
if r['fatal']:lines += [f"致命故障：`{r['fatal']}`。本次未完成全套测试。",'']
if r['done']:lines += [f"错误突发累计：{r['done']['errors']}。",'']
lines+=['| DQ | 位翻转累计 |','| --- | --- |']
lines += [f'| {bit} | {n} |' for bit,n in enumerate(r['dq_bit_flips']) if n]
lines+=['','位翻转是UI位错误计数之和，一次突发可能贡献多个翻转。','',
        '## 固定写入反复读','',
        '| job | 模式 | 原生地址索引 | 返回数 | 错误突发 | 与首次读值不同 |','| --- | --- | --- | --- | --- | --- |']
for j,d in jobs.items():
 if d['stage']==0 and 'reads' in d:
  lines.append(f"| {j} | {d['pattern']} | {d['target']} | {d['reads']} | {d['errors']} | {d['changed_from_first']} |")
lines+=['','固定地址索引0/1/2/3分别为0、8、0x19FD8、0x19FE0。正误不依赖首次读取值，始终逐笔比较写入期望。','',
        '## 读取顺序','',
        '| job | 模式 | 起始位置 | 反序 | 返回数 | 错误突发 | 首个错误地址/序号 |','| --- | --- | --- | --- | --- | --- | --- |']
for j,d in jobs.items():
 if d['stage']==1 and 'reads' in d:
  sample=d['samples'][0] if d['samples'] else None
  first=f"0x{sample['native_addr']:X}/{sample['read_index']}" if sample else '-'
  lines.append(f"| {j} | {d['pattern']} | {d['rotation']} | {d['reverse']} | {d['reads']} | {d['errors']} | {first} |")
lines+=['','## 流量对照汇总','',
        '每项合并其他参数的全部组合；不同模式及配置详情保留在JSON，不能把单项汇总当作单独改变某个电气条件的实验。','',
        '| 参数 | 值 | 完成组数 | 读突发 | 错误突发 | 错误率 |','| --- | --- | --- | --- | --- | --- |']
for key in ('pattern','read_limit','write_limit','turn_gap','read_gap'):
 groups=defaultdict(lambda:[0,0,0])
 for d in jobs.values():
  if d['stage']==2 and 'reads' in d:
   v=groups[d[key]];v[0]+=1;v[1]+=d['reads'];v[2]+=d['errors']
 for value,(n,reads,errors) in sorted(groups.items()):
  lines.append(f'| {key} | {value} | {n} | {reads} | {errors} | {errors/reads:.6%} |')
lines += ['','## 判断边界','',
 '固定写入后出现多个不同返回值，是读路径/采样或存储内容稳定性的线索；固定错误值也可能来自固定读路径，不能单独证明是写错误。',
 '单次有限测试通过，不能代替1 GiB全容量、长时间或温度/电压条件验证。测试失败也不能单凭本结果将责任定位到转接板。',
 '每组只保存前4个原始错误样本；样本地址/序号不能代表全部错误的地址分布。','']
out=a.output or a.input.with_suffix('.md');out.write_text('\n'.join(lines));print(out)
