# 不含应用 CPU 的 DDR3 HELLOWORLD 测试

器件：`xcvu9p-flga2104-2L-e`，Vivado 2022.2。
RTL 顶层：`ddr3_loopback_top`。无需 Vitis、编译器、C 程序或软件启动流程。

```
Si570 250 MHz -> IBUFDS -> BUFG -> DDR3 MIG -> x16 DDR3
                                  | UI 200 MHz
                                  +-> ddr_hello -> uart_tx -> CP2105
                                  +-> init_calib_complete -> GPIO LED 7
```

MIG 配置由 `ip/ddr3_config.tcl` 独立生成：MT41K512M16HA-125，1.5 V，1600 MT/s 目标速率，CL11/CWL8，4:1，128-bit 原生用户接口。没有 AXI interconnect 或应用处理器。Vivado MIG 自带的校准/调试内部模块属于 IP 实现，不需要用户编程。

## 创建和构建

从仓库根目录运行：

```bash
VIVADO/scripts/build.sh prepare       # 生成可在 GUI 打开的工程和 MIG IP
VIVADO/scripts/build.sh bitstream 2   # 综合、实现、bitstream、时序/DRC 检查
```

也支持 `synth` 和 `impl` 阶段。机器内存不足时将并发数量改为 `1`。
默认 Vivado 安装位置为 `/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2`，可设置 `VIVADO_ROOT` 或 `VIVADO_BIN`。

生成的工程：`build/project/ddr3_loopback.xpr`。
最终 bitstream：`build/ddr3_loopback.bit`。
报告：`build/timing_summary.rpt`、`build/drc.rpt`、`build/utilization.rpt`。
修改 RTL/XDC 后再次构建会检查综合是否需要刷新。修改 MIG 配置后也会重新应用配置。
若要完全重新创建，关闭 GUI 及构建进程后删除 `VIVADO/build/`，再运行上述命令。

## 下载和观察

1. 按根 README 和 `EDA/README.md` 检查硬件，VADJ=1.5 V，J8 选择 U18。
2. 每次断电后用板载系统控制器将 Si570_0 设置为 250 MHz。
3. 打开板载 CP2105 的 FPGA/SCI 串口：**115200 baud、8N1、无流控**。先打开终端，再下载 bitstream；多串口设备需选择 SCI，勿与系统控制器通道混淆。
4. 在 Vivado Hardware Manager 连接开发板，选中 VU9P，Program Device，选择 `build/ddr3_loopback.bit`。
5. GPIO LED 7（BA37）亮起表示 DDR3 校准完成。串口正常输出：

```text
DDR WAIT CAL
DDR READ: HELLOWORLD
PASS
```

一次下载只运行一次。按下并松开 SW5 CPU_RESET 可重新校准并重测；SW5 按下为高。
串口打印的 10 字节逐字节来自 DDR 读回寄存器；比较整个 16 字节（含 6 字节零填充），不一致输出实际内容和 `FAIL`。

## RTL 行为与限制

- 上电和 SW5 复位后，在参考时钟域延长 MIG 复位 65536 拍（约 262 us）。MIG 用户时钟域逻辑使用 `ui_clk_sync_rst`。
- 用户时钟及复位可用后输出 `DDR WAIT CAL`，随后等待 `init_calib_complete`，不使用猜测软件延时。
- 在原生地址 0 发起一个 x16 BL8 写，128-bit 数据低字节依次为 `HELLOWORLD`，高 6 字节为零。该测试会覆盖 DDR 起始 16 字节。
- 先将数据送入写 FIFO，再发送写命令。数据和命令各保持到自己的 ready 握手，避免命令先发而数据迟到违反 PG150 的两拍限制。
- 写请求被接收后发起同地址读，等待有效读数据及结束标志，保存后再串行发送。
- 等待校准、写握手、读命令及读返回的单阶段看门狗为约 10 秒，超时输出 `DDR TIMEOUT` 并停止；按 SW5 重试。若参考时钟缺失或 UI 复位始终不释放，串口逻辑也不能工作，可能完全静默。
- GPIO LED 7 仅显示校准状态，不表示读写或压力测试通过。
- 这是单地址、单突发的冒烟测试，不验证全容量、长时间稳定性或实际工作速率。

