# 验证记录（2026-10-24）

## 应用逻辑仿真

Verilator 用户接口级仿真通过：`TEST/run_sim.sh`，结果见 `TEST/build/simulation.log`，包含 `ALL TESTS PASSED`。

覆盖：写数据背压、写命令背压、周期性 ready 停顿、错误数据注入（实际打印 `IELLOWORLD` 并报告 FAIL）、校准超时、写握手超时、读返回超时、复位后重新成功运行。每轮解码 UART 起始位、8 个数据位、停止位并逐字节比较完整输出；正常轮次确认一次写命令、一次写数据及一次读命令。

最初尝试 XSim 2022.2 时，展开成功，但启动快照出现 `unexpected exception when evaluating tcl command`，没有得到有效仿真结果。因此正式可复现测试脚本采用本机已安装的 Verilator，未将 XSim 记为通过。

## Vivado 构建

最终含 GPIO LED 7 的版本通过 Vivado 2022.2 综合、布局布线、bitstream 生成及构建脚本检查。`VIVADO/build/final_console.log` 包含 `BUILD PASSED: bitstream`（本地时间 20:39 完成）。

- 工程：`VIVADO/build/project/ddr3_loopback.xpr`。
- bitstream：`VIVADO/build/ddr3_loopback.bit`，80,159,230 字节。
- SHA256：`f423101ee2459a9e77508962bf76bb0407c9e3dd29021db264c72d5c77d2675a`。
- 源文件散列：`VIVADO/build/build_manifest.json`。
- 建立 WNS=+1.650 ns、TNS=0；保持 WHS=+0.009 ns、THS=0；脉宽 WPWS=+0.143 ns。报告确认全部用户指定时序约束满足。
- Bus skew 报告无 VIOLATED；21,949 根可布线网络全部布通，routing errors=0。
- DRC：0 错误、4 警告，分别为 MIG 调试核心的 3 项 PDCN-1569 LUT 方程提示和 1 项 RTSTAT-10 无可布线负载提示；未降低 DRC 严重等级。
- I/O 报告确认 GPIO_LED7=BA37/LVCMOS12；RTL 直接连接 MIG 校准完成输出。时钟报告确认用户时钟周期 5.000 ns（200 MHz）。
- `python3 TEST/check_pinmap.py` 通过：50 根 DDR 引脚逐项匹配本工程保存的转接板映射，LED 7 引脚正确。
- 时序报告内部无缺失时钟或无约束内部端点。异步 SW5 输入、UART TX、LED 输出使用显式 false path；MIG 的异步 DDR RESET# 输出及 IP 调试接口仍可出现在无约束路径表中，不等同于 DDR 信号已通过板级时序实测。
- 工具仍有本地 Tcl Store 不可写而退回安装目录、固定 BUFG 位置、MIG 生成约束及 Updatemem 的提示；这些未阻止构建。

## 硬件

已连接开发板并完成双 QSPI Flash 烧写及校验，详情见本文后续硬件烧写记录。尚无 DDR3 校准、实际读写或压力测试通过记录，1600 MT/s 仍只是 MIG 配置目标。

## Flash 镜像生成

`VIVADO/scripts/generate_flash.sh` 已通过，日志为 `VIVADO/build/flash_generation.log`，包含 `FLASH GENERATION PASSED`。
复用最终实现，设置 SPIx8 和器件支持的 CONFIGRATE=31.9 MHz，生成 `ddr3_flash.bit`、`ddr3_flash_primary.mcs`、`ddr3_flash_secondary.mcs`。最初使用的 33 MHz 枚举被 Vivado 拒绝，已修正后成功生成。

两份 MCS 的全部 Intel HEX 记录校验和、连续地址和结束标记已检查通过。每颗实际写入 40,079,606 字节，合计 76.446 MiB，占两颗 1-Gbit Flash 总计 256 MiB 容量的 29.86%。MCS 文本各 110,228,728 字节，不代表实际 Flash 占用。散列与地址记录在 `VIVADO/build/flash_manifest.json`。

此镜像生成阶段（20:49）仅生成文件；后续已经执行的硬件烧写见下一节。

## 双 QSPI 硬件烧写（22:32–23:01）

- JTAG：Digilent `210308B43939`，器件 `xcvu9p_0` / `xcvu9p`。
- 镜像：未压缩的 `ddr3_flash_primary.mcs` 和 `ddr3_flash_secondary.mcs`，烧写前 SHA256 与 `flash_manifest.json` 一致。
- 两颗 QSPI 均读到 JEDEC 信息：Mfg ID `20`、Memory Type `bb`、Memory Capacity `21`，符合每颗 1 Gbit 的 Micron Flash。
- 操作：按文件覆盖范围擦除、写入、读回校验；两颗均输出 `Erase Operation successful.` 和 `Program/Verify Operation successful.`。
- 总结果：`Flash programming completed successfully`、`FLASH PROGRAM AND VERIFY PASSED`；`program_hw_cfgmem` 实际耗时 28 分 11 秒。
- 日志：`VIVADO/build/flash_program_console.log`、`flash_program.log`。
- 慢速诊断：两次间隔 20 秒的采样分别观察到 Vivado 至 hw_server 的已确认通信字节增加 984,975 和 984,990 字节，约 48 KiB/s。此为通信数据统计，包含协议开销，不代表 Flash 已写字节或完成百分比。第一颗最终通过校验，排除了该阶段完全卡死的判断；烧写结束后的只读查询确认目标 `PARAM.FREQUENCY=15000000`（15 MHz），见 `VIVADO/build/jtag_query_console.log`；因此不能将慢速简单归因于 TCK 设置过低。
- 用户说明 SW16 尚未调整。烧写后的 Flash 启动尝试与 Flash 写入校验是不同结果，尚未确认冷启动及 DDR3 测试通过。应在烧写结束后断电，将 SW16 第 2/3/4 位设为 OFF/OFF/ON，再上电测试；第 1 位保持原状。

