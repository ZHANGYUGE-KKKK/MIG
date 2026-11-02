# 外接 DDR3 800 MT/s：MIG 配置与引脚交接规范

本文用于指导其他 Agent 在其自己的 MIG/DDR 控制器中配置本套 DDR 硬件。**只按参数和接口规范配置，不要求复制本工程的IP、RTL、CSV、Tcl或其他工程文件。** 控制器界面和参数名可以不同，必须保证下述功能、时序、电气和物理映射一致。本文不包含调试过程。

## 1. 硬件与工作模式

| 项目 | 配置 |
| --- | --- |
| FPGA / 开发板 | `xcvu9p-flga2104-2L-e` / VCU118 Rev2.0 |
| 参考工程工具 | Vivado 2022.2；迁移时在目标MIG中按下述参数配置完整控制器及PHY |
| 外部连接 | 母板 **J2 FMC_HPC1** → 专用重排转接板 → DDR3 子板 **J4**；不是 J22，不是直通连接 |
| 子板 / 颗粒 | Efinix FMC DDR3 GPIO daughtercard；U26 `MT41K512M16VRP-107 IT:P`，标识 D9ZWN |
| 组织 | 单 rank、总 x16；两个 4 Gb x8 die；16行地址位、10列地址位、3 Bank位、8 Bank |
| 总容量 | **1 GiB = 1,073,741,824 字节**，有效字节偏移 `0x00000000–0x3FFFFFFF` |
| DDR 速率 / CK | **800 MT/s / 400 MHz / tCK=2500 ps** |
| UI / 时钟比 | **100 MHz / 4:1**，UI周期10 ns |
| MIG 输入参考时钟 | **250 MHz / 4000 ps**，`System_Clock=No_Buffer` |
| 延迟 | CL=6、CWL=5；物理DDR突发BL8、Sequential |
| 应用接口 | AXI4 Slave；数据128位、字节地址30位、ID 1位；narrow burst关闭 |
| 电压 | FPGA DDR相关VCCO/VADJ与颗粒VDD/VDDQ均1.50 V；VREF/VTT约0.75 V |
| 电气设置 | ODT=`RZQ/6`，DRAM输出驱动=`RZQ/7`；内部VREF开启、DCI Cascade关闭 |
| 功能选择 | Data Mask开启；ECC关闭；自动刷新/ZQ由MIG处理；无用户刷新/ZQ、自刷新/保存恢复接口 |

容量计算：`2^(16+10+3) × 16/8 = 2^30` 字节。不要把GUI自定义条目的单die容量当总容量：参考配置中有值为512的单die容量字段，不能据此把总地址范围缩成512 MiB；目标控制器总容量应按上述组织设置为1 GiB，不照搬不同控制器中语义不明的Capacity数值。

颗粒自定义条目可命名为 `VRP107_800_DIE`（名称本身不影响硬件），`Memory device/component width=8`、`Memory density=4Gb`，接口 `DataWidth=16`。不要改成“单die 8Gb x16”来凑总容量，也不要选母板DDR4预设。器件速度档与本工作速率是两件事，本规范固定800 MT/s。自定义条目的运行周期范围2500–3300 ps是本800模式的配置范围，不等于颗粒速度档的完整工作范围。

## 2. MIG界面配置项

在目标控制器中选择DDR3 Components/离散器件，不使用VCU118母板DDR4预设。根据以下功能项配置；界面没有该项时，由对应的控制器/PHY实现提供等效行为，不要猜测字段名称后强行填写。

