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

## 2026-10-25 压力测试版本：实现、仿真和工具验证

用户同意压力测试方案后，已新增独立 `VIVADO/stress/` RTL 和 `VIVADO/stress_build/` 工程/产物。复用基线 MIG、引脚、250 MHz 输入、200 MHz UI、1600 MT/s DDR3、UART 和 LED 7；不引入应用 CPU 或 AXI。原 HELLOWORLD 源码、原始 bitstream、未压缩及压缩 Flash 文件的 SHA-256 均与原有 manifest 一致。未修改开发板配置或 Flash。

### 已实现行为

- 自动运行 1 MiB 的 9 种模式、64 MiB 的 7 种模式、1 GiB 全容量的 7 种模式覆盖。
- 随后无限循环整区连续写/读、全容量置换读和全部 4 KiB 块的写/读切换。每整轮 2 GiB 写、3 GiB 读，完成后 pass 加 1。连续轮次更换 seed、交替正反方向，块 seed 先经过 xorshift，避免与块地址直接异或造成抵消。
- 读请求最多 32 笔在途；每个 128-bit 返回都比较。整区任务先写完整区，再读完整区，避免逐地址立刻读回漏检地址别名。
- UART 每 5 秒请求状态摘要，阶段/模式变化也请求快照，忙时合并。首错独立保留，停止新请求并有界收尾，输出地址、128-bit 期望/实际/XOR 和上下文。LED 7 仍仅显示校准完成。

### 已通过的验证

命令：`TEST/stress/run_sim.sh`。三项测试均通过，日志在 `TEST/stress/build/`：

| 测试 | 已检查内容 |
| --- | --- |
| `engine_tb` | 缩小容量，全部模式/阶段、两整轮循环、32 笔在途、同时收发、命令/数据独立背压及阻塞时保持稳定、完整写后再读、读地址无重复、全部块覆盖、反向访问、不同块数据差异、seed 更换。独立参考函数校验写数据。注入数据错误与地址别名，检查代码 1–10 的故障、首错冻结、停止新请求及有界收尾。 |
| `telemetry_tb` | 实际解码 UART 8N1 波形，检查 UART 忙时仍保留首错，验证 128-bit 数据/XOR、超过 32-bit 的累计值、最高原生/字节地址编码及 1 秒吞吐窗口。 |
| `address_tb` | 使用生产 26-bit 突发地址参数，选择测试阶段后验证 1 GiB 区域长度、正向首段、最高地址 `0x1ffffff8` 起的反向首段及置换回绕；不是完整 1 GiB 存储器模型仿真。 |

`verilator --lint-only --timing -Wall --top-module ddr_stress_system ...` 返回 0，无 lint 警告。串口解释脚本已验证十六进制秒数、64-bit 计数、KiB/s→MiB/s 转换和故障数据拼接。

Vivado 2022.2 已完成综合、布局布线、bitstream 和最终检查：

| 项目 | 结果 |
| --- | --- |
| WNS / TNS | +0.048 ns / 0.000 ns |
| WHS / THS | +0.001 ns / 0.000 ns |
| WPWS | +0.143 ns |
| Timing | All user specified timing constraints are met |
| Routing errors | 0；25,840 条可布线网络全部完成 |
| Bus skew | 无违例 |
| DRC | 0 错误、4 警告：IP 调试逻辑 3 项 PDCN-1569，1 项 RTSTAT-10；未降低严重等级 |
| 资源（含 MIG/校准/调试 IP） | LUT 10,180；寄存器 12,099；BRAM 25.5 tiles |

报告：`VIVADO/stress_build/timing_summary.rpt`、`drc.rpt`、`route_status.rpt`、`bus_skew.rpt`、`utilization.rpt`。构建日志 `build.log` 结尾为 `BUILD PASSED: bitstream`；控制台记录 `console.log`。工具因用户目录 Tcl Store 写权限使用安装目录回退，不影响本次实现。

### 已生成并校验的 Flash 产物

`VIVADO/scripts/generate_stress_flash.sh` 已成功。从已完成实现读回并核对设置：压缩 true、SPI bus width 8、CONFIGRATE 31.9 MHz，见 `flash_settings.rpt`。

| 文件（均在 VIVADO/stress_build） | 磁盘大小 | 实际 Flash 数据 |
| --- | --- | --- |
| ddr3_stress.bit | 21,054,254 B（20.08 MiB） | — |
| ddr3_stress_primary.mcs | 28,952,152 B | 10,527,112 B |
| ddr3_stress_secondary.mcs | 28,952,152 B | 10,527,112 B |

两颗 Flash 各占地址 `0x00000000–0x00A0A187`；每颗容量 128 MiB，实际合计 20.08 MiB，占总 256 MiB 约 7.84%，容量足够。已逐行校验 Intel HEX 长度/校验和、EOF、连续地址和每颗容量边界，并记录 SHA-256。

校验命令：`python3 TEST/stress/check_artifacts.py`；结果 `ARTIFACT CHECK PASSED`。散列和仿真日志引用保存在 `VIVADO/stress_build/build_manifest.json`，校验日志 `artifact_check.log`，生成日志 `flash_generation.log` / `flash_console.log`。

