# Modbus

| 文档信息 | 内容 |
| --- | --- |
| 分类 | PLC / 工业控制 |
| 主题 | Modbus TCP 通用报文协议与 C# 实现 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Modbus TCP 是本知识库在信创上位机项目中的**首选通用报文协议**：规范公开、无授权与厂商锁定、纯 TCP 传输，在银河麒麟 V11 + 国产 CPU 上只需 .NET 8 的 `System.Net.Sockets` 即可自研驱动。模型为主从（客户端/服务器）：上位机发请求、PLC 或网关应答，一次请求对应一次应答，事务标识符（Transaction ID）用于匹配乱序 / 重发后的响应。寄存器分线圈、离散输入、保持寄存器（0x03 读 / 0x10 写）与输入寄存器（0x04）；地址是零基偏移，手册里的 4xxxx 需换算，映射一律以设备手册为准。

!!! note "为什么优先 Modbus TCP"
    它把协议降为一张公开字节表：不依赖厂商 SDK，报文可自研、可抓包核对、可在国产架构上自由编译。这是「规避厂商专有协议绑定」最落地的一层，也是 [西门子 PLC](Siemens.md) 抽象层的默认驱动。

## 报文与协议要点

报文 = MBAP 头（7 字节）+ PDU（功能码 + 数据），默认 TCP 端口 **502**。所有多字节字段为**大端序（网络字节序）**，用 `BinaryPrimitives.WriteUInt16BigEndian` 处理，切勿用 `BitConverter`（受宿主机字节序影响，国产 CPU 多为小端 ARM / 飞腾 / 鲲鹏，必踩坑）。0x10 写多个寄存器请求的 PDU = FC(1) + 起始(2) + 数量(2) + 字节数(1) + 数据(N*2)，响应回显起始地址与数量；单次 0x03 数量上限以设备手册为准。

| 字段 | 偏移 | 长度 | 说明 |
| --- | --- | --- | --- |
| 事务标识符 TID | 0 | 2 | 请求 / 响应配对，自增即可 |
| 协议标识符 PID | 2 | 2 | 恒为 0x0000 |
| 长度 Length | 4 | 2 | 其后字节数 = Unit ID(1) + PDU |
| 单元标识符 Unit ID | 6 | 1 | 网关下游从站号，纯 TCP 常为 0xFF 或 0x01 |
| 功能码 FC | 7 | 1 | 0x03 读保持 / 0x10 写多个 / 0x04 读输入 |
| 数据 | 8.. | N | 起始地址、数量、字节数、寄存器值，均大端 |

```text
0x03 读保持寄存器（起始 0x0000，读 2 个），共 12 字节
  请求: 00 01 | 00 00 | 00 06 | 01 | 03 | 00 00 | 00 02
  响应: 00 01 | 00 00 | 00 07 | 01 | 03 | 04 | D0 D1 D2 D3
        TID      PID      LEN     UID   FC   BC   寄存器值(大端)
异常响应: FC 最高位置 1(0x83) + 1 字节异常码(0x02 非法数据地址)
```

## 关键用法与代码示例

编解码与传输分离，便于替换驱动；用 `Span<byte>` 原地写入避免中间分配。

```csharp
using System.Buffers.Binary;

public static class ModbusCodec
{
    public static byte[] BuildRead(ushort tid, byte unitId, ushort start, ushort qty)
    {
        byte[] frame = new byte[7 + 5]; // MBAP(7) + PDU: FC(1)+Addr(2)+Qty(2)
        Span<byte> s = frame;
        BinaryPrimitives.WriteUInt16BigEndian(s[0..2], tid);
        BinaryPrimitives.WriteUInt16BigEndian(s[2..4], 0x0000);
        BinaryPrimitives.WriteUInt16BigEndian(s[4..6], (ushort)(1 + 5)); // LEN = UID + PDU
        s[6] = unitId; s[7] = 0x03;
        BinaryPrimitives.WriteUInt16BigEndian(s[8..10], start);
        BinaryPrimitives.WriteUInt16BigEndian(s[10..12], qty);
        return frame;
    }
    public static ushort[] ParseRegisters(ReadOnlySpan<byte> response)
    {
        if ((response[7] & 0x80) != 0)
            throw new InvalidOperationException($"Modbus 异常码 0x{response[8]:X2}");
        ReadOnlySpan<byte> data = response.Slice(9, response[8]); // BC 在偏移 8
        var values = new ushort[data.Length / 2];
        for (int i = 0; i < values.Length; i++)
            values[i] = BinaryPrimitives.ReadUInt16BigEndian(data.Slice(i * 2, 2));
        return values;
    }
}
```