| 功能项 | 配置值 |
| --- | --- |
| Memory type / controller | DDR3 SDRAM，完整内存控制器及PHY |
| Memory part | MT41K512M16VRP-107 IT:P对应的组织；自定义条目按第1、3节填写 |
| Slot / Rank | Single slot、1 rank；无CA镜像 |
| Device width / Density | 每die x8、4 Gb；整体接口x16、1 GiB |
| Row / Column / Bank | 16 / 10 / 3 位；8个Bank |
| Physical bus widths | DQ16、DQS差分2对、DM2、ADDR16、BA3、CK差分1对、CS_N/CKE/ODT各1 |
| Chip select | 启用CS_N，宽1；不共享多rank CKE |
| Memory voltage | 1.5 V |
| Memory clock period | 2500 ps，即CK400 MHz、800 MT/s |
| Reference input clock period | 4000 ps，即250 MHz |
| Reference clock / input buffering | 物理输入为Differential；控制器输入No_Buffer，外部IBUFDS+BUFG已缓冲 |
| PHY/UI clock ratio | 4:1；UI100 MHz |
| CL / CWL | 6 / 5 |
| DDR burst length / type | BL8 / Sequential |
| DRAM ODT | RZQ/6 |
| DRAM output driver | RZQ/7 |
| Data mask / ECC | DM启用；数据ECC关闭 |
| Address ordering | ROW_COLUMN_BANK；若目标控制器不支持此映射，须明确其地址变换并重新验证Bank/行/列覆盖 |
| Transaction ordering / arbitration | Normal / 读优先寄存仲裁（参考项名RD_PRI_REG） |
| Auto precharge / column A3 option | 自动预充电关闭，AUTO_AP_COL_A3关闭 |
| Refresh / ZQ | 控制器自动管理；不依赖用户刷新/ZQCS请求 |
| Self refresh / save restore / restore CRC | 参考配置均关闭；迁移时不引入这些可选接口 |
| PHY-only mode | 关闭，使用完整控制器 |
| Internal VREF / DCI cascade | 内部VREF开启，DCI级联关闭；具体I/O值见第7节 |
| I/O power reduction | 关闭 |
| Optional UI clocks | 不启用额外UI时钟输出 |
| Debug signal option | 参考配置Disable；调试接口不属于DDR正常工作的前提 |
| Calibration | 硬件正常执行校准，不旁路；应用等待校准完成 |
| Application interface | 当前参考为AXI4，参数详见第5节；若目标控制器使用其他接口，业务侧须做完整协议适配 |

本规范只要求功能配置一致，不要求目标控制器带有某种校准处理器或相同内部模块。保持目标控制器正常生成的PHY、校准逻辑和内部约束，不手工删减其实现。

## 3. 颗粒时序参数

在目标MIG的Custom Part/时序设置中填写以下数值。除注明tCK外，表中时间为绝对时间。

| 颗粒时序项 | 值 | 主要生成值（DDR CK周期，限本列所列项） |
| --- | --- | --- |
| Min period / Max period | 2500 / 3300 ps | 当前运行tCK=2500 ps；Max period不是当前频率 |
| tCKE | 7500 ps | 由MIG生成 |
| tFAW | 40000 ps | 16 CK |
| tMRD | 4 tCK | 厂商参数块另有UI域派生值，不要直接当CK数 |
| tRAS | 35000 ps | 14 CK |
| tRCD / tRP | 15000 / 15000 ps | 6 / 6 CK |
| tREFI | 7800000 ps | 3120 CK，7.8 us |
| tRFC | 260000 ps | 104 CK，260 ns |
| tRRD | 10000 ps | 4 CK |
| tRTP / tWTR | 10000 / 10000 ps | 4 / 4 CK |
| tWR | 15000 ps | 6 CK |
| tXPR | 270 ns | 由IP换算，不统一按CK解释所有内部参数 |
| tZQCS | 160 ns | 主要生成参数tZQCS=64 |
| tZQINIT | 1280 ns | 由IP换算 |
| cas latency / cas write latency | 6 / 5 | CL6 / CWL5 |
| burst length | 8 | 物理DDR BL8，不是AXI AxLEN |
| RTT nominal | RZQ/6 | ODT |

生成参数补充：ROW_WIDTH=ADDR_WIDTH=16、COL_WIDTH=10、BANK_WIDTH=3、DQ_WIDTH=16、DQS_WIDTH=DM_WIDTH=2、CS/CKE/ODT/CK_WIDTH=1、RANKS=1、DRAM_WIDTH=COMPONENT_WIDTH=8、APP_DATA_WIDTH=128、APP_MASK_WIDTH=16、APP_ADDR_WIDTH=29、nCK_PER_CLK=4。`APP_ADDR_WIDTH=29`是IP内部native地址，不要用它替换AXI的30位字节地址。

当前参考配置生成的模式寄存器原值：MR0=`13'b0010100100000`（0x520）、MR1=`13'b0000001000100`（0x044）、MR2=0、MR3=0。应由目标控制器依据时序、CL/CWL及ODT/驱动自动生成；不同控制器对初始化瞬态位的处理可能不同，不直接用本原值覆盖其初始化序列。

保留目标控制器的正常硬件校准。仿真中的BFM、快速初始化或BYPASS_CAL配置不能用于实际硬件。不同实现内部时序参数可能按CK或UI计数，填写时先核对单位，不能直接复制内部周期数。

## 4. 时钟与复位规范

时钟路径：