### 尚未执行的硬件压力测试

本次仅完成逻辑/仿真/实现/镜像生成，**未下载新 bitstream、未烧写新 Flash、未执行 30 分钟或 8–12 小时板级压力测试**。已通过的 HELLOWORLD 硬件结果不能替代本版本的全容量或持续压力结果。下一步按 `VIVADO/stress/README.md` 下载后观察自检、err=0 和 pass/W/R 增长，并保存串口日志。此前插卡 JTAG 返回路径断链仍需在实际下载前确认已恢复。

## 2026-10-25 首次实物压力测试：1 MiB 全 1 模式读回不一致

用户自行烧写/运行后提供串口日志，并补充至 `t=0x69`（105 秒）。保存于 `TEST/stress/hardware/2026-10-25_first_stress_failure_uart.txt`。这是用户提供的实物结果，未由代理连接串口采集；当前仅能确认程序已在板上运行，未独立核对本次 Flash Program/Verify 记录。

- `cal=1`：MIG 校准已完成；不是先前的 CAL_TIMEOUT。
- `code=7`、`ph=1`、`st=3`、`pat=1`：在 1 MiB 自检、全 1 模式的读比较阶段发生 DATA_MISMATCH。
- 首错原生地址与突发字节偏移均为 0。期望 128-bit 全 1，实际高 64-bit 为 `FFFFFFFFFFFFFFFD`、低 64-bit 全 1；XOR 为 `00000000000000020000000000000000`，即逻辑 `app_rd_data[65]` 出现 1→0 差异。尚未据此定位到具体物理 DQ、坏单元或写/读方向。
- 此时累计 W=`0x200000`（2 MiB），R=`0x100160`（1 MiB+352 B，包含首错后在途返回）；引擎已完成前一全 0 模式并进入全 1 模式。最大在途读 `0x1F`=31。
- 后续至 105 秒持续 `st=5`、`err=1`、`pass=0`，W/R 不变，最近一秒吞吐为 0，`drain=1`。DDR 测试发生器处于故障状态、未继续发新请求；UART/计时器继续运行并每 5 秒报告状态。`STAT` 不是 PASS；`cal=1` 仅表示校准；`drain=1` 表示故障收尾条件已满足或有界等待已结束。

用户先说明后续“通过”，补充原始日志后确认这些行仍为上述故障状态，因此尚无后续完整压力轮通过证据。首次错误不能单凭此日志归因于物理链路，也不能排除 RTL/接口、MIG 配置、读写时序或供电/信号完整性问题。当前 1600 MT/s 压力验证未通过；尚未进入 64 MiB、1 GiB 或长期循环。

下一步：保持相同镜像，按 SW5 复位重测 3 次，保存每次 ERROR 行及是否冷启动，用于区分固定地址/固定 bit 与变化性错误。若可重现，再用受控的低速或低并发诊断版本对比；降低 DDR 频率时须同时匹配 MIG UI 频率、UART 分频和计时参数，不能只改输入晶振。此记录更新不修改 RTL、bitstream 或开发板配置。

此前构建 manifest 中 `hardware_stress_test=not performed` 是镜像生成时刻的状态；最新实物验证状态以本节为准。

## 2026-10-25 重复实物首错及单笔读对照准备

用户随后提供 4 次测试片段，4 条 ERROR 均完全一致：ph=1、pat=1、addr=0、expected 全 1、actual 高 64-bit=`FFFFFFFFFFFFFFFD`、xorH=2/xorL=0，故障后 W=`0x200000`、R=`0x100160`、maxrd=`0x1F`。片段之间有重新进入 ph=0/st=0、cal=0 的记录；具体是 SW5 还是断电重启未说明，不据此推定。保存于 `TEST/stress/hardware/2026-10-25_repeated_stress_failure_uart.txt`。

进一步核对当前生成的 MIG RTL：其 native UI 是 byte-major 数据分组。由 `bit=byte_lane*64+burst*8+bit_in_byte`，bit65 对应 byte lane1、第0拍、逻辑 DQ9。采用的连线为 AL15 → 母板 J2/D27 → 子板 J4/G37 → U26/C3。该映射没有证明具体物理元件损坏。返回值中同一 DQ9 后续拍仍为1，因此也不能简单归结为整条线永久短接到地。

原 HELLOWORLD 常量在 DQ9 的8拍全部为0；这说明其通过没有验证该位传1的能力，与本次全1模式失败并不矛盾。固定首错可以来自特定单元、首拍/时序、写读通路、MIG/应用逻辑或实现问题，尚未定因。

用户要求继续完成此前的单笔在途读对照版本。新增 `VIVADO/diagnostic/rtl/ddr3_diag_top.v`，只给共享 `ddr_stress_system` 指定 MAX_READS=1；DDR1600 MT/s、UI200 MHz、UART115200、写队列32和测试模式/地址均不变。新输出独立位于 `VIVADO/diagnostic_build/`，不操作开发板、不覆盖原压力版产物。当前单笔读仿真及参数化 lint 已通过，Vivado 实现与产物校验结果将在完成后补充；该诊断版尚未上板。

