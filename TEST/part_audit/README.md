# 第1项：实物颗粒与MIG参数核对

2026-10-25。实物顶标由用户提供：IZP17 / D9ZWN / IP7F。美光官方解码器返回 MT41K512M16VRP-107 IT:P，8Gb、x16、96球、933MHz/1866MT/s，工业温度-40至95°C。官方查询原始JSON见 sources/product_info.json，解码器响应见 ../paired/build/schematic_review/micron_D9ZWN_decoder.json。

## 原始资料与证据

- 美光 TwinDie 数据手册，Rev.D 01/20，CCM005-1005363231-10357，sources/micron_twindie_public.pdf。虽然标题含Automotive，其型号选项包含工业级IT；本次使用工业级温度要求，不将实物写为AAT认证型号。第1、2、6、10页已渲染检查。
- 美光4Gb基础die手册，Rev.R 09/18，09005aef85af8fa8，sources/micron_4gb_revR.pdf，包含E/N/P die，第1页及第80/81/85/86页等已渲染检查。TwinDie手册明确要求未列规格参考4Gb x8选项。该手册说明1.5V兼容模式的电气规格参考DDR3 Die:E，不能把1.35V电气裕量数值直接用于1.5V眼图合格判定。
- 下载源和SHA256见 sources/provenance.json。资料均为美光编写的原始规格书，由公开镜像分发；官方网站当前下载目录要求登录，本次未使用受限下载。
- Vivado 2022.2实际使用的器件库在 data/ip/xilinx/mem_v1_4/csv/ddr3_sdram，包含MT41K512M8DA-107。data/memory目录的另一份旧库不含全部现行器件，不能只检索那里。

## 容量、内部组织和引脚

VRP内部是两个4Gb x8 die，共享A[15:0]、BA[2:0]、CK、CS、CKE和ODT，构成一个rank、两个byte lane、总x16；不是双rank。每die为64M×8×8banks，行16位、列10位、Bank3位；整体可用容量1GiB。

按TwinDie第6页逐一核对 EDA/pinmap.json 中50个DDR信号的U26球位，均与图相符：DQ9=C3、DQ12=A7、UDQS=C7、UDQS#=B7；下字节DQS=F3/G3，上字节DM=D3，下字节DM=E7，地址/命令/时钟球位保持原约束。仅为资料级核对，未新增实物导通或短路测量。

实物支持1.35V及向后兼容1.5V。本项目维持已采用的1.5V/SSTL15，未改Si570、板上电压或接线。保持原ODT/驱动设置，但进一步核对发现：配置属性写作ODT=RZQ/6、输出驱动=RZQ/7，而旧、新生成RTL的初始MR1均为0x44，按手册解码实际初始化输出驱动为RZQ/6（40Ω），名义ODT也为40Ω。不能只凭GUI属性声称已编程为34Ω。本次维持相同初始MR1，未加入驱动强度调优；两个选项都属于颗粒支持值，但最终运行时寄存器未上板读回。

## 独立修订版

配置位于 VIVADO/vrp/，构建目录 VIVADO/vrp_800_build 和 VIVADO/vrp_1600_build。复用原paired RTL、UART、引脚、复位约束。旧paired镜像不覆盖。CSV名称VRP107_<rate>_DIE表示每个逻辑x8 die，不是声称封装型号为x8；MIG把两个4Gb x8逻辑组件配置为16位总线，需断言生成容量为1073741824字节，DQ16/DQS2、CS/CKE/ODT各1、单rank、行16列10Bank3。

分别使用自定义CSV以显式控制与运行点相关的时序，避免仅改成另一内建型号。800版本CL6/CWL5；1600版本CL11/CWL8。-107在1600使用CL11有基础die手册第81页脚注的向后兼容依据；CL12/CWL8在该表是Reserved，未采用。

| 参数 | 原800 HA-125 | 新800 VRP | 新1600 VRP | 依据/判断 |
| --- | --- | --- | --- | --- |
| 内部建模 | 1×8Gb x16 | 2×4Gb x8 | 2×4Gb x8 | TwinDie第1/2/10页 |
| 总容量 | 1GiB | 1GiB | 1GiB | 寻址不变 |
| CK/UI | 400/100MHz | 400/100MHz | 800/200MHz | 参考250MHz不变 |
| CL/CWL | 6/5 | 6/5 | 11/8 | 基础die第81页 |
| tRFC | 350ns | 260ns | 260ns | 每die4Gb，基础die第86页；原350ns偏保守，不能据此说原配置刷新太短 |
| tREFI | 7.8us | 7.8us | 7.8us | 本版本限定Tc≤85°C；高于85°C须改2倍刷新并检查SRT/ASR要求 |
| tFAW | 40ns | 40ns | 40ns | 800 x8要求40ns；1600保守采用40ns，未压到30ns |
| tRRD实际最小 | 4CK=10ns | 4CK=10ns | 8CK=10ns | 选择10ns且满足至少4CK |
| tRAS | 35ns | 35ns | 35ns | 1600向后兼容运行点 |
| tRCD/tRP | 15/15ns | 15/15ns | 15/15ns | 新版显式采用15ns；高频比原11CK更保守 |
| tRC（由tRAS+tRP满足） | ≥50ns | ≥50ns | ≥50ns | 不短于1600运行点48.75ns |
| tWR | 15ns | 15ns | 15ns | 手册要求15ns，MR编码由IP生成 |
| tRTP/tWTR | IP按至少4CK处理 | 10/10ns | 10/10ns | 满足max(4CK,7.5ns) |
| tXPR | 约360ns | 270ns | 270ns | ≥tRFC+10ns且≥5CK |
| tZQCS | ≥64CK | 160ns=64CK | 80ns=64CK | 校准等待需按当前CK检查 |
| tZQINIT | ≥512CK | 1280ns=512CK | 640ns=512CK | 生成参数可能用UI周期表示，不能误读为DDR周期 |

