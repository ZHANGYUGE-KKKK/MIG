# VCU118 DDR3低负载数据位测试：Block Design工程

工具验收及限制见[RESULTS.md](RESULTS.md)。

本工程采用Vivado 2022.2 IP Integrator，顶层是生成的`wiring_wrapper`，实际设计保存在`wiring.bd`。应用没有CPU。内容是当前第一项数据位测试，不包含DM验证或全容量地址唯一性测试。

## 图形界面打开

打开`build/project/wiring_bd.xpr`，在IP Integrator中选择Open Block Design → `wiring`。双击`mig`可查看和配置DDR3 IP；其他自定义模块可查看参数或对应RTL。

实际Vivado导出的BD图：[SVG](build/wiring.svg)、[PNG预览](build/wiring.png)。

| BD模块 | 用途 |
|---|---|
| clocks_resets | 250 MHz差分时钟接收、BUFG、上电复位和UI域复位同步 |
| test_engine | 行走1/0、全0/1、AA/55数据位测试及错误统计 |
| native_axi | 单事务原生格式→AXI4转换，AXI直连MIG，无interconnect |
| mig | DDR3控制器、PHY及厂商内部校准逻辑 |
| uart | 115200、8N1，输出DPIN v1记录 |

Vivado 2022.2的内置DDR3 IP在BD模式下强制启用AXI接口（安装目录`ddr3_v1_4/xgui/ddr3_v1_4.tcl`的`update_ddr_AxiSelection`）。因此加入转换模块，保持原测试引擎源码不变。MIG内置校准模块仍含厂商内部固件处理器，不是用户应用CPU。

## 测试条件

- 外接子板U26：MT41K512M16VRP-107 IT:P，单rank、x16、1 GiB；本工程不使用母板DDR4。
- DDR总线800 MT/s，CK 400 MHz；UI 100 MHz；母板Si570参考250 MHz，保持用户已保存的时钟和1.5 V设置。
- 32个地址：native格式基值0、0x1fffffc0、0x10000000、0x2000，各加0、8、…、56，包含首末突发并覆盖全部8个Bank。
- 每地址260个模式：128位行走1、128位行走0，以及全0、全1、AA、55。总8320写和8320读，覆盖16个DQ×8拍。
- 单笔在途读。写响应成功并向测试引擎确认后额外等100个UI周期，再请求读；读返回比较后也额外等100周期。降低的是事务频率，DDR电气速率仍为800 MT/s。
- 转换采用AXI4 128位、30位字节地址、ID宽1、单拍16字节、INCR、SIZE=4、LEN=0。字节地址=原native格式地址×2，最高测试地址为0x3ffffff0；AXI映射0起始、范围1 GiB。
- AW和W独立握手，B响应成功后才向测试引擎确认写完成。BRESP/BID异常停止转换并由引擎无进展超时报错；RRESP/RID/RLAST异常以非法读结束上报。MIG UI复位独立报告，不能静默抹掉测试统计。
- GPIO LED7仍直接连接MIG校准完成信号（BA37），亮灯不代表数据PASS。

AXI和MIG原生UI均为128位，生成RTL选择NO_UPSIZER，写/读数据不作位重排；命令地址转换右移1位，与桥接的×2互相抵消。因此保留原DPIN包的UI位/DQ/拍定义。图形工程引入AXI和新布局，不能直接将错误总数与旧RTL镜像归因比较。

## 生成和验收

```bash
./vivado2/scripts/build.sh
```

脚本执行应用及桥接仿真、BD创建/校验、综合、布局布线、bitstream、双MCS生成和产物校验。全部运行时源码、CSV、约束均位于本目录；依赖本机Vivado 2022.2、Verilator和Python3，正常构建不读取旧工程。`config/reference_*`和`provenance.json`保存已核实800配置/引脚及复制源码的散列作为验收基准。

产物：

- `build/wiring_bd_800.bit`
- `build/wiring_bd_800_primary.mcs`
- `build/wiring_bd_800_secondary.mcs`
- `build/build_manifest.json`：参数对比、引脚、源码/产物SHA256和仿真记录。

**首次交付仅生成Flash文件；用户随后已授权烧写，最新状态见[RESULTS](RESULTS.md)。** 两个MCS是同一SPIx8镜像的分片，今后需成对烧写；PRM不是额外烧写文件。两颗Flash各128 MiB，生成脚本校验压缩、SPIx8和31.9 MHz设置。

图像导出需图形会话，可在有DISPLAY的终端运行Vivado GUI并使用`scripts/export_diagram.tcl`；它只读打开工程并导出SVG，不访问硬件。脚本不包含Flash编程或在线下载命令。

## 串口及判断边界

协议沿用DPIN v1：`D`加8个64位十六进制字段，头部魔数4450494E。每模式输出结果，首错样本每模式最多8条，最后输出128位错误直方图和DONE。完整无错日志为422条记录，正常串口发送约5.1秒，另有校准时间。有限运行结束后不自动重复。

```bash
python3 vivado2/tests/decode.py /path/to/raw.log --output /path/to/result.json
```

`complete`与`data_pass`分开：必须记录完整、8320写读均完成且0错才能判本测试PASS。UART协议与旧RTL DPIN相同，不能仅由包头区分镜像，应以MCS SHA256及烧写操作记录关联。

仿真不含实际DDR PHY、模拟信号完整性或实物DDR颗粒模型。图样回环即使通过，也不能排除可逆DQ/地址置换；严格逐针线序还需原理图/PCB端点与断电导通核对。全容量和DM测试属于后续项目。

**硬件约束：JTAG与DDR链路无法共存。** 今后只在DDR断开时烧写Flash；完全断电后接回DDR，从Flash启动并采集串口，保持现有SW16设置。