### 单笔读诊断首次实现的复位 CDC 约束补充

首次诊断实现的 DDR/应用数据路径未报违例，但应用复位同步器 3 个 PRE 输入的 Recovery 检查为 -0.110 ns（源 por_count_reg[12]，目的 app_reset_sync_reg[0..2]/PRE）。构建验收失败，未作为可下载产物发布。首轮最终报告保存在 `VIVADO/diagnostic_build/first_attempt_timing_summary.rpt`。

已核对 Vivado 2022.2 官方安装源码：`data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv` 的 xpm_cdc_async_rst 与当前 RTL 同为异步断言、目的域多级同步释放；其 `tcl/xpm_cdc_async_rst.tcl` 使用 `set_false_path -through [get_ports -no_traverse src_arst]`。因此为诊断工程新增 `VIVADO/diagnostic/reset_cdc.xdc`，范围严格限定为本同步器 3 个 PRE 输入脚，并检查数量恰为3且 ASYNC_REG 为真。未屏蔽同步器内部 D 路径或其同步输出消费者，也未改 DDR 引脚、工作频率、数据路径或原压力版源码/约束。

新增构建检查要求 Q0→D1、Q1→D2 及 Q2→应用同步复位路径均存在且时序通过，并保存 reset_stage_0/1.rpt、reset_output.rpt、exceptions.rpt。该约束声明不构成对硬件数据错误原因的定位或修复。

### 单笔读诊断最终产物已通过验收

最终 `VIVADO/diagnostic_build/build.log` 为 `BUILD PASSED: bitstream`，`flash_generation.log` 为 `DIAGNOSTIC FLASH GENERATION PASSED`，`artifact_check.log` 为 `DIAGNOSTIC ARTIFACT CHECK PASSED`。编译器参数化 lint 无警告，single_read_tb 已通过所有阶段、两整轮及故障注入，最大在途读数验证为1。

最终实现 WNS=+0.998 ns、TNS=0、WHS=+0.012 ns、THS=0、WPWS=+0.143 ns；DRC 0错误、4项IP警告；25,674 条可布线网络全部完成，routing errors=0；bus skew 无违例。补充复位 CDC 输入声明后，内部同步器 Q0→D1 的 slack=+4.660 ns、Q1→D2=+4.588 ns，输出 Q2→应用同步复位最差 slack=+1.938 ns；均实际计时并通过，报告 reset_stage_0.rpt、reset_stage_1.rpt、reset_output.rpt 已保存。

压缩 SPIx8 / CONFIGRATE31.9 MHz 已从实现属性核对。输出：

- `ddr3_diag.bit`：21,270,488 B。
- `ddr3_diag_primary.mcs` / `ddr3_diag_secondary.mcs`：各 29,249,504 B 文本，实际各 10,635,230 B，地址 0..0x00A247DD。
- 实际 Flash 数据合计 20.29 MiB，占 256 MiB 约 7.92%。逐行 Intel HEX 校验和、连续地址、EOF、容量边界及 SHA-256 已检查。

`build_manifest.json` 保存产物/源码散列，且已核对原压力版已记录的所有源码和产物散列均未变化。此时诊断版硬件数据测试未完成，不能宣称原 bit65 错误已修复。

### 用户授权直接烧写诊断版本

用户明确要求“我已经连接vcu118，完成后直接开始烧写”。只读探测成功：线缆 `localhost:3121/xilinx_tcf/Digilent/210308B43939`，FPGA `xcvu9p_0` / PART=xcvu9p，Flash 算法 `mt25qu01g-spi-x1_x2_x4_x8`。探测日志在 `VIVADO/diagnostic_build/hardware_probe_console.log`。

已再次执行产物校验（artifact_check_before_program.log）并启动专用 `program_diagnostic_flash.tcl`，只选择 diagnostic_build 中配套两份 MCS，ADDRESS_RANGE=use_file，Erase/Program/Verify 启用。烧写日志为 `flash_program_console.log`；本节启动记录不代表操作已完成，最终结果在后文补充。加载间接 SPI 编程辅助 bitstream 前，对原设计 refresh 的一次查询提示 Calibration Failed；这不是 Flash 校验失败，也不能用于判断尚未启动的诊断应用。

### 诊断版双 Flash 烧写和启动最终结果

按用户明确授权完成烧写。`VIVADO/diagnostic_build/flash_program_console.log` 中两颗 QSPI 各有一次 `Erase Operation successful.` 和 `Program/Verify Operation successful.`，随后 `Flash programming completed successfully`、`FLASH PROGRAM AND VERIFY PASSED`、`DIAGNOSTIC FLASH PROGRAM PASSED`，Vivado 进程退出码0。program_hw_cfgmem 阶段耗时 7分48秒；包含工具启动与辅助 bitstream 的整次操作略长。已对实际烧写两份 MCS 再次核对 SHA-256，匹配已验收的诊断产物，未使用原压力版 MCS。

