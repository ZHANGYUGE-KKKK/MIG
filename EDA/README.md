# 本工程采用的硬件映射

来源：`/home/wenhan/PROJECTS/C910_SOC_VCU118_FMC_DDR3_MIG/EDA/adapter_fmc_hpc1/`。
本目录保存实际采用的 `pinmap.json`（2026-10-04-C）和逐针 `connections.md`，构建不再读取参考工程。

`VIVADO/constraints/vcu118.xdc` 沿用参考工程的 DDR3 50 根信号、Si570 时钟、SW5 复位和 UART TX 引脚；删除 CPU/JTAG/UART RX 约束，并将时钟缓冲层次改为本工程 `ref_clk_bufg`。

GPIO LED 7 采用 BA37 / LVCMOS12，高电平点亮，直接显示 MIG 的 `c0_init_calib_complete`，不代表读写比较通过。
核对来源为本机归档的 VCU118 Rev2.0 官方 XDC：
`ARCHIVE/DATASHEET/VCU118/vcu118-schematic-xtp450_cluster/vcu118-xdc-rdf0400/vcu118_rev2.0_12082017.xdc`（1023–1024 行），以及 VCU118 Rev2.0 原理图第 55 页的 MOSFET LED 驱动。

上板仍须核对 VADJ=1.5 V、J8 选 U18、Si570_0=250 MHz、转接板方向/供电/公共地和 DDR3 RESET# 电路。无源转接板是信号重排板，不能使用直通连接替代。

## 已确认的插卡 JTAG 断链限制（2026-10-24）

当前实物转接板将母板侧 H2 / PRSNT_M2C 接地，但没有连接 TDI/TDO。VCU118 Rev2.0 原理图第 39 页中，U132（NC7SZ66）的 OE 接 PRSNT_M2C_B：OE=1 时关闭旁路开关（导通），H2 接地使 OE=0、旁路断开，串行链改走插卡。因此该实物接入后，母板 JTAG 扫描不到 FPGA，是此未闭合通路的结果，不足以判定 FPGA 未供电或 Flash 启动失败。

建议后续修订：若不使用插卡 JTAG，可在断电后，将转接板**母板侧同一连接器的 D30（TDI）与 D31（TDO）本地短接**，形成无器件旁路。不需要把它们透传到 DDR3 子板，也不要凭同号针脚在子板侧短接。须按实物连接器的正确观察方向核对针号。

这是一项建议修订，尚未实施；本工程保存的历史 pinmap/逐针表仍描述原始方案，不能将其余未列出引脚均为 NC 的规则误认为已包含 JTAG 旁路。此旁路只恢复 JTAG/MIG 调试，不直接解决 DDR3 校准失败，也不影响现有 Flash 镜像内容。
