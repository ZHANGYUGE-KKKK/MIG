# VCU118 母板 FMC 路径与单端 DDR 使用审计

日期：2026-10-27。范围：FPGA U1 → VCU118 Rev2.0 母板 J2 HPC1。用户说明 J2 之后转接板及 DDR 子板已做等长，本轮将其作为用户提供的条件，未重新测量下游 PCB。此次为资料审计，没有新的上板实验、镜像修改或烧写。

## 结论与证据等级

1. 当前 50 根 DDR 信号的 FPGA 球位/母板网名，全部与官方 Rev2.0 XDC 一致，逐线结果在 [signals.csv](signals.csv)。这验证静态映射，不验证实际长度。
2. Rev2.0 原理图 PDF 第12页为 Bank66/67，第39–41页为 J2。DQ8=AK15→LA26_P→J2/D26；DQ9=AL15→LA26_N→J2/D27；DQS1_P/N=AJ13/AJ12→LA32_P/N→J2/H37/H38。图中这些 LA 信号直接连接 FPGA 与 J2，没有画出跨 DQ8/DQ9 的差分终端电阻或串联交流耦合电容。
3. 原理图源文件中确有 `PCBCLASS=FMC_HPC1_LA_BUS`，包括 LA26_P/N；见 [源属性摘录](source_net_attributes.txt)。**同属 PCB class 不等于明确的等长组，也不能证明制造完成后的时延满足约束。**本地归档中未找到实际 PCB 布线文件、逐网长度/时延报告、叠层与阻抗报告；已检查原理图页未见可用于此 DDR 分组的数值长度要求。公开官方资料检索也未取得这份逐网报告。不能据此断言母板做了/没做 DDR 组内等长。
4. [官方 UG1224 v1.5 第95页](https://docs.amd.com/api/khub/documents/Uoc4S9pQd1uve6kiGiG2kA/content?Ft-Calling-App=ft%2Fturnkey-portal&Ft-Calling-App-Version=5.0.55&download=true)明确 J2 支持68路单端或34对差分 LA。P/N 命名没有强迫两根线必须作为差分使用。官方 XDC 的 LVDS 是模板示例，不是板上不可更改的硬件属性；本项目实际约束及实现报告中 DQ/DM 为 SSTL15_DCI，CK/DQS 为 DIFF_SSTL15_DCI。

## 按差分布线的两根线用于独立单端信号

电气上可用，但不能把“差分对合格”直接当成“DDR 单端通道合格”。

- 差分接收用两线电压之差；DQ8和DQ9各自相对 VREF 判决，数据并不互为反相。两线同向翻转、反向翻转、一线翻转另一线静止时，耦合影响不同。若实际母板长距离紧耦合布线，可能出现与数据模式有关的串扰、过冲/欠冲、阈值交越时间变化。这是待验证机制，不是本板已有测量结论。
- 假设某对目标差分阻抗100Ω，也只能推出奇模阻抗50Ω；不能据此断言每根线作为任意独立单端信号时始终呈现50Ω。实际值取决于线宽、线距、叠层、参考面和邻线开关条件。[AMD UG583 阻抗说明](https://docs.amd.com/r/en-US/ug583-ultrascale-pcb-design/Trace-Characteristic-Impedance-Design-for-High-Speed-Transceivers)给出差分阻抗与奇模阻抗关系；此处仅引用传输线原理，不将 GTY 指标套到 LA 总线，也未确认 VCU118 此段实际100Ω。
- DDR 中 CK、DQS 本来就是差分，应保留 P/N 配对；DQ、DM、地址/命令则按单端信号审核。不能给承载两个独立 DQ 的 P/N 之间加差分终端来“改善匹配”。

## 等长必须按完整通道计算

对任意信号 i，应审核 `T_i = FPGA封装延迟_i + 母板延迟_i + 连接器/转接板/子板延迟_i`。以相应 DQS 对的参考延迟检查每组 DQ/DM；地址/命令/控制对 CK 检查。不是要求全部50根信号机械等长，也不能把母板 PCB 球位之外的长度当成 FPGA 芯片内部到颗粒的全部路径。

若下游每根线只是加上相同延迟，那么母板已有的时延差仍保留，不会自动抵消。例如假设母板某DQ比其DQS长10mm，下游各自再等长增加100mm，总路径仍相差10mm；此例不是本板实测。

[AMD UG583 通用内存布线要求](https://docs.amd.com/r/en-US/ug583-ultrascale-pcb-design/General-Memory-Routing-Guidelines)要求把 FPGA 封装延迟计入，建议同字节 DQ/DM/DQS 主走线同层，并检查参考面、过孔及间距。[DDR3约束表](https://docs.amd.com/r/en-US/ug583-ultrascale-pcb-design/DDR3-SDRAM-Routing-Constraints)单独约束 DQ/DM 对 DQS、DQS对内、地址/命令对CK和CK对内。其数值是指南条件下的布局规则，不能仅据当前800 MT/s或MIG校准成功推断实板达到要求。物理长度相同但走不同层/不同介质，也可能传播时间不同。

## 与现有实验的关系

此前800 paired四份记录共1488个错突发：DQ9共1484次、DQ8共4次；DQ8/DQ9恰在同一FMC LA26对。此事实使 LA26 通道及其相对 DQS1 的裕量值得重点检查，但不足以定位母板、转接板、子板、终端、电源或PHY中的具体一处。

最新BD低负载DPIN单次完整运行8320写/8320读、0错，证明这些模式和地址下具备读写能力。1us事务间隔减少活动密度，**每次DDR突发仍为800 MT/s**；不会把突发内部采样窗口放慢，也不能排除模式相关串扰/时序裕量问题。等长本身也不排除阻抗、参考面、过孔、端接或供电因素。

## 后续可执行项

### 补充：FMC是否关注差分对之间的匹配

2026-10-27继续核查：不能把此前的“对内等长不证明DDR组内匹配”误解为“FMC规范不关注对间偏斜”。[Digilent官方Genesys ZU参考手册](https://digilent.com/reference/programmable-logic/genesys-zu/reference-manual)在FMC布线说明中解释，用户IO常用于源同步接口，因此要控制inter-pair skew；其对规范的说明为建议给对间偏斜分配不超过目标UI的10%。该板还发布包含封装延迟的匹配目标以及PCB逐网长度，说明具体母板应有自己的实施指标。这是厂家对规范的公开说明；本轮未取得当前ANSI/VITA57.1完整正文，不能据此声称现行条款编号、强制级别或母板/子板预算分配已经逐条核实。

按10% UI作算术示例：800MT/s的UI=1250ps，对应125ps；1600MT/s对应62.5ps。这是通用FMC偏斜预算示例，不是DDR3合格阈值，不代表VCU118实际达到这些值，也不是要求LA/HA/HB所有对机械完全等长。DDR仍须按对应器件、拓扑、DQ/DM/DQS与地址/CK分组的规则检查完整通道。

另有[Avnet MicroZed FMC母板官方手册](https://www.avnet.com/fsp/opasdata/d120001/medias/docus/58/AES-MBCC-FMC-G-MBCC_FMC_UG_1.1.pdf)公开给出P/N对内偏差及LA总线跨位偏差目标；这属于该板实施规范，不能挪用作VCU118实际走线数据。当前“VCU118母板匹配未证实”的结论保持。

- [x] 50信号官方XDC映射、关键原理图路径及单端使用支持核对。
- [ ] 取得与实物板版本对应的 VCU118 PCB 原文件，或 FPGA球位至J2的50信号 routed length / flight-time、层别、过孔、线宽/线距、叠层和阻抗报告；在缺少这些数据时保留“母板匹配未证实”。
- [ ] 合并 FPGA package flight times 和三板通道报告，计算两组 DQ/DM→DQS、CK/DQS和地址/命令→CK的偏差。若下游报告已补偿母板/封装，应使用报告中的实际值，不能再假设全部下游延迟相同。
- [ ] 当前功能验证继续DM与地址唯一性，不因本审计重做1600 MT/s。若后续专门隔离串扰，在800 MT/s固定地址/事务条件下，对 DQ8/9 做00→11、01→10及一线静止另一线翻转的对照；再扩展同字节邻线激励，记录错误方向/拍/地址。对照只能提供模式相关性，物理定点仍需PCB/SI或波形证据。

原始PDF位于 `/home/wenhan/PROJECTS/ARCHIVE/DATASHEET/VCU118/HW-U1-VCU118_REV2_0_SCHEMATIC_7-14-2017.pdf`。相关页文字摘录随本报告保存，已视觉检查第12、39页；[source_manifest.json](source_manifest.json)记录本地来源散列。本轮未取得实际母板长度，CSV长度栏保留空白，禁止用原理图画线长短估算PCB长度。