随后只读 SCI 采集就绪，再执行独立 `boot_diagnostic.tcl` 请求从 Flash 启动。启动进程退出码0，`DIAGNOSTIC BOOT REQUEST COMPLETED`。寄存器读回：M[2:0]=001、DONE=1、EOS=1、CRC_ERROR=0，BOOT_STATUS 未见 fallback/CRC/ID 错误，确认 FPGA 配置启动成功。UART 稳定设备路径仍为 CP2105 if01-port0，本次实际设备 `/dev/ttyUSB1`，采集前确认没有其他进程使用；未发送 UART 数据，DTR/RTS 置为false，采集结束已关闭端口。

本次新应用启动结果与此前 data mismatch 不同：串口 t=10秒报 `ERROR code=00000001`（CAL_TIMEOUT），cal=0、ph=0、W=R=0、maxrd=0；未进入 DDR 读写，因此没有实际验证单笔读是否仍复现 bit65 错误。新鲜 MIG 调试信息为 CALIBRATION_FAIL.STATUS=TRUE，Rank0 Stage1 DQS_GATE=FAIL，`Pattern not found on GT_STATUS, all samples were 1. Expecting to sample the preamble. Error found on Rank 0, Byte 0, Nibble 9.`。该 nibble 编号是 MIG 校准报告字段，不等同于此前逻辑 DQ9 的定位。

已询问用户当前转接板和 DDR3 子板是否也连接并供电；在答复前不假定当前连接状态，也不把缺少 preamble 直接归因于转接板损坏或诊断 RTL。Flash 烧写/配置加载已成功，与校准失败是不同结论。

日志：`flash_boot_console.log`、`TEST/stress/build/diagnostic_flash_boot.log`；UART 副本保存在 `TEST/stress/hardware/2026-10-25_diagnostic_flash_boot_uart.txt`。操作结果、选用镜像散列及日志散列见 `VIVADO/diagnostic_build/flash_program_manifest.json`。软件构建 manifest 中硬件未测试的字段是生成时刻状态，最新实物结论以本节为准。

## 2026-10-25 用户后续实测：单笔读在行走0模式仍检出错误

用户新提供日志确认：诊断应用已校准成功（cal=1）并以 maxrd=1 执行实际读写，不再是此前代理启动时的 CAL_TIMEOUT 情况。具体接板/复位操作未说明，不推定修复步骤。原文保存于 `TEST/stress/hardware/2026-10-25_single_read_data_failure_uart.txt`。

该轮已完成 1 MiB 模式0..7的读比较，包括此前失败的全1模式。随后在 pat=8 行走0、原生地址0x19FE0（突发字节基址0x33FC0）出现 DATA_MISMATCH。期望高64位 EFFFFFFFFFFFFFFF、实际 FFFFFFFFFFFFFFFF；低64位均全1。XOR=10000000000000000000000000000000，即 app_rd_data[124] 应为0、实际为1。地址对应突发索引13308，低7位124，与该模式的零位生成规则一致；记录的期望值没有发现地址/模式计算不一致。

按当前 MIG byte-major 格式，bit124映射为 byte lane1、第7拍、DQ12；采用连线 AM13 → 母板J2/G33 → 子板J4/G22 → U26/A7。此前 bit65 为相同 byte lane1 的 DQ9 第0拍，故两类首错均位于 DQS1 对应的高字节组。这是优先检查该组的线索，样本不足以证明 DQS1 或转接板设计有错。

故障后 W=0x900000（9 MiB），R=0x833FD0（8 MiB+212944 B），与8个完整模式加当前模式部分读回相符。仍停于1 MiB阶段，尚未进入64 MiB、1 GiB或持续循环。

结论：32笔读取并发不是出现数据错误的必要条件；单笔读未解决全部数据一致性问题。两版之间还存在FIFO实现、布局布线与复位CDC输入声明差异，不能单凭首错位置变化断定原调度器或某一硬件器件有缺陷。下一步建议的受控诊断设计见 `TEST/DIAGNOSTIC_PLAN.md`；本次仅记录和制定方案，没有改动或烧写新镜像。


## 2026-10-25 同镜像372组定位诊断：工具验证完成

- 新增独立 `VIVADO/probe/` 和 `VIVADO/probe_build/`，保持DDR1600 MT/s、UI200 MHz、固定32项期望FIFO。固定写入反复读取24组、起始位置/正反序24组，以及行走0/地址相关PRNG/全1各108组运行时负载组合。
- 两级读回比较流水在阶段结束前排空；数据差异继续计数，输出每组前4个原始样本和128位翻转统计；协议、校准、复位和无进展超时仍停止。
- 正常全配置及664次注入翻转、握手背压、队列上限/高并发、故障退出与UART序列化仿真通过；解析器检验实际覆盖和配置，不以cal=1或状态输出代替PASS。
- 首轮因测试编号组合除法造成严重时序失败，未下载；改为寄存的常量配置表并分级比较。最终372组实现WNS +0.330 ns、WHS +0.015 ns、WPWS +0.143 ns，DRC 0错误4项IP警告，30081条可布线网络全部完成。没有放宽时钟或数据路径时序约束。
- bitstream及配套SPIx8双MCS均已生成并完成校验；实际Flash数据合计21,816,820 B（约20.81 MiB），小于两颗各128 MiB容量。此前stress/单笔读源文件与产物散列保持不变。
- **下载前只读检查**：当前运行镜像UART `cal=0,W=R=0`；MIG为DQS Gate失败、Rank0 Byte0 Nibble9、未发现前导信号。裕量阶段未执行，0值无有效眼宽含义。证据 `TEST/probe/hardware/2026-10-25_before_uart.txt` 和 `2026-10-25_before_margins.txt`。这是下载前状态，不是新增372组测试实物结果。
- 用户确认本次目前只接VCU118，未接DDR链路。新372组镜像已成功JTAG下载并报告原因码1（校准等待超时），W/R=0、数据错误数0，符合当前无DDR条件；尚未发生DDR数据比较。两颗Flash均已按用户授权擦除、编程并读回校验成功（7分59秒）。等待用户断电接好DDR链路后上电；串口接收已提前打开。


