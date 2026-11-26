# 西门子 PLC

| 文档信息 | 内容 |
| --- | --- |
| 分类 | PLC / 工业控制 |
| 主题 | 西门子 PLC 通信族对比与协议抽象层设计 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

西门子 PLC 的以太网通信是分层栈：底层以太网 / Profinet，传输层是 ISO-on-TCP（RFC 1006，TCP 端口 **102**），应用层是 S7 协议（S7Comm / S7CommPlus）。S7 私有协议未公开，依赖社区逆向与第三方库；S7-1200 / 1500 的 S7CommPlus 还引入会话与加密握手，第三方适配更滞后。本知识库的立场：S7 私有协议只作对比与遗留兼容评估，新建项目主链路不直接绑定；优先 Modbus TCP、ISO-on-TCP 之上自建开放帧、OPC UA。落地手段是「协议抽象层 + 可替换驱动」——`IPlcClient` 定义连接 / 读写 / 释放语义，`IPlcFrameCodec` 负责编解码，业务层只依赖接口，驱动通过组合根注入（ModbusTcpDriver / IsoOnTcpDriver / OpcUaDriver / 遗留 S7CompatDriver）。

| 层级 | 协议 | 标准化 / 建议 |
| --- | --- | --- |
| 应用 | 自建开放帧 / OPC UA | 自控 / IEC 62541，首选 |
| 应用 | S7Comm / S7CommPlus | 厂商私有、未公开，仅遗留兼容 |
| 传输 | ISO-on-TCP（RFC 1006） | 公开，可自研承载开放帧 |

## 报文与协议要点

ISO-on-TCP 的骨架是 TPKT（RFC 1006）+ COTP（ISO/IEC 8073）：TPKT 头 4 字节（版本 0x03、保留 0x00、长度 2 字节大端，含 4 字节头自身），随后是 COTP DT 数据帧（LI、PDU 类型 0xF0、TPDU 号 / EOT 0x80），再往后是用户数据。把「自建开放帧」放在用户数据区：自定义帧头（版本 / 命令 / 序号 / 长度）+ 负载 + 校验，语义自控、可抓包、无厂商依赖；字节序统一大端并写成版本化规范文档，避免「口头协议」。

```text
ISO-on-TCP 报文骨架（TCP 102，RFC 1006）
  TPKT:  03 00 | Len(2B 大端，含 4B 头)
  COTP:  LI(1B) | F0(DT Data) | 80(EOT=1) | 用户数据
  开放帧: Ver(1) Cmd(1) Seq(2B 大端) Len(2B 大端) Payload(N) CRC(2B)
解析以 TPKT Length 为准，跳过 LI / F0 / 80 后交给 IPlcFrameCodec
```

!!! warning "不要在新项目主链路绑定 S7 私有协议"
    S7Comm / S7CommPlus 未公开且随固件变更，S7-1500 的会话机制让第三方库适配滞后；闭源驱动常只提供 x86 / Windows 二进制，在国产 CPU + 银河麒麟上可能无对应构建。把它限定在遗留系统兼容评估与迁移期旁路。与设备原生 ISO 连接对接时 COTP 常需先完成 CR / CC 建立，DT 帧的 LI 在部分实现中固定为 0x02（仅计 F0 80），务必现场抓包核对。

## 关键用法与代码示例

接口把「报文编解码」与「传输通道」拆开，Codec 实现为同步纯函数；业务层只持有 `IPlcClient`，启动时按配置注入实现类（`IsoOnTcpDriver` / `ModbusTcpDriver` / `OpcUaDriver`），迁移换设备不改业务代码。下方为驱动的关键片段，完整类还需实现 `IPlcClient` 的 `ConnectAsync` / `ReadAsync` / `WriteAsync` / `DisposeAsync`。

```csharp
public readonly record struct PlcAddress(string Area, ushort Offset, ushort Length);
public readonly record struct PlcRequest(PlcAddress Address, ushort Command);
public readonly record struct PlcResponse(ushort Sequence, ReadOnlyMemory<byte> Payload);

// 业务层只依赖抽象：连接、读写、释放与重连语义
public interface IPlcClient : IAsyncDisposable
{
    Task ConnectAsync(CancellationToken ct = default);
    Task<ReadOnlyMemory<byte>> ReadAsync(PlcAddress address, CancellationToken ct = default);
    Task WriteAsync(PlcAddress address, ReadOnlyMemory<byte> data, CancellationToken ct = default);
}

// 换协议 = 换 Codec + 换驱动，业务代码零改动
public interface IPlcFrameCodec
{
    ReadOnlyMemory<byte> Encode(PlcRequest request, ReadOnlyMemory<byte> payload);
    PlcResponse Decode(ReadOnlySpan<byte> frame);
}
```

