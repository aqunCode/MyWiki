# 异步编程

| 项目 | 内容 |
| :--- | :--- |
| 分类 | C# / .NET |
| 主题 | async/await、取消与超时、多设备并发轮询 |
| 适用技术栈 | .NET 8 / C# 12 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

上位机的本质是一个「长时间运行 + 多设备 I/O + UI 必须流畅」的程序。`async/await` 把 Socket 读写这类**异步 I/O** 挂起为状态机，在等待期间把线程还给线程池，避免为每个 PLC 连接独占一个线程。几个必须建立的认知：

- **I/O 异步而非线程异步**：`NetworkStream.ReadAsync` 靠操作系统完成端口 / epoll，不占用线程；真正的耗时计算才需要 `Task.Run`。
- **`CancellationToken` 要贯穿全链路**：连接、读帧、写库都应接受同一个 token，才能在停机、切换设备、网络断开时干净取消。
- **`ConfigureAwait(false)`**：领域层 / 通信库里加上它，避免把延续强行排回 Avalonia 的 UI `SynchronizationContext`；只有需要更新界面的最外层才回到 UI 线程。
- **`ValueTask`**：高频、常同步完成的热路径可用它减少 `Task` 分配，但只能 `await` 一次，不要保存或多次消费。

## 关键用法与代码示例

通用报文协议（ISO-on-TCP / Modbus TCP / 开放 TCP 帧）多基于 TCP 字节流，必须自己处理**半包 / 粘包**。`ReadExactlyAsync`（.NET 7+）按预期长度读满一帧，比手写循环 `ReadAsync` 偏移累加更不易出错，且全程异步、带取消。

```csharp
using System;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

public sealed class TcpFrameClient : IAsyncDisposable
{
    private readonly TcpClient _client = new();
    private readonly string _host;
    private readonly int _port;
    private NetworkStream? _stream;

    public TcpFrameClient(string host, int port) => (_host, _port) = (host, port);

    public async Task ConnectAsync(CancellationToken ct)
    {
        await _client.ConnectAsync(_host, _port, ct);
        _stream = _client.GetStream();
    }

    // 读满 length 字节才返回；半包时自动继续等待
    public async Task<byte[]> ReadFrameAsync(int length, CancellationToken ct)
    {
        if (_stream is null) throw new InvalidOperationException("尚未建立连接");
        var buffer = new byte[length];
        await _stream.ReadExactlyAsync(buffer, ct);
        return buffer;
    }

    public ValueTask DisposeAsync()
    {
        _client.Dispose();
        return ValueTask.CompletedTask;
    }
}
```

轮询多个设备时，用 `Task.WhenAll` 并发发起，并用 `CancellationTokenSource` 给「单轮采集」设总超时，避免某台离线 PLC 拖垮整个周期；库方法内用 `ConfigureAwait(false)`：

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

public static class PollScheduler
{
    // readers：每台设备一个读取委托，返回本轮采样值
    public static async Task<IReadOnlyList<double>> PollAllAsync(
        IReadOnlyList<Func<CancellationToken, Task<double>>> readers,
        CancellationToken ct)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(2)); // 单轮总超时，按现场网络调整
        Task<double>[] tasks = readers.Select(r => r(cts.Token)).ToArray();
        // 异常由 WhenAll 聚合，调用方按需拆分处理
        return await Task.WhenAll(tasks).ConfigureAwait(false);
    }
}
```

!!! warning "不要用 .Result / .Wait() 阻塞 UI 线程"
    Avalonia 的 UI 线程带 `SynchronizationContext`，在事件处理器里对异步方法调用 `.Result` 或 `.Wait()`，延续要回 UI 线程而 UI 线程又在等结果，会造成经典死锁。命令处理器应声明为 `async`，或使用框架提供的异步命令；底层通信方法务必 `ConfigureAwait(false)`。

## 典型场景：信创平台多设备并发采集

在银河麒麟桌面操作系统 V11 / 国产 CPU 上，网络栈行为和 Windows 不完全一致，现场交换机抖动、PLC 响应慢都更常见。工程上的做法是：一轮采集用 `Task.WhenAll` 并发拉取所有设备，每台设备用独立 `CancellationToken` + 超时，任一失败不影响其他设备；周期间隔用 `await Task.Delay(period, ct)` 而非 `Thread.Sleep`，这样停机时能立即响应取消。读帧统一走 `ReadExactlyAsync` 处理半包，配合帧头长度字段或 Modbus TCP 的 MBAP 头确定 `length`，从而保持「只依赖通用报文、不绑定厂商专有协议」的设计。UI 侧只接收聚合后的快照做绑定，绝不在采集回调里直接操作控件集合。

## 常见坑与排查

- **`async void`**：除事件处理器外一律禁止；异常无法被 `try/catch` 捕获，会直接崩进程。
- **取消令牌断链**：中间层丢了 `ct`，`CancelAfter` 形同虚设；从 UI 命令到 Socket 读写逐层传递。
- **`ValueTask` 多次 await / 保存**：只允许消费一次，热路径之外优先用 `Task` 更安全。
- **忘记释放 `TcpClient` / `NetworkStream`**：设备频繁重连会耗尽句柄；用 `IAsyncDisposable` + `await using`。
- **`Task.Run` 包装 I/O**：把本就异步的 `ReadAsync` 再套线程池任务，纯属浪费调度。
- **`WhenAll` 异常被吞**：一台设备超时会让整轮抛聚合异常，需 `try/catch` 后逐台降级并记录点位质量戳。
- **周期漂移**：用固定 `Task.Delay` 会累积误差，长周期统计应基于时间戳而非「轮数 × 周期」。

## 参考链接

- [异步编程模型](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/)
- [CancellationToken API](https://learn.microsoft.com/dotnet/api/system.threading.cancellationtoken)
- [Stream 类 API](https://learn.microsoft.com/dotnet/api/system.io.stream)
- [Task.ConfigureAwait API](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.configureawait)

## 相关页面

- [LINQ](LINQ.md)
- [反射](Reflection.md)
- [性能优化](Performance.md)
- [返回分组首页](index.md)