## 2026-10-25 接好DDR后从Flash运行372组：完成但数据失败

双Flash已编程校验成功，用户确认断电接链路后重新上电。完整CuteCom日志已存档并严格解析：372组配置、命令数、数据数、返回数、前4错误样本数和累计错误总数相符；无致命故障。总错误突发124738（0x1E742），完成编号371（0x173）。结束后重复类型5摘要，不再发DDR测试请求。

固定地址反复读240000笔和顺序切换720000笔均0错；1 MiB负载对照21233664笔中124738错。读间隔0/16/64UI周期分别124644/47/47错；主要DQ11/9/10、第6拍和byte1，但byte0亦有错。job60复现0x19FE0处bit124差异且读并发仅1。错误明显与访问密度相关，但尚不足以区分RTL/MIG交互与PHY/板级/供电/存储器，也不证明转接板单独合格或有错。插板后JTAG扫描无FPGA，未获取有效校准裕量。

实测详表与证据：`TEST/probe/hardware/2026-10-25_cutecom_uart.md`、同名JSON及TXT，原始含开头噪声的快照为`2026-10-25_cutecom_raw.bin`。代理早前采集运行在job129附近串口断开，未与用户提供的这一完整运行合并。我方后台接收已停止，不占用用户串口。


## 2026-10-25 成对读取与800/1600对照文件：仅工具验证、未上板

按用户要求本次只生成烧写文件，没有访问/下载/烧写开发板。独立paired工程每个1 MiB组只写一次，密集/稀疏交替读取11遍；全1/行走0/地址PRNG × 写队列1/32 × 读上限1/4/32，共18组198遍。片内UltraRAM保存完整128位上一遍读值，逐地址记录错误与相邻遍变化次数；非零48地址计数包和组累计摘要可检查日志缺包。两版参考250 MHz不变，UI200/100 MHz，UART115200，稀疏额外等待均320 ns。

- 两种UI下正常与瞬态/固定错误测试（累计702次预期错误返回）、逐地址变化及尾包、FIFO/背压、比较流水排空、校准/复位/协议/超时故障和UART序列化仿真通过，解析器覆盖与计数检查通过。没有包含DDR3 PHY或板级模拟模型。
- 1600：WNS +0.114 ns、WHS +0.002 ns，DRC 0错误4项原IP警告；双MCS实际数据22,072,008 B，约21.05 MiB。
- 800：MIG tCK2500 ps、CL6/CWL5被工具接受，实际UI周期10 ns；WNS +1.838 ns、WHS +0.011 ns，DRC 0错误4项原IP警告；实际数据21,702,712 B，约20.70 MiB。
- 两版源码/测试/产物散列、MCS长度/校验和/连续地址/容量及旧版本镜像散列完成检查。两颗每颗128 MiB，容量足够。UltraRAM性能建议仍保留在日志，最终数字时序通过，没有增加数据路径时序例外。
- 文件位于VIVADO/paired_1600_build和paired_800_build，前缀ddr3_pair_1600和ddr3_pair_800。每次必须选择同一速率的primary/secondary两份。说明与日志解析见VIVADO/paired/README.md；板级结果待用户后续烧写采集，不将工具通过视为硬件通过。


## 2026-10-25 800 MT/s paired 双 Flash 烧写完成

按用户授权执行 program_paired_800_flash.tcl，锁定线缆 210308B43939、xcvu9p_0，使用 paired_800_build 中同版 primary/secondary 两份 MCS。两颗均擦除成功、Program/Verify 成功，工具明确报告 FLASH PROGRAM AND VERIFY PASSED 和 PAIRED 800 FLASH PROGRAM PASSED，退出码 0。program_hw_cfgmem 耗时 476 秒，20:27:05 退出。烧写前后 MCS SHA256 与 build_manifest.json 相符。详细记录见 VIVADO/paired_800_build/flash_program_manifest.json。未请求启动、未新增 DDR 读写通过结论。

随后用户要求检查 /home/wenhan/cutecom.log。文件修改时间仍为 19:38，278693 字节，SHA256 为 6f522aec43d8f6192760bb987940982bb8f4dfd3b4fbbd7c1df93907e322669c，与此前存档 TEST/probe/hardware/2026-10-25_cutecom_raw.bin 完全相同；这仍是 372 组旧日志，结束编号 0x173、错误突发 0x1E742=124738，无 PAIR 新镜像头，不能用作 800 MT/s 结果。

