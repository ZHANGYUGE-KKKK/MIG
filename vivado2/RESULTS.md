# BD版数据位测试：工具记录

日期：2026-10-26。用户要求新建根目录vivado2，采用图形Block Design；只生成Flash文件，不烧写新BD版。

## 已验证内容

- 实际IP Integrator设计wiring.bd已创建、连接校验通过。图形界面已只读打开并导出SVG，PNG预览已检查，包含5个块：时钟/复位、测试引擎、单事务转换、MIG、UART。
- MIG厂商GUI在BD模式强制AXI，故采用AXI4单拍16字节直连，不增加应用CPU或AXI interconnect。使用原测试引擎、UART和800配置CSV的精确副本。
- 生成参数与原已核实800 MIG比较，仅AXI启用、数据宽128、地址宽30、ID宽1及CSV路径不同；其他DDR C0参数、几何组织及时序一致。
- 原测试逻辑10例、AXI转换10例和时钟/复位1例全部通过；115200 UART和严格解码检查通过。
- 正常AXI和零周期读返回用例均完成8320个AW/W/B/AR/R握手；独立AW/W背压、BRESP/BID/RRESP/RID/RLAST错误、写途中复位和待读UI复位均覆盖。注入全部128个位的错误能原样返回。
- 图样覆盖32地址×260模式，16个DQ×8拍，8320次写/读；不是全容量/DM测试。可逆置换回环仍可能通过。
- 已核对实现后的55个板级IO封装脚及IO标准与已验证RTL800一致，GPIO LED7为BA37/LVCMOS12。
- 首次实现时发现XDC中不支持if检查，已将计数检查保留在构建Tcl中，从XDC移除条件语句；最终重新实现和全部时序/异常路径检查已通过，最终构建无该约束关键警告。

## 最终工具状态

综合、布局布线、bitstream、双MCS生成及产物检查均完成。

- WNS **+1.475 ns**、WHS **+0.011 ns**、WPWS **+0.456 ns**，全部用户时序约束满足，布线错误0，bus skew检查通过。
- DRC **0错误、4条厂商IP相关警告**：PDCN-1569×3、RTSTAT-10×1。编译环境的本地Tcl商店无写权限提示使用安装目录回退，不影响工具产物。
- 三级复位同步器仅3个PRE异步入口被豁免；两段Q→D及同步器输出路径仍受时序检查且通过，没有放宽数据路径时序。
- 压缩SPIx8、配置时钟31.9 MHz已读回核实；双MCS每颗实际10,723,422字节，共21,446,844字节（约20.45 MiB），各小于128 MiB容量，Intel HEX记录校验和/地址连续性通过。
- 产物校验器已核对保存BD的5个块、时钟/复位/LED/记录通道/原生格式信号/直连AXI网及1 GiB映射，并保存源代码与仿真/产物散列。

硬件DDR实测：**未执行**。新BD镜像烧写：**未执行**（用户只要求生成文件）。

完整清单：[build_manifest.json](build/build_manifest.json)。

既有RTL数据位镜像VIVADO/databit_800_build已经另行完成两颗Flash写入校验，耗时7分51秒；此记录不代表本BD版已经烧写或实物测试通过。

- `wiring_bd_800_primary.mcs` SHA256：`1b47bed7ef69fb53dc8e0d0f422b55e7ada576ef415752eafee44cf2b039ca75`

- `wiring_bd_800_secondary.mcs` SHA256：`c185ca3fc0e1e3756090f0194508e8910a7dafb424c47229e73de3fc63c7a93e`

## 后续授权：烧写BD版（2026-10-26）

用户在文件生成完成后明确要求烧写。已重新通过产物校验，核对两份MCS的SHA256，并识别JTAG序列号210308B43939、xcvu9p。两颗Flash的擦除、写入及读回校验全部成功，烧写耗时7分51秒，进程退出0。两份MCS的SHA256在完成后再次核对未变。日志与预检分别为build/flash_program_console.log、build/flash_program_preflight.json。旧镜像在DDR断开时报告校准失败，不作为本BD版DDR数据结果。

烧写清单：[flash_program_manifest.json](build/flash_program_manifest.json)。此BD版已烧入Flash，但尚未接DDR运行；配置启动和DDR数据结果待串口实测，不标记数据PASS。

## 首份完整DDR实测：通过（2026-10-26）

用户提交的422条DPIN记录完整通过严格解码：260模式、32地址、8320次写及8320次读，错误突发和128位直方图全部0，无致命故障或协议缺项，complete=true、data_pass=true。包含历史关注的DQ9。第一项数据位功能可标记通过；实际唯一地址位置512字节，不是全容量或地址别名验证，未验证DM及逐针物理身份，也未证明原密集读问题已解决。后续按计划进入DM测试。

原始文本、解析JSON、散列和结论边界见[实测报告](tests/hardware/2026-10-26_bd_dpin_run1.md)。前面“未实测”是文件交付/烧写阶段的历史状态，以本节为最新结果。
