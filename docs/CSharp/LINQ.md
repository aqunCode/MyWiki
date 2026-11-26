# LINQ

| 项目 | 内容 |
| :--- | :--- |
| 分类 | C# / .NET |
| 主题 | LINQ 延迟执行、查询物化与采集数据处理 |
| 适用技术栈 | .NET 8 / C# 12 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

LINQ 把「对一组点位 / 采样值的筛选、投影、聚合」写成声明式管道，省去手写嵌套循环。但在工业上位机里要清楚两条边界：其一，`IEnumerable<T>` 大多是**延迟执行**（deferred execution），拿到的是查询描述而非结果；其二，多数标准运算符在枚举时会**分配迭代器对象**。在信创平台国产 CPU 上跑 7×24 小时采集，热路径里的分配会直接变成 GC 压力和 UI 抖动，因此 LINQ 更适合配置解析、历史数据离线统计、班次报表，而不是每帧都要过一遍的实时采集循环。

- **延迟执行**：`Where` / `Select` / `OrderBy` 只构建管道，真正执行发生在 `foreach` / `ToList` / `Count` 等消费点。
- **立即执行**：`ToList` / `ToArray` / `ToDictionary` / `Count` / `First` 触发枚举并物化结果，结果可安全复用。
- **数据源差异**：`IEnumerable<T>`（LINQ to Objects，内存中执行）与 `IQueryable<T>`（表达式树，交给 EF Core 等 Provider 翻译）不能混用；后者的方法调用可能被翻译成 SQL，误用会把整张历史表拉回内存。

## 关键用法与代码示例

延迟执行最典型的代价是**重复枚举**：同一个 `IEnumerable<T>` 被消费两次，管道就完整跑两次。如果源头本身是一次网络读取或串口采样，代价会被放大。

```csharp
using System;
using System.Collections.Generic;
using System.Linq;

public record TagValue(int Id, double Value, DateTime Timestamp);

public static class TagQuery
{
    // 返回的只是「查询」，此刻尚未读取任何数据
    public static IEnumerable<string> AlarmLines(IEnumerable<TagValue> samples, double limit)
        => samples
            .Where(s => s.Value > limit)
            .OrderBy(s => s.Timestamp)
            .Select(s => $"{s.Id} 超限 {s.Value:F2} @ {s.Timestamp:HH:mm:ss}");

    public static void Demo()
    {
        var samples = new List<TagValue>
        {
            new(1, 36.5, DateTime.Now),
            new(2, 41.2, DateTime.Now),
            new(3, 28.0, DateTime.Now),
        };
        IEnumerable<string> query = AlarmLines(samples, 40.0);
        foreach (var line in query) Console.WriteLine(line); // 第一次枚举
        int count = query.Count();                           // 第二次枚举，管道重跑
        Console.WriteLine($"报警条数：{count}");
    }
}
```

需要复用结果时，应在消费点一次性物化，再基于物化集合做聚合：

```csharp
using System;
using System.Collections.Generic;
using System.Linq;

public record Sample(string Device, string Tag, double Value);

public static class Aggregator
{
    // 按点位聚合，用于班次最大值 / 最小值 / 均值统计
    public static Dictionary<string, (double Min, double Max, double Avg)> ByTag(
        IEnumerable<Sample> rows)
        => rows.GroupBy(r => r.Tag)
               .ToDictionary(
                   g => g.Key,
                   g => (Min: g.Min(x => x.Value),
                         Max: g.Max(x => x.Value),
                         Avg: g.Average(x => x.Value)));

    public static void Demo(IEnumerable<Sample> rows)
    {
        List<Sample> snapshot = rows.ToList(); // 物化一次，杜绝重复 I/O
        foreach (var (tag, v) in ByTag(snapshot))
            Console.WriteLine($"{tag}: min={v.Min:F2} max={v.Max:F2} avg={v.Avg:F2}");
    }
}
```

!!! warning "别在热路径里对同一个查询反复枚举"
    常见错误写法是「先 `Any()` 判空、再 `foreach` 遍历、最后 `Count()` 统计」，若源头是 `IEnumerable<T>`，过滤逻辑会跑三次。对 `List<T>` 直接读 `Count` 属性；对流式数据源先 `ToList()` 物化，或用 `List<T>` 承载单轮采样结果后再统计。

## 典型场景：信创上位机的离线统计

上位机把采集到的点位按「通用报文 → 统一模型」落地后，常见诉求是按设备、按点位、按班次做离线统计：报警次数、超限时长、均值与极值。这类数据量大、不要求实时、跑在后台线程或报表进程里，正是 LINQ 的合适场景。结合通用报文协议（ISO-on-TCP / Modbus TCP / 开放 TCP 帧）时，先把每帧解析出的寄存器值转成 `struct` / `record` 样本，再用 `GroupBy` / `ToLookup` 聚合，避免把业务逻辑绑死在某家厂商的 SDK 上。要注意 `IQueryable<T>` 与 EF Core 配合时，聚合应下推到数据库侧执行，别用 `AsEnumerable()` 把历史表全量拉回国产 CPU 的内存再算。

## 常见坑与排查

- **重复枚举**：`IEnumerable<T>` 被 `foreach` + `Count()` + `Any()` 多次消费，源头若是网络流会重复读甚至阻塞；先物化。
- **`Count()` 与 `Count` 混淆**：`Enumerable.Count()` 会枚举整个序列，`List<T>.Count` 是 O(1) 属性。
- **闭包捕获变量**：`Where(s => s.Value > limit)` 捕获外部变量，延迟到枚举时才取值；循环里改 `limit` 会让结果和预期不符。
- **全排序开销**：只取 TopN 时 `OrderBy(...).Take(n)` 可以，但 `OrderBy` 默认对全序列排序；能预过滤就先 `Where`。
- **`IQueryable` 客户端求值**：自定义方法无法翻译时 EF Core 可能抛异常或隐式拉回内存；开启日志确认生成的 SQL。
- **PLINQ 滥用**：`AsParallel` 在采集线程里会抢线程池、引入调度开销，国产 CPU 核心数与开发机不同，须实测再决定。

## 参考链接

- [LINQ 文档](https://learn.microsoft.com/dotnet/csharp/linq/)
- [Enumerable 类 API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable)
- [IQueryable&lt;T&gt; API](https://learn.microsoft.com/dotnet/api/system.linq.iqueryable-1)
- [EF Core 查询工作原理](https://learn.microsoft.com/ef/core/querying/)

## 相关页面

- [异步编程](Async.md)
- [反射](Reflection.md)
- [性能优化](Performance.md)
- [返回分组首页](index.md)
