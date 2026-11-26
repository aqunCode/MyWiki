# 性能优化

| 项目 | 内容 |
| :--- | :--- |
| 分类 | C# / .NET |
| 主题 | Span / 内存池、零拷贝报文解析与 GC 优化 |
| 适用技术栈 | .NET 8 / C# 12 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

高频采集里真正的成本往往不在「算」，而在**分配与拷贝**：每帧 `new byte[]`、把字节 `ToArray()` 成字符串、LINQ 迭代器、装箱，都会把短暂对象推给 GC，GC 暂停又直接反映为 Avalonia 界面的卡顿。.NET 8 提供的关键工具是：

- **`Span<T>` / `ReadOnlySpan<T>`**：栈上、零分配的连续内存视图，可切片；`ref struct`，不能装箱、不能当字段、不能跨 `await` 存活。
- **`Memory<T>` / `ReadOnlyMemory<T>`**：可跨异步、可存字段的「Span 拥有者」，配合 `ArrayPool<T>` 复用大缓冲区。
- **`ArrayPool<T>`**：租借 / 归还字节数组，避免 LOH（大对象堆）反复分配与碎片。
- **`BinaryPrimitives`**：按显式大端 / 小端读整数，替代 `BitConverter` + 手动反转，避免临时数组。
- **实测而非猜测**：一切结论用 BenchmarkDotNet 在**目标国产 CPU + 目标系统**上跑出来，不照搬开发机数字。

## 关键用法与代码示例

Modbus TCP / 开放 TCP 帧里的多字节字段多为**大端序**。用 `ReadOnlySpan<byte>` + `BinaryPrimitives` 原地解析，整个过程零分配：

```csharp
using System;
using System.Buffers.Binary;

public static class FrameCodec
{
    public static ushort ReadUInt16BigEndian(ReadOnlySpan<byte> frame, int offset)
        => BinaryPrimitives.ReadUInt16BigEndian(frame.Slice(offset, 2));

    public static float ReadFloatBigEndian(ReadOnlySpan<byte> frame, int offset)
    {
        // PLC 的 REAL 常为 4 字节大端 IEEE754
        int bits = BinaryPrimitives.ReadInt32BigEndian(frame.Slice(offset, 4));
        return BitConverter.Int32BitsToSingle(bits);
    }
}
```

采集循环里用 `ArrayPool<byte>` 租借缓冲区，读完在 `Span` 上原地解析，用完归还，避免每帧分配：

```csharp
using System;
using System.Buffers;
using System.IO;
using System.Threading.Tasks;

public static class BufferDemo
{
    public static async Task ProcessAsync(Stream stream)
    {
        byte[] buffer = ArrayPool<byte>.Shared.Rent(4096);
        try
        {
            int n = await stream.ReadAsync(buffer.AsMemory(0, 4096));
            if (n > 0)
            {
                ReadOnlySpan<byte> frame = buffer.AsSpan(0, n); // 无额外拷贝
                Console.WriteLine($"收到 {frame.Length} 字节");
            }
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer); // 归还后不得再使用 buffer
        }
    }
}
```

发布配置同样影响性能表现，下面这些 MSBuild 属性按需开启，**是否启用应以压测结果为准**：

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <Nullable>enable</Nullable>
  <ImplicitUsings>enable</ImplicitUsings>
  <!-- 工作站 GC 通常更适合低延迟上位机；服务器 GC 需实测再定 -->
  <ServerGarbageCollection>false</ServerGarbageCollection>
  <ConcurrentGarbageCollection>true</ConcurrentGarbageCollection>
  <TieredPGO>true</TieredPGO>
</PropertyGroup>
```

!!! note "关于国产 CPU 上的实测"
    飞腾 / 鲲鹏（ARM64）、龙芯（LoongArch64）、兆芯 / 海光（x86_64）的 JIT 优化与硬件 intrinsics（如 NEON / AdvSimd）支持不同，同一段向量化代码表现可能差异明显。不要给「提升百分之多少」下结论，也不要把 Windows 开发机的基准数字写进交付文档；以目标银河麒麟 V11 机器上的 BenchmarkDotNet 结果为准，具体优化能力以实际 .NET 版本为准。

## 典型场景：高频采集的零拷贝链路

每秒几十到几百帧的 ISO-on-TCP / Modbus TCP 采集，理想链路是：`ArrayPool` 租缓冲 → `await ReadAsync` 填充 → 用 `ReadOnlySpan<byte>` 切片解析帧头与寄存器 → 数值直接写入预分配的 `struct` 数组 / 环形缓冲 → 聚合成快照后一次性通知 UI。全程不做 `ToArray()`、不拼接中间字符串、不在采集线程里构造临时对象。历史曲线、报警统计交给后台线程或数据库侧处理，UI 只绑定低频快照。这样才能在国产 CPU 上把 GC 暂停和界面抖动压到可控范围。

## 常见坑与排查

- **`Span` 跨 `await`**：`ref struct` 不能作为 async 方法的局部状态跨挂起保存，也不能存字段 / 装箱；需要跨异步用 `Memory<T>`。
- **`ArrayPool` 忘记归还或归还后继续使用**：`Return` 之后 buffer 可能被别的线程复用，继续读会拿到脏数据；务必 `try/finally`。
- **过早优化**：先定位瓶颈（分配、锁、I/O、序列化），再改代码；凭直觉把 `class` 全改 `struct` 往往适得其反。
- **热路径隐式分配**：闭包捕获、`params` 数组、字符串 `+` 拼接、`Enumerable` 迭代器、装箱到 `object`，都是隐形 GC 来源。
- **微基准不严谨**：不预热、把 I/O 混进基准、用 `Stopwatch` 手测单次调用，结论都不可信；用 BenchmarkDotNet。
- **误用 Server GC**：上位机更看重低暂停，工作站 GC + 后台 GC 通常更合适；是否切换需结合压测与延迟指标。

## 参考链接

- [Memory 与 Span 使用指南](https://learn.microsoft.com/dotnet/standard/memory-and-spans/)
- [ArrayPool 共享池 API](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [BinaryPrimitives API](https://learn.microsoft.com/dotnet/api/system.buffers.binary.binaryprimitives)
- [BenchmarkDotNet 官网](https://benchmarkdotnet.org/)

## 相关页面

- [LINQ](LINQ.md)
- [异步编程](Async.md)
- [反射](Reflection.md)
- [返回分组首页](index.md)
