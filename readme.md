# VCU118 FMC DDR3 MIG 裸机验证工程

## 项目简介

本工程在 VCU118 上通过 **J2 FMC_HPC1 → 无源信号重排转接板 → FMC DDR3 子板 J4** 接入 x16 DDR3，由 FPGA 内部 RTL 状态机完成最小读写回环：向 DDR 写入 `HELLOWORLD`，读回后逐字节通过串口输出，并报告 `PASS` 或 `FAIL`。

顶层采用 **Verilog RTL 直接例化 MIG IP**，没有手工搭建的 Block Design、应用 CPU、AXI interconnect、Boot ROM 或 C 程序，也不依赖 Vitis、C910 或操作系统。MIG 自带的内部校准与调试模块由厂商 IP 生成，不需要用户编写处理器软件。

本工程参考 `/home/wenhan/PROJECTS/C910_SOC_VCU118_FMC_DDR3_MIG` 的硬件连接和构建经验，但已将采用的 RTL、MIG 配置、引脚约束及脚本保存到本目录，正常构建无需读取参考工程。

## 当前任务与进度

**当前状态：工程构建、应用逻辑仿真、双 QSPI Flash 烧写校验及调整启动模式后的 FPGA 上电配置已通过；接入 DDR3 链路后仍出现 `DDR TIMEOUT`，GPIO LED 7 不亮，尚未完成 MIG 校准和实际 DDR 读写验证。**

| 状态 | 任务及结果 |
| --- | --- |
| 已完成 | 最小 RTL 系统：MIG 原生接口、HELLOWORLD 单突发读写、UART TX、校准指示 LED 7。 |
| 已完成（静态） | 迁移并检查 50 根 DDR 信号，引脚与本工程保存的转接板映射一致。 |
| 已完成（工具验证） | Vivado 2022.2 综合、布局布线及 bitstream 生成；WNS=+1.650 ns、WHS=+0.009 ns，DRC 0 错误、4 个 IP 相关警告。 |
| 已完成（仿真） | Verilator 用户接口级测试，覆盖握手背压、读回错误、超时和复位重测；未包含 DDR3 PHY 或外部存储器时序模型。 |
| 已完成（硬件） | 两颗 QSPI Flash 的擦除、写入和读回校验；本次烧入未压缩版本，共耗时 28 分 11 秒。 |
| 已完成（硬件） | 调整 SW16 并断电重启后，JTAG 读回 M[2:0]=001、DONE=1、EOS=1，未见配置 CRC 错误。 |
| 已确认（用户设置） | 母板 VADJ=1.5 V、Si570_0=250 MHz；用户确认已配置为掉电后仍有效的上电设置。 |
| 已确认（现象） | 接入转接板和 DDR3 子板并断电重启后，串口仍 TIMEOUT、LED 7 不亮。 |
| 已定位（调试限制） | 转接板 H2 接地而 TDI/TDO 未闭合，会断开母板 JTAG 链路；接板后暂时无法读取新的 MIG 校准状态。 |
| 待完成 | 明确子板实物测量点，实测 VDD/VDDQ、VTT/VREF、RESET#，核对供电选择、复位和实物连线。 |
| 待完成 | MIG 校准、HELLOWORLD 实际读写、全地址测试及持续压力测试。 |

完整结果、时间顺序和日志位置见 [验证记录](TEST/RESULTS.md)。**FPGA 配置加载成功、MIG 校准成功、DDR 读写通过是三个不同的验证结论。** 1600 MT/s 仍为配置目标，尚不能标为硬件已验证速率。

## 硬件与时钟

| 项目 | 当前采用的配置 |
| --- | --- |
| 母板 / FPGA | VCU118，`xcvu9p-flga2104-2L-e`。 |
| DDR3 连接 | 母板 J2 FMC_HPC1，经专用重排转接板，接子板 J4；不能用直通 FMC 线序替代。 |
| DDR3 颗粒 | MIG 配置为 `MT41K512M16HA-125`，x16。 |
| DDR 引脚 | SLR1、同一 I/O 列的 Bank 66/67，共 50 根信号。 |
| I/O 电压 | VADJ/VCCO 1.5 V；DDR 使用 SSTL15 系列标准，FPGA 内部 VREF 为 0.75 V。 |
| MIG 参考时钟 | 板载 Si570_0 / U18，250 MHz，J8 选择 U18，经 AW23/AW22 差分输入 FPGA。 |
| 参考时钟路径 | `IBUFDS → BUFG → MIG`，不经过转接板，不增加 Clock Wizard。 |
| DDR 工作时钟 | MIG 配置为 800 MHz，双沿对应 1600 MT/s 目标速率。 |
| 用户时钟 | MIG 输出 200 MHz，驱动读写状态机和 UART。 |
| 复位 | SW5 CPU_RESET，按下为高、松开为低；RTL 同步释放并延长 MIG 复位。 |
| 校准指示 | `init_calib_complete → GPIO_LED7`，BA37 / LVCMOS12，高电平点亮。 |
| UART TX | BB21，连接板载 CP2105 的 FPGA SCI 通道。 |