```text
VCU118 U18 Si570 / U157 Q2
  → USER_SI570_CLOCK1_P/N（AW23/AW22）
  → 输入IBUFDS → ref_clk_bufg（BUFG）
  → MIG c0_sys_clk_i（250 MHz，No_Buffer）
  → MIG内部时钟逻辑 → DDR CK 400 MHz、UI 100 MHz
```

- J8应选择U18路径，实际输入必须为250 MHz。已固化正确的时钟配置无需每次重设；仍需保证掉电后的实际频率正确。不能仅凭XDC中的create_clock就认为晶振已变为250 MHz。
- 输入参考250 MHz、DDR CK400 MHz、UI100 MHz不可互换；外部DDR CK是FPGA向子板的输出，走FMC `CLK0_M2C` 命名触点并不改变其实际方向。
- `No_Buffer`下由顶层完成IBUFDS/BUFG；不得省掉缓冲，也不得额外增加重复缓冲、外部PLL或MMCM后仍声称配置未变。
- 保留BUFG定位 `BUFGCE_X1Y120` 和输出网 `CLOCK_DEDICATED_ROUTE BACKBONE`。不是 `FALSE`。不要改用其他板载时钟球位后仅靠放宽专用时钟规则通过实现。
- 参考平台MIG生成MMCM参数：CLKIN_PERIOD=4000 ps、CLKFBOUT_MULT=6、DIVCLK_DIVIDE=1、CLKOUT0_DIVIDE=15；用于核对参考时钟关系；目标PHY若采用不同内部结构，由其自动生成等效时钟，不手工覆盖其内部参数。

| 信号 | 极性 / 用途 |
| --- | --- |
| 顶层 `sys_rst` | 高有效，VCU118 SW5 CPU_RESET，L19 |
| `mig_rst` → `mig/sys_rst` | 高有效；输入复位同步后保持16位POR计数，约65535个250 MHz周期，约262 us |
| `mig/c0_ddr3_ui_clk_sync_rst` | 高有效，UI域同步复位，不能当作低有效AXI复位直接连接 |
| `app_reset` | 高有效，UI域三级异步置位/同步释放应用复位 |
| `mig/c0_ddr3_aresetn` | 低有效AXI复位；基线使用 `~app_reset & ~c0_ddr3_ui_clk_sync_rst` |
| `mig/c0_init_calib_complete` | 高为DDR校准完成；应用仅在其为1且复位释放后发DDR请求 |
| `C0_DDR3_0_reset_n` | MIG输出到颗粒的低有效复位，不能由应用另行驱动 |

AXI复位应同步于UI100 MHz释放。其他时钟域各自同步复位并通过AXI Clock Converter/异步桥连接；不能仅设置false_path来替代CDC。不要将“校准尚未完成”反馈成MIG sys_rst持续有效，形成无法完成校准的复位环路。运行中复位时同时正确清理主从事务状态，不能仅复位一侧而遗留在途请求。

复位同步器保留ASYNC_REG；若沿用相同寄存器命名，参考约束只豁免三级 `app_reset_sync_reg[0..2]` 的异步PRE端，且只在实现阶段使用。若目标工程自带复位同步器，则按其实际原语和层级约束，不复制匹配不到对象的查询。各级Q→D及同步复位输出仍正常分析时序。

## 5. AXI接口与系统地址规范

| 项目 | 接入规范 |
| --- | --- |
| Slave接口 | 参考接口名 `mig/C0_DDR3_S_AXI`；目标控制器按同等接口连接 |
| 时钟 | MIG UI100 MHz；其他域经过AXI CDC |
| 地址 | AWADDR/ARADDR `[29:0]`，**字节偏移地址**，不是DDR半字地址或16字节拍序号 |
| 数据 / strobe | WDATA/RDATA `[127:0]`；WSTRB `[15:0]` |
| ID | AWID/ARID/BID/RID各1位；多主机或宽ID通过有序的互连/适配，不直接截断ID |
| 长度 / 大小 | AxLEN `[7:0]`，表示拍数减1；完整128位传输用AxSIZE=4，地址16字节对齐 |
| 突发 | 基线使用INCR，AxBURST=1；单拍AxLEN=0，32拍AxLEN=31 |
| AXI narrow burst | 关闭；CPU字节/半字/32/64位请求需要正确的宽度/窄访问适配，不能直接改AxSIZE冒充完整拍 |
| 部分写 | IP启用DM；全拍写WSTRB=0xFFFF。掩码写需保证WSTRB与字节lane对应并单独验证 |
| 写完成 | 正确握手AW/W，最后一拍WLAST，成功接收BRESP后才确认写事务完成 |
| 读完成 | VALID/READY握手逐拍计数，检查RRESP/RID以及末拍RLAST |
| 边界 | 不越过1 GiB，AXI突发不得跨4 KiB边界；32拍×16字节时可用512字节对齐地址 |
| 仲裁 | `RD_PRI_REG`，Ordering=Normal；不要把测试引擎的并发上限当MIG参数 |

