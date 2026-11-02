# 2026-10-29 H2移除后的JTAG访问验证

用户说明已去除H2引脚并插上板卡，要求检查JTAG调试。此次仅执行硬件管理器连接、扫描、读取状态、调试核枚举及连续刷新；没有下载、烧写、复位或触发校准。

结果：完成，Vivado退出0。

- 目标：Digilent 210308B43939，设备xcvu9p_0。
- 初次刷新及后续3次刷新均可访问，最后AUDIT_COMPLETE。
- 当前设计发现1个MIG，路径末尾为0_1/MIG_1；没有发现用户ILA或VIO。
- FPGA配置状态EOS=1，PLL_LOCK=1，配置CRC错误=0。
- 每次刷新均警告Calibration Failed。此轮只确认调试接口可访问，尚未读取完整MIG校准阶段报告，不能从警告直接确定故障原因，也不能证明DDR数据读写正常。
- 用户提供的板卡连接状态未在本轮通过UART/实物图独立核实。不能仅凭FPGA识别成功宣称DDR链路与JTAG同时工作正常；当前DDR校准失败。

原始记录：[console](2026-10-29_console.txt)、[Vivado日志](2026-10-29_vivado.log)、[只读检查脚本](check.tcl)。

此前“JTAG与DDR无法共存”是旧H2接地条件下的历史限制。用户改变H2后，本次证据已支持在当前连接状态下用JTAG读取器件与MIG；不再把旧限制无条件用于新连接。下一步可通过现有MIG调试接口读取校准失败阶段，再结合当前供电和UART判断DDR状态。任意信号ILA抓取仍需镜像内有相应探针。

## 完整链路复查（同日，用户后续补充并连接DDR核心板）

用户澄清：上次Calibration Failed时只有转接板，尚未连接DDR核心板。因此旧失败是缺少DDR条件下的数据，不用于定位完整链路。现完整连接后再次只读检查：

- JTAG持续可访问，MIG Overall Status=CAL PASS，MicroBlaze Status=PASS，无校准错误或警告。
- 报告Memory Frequency=400MHz，Bit Time=1250ps，对应DDR800MT/s；1 rank、2 bytes、4 nibbles。
- 已启用的12个校准阶段全部PASS，复杂模式和VREF训练等阶段SKIP。原始报告中的DQS Gate Status=RUNNING与具体校准阶段DQS Gate=PASS分别原样保留，不据此单独推断故障。
- 简单模式下降沿读margin，Byte0/Nibble0、Byte0/Nibble1、Byte1/Nibble0、Byte1/Nibble1的Left/Right报告值分别527/531、535/535、539/539、532/532。
- 上升沿对应687/687、687/690、672/676、665/668；简单写Byte0为587/583、Byte1为568/565。以上为格式化报告原始数值，本条不作单位换算或跨模式阈值判断。
- 这些结果没有显示高字节简单校准窗口明显塌陷，不能排除DQ9在复杂PRNG密集流量下的动态错误。Nibble/Byte汇总不是逐DQ眼图；Complex阶段未运行的零值不能解释为零裕量。
- 本轮没有重新下载、烧写、修改PHY或触发新训练，也没有采集新的应用压力测试计数。仅靠校准报告尚不能确定历史错误根因。

证据：[完整属性](2026-10-29_full_chain_console.txt)、[格式化MIG报告](2026-10-29_mig_report_console.txt)。同时核对了R257为本地VDDQ调压电位器、VTT/VREF跟随，详见[测量说明](../../EDA/measurement/README.md)。已请求用户提供J199/J200/J201/J202负载端电压，尚无读数。用户授权后续优先JTAG直接下载，撤销必须通过Flash下载的限制。