网络读写必须「先读定长 7 字节 MBAP，再按 Length 读剩余」，不能假定一次 `ReadAsync` 读满；用 `CancellationToken` 串起超时与取消。

```csharp
using System.Buffers.Binary;
using System.Net.Sockets;

public sealed class ModbusTcpClient
{
    private readonly TcpClient _tcp = new();
    private ushort _tid;
    public async Task ConnectAsync(string host, int port, CancellationToken ct)
    {
        await _tcp.ConnectAsync(host, port, ct).ConfigureAwait(false); // 端口 502
        _tcp.NoDelay = true;
    }
    public async Task<ushort[]> ReadAsync(byte unitId, ushort start, ushort qty, CancellationToken ct)
    {
        NetworkStream ns = _tcp.GetStream();
        ushort tid = ++_tid;
        await ns.WriteAsync(ModbusCodec.BuildRead(tid, unitId, start, qty), ct).ConfigureAwait(false);
        byte[] mbap = new byte[7];
        await ns.ReadExactlyAsync(mbap, ct).ConfigureAwait(false);
        ushort respTid = BinaryPrimitives.ReadUInt16BigEndian(mbap.AsSpan(0, 2));
        ushort len = BinaryPrimitives.ReadUInt16BigEndian(mbap.AsSpan(4, 2));
        if (respTid != tid) throw new InvalidDataException("事务 ID 不匹配，帧已错位");
        byte[] pdu = new byte[len - 1]; // LEN 含 1 字节 UID，余下为 PDU
        await ns.ReadExactlyAsync(pdu, ct).ConfigureAwait(false);
        byte[] full = new byte[7 + pdu.Length];
        mbap.CopyTo(full, 0); pdu.CopyTo(full, 7);
        return ModbusCodec.ParseRegisters(full);
    }
}
```

## 常见坑与排查

- **帧错位**：不校验 TID 时，一次超时后的迟到响应会污染后续请求，表现为数据整体错位；校验 TID / PID / LEN，错位即丢弃并重建连接。
- **字节序**：`BitConverter` 在小端国产 CPU 上把 0x0001 写成 `01 00`，读到完全错误的寄存器；一律用 `BinaryPrimitives` 大端 API。
- **半包 / 粘包**：TCP 是字节流，`ReadAsync` 不保证读满，必须 `ReadExactlyAsync`（.NET 8）或自写循环。
- **地址偏移**：手册 40001 对应偏移 0x0000，「1 基」与「0 基」混用是最高频现场问题；数量上限与映射以设备手册为准。
- 排错顺序：先用 Wireshark（自带 Modbus/TCP 解析）核对报文，再调 C# 代码，别靠猜。

## 信创与跨平台注意事项

银河麒麟 V11 + 国产 CPU 上，`System.Net.Sockets` 与 `System.Buffers.Binary` 均为纯托管实现，无平台差异；注意国产防火墙 / 等保策略可能限制 502 端口，需与安全管理员确认放通。高频采集用 `ArrayPool<byte>` 复用缓冲降低 GC 压力，长连接设 `NoDelay = true` 降低小报文时延；经串口 / 协议网关转接时 Unit ID 常对应下游从站号，超时阈值须现场实测。部署为 systemd 服务的工作目录与日志权限见 [数据采集](DataAcquisition.md) 与 [银河麒麟 V11](../DevOps/KylinV11.md)。

## 参考链接

- modbus.org《MODBUS Messaging on TCP/IP Implementation Guide》《MODBUS Application Protocol》
- Microsoft .NET 8 API：`BinaryPrimitives`、`Stream.ReadExactlyAsync`、`TcpClient`；Wireshark · Modbus/TCP dissector

## 相关页面

- [返回分组首页](index.md)
- [西门子 PLC](Siemens.md)
- [串口通信](SerialPort.md)
- [数据采集](DataAcquisition.md)
