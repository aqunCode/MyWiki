# SqlSugar

| 文档信息 | 内容 |
|---|---|
| 分类 | 数据库 |
| 主题 | SqlSugarClient / IAdo、批量写入、事务与多库（含国产库）适配 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

- **入口与 provider**：`SqlSugarClient` 是主入口，`ConnectionConfig.DbType` 决定底层数据库；切库主要改 `DbType` 与连接串，业务代码基本不动。
- **常用 API 面**：`db.Queryable<T>()`、`db.Insertable<T>()`、`db.Updateable<T>()`、`db.Ado`（`IAdo`）、`db.Fastest<T>()`；事务用 `db.Ado.BeginTran()` / `CommitTran()` / `RollbackTran()`。
- **批量与多库**：高频采集用 `Fastest<T>().BulkCopyAsync()` 或 `Insertable(list).ExecuteCommandAsync()`，不要循环逐条插入；`SqlSugarScope` 或 `ConfigId` 多组连接适合「边缘 SQLite + 中心库」双写。

## 连接与配置

连接串例如 `Server=10.0.0.9;Database=collector;Uid=collector;Pwd=***;CharSet=utf8mb4;`，连同 `DbType` 收敛到 Infrastructure 层的 `ConnectionConfig`；具体枚举名「以实际安装的 NuGet 包版本为准」。

```csharp
using SqlSugar;

public static class DbFactory
{
    public static SqlSugarClient Create(DbType dbType, string cs) => new(new ConnectionConfig
    {
        ConnectionString = cs,
        DbType = dbType,
        IsAutoCloseConnection = true,
        InitKeyType = InitKeyType.Attribute
    });
}

[SugarTable("tag_history")]
public sealed class TagHistory
{
    [SugarColumn(IsPrimaryKey = true, IsIdentity = true)]
    public long Id { get; set; }
    public int TagId { get; set; }
    public DateTime SampleTime { get; set; }
    public double Value { get; set; }
    public short Quality { get; set; }
}
```

!!! warning "多库切换不等于零改造"
    `DbType` 只是切换起点：国产数据库各自的 .NET 驱动、参数前缀、批量能力与函数映射都有差异，`Fastest` 在部分库上可能退化为逐条插入。具体枚举名、驱动包与批量能力一律「以实际安装的 NuGet 包版本为准」，上线前用真实数据量验证。

## 关键用法与代码示例

高频批量写入与「写入 + 更新水位线」的显式事务；查询只用 `Queryable`，迁移时换构造参数：

```csharp
using SqlSugar;

public sealed class SugarTagWriter
{
    private readonly SqlSugarClient _db;
    public SugarTagWriter(SqlSugarClient db) => _db = db;

    public async Task<int> BulkWriteAsync(IReadOnlyList<TagHistory> rows)
        => rows.Count == 0 ? 0
            : await _db.Fastest<TagHistory>().BulkCopyAsync(rows.ToList());

    public async Task WriteWithWatermarkAsync(
        IReadOnlyList<TagHistory> rows, long watermark)
    {
        try
        {
            _db.Ado.BeginTran();
            await _db.Insertable(rows.ToList()).ExecuteCommandAsync();
            await _db.Ado.ExecuteCommandAsync(
                "UPDATE sync_state SET last_id = @lastId WHERE name = 'tag_history'",
                new { lastId = watermark });
            _db.Ado.CommitTran();
        }
        catch
        {
            _db.Ado.RollbackTran();
            throw;
        }
    }

    public Task<List<TagHistory>> QueryRangeAsync(int tagId, DateTime from)
        => _db.Queryable<TagHistory>()
            .Where(x => x.TagId == tagId && x.SampleTime >= from)
            .OrderBy(x => x.SampleTime)
            .ToListAsync();
}
```

## 常见坑与排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| 事务内连接被提前关闭 | `IsAutoCloseConnection` 与手动 `BeginTran` 混用 | 事务期间复用同一 client，统一走 `db.Ado` |
| 并发异常 / 主键冲突 | `SqlSugarClient` 非线程安全、主键未配 `IsIdentity` | 每次新建实例或改用 `SqlSugarScope`；显式声明主键 |
| 批量结果异常 / 找不到表 / 注入 | `Fastest` 默认值列差异、Linux 大小写、字符串插值 | 对照逐条插入验证；统一小写映射；一律参数化 |

## 信创与跨平台注意事项

- **provider 收敛**：把 `ConnectionConfig` 放在 Infrastructure 层，业务层只用 `Queryable` / `Insertable` / `Fastest`，迁移国产库时改动面最小。
- **国产库驱动**：达梦、人大金仓、神通、海量等各自提供 .NET 驱动，需单独安装并确认支持 .NET 8 与目标 CPU 架构；具体驱动与枚举「以实际安装的 NuGet 包版本为准」。
- **大小写与批量差异**：Linux 下表名、列名严格区分大小写，统一小写并用特性显式映射；`Fastest` 在国产库上可能降级，用真实采集频率压测后再定批大小。
- **与 EF Core 取舍**：SqlSugar 偏「快速落库 + 多库切换」，[EF Core](EFCore.md) 偏「领域模型 + 迁移」，按是否需要 Code First 决定。

## 参考链接

- SqlSugar 官方文档：https://www.donet5.com/Home/Doc
- NuGet `SqlSugarCore`：https://www.nuget.org/packages/SqlSugarCore/

## 相关页面

- [Oracle 19c](Oracle19c.md)
- [MySQL](MySQL.md)
- [SQLite](SQLite.md)
- [EF Core](EFCore.md)
- [返回分组首页](index.md)