基线BD中的地址段为 `/mig/C0_DDR3_MEMORY_MAP/C0_DDR3_ADDRESS_BLOCK`，起点 `0x00000000`、范围 `1G`。若目标SoC软件仍使用原DDR基址（例如高地址区域），必须在系统地址译码中明确把该1 GiB窗口映射到MIG的本地30位字节偏移；同时更新链接脚本、设备树/内存映射及DMA地址等实际使用项。不能未经范围检查直接丢弃高位而让越界地址折叠进DDR。

原接口是DDR4、不同位宽/容量或native app接口时，不能仅换颗粒名称或重新接几根线；须按目标控制器接口重新适配时钟、复位和事务握手。目标控制器若采用native接口，需要按其地址单位、命令/写数据握手、掩码及读返回约定适配；不得将AXI字节地址直接接到语义不同的native地址。

保留128位数据和16位WSTRB的原顺序。FMC的P/N标记不代表DQ需要取反；单端DQ按映射逐根接，CK/DQS才作为差分对。若做总线打包、native转换或大小端转换，必须独立确认字节lane，不能用任意交换位序来掩盖接线差异。

## 6. 完整DDR引脚映射

下表50根DDR信号全部对应本套转接板。Bank66放地址/控制/CK/RESET；Bank67 T0放DQ[7:0]/DQS0/DM0，T3放DQ[15:8]/DQS1/DM1。不可随意调换DQS、DM和所属DQ字节组。

