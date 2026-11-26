# 串口通信

| 文档信息 | 内容 |
| --- | --- |
| 分类 | PLC / 工业控制 |
| 主题 | 跨平台串口链路与 Modbus RTU 帧处理 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

当 PLC、仪表或网关只提供 RS-485 / RS-232，或现场无以太网时，串口是必需通道。.NET 8 用 `System.IO.Ports.SerialPort` 访问串口（Linux 侧基于 termios），信创平台设备路径为 `/dev/ttyS*`（板载 UART）、`/dev/ttyUSB*`（USB 转串口）、`/dev/ttyAMA*`（部分 ARM 板），与 Windows 的 `COMx` 完全不同，必须外部化配置。串口上最常用的开放协议是 Modbus RTU：主从、二进制帧、靠总线静默间隔分帧、CRC16 校验；它与 [Modbus](Modbus.md) TCP 的 PDU 一致，只是把 MBAP 头换成了「从站地址 + CRC」。RTU 半双工、受波特率限制，多从站轮询的超时与调度见 [数据采集](DataAcquisition.md)。

!!! note "优先 TCP 还是 RTU"
    有条件优先 Modbus TCP（[Modbus](Modbus.md)）；串口作为无网络场景与串口网关的补充，不要因为「现场有串口」就把主链路设计成 RTU。

## 报文与协议要点

| 项 | Modbus RTU | Modbus TCP |
| --- | --- | --- |
| 分帧 | ≥ 3.5 个字符时间的静默 | MBAP Length 字段 |
| 寻址 | 1 字节从站地址 | MBAP Unit ID + IP |
| 校验 | CRC16，低字节在前 | 无（依赖 TCP 校验和） |

```text
0x03 读保持寄存器（从站 0x01，起始 0x0000，数量 0x0002）
  请求: 01 03 00 00 00 02 CRC_L CRC_H
  响应: 01 03 04 D0 D1 D2 D3 CRC_L CRC_H（寄存器值仍大端）
  异常: 01 83 02 CRC_L CRC_H（FC 最高位置 1 + 异常码）；帧间 ≥ 3.5 字符静默
```

## 关键用法与代码示例

CRC16（多项式 0xA001、初值 0xFFFF）覆盖从站地址到数据全部字节，发送时**低字节在前**，与地址 / 寄存器值的「大端」方向相反，是最高频的字节序坑；波特率、数据位 8、校验位、停止位以设备手册为准。响应采用「先读 3 字节头（地址 / FC / 字节数），再读剩余数据 + CRC」以兼容异常短帧，Linux 上用 `BaseStream` 主动按长度读取而非 `DataReceived` 事件。

```csharp
public static class Crc16
{
    public static ushort Compute(ReadOnlySpan<byte> data)
    {
        ushort crc = 0xFFFF;
        foreach (byte b in data)
        {
            crc ^= b;
            for (int i = 0; i < 8; i++)
                crc = (crc & 1) != 0 ? (ushort)((crc >> 1) ^ 0xA001) : (ushort)(crc >> 1);
        }
        return crc;
    }
    public static void Append(Span<byte> frame, ReadOnlySpan<byte> body)
    {
        ushort crc = Compute(body);
        frame[body.Length] = (byte)(crc & 0xFF); frame[body.Length + 1] = (byte)(crc >> 8); // CRC_L 先发、CRC_H 后发
    }
}
```