GPIO LED 7 是板上 **“GPIO LEDs”灯组**中的 LED 7，对应原理图元件 **DS18**；校准完成后常亮，不是心跳灯，也不表示读写比较已经通过。

母板时钟与电压的上电设置已由用户确认保存。本工程仍要求每次硬件变更后核对实际状态；**母板 VADJ 的设置不能代替子板端供电、跳线及复位电压的实测**。历史 AXVU13P / 板载 DDR4 方案不作为本工程接线依据。

## 最小系统与测试行为

```text
Si570_0 250 MHz -> IBUFDS -> BUFG -> DDR3 MIG <-> x16 DDR3
                                      |
                                      +-> UI 200 MHz -> ddr_hello -> uart_tx -> CP2105 SCI
                                      |
                                      +-> init_calib_complete -> GPIO LED 7 / DS18
```

1. 用户时钟域复位释放后，串口输出 `DDR WAIT CAL`，等待 MIG 校准完成。
2. 在 MIG 原生地址 0 写入一个 x16 BL8 突发，即 16 字节。前 10 字节为 `HELLOWORLD`，其余 6 字节为零。
3. 先提交写数据，再提交写命令；各自遵守 ready/valid 握手规则。
4. 读回同一地址，将 128-bit 返回数据保存到寄存器，比较全部 16 字节。
5. 串口输出读回寄存器中的前 10 字节，随后输出 `PASS` 或 `FAIL`，不直接用写入常量代替读回值。

预期成功输出如下；**这是预期结果，尚未在接好 DDR3 的实物链路上取得通过记录**：

```text
DDR WAIT CAL
DDR READ: HELLOWORLD
PASS
```

等待校准、写握手、读命令或读返回的单阶段超时约为 10 秒，超时统一输出 `DDR TIMEOUT` 并停止。当前 UART 消息未区分超时阶段；LED 7 持续熄灭表明尚无校准完成指示，进一步定位应结合 MIG 调试信息和实物测量。

测试每次上电或复位只执行一次。按下并松开 **SW5 CPU_RESET** 可重新校准并重测。该测试覆盖 DDR 起始 16 字节，不验证全容量或长时间稳定性。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `VIVADO/rtl/` | 顶层 `ddr3_loopback_top.v`、读写状态机 `ddr_hello.v`、串口发送器 `uart_tx.v`。 |
| `VIVADO/ip/` | 可复现的 MIG 配置 `ddr3_config.tcl`。 |
| `VIVADO/constraints/` | VCU118 DDR3、时钟、复位、UART 和 LED 引脚约束。 |
| `VIVADO/scripts/` | 工程构建、Flash 镜像生成、硬件烧录及只读检查脚本。 |
| `VIVADO/build/` | 生成的 Vivado 工程、bitstream、MCS、报告及日志；不作为源文件维护。 |
| `EDA/` | 采用的转接板映射、逐针表及硬件说明，含已确认的 JTAG 断链限制。 |
| `TEST/` | 用户接口级测试台、仿真/引脚检查脚本和验证记录。 |
| `TEST/build/` | 仿真与调试中间产物。 |

详细操作见 [Vivado 工程说明](VIVADO/README.md)，硬件映射见 [EDA 说明](EDA/README.md)、[逐针表](EDA/connections.md) 和 [pinmap.json](EDA/pinmap.json)。

## 开发环境与构建

当前验证环境为 **Linux Vivado 2022.2**，默认安装目录：

```text
/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2
```

在本工程根目录执行：