| 顶层端口 | FPGA球位 | Bank | 母板FMC网名 | 母板J2 | 子板J4 | U26球位 |
| --- | --- | ---: | --- | --- | --- | --- |
| `C0_DDR3_0_addr[0]` | BD12 | 66 | FMC_HPC1_LA03_P | G9 | D9 | N3 |
| `C0_DDR3_0_addr[1]` | BE12 | 66 | FMC_HPC1_LA03_N | G10 | D8 | P7 |
| `C0_DDR3_0_addr[2]` | BF12 | 66 | FMC_HPC1_LA04_P | H10 | G9 | P3 |
| `C0_DDR3_0_addr[3]` | BF11 | 66 | FMC_HPC1_LA04_N | H11 | G10 | N2 |
| `C0_DDR3_0_addr[4]` | BC11 | 66 | FMC_HPC1_LA02_P | H7 | H14 | P8 |
| `C0_DDR3_0_addr[5]` | BD11 | 66 | FMC_HPC1_LA02_N | H8 | H13 | P2 |
| `C0_DDR3_0_addr[6]` | BD13 | 66 | FMC_HPC1_LA06_P | C10 | D15 | R8 |
| `C0_DDR3_0_addr[7]` | BE13 | 66 | FMC_HPC1_LA06_N | C11 | D14 | R2 |
| `C0_DDR3_0_addr[8]` | BE14 | 66 | FMC_HPC1_LA05_P | D11 | H7 | T8 |
| `C0_DDR3_0_addr[9]` | BF14 | 66 | FMC_HPC1_LA05_N | D12 | H8 | R3 |
| `C0_DDR3_0_addr[10]` | BE15 | 66 | FMC_HPC1_LA08_P | G12 | H11 | L7 |
| `C0_DDR3_0_addr[11]` | BF15 | 66 | FMC_HPC1_LA08_N | G13 | H10 | R7 |
| `C0_DDR3_0_addr[12]` | BC14 | 66 | FMC_HPC1_LA12_P | G15 | C11 | N7 |
| `C0_DDR3_0_addr[13]` | BC13 | 66 | FMC_HPC1_LA12_N | G16 | C10 | T3 |
| `C0_DDR3_0_addr[14]` | BB16 | 66 | FMC_HPC1_LA15_P | H19 | G13 | T7 |
| `C0_DDR3_0_addr[15]` | BC16 | 66 | FMC_HPC1_LA15_N | H20 | G12 | M7 |
| `C0_DDR3_0_ba[0]` | BC15 | 66 | FMC_HPC1_LA07_P | H13 | C14 | M2 |
| `C0_DDR3_0_ba[1]` | BD15 | 66 | FMC_HPC1_LA07_N | H14 | C15 | N8 |
| `C0_DDR3_0_ba[2]` | BA16 | 66 | FMC_HPC1_LA11_P | H16 | G16 | M3 |
| `C0_DDR3_0_ras_n` | BA14 | 66 | FMC_HPC1_LA09_P | D14 | C18 | J3 |
| `C0_DDR3_0_cas_n` | BA15 | 66 | FMC_HPC1_LA11_N | H17 | C19 | K3 |
| `C0_DDR3_0_we_n` | BB14 | 66 | FMC_HPC1_LA09_N | D15 | G15 | L3 |
| `C0_DDR3_0_cs_n[0]` | BB13 | 66 | FMC_HPC1_LA10_P | C14 | G19 | L2 |
| `C0_DDR3_0_cke[0]` | BB12 | 66 | FMC_HPC1_LA10_N | C15 | G18 | K9 |
| `C0_DDR3_0_odt[0]` | AV9 | 66 | FMC_HPC1_LA16_P | G18 | G6 | K1 |
| `C0_DDR3_0_reset_n` | AV8 | 66 | FMC_HPC1_LA16_N | G19 | G7 | T2 |
| `C0_DDR3_0_ck_p[0]` | BC9 | 66 | FMC_HPC1_CLK0_M2C_P | H4 | D11 | J7 |
| `C0_DDR3_0_ck_n[0]` | BC8 | 66 | FMC_HPC1_CLK0_M2C_N | H5 | D12 | K7 |
| `C0_DDR3_0_dq[0]` | AW12 | 67 | FMC_HPC1_LA19_P | H22 | G30 | E3 |
| `C0_DDR3_0_dq[1]` | AY12 | 67 | FMC_HPC1_LA19_N | H23 | G31 | F7 |
| `C0_DDR3_0_dq[2]` | AW11 | 67 | FMC_HPC1_LA20_P | G21 | H31 | F2 |
| `C0_DDR3_0_dq[3]` | AY10 | 67 | FMC_HPC1_LA20_N | G22 | H32 | F8 |
| `C0_DDR3_0_dq[4]` | AW13 | 67 | FMC_HPC1_LA22_P | G24 | G34 | H3 |
| `C0_DDR3_0_dq[5]` | AY13 | 67 | FMC_HPC1_LA22_N | G25 | G33 | H8 |
| `C0_DDR3_0_dq[6]` | AU11 | 67 | FMC_HPC1_LA21_P | H25 | H34 | G2 |
| `C0_DDR3_0_dq[7]` | AV11 | 67 | FMC_HPC1_LA21_N | H26 | H35 | H7 |
| `C0_DDR3_0_dq[8]` | AK15 | 67 | FMC_HPC1_LA26_P | D26 | G36 | D7 |
| `C0_DDR3_0_dq[9]` | AL15 | 67 | FMC_HPC1_LA26_N | D27 | G37 | C3 |
| `C0_DDR3_0_dq[10]` | AK12 | 67 | FMC_HPC1_LA30_P | H34 | H38 | C8 |
| `C0_DDR3_0_dq[11]` | AL12 | 67 | FMC_HPC1_LA30_N | H35 | H37 | C2 |
| `C0_DDR3_0_dq[12]` | AM13 | 67 | FMC_HPC1_LA31_P | G33 | G22 | A7 |
| `C0_DDR3_0_dq[13]` | AM12 | 67 | FMC_HPC1_LA31_N | G34 | G24 | A2 |
| `C0_DDR3_0_dq[14]` | AK14 | 67 | FMC_HPC1_LA33_P | G36 | G25 | B8 |
| `C0_DDR3_0_dq[15]` | AK13 | 67 | FMC_HPC1_LA33_N | G37 | H29 | A3 |
| `C0_DDR3_0_dm[0]` | AT12 | 67 | FMC_HPC1_LA25_P | G27 | H28 | E7 |
| `C0_DDR3_0_dm[1]` | AL14 | 67 | FMC_HPC1_LA27_P | C26 | C23 | D3 |
| `C0_DDR3_0_dqs_p[0]` | AV10 | 67 | FMC_HPC1_LA28_P | H31 | D26 | F3 |
| `C0_DDR3_0_dqs_n[0]` | AW10 | 67 | FMC_HPC1_LA28_N | H32 | D27 | G3 |
| `C0_DDR3_0_dqs_p[1]` | AJ13 | 67 | FMC_HPC1_LA32_P | H37 | C26 | C7 |
| `C0_DDR3_0_dqs_n[1]` | AJ12 | 67 | FMC_HPC1_LA32_N | H38 | C27 | B7 |