### 后续压缩镜像

同一份最终实现开启 `BITSTREAM.GENERAL.COMPRESS` 后，bitstream 缩小为 21,185,044 字节（20.20 MiB）；两颗 Flash 各需 10,592,506 字节数据。两份 MCS 的全部记录校验和、连续地址和 EOF 已验证，散列见 `VIVADO/build/compressed_flash_manifest.json`。该压缩镜像没有用于上述本次烧写，没有改写正在烧录的原始输入。

### 本次启动尝试结果

Flash 写入校验完成后，`boot_hw_device` 等待 180 秒，最终报告 `Booting from configuration memory device unsuccessful`，于 23:03:58 退出。烧写脚本最终非零退出来自此启动步骤，**并非 Flash 擦除、写入或校验失败**；此前两颗均明确校验成功。

当前用户尚未调整 SW16，需先断电切换到 Master SPI 后再验证冷启动；此次启动失败的具体原因尚未通过调整启动模式后的测试确认。CP2105 SCI（if01，`/dev/ttyUSB2`）以 115200/8N1 接收，捕获文件 `TEST/build/uart_flash_boot.log` 为 0 字节，尚不能确认 MIG 校准或 HELLOWORLD 实测通过。串口监听已关闭。

## SW16 调整并断电重启后的只读检查（23:11）

用户确认已修改 SW16 并完全断电后上电。JTAG 读回三个 SLR 的配置寄存器，其中 SLR0 的 `CONFIG_STATUS=0x10b079fc`：M[2:0]=001，DONE 内部/引脚=1，EOS=1，CRC_ERROR=0；启动状态无 fallback、ID 或 CRC 错误。确认 FPGA 已完成上电配置，先前未调整启动模式时的启动超时已不代表当前状态。

用户报告 GPIO LED 7 未点亮。官方 Rev2.0 原理图第 55 页确认 GPIO_LED7 对应 DS18，经 Q8 驱动；本工程 BA37/LVCMOS12 约束和 RTL 直接显示校准完成信号。此时尚未证明 DDR3 校准或数据测试通过，仍需结合串口与 MIG 调试状态定位。

### 硬件连接状态澄清

用户随后明确说明：当前尚未连接无源转接板及 DDR3 子板。因此校准不能完成，GPIO LED 7 不亮符合当前硬件状态，不能据此判为工程故障。用户选择串口可见 `DDR WAIT CAL` 或 `DDR TIMEOUT`：这与测试逻辑已运行、但等待 DDR 校准超时的情形一致。尚未进行完整 DDR3 硬件链路测试。

MIG 调试对象的只读查询还确认：`CALIBRATION_FAIL.STATUS=TRUE`，阶段 1 的 `CAL_STATUS.RANK0.01_DQS_GATE=FAIL`，错误为未采到预期 DQS preamble（`Pattern not found on GT_STATUS`）。在未连接 DDR3 子板的前提下，这是缺少存储器返回信号的预期结果，不构成已接好硬件后的故障结论。日志：`VIVADO/build/mig_inspection_console.log`。未修改 FPGA 配置或 Flash。

## 接入 DDR3 链路后的检查（23:15 起）

用户确认连接链路后完全断电重启，串口仍 TIMEOUT，GPIO LED 7 仍不亮。当前尚无校准通过证据。

普通 JTAG 扫描及降至 3 MHz 后重试，均报告 `No devices detected on target`；没有取得新的 MIG 校准错误，因此不能沿用之前未接子板时的 DQS_GATE 错误作为当前连接后的结果。日志：`linked_mig_inspection_console.log`、`linked_mig_retry_console.log`。

用户随后说明：转接板母板侧 H2 接地，但 TDI/TDO 未接。已核对 VCU118 Rev2.0 原理图第 39 页：U132 的 PRSNT 控制旁路在 H2 拉低时断开，D30(TDI)/D31(TDO) 需要通过插卡闭合，故当前 JTAG 断链可由此解释。待硬件恢复调试旁路，或通过串口/实测进一步定位。尚未对转接板进行修改。

下一步需实测子板 VDD/VDDQ、VTT/VREF、稳定后的 RESET#；用户先前确认的母板 VADJ/时钟设置不等同于这些子板端实测值。

### 子板供电读数（用户实测反馈）

用户报告：J199、J200、J202 均约 500 mV，J201 约 0 V。对应 VDD/VDDQ/VTT/VREF 明显不满足工程目标。暂停将 TIMEOUT 归因于读写状态机；优先核对测量参考、3V3→J5→3V3_B→5V_B→U25 输入及 J220 使能链路。尚未确认具体故障元件或跳线错误，未修改电位器或实物跳线。

### 2026-10-25 裸机测试结果

用户确认：裸机测试通过。此结果为最新反馈；上述供电异常及排查内容保留为历史记录。具体修复步骤、测试参数及通过日志尚未补充。