用户提供 U26 丝印 IZP17 / D9ZWN / IP7F。美光官网公开 FBGA 解码接口返回 D9ZWN=MT41K512M16VRP-107 IT:P，原始 JSON 保存在 TEST/paired/build/schematic_review/micron_D9ZWN_decoder.json。实际完整型号与当前 MIG 的 MT41K512M16HA-125 不同；不得将其完全兼容性或已有错误根因视作已确认。-107 为 1866 MT/s 档（CK 约933 MHz），不能把资料目录中 Alliance -12 的 1600 MT/s 规格当成这颗实物的规格。原理图第4页和 BOM 第5页只有通用 MT41K512M16 标注，未给速度后缀。


## 2026-10-25 用户提供800 MT/s paired实测日志

来源为本次用户粘贴附件，原样存档 TEST/paired/hardware/2026-10-25_800_user_uart.txt，解析报告与逐地址JSON同名。PAIR头UI=100 MHz、gap=32周期，对应800 MT/s；18组198遍覆盖完整，无日志格式错误、无致命故障，DONE末编号0xC5，错误0x138=312。总读取12,976,128个128位突发，数据未通过。

密集读取：312/7,077,888错突发（约44.08 ppm）；稀疏读取：0/5,898,240。全1和行走0均0错，全部错误在地址PRNG；读上限1为0/4,325,376，4为248/4,325,376，32为64/4,325,376，不呈并发越大错误必然越多的单调关系。写队列1共123错、32共189错。

312个错突发均为DQ9单bit翻转，UI bit73（beat1）277次、bit121（beat7）35次。前4样本/遍共94份，全部为1读成0；日志未保存所有错误的完整期望/实际值，不将样本方向泛化为全部312次。错误/变化地址按组累计180项、跨组合并128个不同字节基地址，180项全部是间歇性错误、返回值会变化；没有11遍恒错且值不变的地址。相邻遍返回值变化共521次，含错误恢复的变化，不能当作521个新错。

每组11遍之间没有重写，密集错而稀疏全部正确，更支持读请求密度/模式/并发相关的读取路径或稳定性问题，不支持把现象简单解释成固定写错且一直读回同一错值。不能单凭此排除内容保持、应用逻辑、MIG参数、物理实现，也不能确定转接板或某处焊点损坏。优先核对实物MT41K512M16VRP-107 IT:P与当前HA-125的器件组织、刷新/时序、引脚兼容性，再采集校准成功时DQ9/DQS1的读窗口。当前800 paired与此前1600 probe测试方案不同，不能以312/124738的比值声称降频改善倍数；需要同一paired设计的1600日志做对应比较。


## 2026-10-25 第1项颗粒审计及修订文件完成

实物D9ZWN对应MT41K512M16VRP-107 IT:P，TwinDie两个4Gb x8组成单rank x16、1GiB。50根DDR信号球位与实际TwinDie规格书匹配（静态资料核对）。独立VIVADO/vrp/使用运行点专用CSV；800/1600均已生成独立双MCS并通过TEST/part_audit/check_vrp.py验收。保持paired应用RTL、引脚和参考250MHz；内部组件建模及部分等待参数改变，不能将后续可能的改善直接归因于唯一配置因素。旧镜像按清单保持散列。

| 800 MT/s | +1.626 ns | +0.013 ns | 21,649,004 B（20.65 MiB） |
| 1600 MT/s | +0.310 ns | +0.010 ns | 22,276,628 B（21.24 MiB） |

两版DRC均0错误4项IP警告。详细参数对照、模式寄存器编码、温度/刷新适用范围、769MT/s仅IP生成的探索边界、文件及SHA记录见TEST/part_audit/README.md与VIVADO/vrp_<rate>_build/build_manifest.json。未访问硬件、未烧写修订版；下一次优先复测800。


## 2026-10-25 VRP参数修订800 MT/s双Flash烧写成功

按用户“帮我烧写800的”授权，锁定线缆210308B43939、xcvu9p_0，使用VIVADO/vrp_800_build/ddr3_vrp_pair_800_primary.mcs与secondary.mcs。烧写前核对build_manifest.json内全部产物和源码散列；烧写后两份MCS散列仍与验收及preflight记录一致，未使用旧paired或1600文件。

两颗QSPI均擦除成功、Program/Verify成功；Vivado报告Flash programming completed successfully、FLASH PROGRAM AND VERIFY PASSED、VRP 800 FLASH PROGRAM PASSED，退出码0。program_hw_cfgmem耗时476秒，工具于23:16:30退出。JEDEC均为20/bb/21。完整日志和烧写清单位于VIVADO/vrp_800_build/flash_program_console.log及flash_program_manifest.json。

未执行boot操作、未采集本修订版DDR数据。烧写辅助逻辑仍在FPGA SRAM中，需从Flash重启后再测试。烧写前refresh旧设计的Calibration Failed提示不属于新镜像测试结果。1600修订文件未烧写。下一步保持SW16既有Flash启动设置，断电后确认DDR链路连接再上电，用新日志采集115200 8N1完整输出，避免与此前312次错误日志混合。