附加板级端口：参考时钟P/N=AW23/AW22（LVDS），sys_rst=L19（LVCMOS12），可选UART tx=BB21（LVCMOS18），可选GPIO_LED7=BA37（LVCMOS12、高亮）。LED7直接接 `c0_init_calib_complete`，仅指示校准，不代表应用数据正确。

## 7. XDC配置规范

以下是给目标工程填写的完整物理约束。端口名可按目标顶层一对一替换，球位、DQ/DQS/DM所属组和电气标准保持一致。它们是约束文本示例，不要求复制本工程的XDC文件。

- 地址/Bank/命令/CS/CKE/ODT/DM/DQ：SSTL15_DCI、FAST。
- CK/DQS：DIFF_SSTL15_DCI、FAST。
- 颗粒RESET#：SSTL15，保持默认slew。
- Bank66/67：INTERNAL_VREF=0.75；不启用DCI Cascade。保留控制器自动生成的DCI/阻抗/PHY时序约束。
- 参考时钟：LVDS、DIFF_TERM_ADV=TERM_NONE，板端已有终端；输入时钟周期4.000 ns。
- ref_clk_bufg定位BUFGCE_X1Y120，输出网络CLOCK_DEDICATED_ROUTE=BACKBONE。匹配层级按目标工程实际实例名修改。
- 不沿用旧DDR的引脚、输入/输出延迟、专用时钟例外；目标控制器的内部PHY约束由其正常生成，不把IP内部scoped XDC作为第二份全局约束导入。
- 不添加覆盖整个DDR数据路径的false_path；不以CLOCK_DEDICATED_ROUTE=FALSE或降低DRC等级绕过问题。

