# Xilinx DDR3 MIG 验证工程

本项目使用 VCU118，通过 FMC 转接板连接外部 DDR3 子板，以 Vivado Block Design 搭建 MIG、RTL 测试引擎和 UART。应用不使用 CPU，测试结果通过串口输出，GPIO LED 7 指示 DDR 校准完成。

## 项目目标

先在低负载条件下验证 DDR3 数据位读写功能，再逐步完成 DM 掩码、地址别名和全容量测试，结合原理图及断电导通检查验证转接板线序，并保留完整的实验和调试记录。

原始低负载工程使用 800 MT/s DDR3、单笔在途事务和额外 1 us 事务间隔。已有一次完整数据位测试通过：32 个地址 × 260 种模式，8320 次写入和读取，错误数为 0。该结果尚不能证明全容量、长期稳定性或物理逐针线序均正确。

2026-10-29：H2移除后已实现JTAG在线调试。用户调压重启后，低负载ILA复测通过；新增[VIO/ILA在线诊断工程](vivado2/online_diag/README.md)完成16轮PRNG密集/间隔读，累计256MiB、0错。该工程使用AXI连续突发，非历史native多并发；[报告](vivado2/online_diag/hardware/2026-10-29_results.md)记录了覆盖及归因限制。UART保留，Flash未改写。

此前：800独立请求3次重新配置、24轮读384MiB为0错；用户授权恢复的[1600在线压力工程](vivado2/online_1600/README.md)已下载并完成测试，1MiB对照330错拍、16MiB压力3069错拍，全部位翻转在DQ9/10/11，校准PASS。用户确认电压符合目标，下一步集中高字节高速读裕量，不能将低电压作为唯一解释。见[1600实测报告](vivado2/online_1600/hardware/2026-10-29_results.md)。

最新：按用户要求切回800，已完成[全容量连续突发压力](vivado2/online_800_burst/hardware/2026-10-29_results.md)：全1GiB两种互补地址模式，累计写17GiB、读272GiB，0错/fatal0。连续突发端到端均值1.442GB/s，实测2个32拍请求在途；单拍版峰值30。当前FPGA保留800突发镜像、HALT，Flash未改写。DM、混合随机读写及冷启动温度范围仍待验收。

接入其他工程时使用[800 MT/s MIG 配置与引脚交接规范](HANDOFF/DDR3_800_CONFIGURATION.md)，仅包含配置、接口、约束及迁移注意事项。

## 项目结构

| 目录 | 内容 |
| --- | --- |
| `vivado2/` | 当前使用的 Vivado BD 工程。 |
| `vivado2/rtl/` | 测试引擎、AXI 转换、UART、时钟与复位模块。 |
| `vivado2/config/` | MIG 配置、参数与引脚核对基准。 |
| `vivado2/constraints/` | 引脚、时序和 Flash 配置约束。 |
| `vivado2/scripts/` | 创建 BD、构建、生成 Flash 文件和烧写脚本。 |
| `vivado2/tests/` | 仿真、串口解析及上板测试数据。 |
| `vivado2/build/` | 生成的 GUI 工程、bitstream、双 Flash 文件及报告；不纳入 Git。 |
| `EDA/` | 硬件连接、逐针映射与原理图核对资料。 |
| `TEST/` | 调试过程、实验统计、待办及历史资料。 |

旧 `VIVADO` 工程已删除；历史文档中对应路径仅用于记录当时实验。

## 使用方法

使用 Vivado 2022.2 打开 `vivado2/build/project/wiring_bd.xpr`，选择 **Open Block Design → wiring** 查看图形设计。

在项目根目录执行以下命令可运行仿真、创建工程并生成 bitstream 和双 Flash 烧写文件，依赖 Vivado 2022.2、Verilator 和 Python 3：

```bash
./vivado2/scripts/build.sh
```

Flash 文件为 `vivado2/build/wiring_bd_800_primary.mcs` 和 `vivado2/build/wiring_bd_800_secondary.mcs`，需成对烧写。构建脚本不自动烧写开发板。

串口配置为 **115200、8N1**。**2026-10-29：用户移除转接板H2，撤销JTAG/DDR不能共存及必须经Flash下载的限制。调试优先JTAG直接下载；Flash用于需要掉电保存时。旧接线记录仅作历史。**

详细说明见 [BD 工程 README](vivado2/README.md)、[调试记录](TEST/DEBUG_LOG.md)、[测试结果](TEST/RESULTS.md)和[待办清单](TEST/TODO.md)。
