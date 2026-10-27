# Xilinx DDR3 MIG 验证工程

本项目使用 VCU118，通过 FMC 转接板连接外部 DDR3 子板，以 Vivado Block Design 搭建 MIG、RTL 测试引擎和 UART。应用不使用 CPU，测试结果通过串口输出，GPIO LED 7 指示 DDR 校准完成。

## 项目目标

先在低负载条件下验证 DDR3 数据位读写功能，再逐步完成 DM 掩码、地址别名和全容量测试，结合原理图及断电导通检查验证转接板线序，并保留完整的实验和调试记录。

当前使用 800 MT/s DDR3、单笔在途事务和额外 1 us 事务间隔。已有一次完整数据位测试通过：32 个地址 × 260 种模式，8320 次写入和读取，错误数为 0。该结果尚不能证明全容量、长期稳定性或物理逐针线序均正确。

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

串口配置为 **115200、8N1**。**JTAG 与 DDR 链路无法共存：断开 DDR 链路时烧写 Flash，完全断电后接回 DDR，再上电测试。**

详细说明见 [BD 工程 README](vivado2/README.md)、[调试记录](TEST/DEBUG_LOG.md)、[测试结果](TEST/RESULTS.md)和[待办清单](TEST/TODO.md)。
