# C# 基础

> 面向 .NET 8 / Avalonia 工业上位机的 C# 工程实践索引，聚焦信创平台上的通用报文采集链路。

## 分组说明

本组不重复语言入门内容，而是围绕「一台 7×24 小时运行的上位机」真正会踩到的语言与运行时问题组织：如何把采集到的字节帧稳定地读进来（异步编程）、如何把点位与协议做成可配置而非绑死厂商 SDK（反射）、如何在国产 CPU 上做离线统计而不过度分配（LINQ）、以及如何用 `Span` / 内存池把高频采集的 GC 压力压下去（性能优化）。示例统一以 .NET 8 / C# 12 为基线，通信侧假设使用 ISO-on-TCP、Modbus TCP 或开放 TCP 帧这类通用报文，避免引入专有协议依赖；具体 API 行为与优化能力以实际版本为准。阅读时建议结合 PLC 分组的协议文档与 Avalonia 分组的界面文档一起看。

## 本组文档

| 文档 | 内容 | 重点 |
| :--- | :--- | :--- |
| [C# 基础](index.md) | 本组知识地图、学习路径与跨分组关系 | 先建立「采集 → 解析 → 展示」的整体链路视角 |
| [LINQ](LINQ.md) | 延迟执行、查询物化与采集数据聚合 | 重复枚举、`IQueryable` 客户端求值、热路径分配 |
| [异步编程](Async.md) | async/await、取消超时、多设备并发轮询 | `ReadExactlyAsync` 处理半包、避免 `.Result` 死锁 |
| [反射](Reflection.md) | 特性驱动点位映射与协议解析器插件化 | 裁剪 / AOT 下反射失效、缓存 `PropertyInfo` |
| [性能优化](Performance.md) | Span / 内存池、零拷贝帧解析与 GC 调优 | 大端解析、`ArrayPool`、目标机 BenchmarkDotNet 实测 |

## 学习路径

1. **先读本页**，明确上位机里「采集线程 / UI 线程 / 离线统计」三者边界，以及为何选通用报文协议而非厂商专有栈。
2. **异步编程**：掌握 `CancellationToken` 全链路传递、`Task.WhenAll` 并发轮询、UI 线程不阻塞，这是稳定采集的地基。
3. **性能优化**：把帧解析改造成 `ReadOnlySpan<byte>` + `ArrayPool` 零拷贝链路，控制 GC 对界面的影响。
4. **反射**：用特性 + 插件化把点位表和协议解析器从编译期代码里解耦，并评估裁剪 / AOT 兼容性。
5. **LINQ**：在离线统计与报表侧合理使用声明式查询，同时避开重复枚举与 `IQueryable` 全量拉回内存。

## 与其他分组的关系

- [PLC / 工业控制](../PLC/index.md)：本组的帧解析、点位映射最终要落到具体协议（Modbus TCP、ISO-on-TCP、开放 TCP 帧）与数据采集策略上。
- [Avalonia](../Avalonia/index.md)：异步采集结果如何安全回到 UI 线程、绑定与刷新节奏，界面侧的低延迟要求反过来约束本组的线程与分配设计。
- [数据库](../Database/index.md)：历史点位、报警与班次统计的持久化；LINQ 章节的 `IQueryable` 注意事项与 EF Core 查询直接相关。
- [DevOps](../DevOps/index.md)：银河麒麟桌面操作系统 V11 / 国产 CPU 上的发布、裁剪、GC 配置与运行时验证，是性能与反射章节结论的落地环境。

## 参考链接

- [C# 官方文档](https://learn.microsoft.com/dotnet/csharp/)
- [.NET 文档中心](https://learn.microsoft.com/dotnet/)
- [LINQ](https://learn.microsoft.com/dotnet/csharp/linq/)
- [异步编程](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/)
- [Memory 与 Span](https://learn.microsoft.com/dotnet/standard/memory-and-spans/)
- [.NET 8 新增功能](https://learn.microsoft.com/dotnet/core/whats-new/dotnet-8)