```tcl
set_property -dict {PACKAGE_PIN AW23 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE} [get_ports BADJ_CLK_clk_p]
set_property -dict {PACKAGE_PIN AW22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE} [get_ports BADJ_CLK_clk_n]
create_clock -period 4.000 -name BOARD_SYSCLK_250M [get_ports BADJ_CLK_clk_p]
set_property LOC BUFGCE_X1Y120 [get_cells -hier -filter {NAME =~ */ref_clk_bufg}]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets -of_objects [get_pins -hier -filter {NAME =~ */ref_clk_bufg/O}]]
set_property PACKAGE_PIN BD12 [get_ports {C0_DDR3_0_addr[0]}]
set_property PACKAGE_PIN BE12 [get_ports {C0_DDR3_0_addr[1]}]
set_property PACKAGE_PIN BF12 [get_ports {C0_DDR3_0_addr[2]}]
set_property PACKAGE_PIN BF11 [get_ports {C0_DDR3_0_addr[3]}]
set_property PACKAGE_PIN BC11 [get_ports {C0_DDR3_0_addr[4]}]
set_property PACKAGE_PIN BD11 [get_ports {C0_DDR3_0_addr[5]}]
set_property PACKAGE_PIN BD13 [get_ports {C0_DDR3_0_addr[6]}]
set_property PACKAGE_PIN BE13 [get_ports {C0_DDR3_0_addr[7]}]
set_property PACKAGE_PIN BE14 [get_ports {C0_DDR3_0_addr[8]}]
set_property PACKAGE_PIN BF14 [get_ports {C0_DDR3_0_addr[9]}]
set_property PACKAGE_PIN BE15 [get_ports {C0_DDR3_0_addr[10]}]
set_property PACKAGE_PIN BF15 [get_ports {C0_DDR3_0_addr[11]}]
set_property PACKAGE_PIN BC14 [get_ports {C0_DDR3_0_addr[12]}]
set_property PACKAGE_PIN BC13 [get_ports {C0_DDR3_0_addr[13]}]
set_property PACKAGE_PIN BB16 [get_ports {C0_DDR3_0_addr[14]}]
set_property PACKAGE_PIN BC16 [get_ports {C0_DDR3_0_addr[15]}]
set_property PACKAGE_PIN BC15 [get_ports {C0_DDR3_0_ba[0]}]
set_property PACKAGE_PIN BD15 [get_ports {C0_DDR3_0_ba[1]}]
set_property PACKAGE_PIN BA16 [get_ports {C0_DDR3_0_ba[2]}]
set_property PACKAGE_PIN BA14 [get_ports {C0_DDR3_0_ras_n}]
set_property PACKAGE_PIN BA15 [get_ports {C0_DDR3_0_cas_n}]
set_property PACKAGE_PIN BB14 [get_ports {C0_DDR3_0_we_n}]
set_property PACKAGE_PIN BB13 [get_ports {C0_DDR3_0_cs_n[0]}]
set_property PACKAGE_PIN BB12 [get_ports {C0_DDR3_0_cke[0]}]
set_property PACKAGE_PIN AV9 [get_ports {C0_DDR3_0_odt[0]}]
set_property PACKAGE_PIN AV8 [get_ports {C0_DDR3_0_reset_n}]
set_property PACKAGE_PIN BC9 [get_ports {C0_DDR3_0_ck_p[0]}]
set_property PACKAGE_PIN BC8 [get_ports {C0_DDR3_0_ck_n[0]}]
set_property PACKAGE_PIN AW12 [get_ports {C0_DDR3_0_dq[0]}]
set_property PACKAGE_PIN AY12 [get_ports {C0_DDR3_0_dq[1]}]
set_property PACKAGE_PIN AW11 [get_ports {C0_DDR3_0_dq[2]}]
set_property PACKAGE_PIN AY10 [get_ports {C0_DDR3_0_dq[3]}]
set_property PACKAGE_PIN AW13 [get_ports {C0_DDR3_0_dq[4]}]
set_property PACKAGE_PIN AY13 [get_ports {C0_DDR3_0_dq[5]}]
set_property PACKAGE_PIN AU11 [get_ports {C0_DDR3_0_dq[6]}]
set_property PACKAGE_PIN AV11 [get_ports {C0_DDR3_0_dq[7]}]
set_property PACKAGE_PIN AK15 [get_ports {C0_DDR3_0_dq[8]}]
set_property PACKAGE_PIN AL15 [get_ports {C0_DDR3_0_dq[9]}]
set_property PACKAGE_PIN AK12 [get_ports {C0_DDR3_0_dq[10]}]
set_property PACKAGE_PIN AL12 [get_ports {C0_DDR3_0_dq[11]}]
set_property PACKAGE_PIN AM13 [get_ports {C0_DDR3_0_dq[12]}]
set_property PACKAGE_PIN AM12 [get_ports {C0_DDR3_0_dq[13]}]
set_property PACKAGE_PIN AK14 [get_ports {C0_DDR3_0_dq[14]}]
set_property PACKAGE_PIN AK13 [get_ports {C0_DDR3_0_dq[15]}]
set_property PACKAGE_PIN AT12 [get_ports {C0_DDR3_0_dm[0]}]
set_property PACKAGE_PIN AL14 [get_ports {C0_DDR3_0_dm[1]}]
set_property PACKAGE_PIN AV10 [get_ports {C0_DDR3_0_dqs_p[0]}]
set_property PACKAGE_PIN AW10 [get_ports {C0_DDR3_0_dqs_n[0]}]
set_property PACKAGE_PIN AJ13 [get_ports {C0_DDR3_0_dqs_p[1]}]
set_property PACKAGE_PIN AJ12 [get_ports {C0_DDR3_0_dqs_n[1]}]
set_property IOSTANDARD SSTL15_DCI [get_ports {C0_DDR3_0_addr[*] C0_DDR3_0_ba[*] C0_DDR3_0_ras_n C0_DDR3_0_cas_n C0_DDR3_0_we_n C0_DDR3_0_cke[*] C0_DDR3_0_cs_n[*] C0_DDR3_0_odt[*] C0_DDR3_0_dm[*] C0_DDR3_0_dq[*]}]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports {C0_DDR3_0_ck_p[*] C0_DDR3_0_ck_n[*] C0_DDR3_0_dqs_p[*] C0_DDR3_0_dqs_n[*]}]
set_property IOSTANDARD SSTL15 [get_ports C0_DDR3_0_reset_n]
set_property SLEW FAST [get_ports {C0_DDR3_0_addr[*] C0_DDR3_0_ba[*] C0_DDR3_0_ras_n C0_DDR3_0_cas_n C0_DDR3_0_we_n C0_DDR3_0_cke[*] C0_DDR3_0_cs_n[*] C0_DDR3_0_odt[*] C0_DDR3_0_dm[*] C0_DDR3_0_dq[*] C0_DDR3_0_ck_p[*] C0_DDR3_0_ck_n[*] C0_DDR3_0_dqs_p[*] C0_DDR3_0_dqs_n[*]}]
set_property INTERNAL_VREF 0.75 [get_iobanks {66 67}]
set_property PACKAGE_PIN L19 [get_ports sys_rst]
set_property IOSTANDARD LVCMOS12 [get_ports sys_rst]
set_false_path -from [get_ports sys_rst]
set_property PACKAGE_PIN BB21 [get_ports tx]
set_property IOSTANDARD LVCMOS18 [get_ports tx]
set_false_path -to [get_ports tx]
set_property PACKAGE_PIN BA37 [get_ports GPIO_LED7]
set_property IOSTANDARD LVCMOS12 [get_ports GPIO_LED7]
set_false_path -to [get_ports GPIO_LED7]
```

