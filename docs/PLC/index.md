# PLC 首页

> 面向信创平台（银河麒麟 V11 / 国产 CPU / Linux）的 .NET 8 西门子 PLC 上位机通信知识地图，坚持「通用报文协议优先、驱动可替换」。

本组文档围绕「跨平台 PLC 数据采集与通信」展开，技术路线明确：**优先采用标准化、开放的通用报文协议**——Modbus TCP、ISO-on-TCP（RFC 1006）之上自建或开放帧、OPC UA；把 Siemens S7 私有协议仅作为对比与遗留兼容项客观说明，不推荐在新建项目主链路中直接绑定。核心设计是「协议抽象层 + 可替换驱动」：`IPlcClient` 定义连接、读写、释放与重连语义，`IPlcFrameCodec` 负责报文编解码，业务层只依赖抽象，国产化环境与具体设备差异被隔离在驱动实现里。内容偏工程实践：报文结构与字节序、超时与重连、线程安全、采集任务调度，并结合信创落地约束，不做入门科普。

## 本组文档

| 文档 | 内容 | 重点 |
| --- | --- | --- |
| [PLC 首页](index.md) | 分组知识地图、技术选型对比、学习路径 | 通用协议优先的路线与选型立场 |
| [Modbus](Modbus.md) | Modbus TCP 报文、MBAP 头、功能码、字节序 | 首选开放协议的 C# 编解码与排错 |
| [西门子 PLC](Siemens.md) | S7 通信族对比、ISO-on-TCP 开放帧、抽象层设计 | 规避 S7 私有协议绑定，落地接口设计 |
| [串口通信](SerialPort.md) | 串口 / Modbus RTU、帧边界、CRC、跨平台设备路径 | 无网络场景下的串行链路 |
| [数据采集](DataAcquisition.md) | 采集调度、线程安全、超时重连、缓冲与落库 | 长期运行的上位机运行时架构 |

## 技术选型对比

| 维度 | Modbus TCP | ISO-on-TCP 开放帧 | OPC UA | S7 私有协议 |
| --- | --- | --- | --- | --- |
| 标准化程度 | 公开事实标准，报文规范可查 | 传输基于 RFC 1006，帧语义项目自定义 | IEC 62541 国际标准 | 厂商私有、未公开，社区逆向 |
| 跨平台 | 纯 TCP，任意平台可自研 | TCP 102，纯托管可实现 | 跨平台，需验证 SDK 国产架构包 | 依赖厂商 / 第三方库二进制 |
| 厂商锁定 | 无 | 低（传输标准化，帧自控） | 无 | 高，绑定西门子生态与固件版本 |
| 实现成本 | 低，可自研且可抓包核对 | 中，需自定义并文档化帧规范 | 中高，依赖协议栈 / SDK | 低（现成库）但长期受制于人 |
| 信创适配 | 优 | 优 | 良（需实测国产 CPU 兼容） | 差（闭源库常无 aarch64 / loongarch64 构建） |

综合结论：新建信创上位机的默认组合是「Modbus TCP 主链路 + ISO-on-TCP 开放帧备用 + OPC UA 视设备支持」，S7 私有协议仅留在兼容清单；四类方案都通过 `IPlcClient` 注入，切换协议不改业务代码。

!!! note "选型立场（重要）"
    在信创与国产化项目里，**不绑定厂商私有协议是底线**：优先 Modbus TCP 与 ISO-on-TCP 之上自建开放帧，设备原生支持时选 OPC UA；S7 私有协议仅用于遗留系统兼容评估与迁移期旁路，不纳入新建项目主链路。抽象层与驱动替换方案见 [西门子 PLC](Siemens.md)。

## 学习路径

1. 先读 [Modbus](Modbus.md)：掌握通用报文、大端序、MBAP 与功能码的 C# 编解码，建立「报文即字节」的工程思维。
2. 再看 [西门子 PLC](Siemens.md)：理解 S7 通信族差异，落地 `IPlcClient` / `IPlcFrameCodec` 抽象层与可替换驱动。
3. 接着 [串口通信](SerialPort.md)：处理 RTU 帧边界、CRC 与 Linux 设备路径，覆盖无以太网或串口网关场景。
4. 然后 [数据采集](DataAcquisition.md)：把单点读写扩展为任务调度、线程安全、重连与持久化的完整上位机。
5. 回到本页对照「技术选型对比」，按设备实际能力与等保要求确定最终协议组合。

## 与其他分组的关系

- [C# 异步编程](../CSharp/Async.md)：`async/await`、`CancellationToken`、超时与取消是通信和采集的公共基础。
- [Avalonia](../Avalonia/index.md)：跨平台桌面 UI，承载上位机监控画面与实时曲线。
- [数据库](../Database/index.md)：采集数据的时序存储、批量写入与归档。
- [银河麒麟 V11](../DevOps/KylinV11.md)：信创操作系统部署、国产 CPU、systemd 服务与网络策略。

## 参考链接

- modbus.org《MODBUS Messaging on TCP/IP Implementation Guide》与《MODBUS Application Protocol》
- RFC 1006《ISO Transport Service on top of the TCP》、ISO/IEC 8073（COTP）
- OPC Foundation：IEC 62541 / OPC UA 规范
- Microsoft .NET 8 文档：`System.Net.Sockets`、`System.Buffers.Binary.BinaryPrimitives`、`System.Threading.Channels`
- 具体 PLC 型号、寄存器映射、端口与握手要求一律以设备手册和现场抓包为准