```bash
# 创建工程、生成 MIG 输出文件
VIVADO/scripts/build.sh prepare

# 综合、实现、生成 bitstream，并检查时序和 DRC
VIVADO/scripts/build.sh bitstream 2

# 应用逻辑功能仿真（依赖 Verilator 和 C++ 编译器）
TEST/run_sim.sh

# 检查 DDR 引脚与采用的转接板映射是否一致
python3 TEST/check_pinmap.py
```

构建也支持 `synth` 和 `impl` 阶段；并行任务数默认 2，可改为 1。其他安装位置可通过 `VIVADO_ROOT` 或 `VIVADO_BIN` 指定。

主要输出：

| 文件 | 用途 |
| --- | --- |
| `VIVADO/build/project/ddr3_loopback.xpr` | 可在 Vivado GUI 中打开的工程。 |
| `VIVADO/build/ddr3_loopback.bit` | 常规 JTAG 下载文件。 |
| `VIVADO/build/timing_summary.rpt` | 时序报告。 |
| `VIVADO/build/drc.rpt` | DRC 报告。 |
| `VIVADO/build/build_manifest.json` | 本次构建文件散列及产物信息。 |

本次实现 WNS=+1.650 ns、WHS=+0.009 ns、WPWS=+0.143 ns，routing errors=0，bus skew 无违例。DRC 的 4 项警告为 MIG 调试逻辑的 3 项 LUT 方程提示和 1 项无可布线负载提示，未降低检查严重等级。工具验证不替代板级电气和时序验证。

## 串口与日常运行

串口参数：**115200 baud、8 数据位、无校验、1 停止位、关闭流控**。

本机此次识别的 FPGA SCI 通道为 `/dev/ttyUSB2`，稳定设备路径为：

```text
/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_012F60DB-if01-port0
```

重新插拔后 `ttyUSB` 编号可能变化，应优先使用 `if01-port0` 设备路径。先打开终端，再上电或按 SW5，以免错过只打印一次的结果。

若使用 JTAG 临时下载，在 Hardware Manager 选择 `ddr3_loopback.bit`。若已使用本次 Flash 镜像，则正常上电即可加载，**接好 DDR 子板后无需因连接变化而重新烧写同一镜像**。连接或拆卸转接板和子板应在断电状态下进行。

## Flash 固化与自动启动

VCU118 Rev2.0 的两颗 MT25QU01G QSPI Flash 各为 **1 Gbit / 128 MiB**，合计 **256 MiB**。本工程使用 `SPIx8`，两颗 4-bit QSPI 并联组成配置通道；`primary.mcs` 和 `secondary.mcs` 是镜像拆分后的两部分，均须烧写。

### 镜像生成

完成实现后，在根目录执行：

```bash
VIVADO/scripts/generate_flash.sh
```

脚本复用 `impl_1`，生成 SPIx8 bitstream 及两份 MCS，不执行硬件烧录。CCLK 配置速率采用器件支持的 **31.9 MHz**；它只用于 FPGA 配置加载，与 DDR 工作时钟独立。

| 版本 | bitstream | 两份烧录文件 | 状态 |
| --- | --- | --- | --- |
| 未压缩 | `ddr3_flash.bit` | `ddr3_flash_primary.mcs`、`ddr3_flash_secondary.mcs` | 已生成、已校验、已烧入开发板。 |
| 压缩 | `ddr3_flash_compressed.bit` | `ddr3_flash_compressed_primary.mcs`、`ddr3_flash_compressed_secondary.mcs` | 已生成并校验，尚未用于本次硬件烧写。 |

以上文件均位于 `VIVADO/build/`。未压缩版实际 Flash 数据合计约 **76.45 MiB**，占总容量约 **29.86%**；压缩 bitstream 约 **20.20 MiB**。MCS 是文本格式，其磁盘文件大小不等于 Flash 数据占用。

压缩镜像由 `VIVADO/scripts/generate_compressed_flash.tcl` 生成，开启 `BITSTREAM.GENERAL.COMPRESS`，复用相同实现。已有生成日志为 `VIVADO/build/compressed_flash_generation.log`，散列及地址记录见 `compressed_flash_manifest.json`。

### 烧录与启动模式

在 Hardware Manager 添加 Configuration Memory Device，选择：

```text
mt25qu01g-spi-x1_x2_x4_x8
```