驱动片段：TPKT / COTP 封装 + 一次交换，长度字段全部大端；async 方法内不声明 `Span<byte>` 局部变量（.NET 8 / C# 12 不允许跨 await 持有 ref struct），编码在 await 之前完成。

```csharp
using System.Buffers.Binary;
using System.Net.Sockets;

public sealed class IsoOnTcpDriver
{
    private readonly TcpClient _tcp = new();
    private readonly IPlcFrameCodec _codec;
    public IsoOnTcpDriver(IPlcFrameCodec codec) => _codec = codec;

    private static byte[] Wrap(ReadOnlySpan<byte> userData)
    {
        int total = 7 + userData.Length; // TPKT(4)+LI(1)+DT 头(2)+数据
        byte[] f = new byte[total];
        Span<byte> s = f;
        s[0] = 0x03; s[1] = 0x00;       // TPKT Version / Reserved
        BinaryPrimitives.WriteUInt16BigEndian(s[2..4], (ushort)total); // 含 4 字节头
        s[4] = (byte)(2 + userData.Length); // LI：其后字节数（自建规范）
        s[5] = 0xF0; s[6] = 0x80;       // COTP DT Data / EOT=1
        userData.CopyTo(s[7..]);
        return f;
    }
    public async Task<PlcResponse> ExchangeAsync(PlcRequest req, CancellationToken ct)
    {
        byte[] frame = Wrap(_codec.Encode(req, ReadOnlyMemory<byte>.Empty).Span);
        NetworkStream ns = _tcp.GetStream();
        await ns.WriteAsync(frame, ct).ConfigureAwait(false);
        byte[] tpkt = new byte[4];
        await ns.ReadExactlyAsync(tpkt, ct).ConfigureAwait(false);
        int total = BinaryPrimitives.ReadUInt16BigEndian(tpkt.AsSpan(2, 2));
        byte[] rest = new byte[total - 4];
        await ns.ReadExactlyAsync(rest, ct).ConfigureAwait(false);
        return _codec.Decode(rest.AsSpan(3)); // 跳过 LI / 0xF0 / 0x80
    }
}
```

## 常见坑与排查

- 把 S7 私有协议当主链路：固件升级（尤其 S7-1500 的 S7CommPlus 会话）会让第三方库失效，闭源库常无国产架构二进制。
- ISO-on-TCP 连接需先完成 COTP CR / CC（Class 0），部分网关 / 设备要求握手后才收 DT；对接前抓包确认。
- TPKT Length 与 LI 解析口径不一致导致半包；统一以 TPKT Length 定长读取；TCP 102 还需在防火墙与设备侧放行，以设备手册为准。
- `NetworkStream` 非线程安全，多采集点必须串行化请求（见 [数据采集](DataAcquisition.md)）；async 方法里声明 `Span<byte>` 局部变量会触发编译错误（CS4012）。

## 信创与跨平台注意事项

国产 CPU（aarch64 / loongarch64 / x86_64）上优先纯托管实现，避免依赖带原生二进制的厂商 SDK；OPC UA 若设备支持，选有跨平台 .NET 栈的实现并实测国产架构可运行。自建开放帧必须有版本化规范文档（命令字、字节序、校验、错误码），便于长期维护与等保测评材料。银河麒麟上以 systemd 部署、端口放通、日志审计详见 [银河麒麟 V11](../DevOps/KylinV11.md)；采集数据落库见 [数据库](../Database/index.md)。

## 参考链接

- RFC 1006《ISO Transport Service on top of the TCP》、ISO/IEC 8073（COTP）；Wireshark · S7Comm / TPKT dissector
- Microsoft .NET 8 文档：`System.Net.Sockets`、`BinaryPrimitives`、`IAsyncDisposable`；会话握手与端口以设备手册为准

## 相关页面

- [返回分组首页](index.md)
- [Modbus](Modbus.md)
- [串口通信](SerialPort.md)
- [数据采集](DataAcquisition.md)