```csharp
using System.Buffers.Binary;
using System.IO.Ports;
public sealed class RtuLink : IDisposable
{
    private readonly SerialPort _port;
    public RtuLink(string device, int baudRate = 9600)
    {
        _port = new SerialPort(device, baudRate, Parity.None, 8, StopBits.One)
        { ReadTimeout = 500, WriteTimeout = 500, Handshake = Handshake.None };
        _port.Open();
    }
    public async Task<byte[]> ReadExactAsync(int count, CancellationToken ct)
    {
        byte[] buffer = new byte[count];
        int offset = 0;
        while (offset < count)
        {
            int n = await _port.BaseStream.ReadAsync(buffer.AsMemory(offset), ct).ConfigureAwait(false);
            if (n == 0) throw new EndOfStreamException("串口超时或设备无响应");
            offset += n;
        }
        return buffer;
    }
    public async Task<ushort[]> ReadHoldingAsync(byte slave, ushort start, ushort qty, CancellationToken ct)
    {
        byte[] body = new byte[6];
        body[0] = slave; body[1] = 0x03;
        BinaryPrimitives.WriteUInt16BigEndian(body.AsSpan(2, 2), start);
        BinaryPrimitives.WriteUInt16BigEndian(body.AsSpan(4, 2), qty);
        byte[] frame = new byte[8];
        body.CopyTo(frame, 0);
        Crc16.Append(frame, body);
        await _port.BaseStream.WriteAsync(frame, ct).ConfigureAwait(false);
        await _port.BaseStream.FlushAsync(ct).ConfigureAwait(false);
        byte[] head = await ReadExactAsync(3, ct).ConfigureAwait(false);
        if ((head[1] & 0x80) != 0)
            throw new InvalidOperationException($"Modbus 异常码 0x{head[2]:X2}");
        byte[] tail = await ReadExactAsync(head[2] + 2, ct).ConfigureAwait(false);
        byte[] resp = new byte[3 + tail.Length];
        head.CopyTo(resp, 0); tail.CopyTo(resp, 3);
        ushort crc = (ushort)(resp[^2] | (resp[^1] << 8));
        if (Crc16.Compute(resp.AsSpan(0, resp.Length - 2)) != crc)
            throw new InvalidDataException("RTU CRC 校验失败");
        var values = new ushort[qty];
        for (int i = 0; i < qty; i++)
            values[i] = BinaryPrimitives.ReadUInt16BigEndian(resp.AsSpan(3 + i * 2, 2));
        return values;
    }
    public void Dispose() => _port.Dispose();
}
```

## 常见坑与排查

- **CRC 方向**：CRC 低字节先发，寄存器值高字节先发；两者方向相反，拼错表现为「偶尔校验通过但值乱码」。
- **异常短帧**：固定长度读取会在 `01 83 02 ...`（5 字节）上卡住；必须先读 3 字节头再按字节数读剩余。
- **静默间隔、权限与路径**：高波特率下按长度 + `ReadTimeout` + `CancellationToken` 读取；Linux 用户需加入 `dialout` 组（以发行版为准），`dmesg` 查 CH340 / CP210x / FTDI 驱动；热插拔后 `ttyUSB0` 可能变 `ttyUSB1`，用 `/dev/serial/by-id/...` 固定路径；不要既挂 `DataReceived` 又用 `BaseStream.ReadAsync`，会竞争缓冲区丢字节。RS-485 半双工需确认方向控制并留足帧间延时。

## 信创与跨平台注意事项

银河麒麟 V11 + 国产 CPU 主板的 UART 命名（`ttyS` / `ttyAMA`）与设备树相关，设备路径必须写进配置而非硬编码；`SerialPort` 在 .NET 8 各平台对 `Handshake`、`DtrEnable` 等支持存在差异，以实测为准。系统服务以相应串口组权限运行、日志进 journald；长时间运行注意句柄释放与热插拔后的重枚举、重连（见 [数据采集](DataAcquisition.md) 与 [银河麒麟 V11](../DevOps/KylinV11.md)），等保场景还需记录串口访问审计。

## 参考链接

- modbus.org《MODBUS over Serial Line Specification and Implementation Guide》；Microsoft .NET 8 API：`SerialPort`、`SerialPort.BaseStream`；Linux `termios` 与 `/dev/serial/by-id/`，参数以设备手册为准

## 相关页面

- [返回分组首页](index.md)
- [Modbus](Modbus.md)
- [西门子 PLC](Siemens.md)
- [数据采集](DataAcquisition.md)
