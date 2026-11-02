# 1600MT/s在线并发及扩区压力测试

2026-10-29用户明确要求恢复1600MT/s并加大压力。状态：实现及上板已完成，数据失败。1MiB对照8轮128MiB读取330错拍；16MiB压力8轮2GiB读取3069错拍，校准PASS、fatal0。见[完整实测报告](hardware/2026-10-29_results.md)。800镜像及数据保留。

## 配置

- Micron VRP107每die4Gb x8、单rank、总x16/1GiB，保持引脚及1.5V/SSTL15。
- Si570参考仍250MHz；DDR tCK1250ps即CK800MHz/1600MT/s，UI200MHz，CL11/CWL8。
- 采用既有颗粒审计确定的保守1600参数：tRCD/tRP15ns、tRAS35ns、tFAW40ns、tRRD10ns、tRFC260ns、tREFI7.8us、tZQCS80ns、tZQINIT640ns。自定义CSV Max period为器件DLL最长3300ps，不是当前运行周期；首次误填1250被IP校验拒绝，已修正为3300，未绕过工具检查。
- UART与时钟接口元数据适配200MHz；SPARSE_GAP=200保持额外1us，与800版100周期等时。

## 负载与控制

保持独立ARLEN0请求、同ID顺序返回比较、最多32在途，记录实测峰值；交替8遍密集和8遍间隔读，写一次后不重写。

VIO probe_out0为start，probe_out1为cfg_large。仅在start=0/IDLE时改变cfg_large：0使用1MiB用于与800版比较；1使用16MiB用于压力测试。开始时锁存active_limit，避免运行期间边界变化。每轮读取量分别16MiB或256MiB。唯一覆盖上限16MiB，累计流量不能当作全容量覆盖。

ILA记录总体/各遍/各DQ计数和首错，首错padding新增large标志及实际在途峰值。旧800解码器不能直接用于本版本；新版拒绝区域/计数不一致、fatal及不完整捕获。UART保留独立AXID/LEGS格式，不参与在线判定。

仿真覆盖200MHz时钟下的背压、达到32在途、DQ9注入、错误RLAST/BRESP、超时、校准丢失、动态区域选择；写数据与Python独立表对照。小区域64拍×4遍、大区域128拍×4遍的缩小模型均按预期通过。仿真不包含PHY/板级模拟模型。

脚本run.tcl的参数为`轮数 标签 reuse或program 大区域标志`，-tclargs应放Vivado命令最后。默认重新下载；仅明确给reuse才复用。start只在IDLE/HALT清零，fatal或计数异常时脚本停止。上板前必须通过实际200MHz时序、DRC、55引脚及生成MIG参数检查。

用户已确认调压后四路电压符合目标（未抄精确值）；不同速率需要重新实现及训练，因此不能把差异单独归因总线频率，更不能把通过等同于模拟SI/全容量合格。
