# JTAG/ILA低负载基线，2026-10-29

用户报告已调节R257并重新上电；调整后的具体电压数值未回报，不能写成仪表已验证1.50V。本轮不更改DDR800MT/s、颗粒参数或原DPIN应用逻辑，保留UART；在原综合checkpoint上加入ILA并重新布局布线。原Flash镜像及原BD镜像保留。

实现后setup/hold检查通过、DRC0错误，镜像及匹配LTX见本目录。首次默认JTAG频率采集时工具报ILA数据损坏，不解释为DDR错误；将JTAG设为3MHz后重新下载并采集成功。不能仅据一次重试确定调试传输异常的物理根因。

ILA完成样本：done=1，pattern=259，8320写、8320读、total_errors=0、fatal_code=0、calib_complete=1、ui_reset=0。1024样本中512个终态样本。证明32地址×260模式的低负载测试完成，不是全容量/DM/密集读验收，也不宣称DQ9历史故障已消失。

- [解析汇总及镜像散列](2026-10-29_baseline_summary.json)
- [ILA原始CSV](2026-10-29_baseline_ila.csv)
- [Vivado原生波形](2026-10-29_baseline_ila.ila)
- [3MHz JTAG运行日志](run_ila_3mhz_console.txt)
- [探针位序](probes.tsv)
- [构建脚本](build_ila.tcl)和[下载采集脚本](run_ila.tcl)

probe顺序为done、total_writes、total_reads、total_errors、fatal_code、state、pattern、actual、expected、address、calib_complete、ui_reset。综合优化可能压缩常量位、重命名/拆分探针；CSV不可按列序盲目解释，计数器根据唯一字段名解析。state按映射解释，不混淆分片与完整状态编码。

后续准备独立AXI PRNG密集/稀疏对照，使用VIO控制启动、ILA读取各轮计数与首错信息。该流量实现与历史native paired不同，必须说明实验条件变化，不能把新的通过单独当作低电压已被证明是唯一根因。