## 2026-10-25 VRP修订800 MT/s用户实测：仍失败472次

用户在VRP参数修订版双Flash烧写校验成功后提供本次串口附件。UART头确认UI100MHz、稀疏间隔32周期、18组198遍；头本身不包含镜像散列，因此版本关联依据烧写记录和本次用户反馈顺序。

两次完整性检查均通过，读取总数均12,976,128个128位突发，无致命故障。旧版312错，新版472错，均数据失败。新版DONE=0x1D8，末编号0xC5；后续重复摘要为结束状态。

| 条件 | 原HA配置800 | VRP修订800 | 两次各自读取突发数 |
| --- | --- | --- | --- |
| 密集读 | 312 | 472 | 7,077,888 |
| 稀疏读 | 0 | 0 | 5,898,240 |
| 读上限1 | 0 | 0 | 4,325,376 |
| 读上限4 | 248 | 358 | 4,325,376 |
| 读上限32 | 64 | 114 | 4,325,376 |

新版全部错误仍在地址PRNG，全部在高字节/DQS1组：DQ9 470次，DQ8 2次。突发beat1 350次、beat7 122次；UI bit72=2、bit73=348、bit121=122。全1和行走0各4,325,376次读取均0错。

新版逐组间歇错误地址合计301项（跨组合并201个地址），全部存在实际值变化；没有11遍恒错且实际值不变的地址。相邻遍变化787次包含错误恢复，不能当作787个新错。日志仅保存每遍前4个样本，共95份，样本均1→0；不能由此推断未保存完整样本的全部错误方向。

结论：参数修订未消除错误，现象仍为PRNG、密集读取、多笔在途相关，以DQ9为主且出现少量DQ8。单次312与472的差异不能证明参数修订导致恶化；两次校准、布局布线及环境/连接状态均未完全隔离，也不证明实际颗粒匹配参数与故障毫无关系。不能将结果归因于转接板或某个焊点。

下一步可先在相同修订镜像和连接下做3次独立上电，保存完整日志确认分布；并获取校准成功时DQ9/DQ8/DQS1的读窗口，若接板JTAG仍不可用则先解决调试链路。全容量地址唯一性验证尚待按TODO第2项实施。


## 2026-10-25 VRP修订800第2次上电：317次错误


用户明确说明重新上电，原始附件存为2026-10-25_vrp800_powercycle2_uart.txt。18组198遍完整，UI100MHz，读数与上次一致，无致命故障、无格式错误，DONE错误0x13D=317。DQ9翻转316次、DQ8 1次；全部在DQS1高字节组，beat1 220次、beat7 97次。

| 条件 | 第1次 | 第2次 | 每次各自读取数 |
| --- | --- | --- | --- |
| 密集读错误 | 472 | 317 | 7,077,888 |
| 稀疏读错误 | 0 | 0 | 5,898,240 |
| 读上限1错误 | 0 | 0 | 4,325,376 |
| 读上限4错误 | 358 | 208 | 4,325,376 |
| 读上限32错误 | 114 | 109 | 4,325,376 |

错误仍仅出现在PRNG、密集读及上限4/32；全1、行走0通过。按组合计间歇地址234项，合并165个不同字节基地址，其中125个曾在上轮出现；同组同地址重合170项。没有11遍稳定错误且值不变的地址；相邻遍变化540次包含错误恢复。

同镜像472→317表明两次独立上电的错误数量有波动，主要错误位和触发条件则稳定复现。不能把此前不同配置的312→472单独归因于参数修订，也不能据此确定上电变化来自校准、温度或接触中的哪一个因素。当前完成2次同修订镜像运行，建议再做1次相同条件的独立上电以完成3次重复；随后获取有效读窗口/调试证据。


## 2026-10-25 VRP修订800第3轮：263次错误


本份附件接续前一轮要求再独立上电的对话提供；文件本身可确认完整新运行，不能独立证明物理断电过程。原样存档2026-10-25_vrp800_run3_uart.txt。18组198遍完整，UI100MHz、无致命故障和格式错误，末编号0xC5，DONE错误0x107=263。

| 项目 | 第1轮 | 第2轮 | 第3轮 |
| --- | --- | --- | --- |
| 错误突发总数 | 472 | 317 | 263 |
| DQ9翻转 | 470 | 316 | 263 |
| DQ8翻转 | 2 | 1 | 0 |
| 稀疏读错误 | 0 | 0 | 0 |
| 读上限1错误 | 0 | 0 | 0 |
| 读上限4错误 | 358 | 208 | 169 |
| 读上限32错误 | 114 | 109 | 94 |

三轮全部错误仅出现在地址PRNG的密集读，位于DQS1高字节组。累计1,052个错突发/21,233,664个密集读突发；稀疏读累计0/17,694,720，读上限1累计0/12,976,128。全1和行走0三轮都无错。