额外校验生成RTL的初始MR0/MR1/MR2：CL/CWL、固定BL8、顺序突发、DLL开启和ODT编码均检查通过，详见parameter_validation.json。XCI中某些旧模型占位字段为0，不能据此说实际CL/CWL为0。

这是一套可审计、保守时序的匹配配置；包括内部组件建模与部分等待参数变化，不是只改型号字符串。重新构建也改变了布局布线，因此即使之后结果改善，也不能单独证明颗粒型号选择是唯一原因。尚未证明其能消除DQ9错误。原配置在800下多项等待本来就满足或更保守，型号差异不能直接当作故障根因。

## 能否继续降频

实物DLL开启模式最长tCK=3.3ns，理论最低约606MT/s。但当前xcvu9p-flga2104-2L-e的Vivado配置验证限制tCK≤2666ps，约750MT/s。query_640_console.log显示640MT/s(3125ps)被拒绝，不能强行绕过此限制。

query_769_console.log确认tCK=2600ps、参考4000ps、CL6/CWL5、MT41K512M8DA-107配置成功生成MIG，对应约769.23MT/s，UI约96.154MHz。这个探索仅做IP生成，未综合/布线/生成Flash，未上板；应用UART及计时也未为此频率调整。800以下可探索空间很小，不能声称当前工程支持640/400MT/s。

## 构建与导出

```bash
VIVADO/scripts/build_vrp.sh 800 bitstream 2
VIVADO/scripts/generate_vrp_flash.sh 800
VIVADO/scripts/build_vrp.sh 1600 bitstream 2
VIVADO/scripts/generate_vrp_flash.sh 1600
```

最终必须检查生成MIG实际参数、时序/DRC、完整布线、50根引脚、bitstream与双MCS校验和/容量/SHA256，再将第1项标为完成。应用逻辑仿真不包含DDR3 PHY或外部芯片电气模型。此次用户授权范围止于生成Flash文件，尚无本修订版上板结论。


## 最终文件验收：第1项完成

两版均已完成综合、布局布线、bitstream、SPIx8双MCS生成与逐行Intel HEX长度/校验和/连续地址/容量检查；build_manifest.json记录源码/产物SHA256及生成参数。几何及初始MR编码检查通过。沿用paired RTL的100/200MHz应用仿真、UART和解析器检查通过；没有DDR3 PHY或板级模拟模型。旧HELLOWORLD/stress/diagnostic/probe/paired源码及镜像按已有清单核对保持原散列，旧probe校验脚本已知清单维护差异继续明确记录。

| 速率 | WNS | WHS | 双Flash实际数据合计 |
| --- | --- | --- | --- |
| 800 MT/s | +1.626 ns | +0.013 ns | 21,649,004 B（20.65 MiB） |
| 1600 MT/s | +0.310 ns | +0.010 ns | 22,276,628 B（21.24 MiB） |

两版DRC均为0错误、4项厂商IP警告（PDCN-1569三项、RTSTAT-10一项）；未增加数据路径时序例外。综合日志仍有UltraRAM性能建议，最终时序通过。每颗Flash容量128MiB，文件占用远小于容量。

可烧写文件：

- VIVADO/vrp_800_build/ddr3_vrp_pair_800_primary.mcs
- VIVADO/vrp_800_build/ddr3_vrp_pair_800_secondary.mcs
- VIVADO/vrp_1600_build/ddr3_vrp_pair_1600_primary.mcs
- VIVADO/vrp_1600_build/ddr3_vrp_pair_1600_secondary.mcs

每次只选同速率配套两份；PRM不用选。此次仅生成文件，没有访问开发板或烧写本修订版，尚无新板级数据结果。下一次优先烧写修订800版，保持原paired测试方法，完整保存新日志后比较DQ9错误。1600修订版用于后续相同测试和匹配颗粒配置下的速率对照，不是要求先上1600；不同布局布线和控制器参数变化仍是比较限制。
