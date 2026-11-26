# 数据采集

| 文档信息 | 内容 |
| --- | --- |
| 分类 | PLC / 工业控制 |
| 主题 | 上位机采集调度、线程安全、重连与持久化 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

把单点读写（[Modbus](Modbus.md)、[西门子 PLC](Siemens.md)）组织成长期运行的上位机：周期轮询、多采集点、异常恢复、数据落地。四条硬约束：① 单条 TCP / 串口连接**非线程安全**，同一连接上的请求必须串行化；② 每次请求要有独立超时与取消，不能让一个卡死点拖垮整轮；③ 断线可恢复且带退避，避免重连风暴；④ 采集与落库解耦，用有界队列削峰。.NET 8 的 `PeriodicTimer`、`System.Threading.Channels`、`SemaphoreSlim`、`CancellationTokenSource` 四件套即可覆盖，无需第三方调度框架。

!!! warning "不要在多线程里共享裸 Socket"
    `NetworkStream` 并发 Write / Read 会交错报文、破坏事务 ID 配对；即便协议支持流水线，也先用 `SemaphoreSlim(1,1)` 串行化，确认设备能力后再考虑并发（见 [Modbus](Modbus.md) 的 TID 校验）。

## 调度模型与数据流

| 阶段 | 职责 | .NET 8 关键类型 |
| --- | --- | --- |
| 触发 | 固定节拍产生采集轮次 | `PeriodicTimer.WaitForNextTickAsync` |
| 串行化 | 单连接请求互斥 | `SemaphoreSlim(1, 1)` |
| 超时 | 每请求独立超时 / 取消 | `CreateLinkedTokenSource` + `CancelAfter` |
| 传输 | 字节收发与帧校验 | `IPlcClient` / `NetworkStream` |
| 缓冲 | 采集与落库解耦 | `Channel<T>`（有界、SingleReader） |

采集点按变化频率分级（快变量、慢变量、状态量），用「节拍序号 % 周期倍数」跳过慢速点，避免所有点挤在同一频率把链路打满；周期数值按现场实测确定，落库见 [数据库](../Database/index.md)。

## 关键用法与代码示例

`IPlcClient` / `PlcAddress` 定义见 [西门子 PLC](Siemens.md)；`PlcSample` 为本页样本。

```csharp
using System.Threading.Channels;
public sealed record PlcSample(PlcAddress Point, ReadOnlyMemory<byte> Raw, DateTimeOffset Ts);
public sealed class AcquisitionLoop(IPlcClient client)
{
    private readonly IPlcClient _client = client;
    private readonly SemaphoreSlim _gate = new(1, 1); // 单连接请求串行化
    private readonly Channel<PlcSample> _queue = Channel.CreateBounded<PlcSample>(
        new BoundedChannelOptions(2048)
        { SingleReader = true, SingleWriter = false, FullMode = BoundedChannelFullMode.Wait });
    public ChannelReader<PlcSample> Samples => _queue.Reader;
    public async Task RunAsync(
        IReadOnlyList<(PlcAddress Point, TimeSpan Period)> points,
        TimeSpan tick, CancellationToken ct)
    {
        using var timer = new PeriodicTimer(tick);
        long tickNo = 0;
        while (await timer.WaitForNextTickAsync(ct).ConfigureAwait(false))
        {
            tickNo++;
            foreach (var (point, period) in points)
            {
                long every = Math.Max(1L, period.Ticks / tick.Ticks);
                if (tickNo % every != 0) continue; // 慢速点跳过本轮
                await PollOneAsync(point, ct).ConfigureAwait(false);
            }
        }
    }
    private async Task PollOneAsync(PlcAddress point, CancellationToken ct)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(2)); // 单请求独立超时
        await _gate.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            ReadOnlyMemory<byte> raw = await _client.ReadAsync(point, cts.Token).ConfigureAwait(false);
            await _queue.Writer.WriteAsync(
                new PlcSample(point, raw, DateTimeOffset.UtcNow), ct).ConfigureAwait(false);
        }
        finally { _gate.Release(); }
    }
}
```

断线重连采用指数退避并设上限；`factory` 由调用方提供，负责创建并 `ConnectAsync` 驱动。消费者批量落库，慢消费者不会把反压传导到 PLC 通信，`flush` 由调用方注入（见 [数据库](../Database/index.md)）。

```csharp
using System.Net.Sockets;
public static async Task<IPlcClient> ConnectWithBackoffAsync(
    Func<CancellationToken, Task<IPlcClient>> factory, CancellationToken ct)
{
    TimeSpan delay = TimeSpan.FromMilliseconds(500);
    while (!ct.IsCancellationRequested)
    {
        try { return await factory(ct).ConfigureAwait(false); }
        catch (SocketException) { /* 记录日志后进入退避 */ }
        await Task.Delay(delay, ct).ConfigureAwait(false);
        delay = TimeSpan.FromMilliseconds(Math.Min(delay.TotalMilliseconds * 2, 30_000));
    }
    throw new OperationCanceledException(ct);
}
public static async Task DrainAsync(
    ChannelReader<PlcSample> reader,
    Func<List<PlcSample>, CancellationToken, Task> flush,
    CancellationToken ct)
{
    var batch = new List<PlcSample>(256);
    await foreach (PlcSample s in reader.ReadAllAsync(ct).ConfigureAwait(false))
    {
        batch.Add(s);
        if (batch.Count < 256) continue;
        await flush(batch, ct).ConfigureAwait(false);
        batch.Clear();
    }
    if (batch.Count > 0) await flush(batch, ct).ConfigureAwait(false);
}
```

## 常见坑与排查

- 未串行化 → 事务 ID 错位、报文交错；用 `SemaphoreSlim` 包住整个「写请求 + 读响应」。
- 全局单一 `CancellationToken` 无单请求超时 → 一个卡死点阻塞整轮；用 `CreateLinkedTokenSource` + `CancelAfter`，停止令牌与超时令牌不要混用。
- 重连风暴 / 无界队列 OOM：退避要有上限，Channel 要有界（`FullMode = Wait` 反压、`DropOldest` 丢点）；`PeriodicTimer` 不累积节拍，时间用 `DateTimeOffset.UtcNow` + NTP / chrony 对齐，停机时 `TryComplete` Channel 并 `DisposeAsync`。

## 信创与跨平台注意事项

银河麒麟 V11 上以 systemd 部署（`Restart=always`、日志进 journald、工作目录与权限显式配置），SIGTERM 映射为 `CancellationToken` 实现优雅停机，详见 [银河麒麟 V11](../DevOps/KylinV11.md)。国产 CPU 上注意 Server GC 与容器内存限制、定时器精度；网络侧放通 502 / 102 端口、时钟同步与访问审计按等保策略执行。落库对接国产数据库 / 时序库时批量参数化写入，见 [数据库](../Database/index.md)；界面实时刷新见 [Avalonia](../Avalonia/index.md)。

## 参考链接

- Microsoft .NET 8 文档：`PeriodicTimer`、`System.Threading.Channels`、`CancellationTokenSource`、`SemaphoreSlim`；《.NET 中的取消》；分组内 [Modbus](Modbus.md) 的 TID 校验、[串口通信](SerialPort.md) 的 RTU 超时，数值按现场实测确定

## 相关页面

- [返回分组首页](index.md)
- [Modbus](Modbus.md)
- [西门子 PLC](Siemens.md)
- [串口通信](SerialPort.md)