上述文本包含可选UART tx、GPIO_LED7和板载sys_rst。若目标设计不导出某端口，同步删去它的PACKAGE_PIN、IOSTANDARD及set_false_path；不要保留空匹配告警。DDR端口必须全部存在，50根映射不得删减。参考时钟不能被旧工程重复create_clock或重复缓冲。

应用复位同步器若采用参考三级PRE结构，可按实际名称添加以下精确例外，仅用于实现；不用该结构时应改成目标同步器相应约束：

```tcl
set async_pins [get_pins -hier -regexp {.*app_reset_sync_reg\[[012]\]/PRE}]
# 核对匹配数确为3，再设置例外。
set_false_path -to $async_pins
```

需要VCU118双QSPI x8启动时，bitstream配置为：

```tcl
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 31.9 [current_design]
```

这些Flash选项不属于DDR工作条件。直接JTAG下载不需要为本DDR接口改变SW16；Flash启动方式由目标工程另行管理。

## 8. 硬件与迁移注意事项

- FPGA DDR I/O供电与子板供电分别确认，不能把R257当作VCU118 VADJ调节器。R257调子板本地VDDQ，VTT/VREF跟随约一半。工程维持1.5V/SSTL15，不因颗粒兼容1.35V就把子板单独设为1.35V。
- 子板负载端测量目标：J199-2=VDD约1.50V、J200-2=VDDQ约1.50V、J201-2=VREF约0.75V、J202-2=VTT约0.75V。这四组排针不提供GND；可用已确认的子板J1第5/6脚公共地。
- 采用当前本地3.3V输入供电方式时，J5只接5–6、7–8；J220接1–2以使能本地稳压器；J199/J200/J201/J202按本地电源选择1–2、3–4。若供电方案不同，应按原理图重新核对，不把不同来源的电源并接。
- 本套硬件H2已作处理，允许JTAG与完整DDR链路同时连接；不要依据旧版转接板网表备注擅自恢复H2接地，也不要改动未核对的JTAG触点。
- 不把FMC的成对命名解释为DQ差分或自动取反；不同DDR信号仍需遵守自身时序及所属DQS组要求。保持当前转接映射，替换其他转接板/PCB需要重新审核。
- 生成后核对：器件/控制器版本、颗粒定义与全部有效配置、tCK=2500、UI=100 MHz、行列Bank组织、AXI1G地址段、50根DDR及其他启用端口球位、I/O标准、VREF和所有约束查询匹配数。
- 完成validate_bd_design、generate_target、综合及实现，检查setup/hold/pulse width、bus skew、DRC和复位CDC；不能只以生成bitstream成功作为接入完成条件。
- 上板确认MIG校准完成后，再做目标系统实际读写、边界、部分写及并发验证。若控制器提供Hardware Manager状态，Bit Time应为1250 ps、Memory Frequency为400 MHz；无该状态接口时按实际PHY时钟及数据速率核对。不能把Bit Time当作tCK。
- 替换SoC DDR时同步核对启动/链接地址、容量、cache一致性、DMA可达范围及总线宽度/ID/时钟转换。保留目标业务逻辑，移除与原DDR冲突的管脚、复位和时钟假设。

## 9. 交给接收Agent的完成标准

1. 根据本规范在自己的MIG中配置本套DDR，不导入本工程的测试逻辑或IP文件。
2. 给出功能配置对照，确认1GiB组织、800 MT/s、250 MHz参考、100 MHz UI、CL6/CWL5、1.5V以及本规范时序/接口项。
3. 给出50根DDR及启用板级端口的一对一约束核对，确认旧DDR约束无残留冲突。
4. 说明时钟缓冲、复位释放、校准门控、CDC/位宽/ID适配和系统地址窗口怎样接入。
5. 对自己的完整工程重新完成实现/时序/DRC检查，再验证实际业务读写；不能以“参数填完”或“校准灯亮”代替接入完成。