将同一版本的 primary / secondary 文件分别填入 **Configuration file / Configuration file 2**，执行 Erase、Program、Verify。不要混用压缩与未压缩版本的两份文件。对应文件区域的旧镜像会被覆盖。

烧录完成后断电，将 **SW16 第 2、3、4 位设置为 OFF、OFF、ON**，即 `M[2:0]=001`（Master SPI）；第 1 位保持原状，再重新上电。

本次两颗 Flash 均返回 `Program/Verify Operation successful`，完整烧写校验耗时 **28 分 11 秒**。随后启动尝试在未调整启动模式时超时；调整 SW16 并断电重启后，已读到 DONE=1、EOS=1。**原烧写脚本的最终非零退出来自后续启动尝试，不是 Flash 写入校验失败。** 详细记录见 `VIVADO/build/flash_program_console.log` 和 [验证记录](TEST/RESULTS.md)。

## 当前调试问题与下一步

### DDR 校准仍未完成

接入链路并断电重启后，用户观察到 `DDR TIMEOUT`，GPIO LED 7 仍熄灭。当前重点是确认子板端电源、复位和实物连接；尚没有证据将问题归因于 RTL 读写握手或某一具体 DDR 引脚。

需要区分两个阶段的记录：

- **未接转接板和子板时**：曾读到 MIG 在 DQS_GATE 阶段失败，这是缺少 DDR 返回信号时的记录。
- **接好链路后**：JTAG 链路断开，尚未取得新的 MIG 校准错误，不能直接沿用上述 DQS_GATE 结论。

下一步核对及实测项：

| 项目 | 目标或检查内容 |
| --- | --- |
| 子板 VDD / VDDQ | 约 1.5 V；应确认实际送到 DRAM 的电压。 |
| 子板 VTT / VREF | 约 0.75 V。 |
| DDR RESET# | 核对上电复位过程及稳定后的电平。 |
| 子板供电选择 | 核对本地稳压器与外部供电的选择跳线，不并联两个电源来源。 |
| 实物信号链 | 核对重排转接板、连接器方向和 50 根 DDR 信号的连续性。 |

测量位置需结合子板原理图及实物丝印确认；当前尚未取得以上实测值。参考子板还存在 RN28 的 RESET# 到 VTT 终端支路问题，任何下拉或终端修改都需先核对实物，不能直接整颗拆除 RN28。

### 插卡后 JTAG 断链

当前转接板将母板侧 **H2 / PRSNT_M2C 接地**，但未闭合 TDI/TDO。VCU118 的 U132 旁路开关在检测插卡后断开，JTAG 链需要经过插卡返回，所以接板后扫描不到 FPGA 的现象可以由此解释；这不等同于 Flash 镜像失效。

后续可在断电并核对针号后，于转接板**母板侧同一连接器的 D30（TDI）与 D31（TDO）之间做本地旁路连接**，恢复未使用的插卡 JTAG 通路。不要将此建议误用为子板侧同号针脚短接。此修订尚未实施，也不能直接替代 DDR 校准问题的定位。详见 [EDA 说明](EDA/README.md)。

## 参考资料

| 路径 | 说明 |
| --- | --- |
| `/home/wenhan/PROJECTS/C910_SOC_VCU118_FMC_DDR3_MIG` | 参考工程，提供原硬件连接、约束及构建经验。 |
| `/home/wenhan/PROJECTS/ARCHIVE/DATASHEET/VCU118` | VCU118 原理图、官方约束及系统控制器资料。 |
| `/home/wenhan/PROJECTS/ARCHIVE/DATASHEET/FMC_DDR3` | DDR3 子板原理图和存储器资料。 |

本工程的实际采用文件以当前 `VIVADO/`、`EDA/` 内容为准，验证结论以 `TEST/RESULTS.md` 及对应日志为准。原参考工程的工具或硬件结果不自动视为本工程结果。

## 维护约束

- 保持根目录清晰，新增内容按职责放入 `VIVADO/`、`EDA/` 或 `TEST/`。
- 临时文件和构建产物归入对应 build 目录；无保留必要的中间文件及时清理。
- 保持纯 RTL 最小验证系统，不引入无必要的应用 CPU、操作系统或跨工程构建依赖。
- 修改 MIG、引脚、时钟或复位后，重新执行相应构建和硬件验证。
- 进度记录区分用户确认、静态检查、仿真、工具验证和硬件实测，不将预期输出写成实测通过结果。