第3轮beat1翻转188次、beat7 75次；137个不同字节基地址有错，三轮共有98个地址出现过错误，但各组内部均无11遍恒错且实际值不变的地址。这是数据模式/负载相关错误可复现的证据，不能据此判定固定坏单元或转接板某处损坏。每组写一次且稀疏读正确，支持优先检查读取稳定性、DQ9/DQS1裕量及应用/MIG交互。

三轮计数依次下降不足以证明预热改善、某个因素单调变化或多运行即可消除错误。当前可结束这轮重复日志收集，优先获取校准成功时DQ9/DQ8/DQS1读窗口；若接板JTAG返回链路仍不可用，需先恢复调试能力。全容量地址唯一性测试仍待按TODO第2项实施。


## 后续重试附件：436次错误

用户说明又重试数次；本附件只有1个PAIR头和1轮完整198遍运行，不能将重复DONE当作多轮实测。DONE=0x1B4=436，DQ9翻转435、DQ8 1，均在DQS1高字节。无致命故障或格式错误。

仍只有PRNG密集读出错；读上限4共332错、32共104错，上限1为0/4,325,376；稀疏读0/5,898,240。全1与行走0均无错。拍分布beat1=342、beat3=1、beat7=93，比前三份新增1次beat3翻转。各组均无11遍恒错且实际值不变的地址。

现有4份完整修订800日志总错数依次472、317、263、436，合计1488；DQ9共1484、DQ8共4。错误数量并不持续下降，不支持“逐渐预热后会自然稳定”的判断；没有温度或校准窗口数据，仍不能据此排除温度影响。错误负载/模式及主要DQ持续复现，应继续定位读窗口与调试链路，而非将更多同类重试视作修复措施。

## 2026-10-26：第一项低负载数据位测试（DPIN v1）

用户暂停1600 MT/s，先验证基本数据位功能。独立800镜像覆盖32地址×260模式、8320写/读，单笔读和1 us额外读写间隔。10项应用层仿真、UART、解码器及MCS校验通过；WNS +1.793 ns、WHS +0.019 ns、DRC 0错误/4厂商警告。MIG和55个板级IO与已核实VRP800一致，旧实验散列未变。旧RTL数据位版双Flash已烧写校验成功（7分51秒）；当前无该镜像DDR实测数据。详细结果与后续状态见[本项记录](databit/RESULTS.md)。

## 2026-10-26：独立Block Design工程vivado2（文件生成完成）

按用户要求与VIVADO并列创建vivado2，实际BD含时钟/复位、测试引擎、UART、单事务原生格式→AXI及MIG五个块，图形导出已检查。工具限制要求BD中的MIG启用AXI；测试引擎、模式、地址及额外1 us访问间隔保留。21项应用/桥接/复位仿真及UART/解码检查通过；最终WNS +1.475 ns、WHS +0.011 ns、DRC 0错误/4厂商警告。55个IO和标准与原800版一致，双MCS校验通过，共20.45 MiB。

用户明确本轮只生成Flash文件，未烧写BD镜像，也无新硬件DDR实测结果。详见[vivado2记录](../vivado2/RESULTS.md)及[清单](../vivado2/build/build_manifest.json)。

## 2026-10-26：vivado2 BD版双Flash烧写成功

用户在文件交付后明确授权烧写。已复核产物和两份MCS SHA256，锁定Digilent 210308B43939 / xcvu9p，执行两颗MT25QU01G擦除、写入及读回校验，全部成功；program_hw_cfgmem耗时7分51秒，进程退出0，完成后文件散列未变。记录见[vivado2烧写清单](../vivado2/build/flash_program_manifest.json)。未自动启动新镜像；仍需完全断电、接回DDR并采集UART。尚无新BD版DDR实测数据。

## 2026-10-26：BD数据位实测第1份完整通过

已原样归档用户粘贴的UART文本并用DPIN严格解码器校验：422条记录完整，32地址、260模式，8320写/8320读，错突发0、位翻转0，全部16个DQ对应的8拍模式均未检出错误（含DQ9），无致命码或畸形记录。标记低负载数据位功能通过；不是整容量、DM或物理逐针身份通过，也不能证明历史密集读故障消失。下一项为DM掩码，然后地址别名及全容量。证据见[报告](../vivado2/tests/hardware/2026-10-26_bd_dpin_run1.md)。


## 2026-10-27：工程目录清理

用户明确要求删除整个旧 `VIVADO` 目录、完整保留 `vivado2`。已删除旧目录（3304 个文件，逻辑大小 3,054,061,684 字节，磁盘占用约 2.9 GiB）；未改动 `vivado2` 中任何内容，删除前后 951 个文件/目录的类型、大小、修改时间清单一致，25 个关键源码/配置/约束/脚本及工程/BD/bitstream/双 MCS 文件 SHA256 一致。

根 README 已更新为当前 BD 工程入口。EDA、TEST 与实测数据保留；历史文档的 `VIVADO/...` 路径对应已删除的旧工程，历史脚本若引用该目录不再可直接运行。清理前 README 与文件清单见 `TEST/history/2026-10-27_legacy_root_readme.md`、`TEST/history/2026-10-27_vivado_cleanup.json`。本次仅清理目录，未重建或烧写，未产生新的 DDR 实测结论；下一项仍为 DM 掩码测试。