接口依据：[AMD PG150 Command Path](https://docs.amd.com/r/en-US/pg150-ultrascale-memory-ip/Command-Path)、[User Interface](https://docs.amd.com/r/en-US/pg150-ultrascale-memory-ip/User-Interface)。

## 功能仿真

```bash
TEST/run_sim.sh
```

可先运行 `python3 TEST/check_pinmap.py` 核对本工程 50 根 DDR 引脚和 LED 7 引脚。

依赖 Verilator 5 和 C++ 编译器。测试检查 UART 实际波形、写数据停顿、写命令停顿、周期性握手停顿、读回数据故障、校准/写/读超时和复位重跑。
`TEST/build/simulation.log` 必须出现 `ALL TESTS PASSED`。
仿真使用 MIG 用户接口内存模型，不包含 MIG PHY、电气链路、校准算法或外部 DDR3 时序模型，不能代替上板验证。

## 生成 Flash 固化文件

本工程按 VCU118 Rev2.0 的双 QSPI 配置生成镜像，两颗 MT25QU01G 各为 1 Gbit（128 MiB），总容量 256 MiB。

```bash
VIVADO/scripts/generate_flash.sh
```

脚本要求已完成且未过期的 `impl_1`，复用布局布线结果，重新生成 SPIx8 bitstream（CCLK 配置速率设为器件支持的 31.9 MHz），再生成两份 MCS。无需重新综合，不修改原 `ddr3_loopback.bit`，也不连接或写入硬件。

输出到 `VIVADO/build/`：

- `ddr3_flash.bit`：SPIx8 版本 bitstream。
- `ddr3_flash_primary.mcs`：第一颗 QSPI 的烧录文件。
- `ddr3_flash_secondary.mcs`：第二颗 QSPI 的烧录文件。
- `flash_generation.log`：生成日志，成功标记为 `FLASH GENERATION PASSED`。

Hardware Manager 添加 Configuration Memory Device，选择 `mt25qu01g-spi-x1_x2_x4_x8`，分别将两份 MCS 填入 Configuration file 和 Configuration file 2，选中 Erase / Program / Verify 后烧录。写入会覆盖对应 Flash 区域原有镜像。

断电后将 SW16 的 2/3/4 位设为 OFF/OFF/ON（M[2:0]=001），第 1 位保持原状态，重新上电即可从 Flash 加载。时钟和供电配置应已按实际硬件设置完成。

MCS 是 Intel HEX 文本，磁盘文件大小大于实际 Flash 数据大小。容量应按数据地址范围计算，不能将两份 MCS 的文本字节数与 Flash 容量直接比较。

依据：[VCU118 UG1224](https://docs.amd.com/api/khub/documents/Uoc4S9pQd1uve6kiGiG2kA/content)、[AMD 双 QSPI 烧录步骤](https://docs.amd.com/r/en-US/xapp1338-fast-partial-reconfiguration-pci-express/Configure-the-Device-via-Dual-QSPI)。

### 压缩版镜像

也可用 `VIVADO/scripts/generate_compressed_flash.tcl` 生成开启 `BITSTREAM.GENERAL.COMPRESS` 的 SPIx8 镜像，输出文件名前缀为 `ddr3_flash_compressed`。复用同一份最终实现，不改变 RTL 功能或工作时钟。

2026-10-24 实际生成的压缩 bitstream 为 21,185,044 字节（约 20.20 MiB），原未压缩版本为 80,159,230 字节（约 76.45 MiB）。两份压缩 MCS 文件各 29,132,000 字节；压缩后每颗 Flash 的实际数据约 10.10 MiB。生成日志保存在 `VIVADO/build/compressed_flash_generation.log`。

当前第一次硬件烧写采用先前校验的未压缩镜像；生成压缩版本未覆盖或更改正在烧写的输入文件。
