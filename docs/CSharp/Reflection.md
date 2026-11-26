# 反射

| 项目 | 内容 |
| :--- | :--- |
| 分类 | C# / .NET |
| 主题 | 特性驱动的点位映射与协议解析器插件化 |
| 适用技术栈 | .NET 8 / C# 12 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

反射（`System.Reflection`）让程序在运行时读取类型元数据、发现特性、按名字创建实例。对工业上位机最有价值的用法不是「动态调用一切」，而是把**易变的现场配置**从编译期代码中剥离：

- **特性（Attribute）+ 扫描**：用 `[PlcTag]` 标注强类型模型的属性，运行时反射出「属性 ↔ 寄存器偏移 / 数据类型」映射表，组态导入点位表时无需改一行解析代码。
- **插件化发现**：按接口扫描程序集，把 ISO-on-TCP / Modbus TCP / 开放 TCP 帧的解析器注册进字典，按配置字符串选择实现，避免把主工程编译期绑定到某家厂商的专有 SDK。
- **代价**：运行时类型解析、无法内联、每次 `GetValue` / `SetValue` 有装箱与校验开销；更重要的是**裁剪 / AOT 兼容性**——用 `PublishTrimmed` 或 NativeAOT 发布时，未被静态引用的类型可能被裁掉，反射扫描会「扫了个空」。

## 关键用法与代码示例

用自定义特性把 PLC 寄存器偏移直接写在模型上，反射扫描一次后缓存映射，用于把通用报文解出的字节填充到强类型对象。示例用 C# 12 主构造函数声明特性：

```csharp
using System;
using System.Reflection;

[AttributeUsage(AttributeTargets.Property)]
public sealed class PlcTagAttribute(int offset, string dataType) : Attribute
{
    public int Offset { get; } = offset;
    public string DataType { get; } = dataType;
}

public sealed class PressStation
{
    [PlcTag(0, "REAL")]
    public double Temperature { get; set; }
    [PlcTag(4, "INT")]
    public short Pressure { get; set; }
}

public static class TagRegistry
{
    // 一次性扫描并缓存，别在每帧采集里反复调用
    public static void Dump<T>()
    {
        foreach (PropertyInfo prop in typeof(T).GetProperties(
                     BindingFlags.Public | BindingFlags.Instance))
        {
            var tag = prop.GetCustomAttribute<PlcTagAttribute>();
            if (tag is null) continue;
            Console.WriteLine($"{prop.Name} -> 偏移 {tag.Offset}, 类型 {tag.DataType}");
        }
    }
}
```

协议解析器插件化：按接口扫描程序集，用协议名建索引，主流程只依赖 `IFrameParser` 抽象：

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

public interface IFrameParser
{
    string Name { get; }
    int ReadTransactionId(ReadOnlyMemory<byte> frame);
}

public sealed class ModbusTcpParser : IFrameParser
{
    public string Name => "ModbusTCP";
    public int ReadTransactionId(ReadOnlyMemory<byte> frame)
    {
        ReadOnlySpan<byte> s = frame.Span; // MBAP 头前两字节为事务标识
        return s.Length >= 4 ? s[0] << 8 | s[1] : 0;
    }
}

public static class ParserFactory
{
    public static IReadOnlyDictionary<string, IFrameParser> Scan(Assembly assembly)
        => assembly.GetTypes()
            .Where(t => typeof(IFrameParser).IsAssignableFrom(t)
                     && !t.IsAbstract && !t.IsInterface)
            .Select(t => (IFrameParser)Activator.CreateInstance(t)!)
            .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);
}
```

!!! warning "裁剪 / AOT 发布时反射会失效"
    在银河麒麟 + 国产 CPU 上为减小体积或加快启动采用 `PublishTrimmed`、`PublishAot` 时，仅被反射引用的类型会被裁剪器移除，`GetTypes()` 扫不到解析器，`Activator.CreateInstance` 抛异常。应对方式：对目标程序集标注 `[DynamicallyAccessedMembers]`、在描述文件中保留类型、或改用**源生成器 / 显式注册表**在编译期生成映射。是否启用裁剪以项目实测结果为准。

## 典型场景：通用报文协议下的可配置驱动

现场往往同时存在多台不同型号 PLC，且要求「不绑死厂商协议」。工程做法是：通信层只认字节帧，配置里写「协议名 + 寄存器偏移 + 数据类型」；启动时用上面的 `Scan` 把各协议解析器注册进字典，用 `[PlcTag]` 特性把点位表映射成强类型模型，后续按配置选择解析器解析开放 TCP 帧 / Modbus TCP 响应。新增一种设备或调整点位偏移时，改配置或加一个带特性的模型即可，不改采集主循环。这套结构也便于把国产化适配（不同 CPU 架构、不同字节序）集中在编解码层处理。

## 常见坑与排查

- **Trim / AOT 裁掉类型**：现象是开发环境正常、发布包里 `Scan` 返回空；用保留注解或源生成器解决，别靠 `DynamicDependency` 到处打补丁。
- **热路径反复反射**：每帧 `GetProperties` + `SetValue` 开销显著；启动时扫描一次，缓存 `PropertyInfo`，或用 `Expression` 编译成强类型委托、交由源生成器生成赋值代码。
- **`BindingFlags` 漏写**：默认 `GetProperties` 不含非公开成员，也不含静态成员；确认 `Public | Instance` 是否覆盖目标。
- **只扫当前程序集**：`Assembly.GetExecutingAssembly()` 扫不到插件 DLL；需显式加载目标程序集并注意 `AssemblyLoadContext` 隔离与卸载。
- **`Activator.CreateInstance` 要求无参构造**：带参构造的类型会抛异常；插件接口应约定无参构造，或改注册工厂委托 `Func<IFrameParser>`。

## 参考链接

- [特性（C# 编程指南）](https://learn.microsoft.com/dotnet/csharp/programming-guide/concepts/attributes/)
- [System.Reflection 命名空间](https://learn.microsoft.com/dotnet/api/system.reflection)
- [裁剪选项与警告](https://learn.microsoft.com/dotnet/core/deploying/trimming/trimming-options)

## 相关页面

- [LINQ](LINQ.md)
- [异步编程](Async.md)
- [性能优化](Performance.md)
- [返回分组首页](index.md)
