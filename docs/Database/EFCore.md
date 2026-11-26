# EF Core

| 文档信息 | 内容 |
|---|---|
| 分类 | 数据库 |
| 主题 | DbContext / DbSet、异步 API、迁移与高频采集批量写入策略 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

- `DbContext` 是工作单元 + 变更跟踪器，`DbSet<T>` 是实体入口；查询默认跟踪，写入靠 `SaveChangesAsync` 提交。
- 采集链路要点：`AddRangeAsync` + 单次 `SaveChangesAsync` 仍会生成逐行 INSERT，高频场景是瓶颈；需用批量扩展或原生 SQL / BulkCopy。
- 只读查询用 `AsNoTracking()` 避免跟踪开销，用 `IDbContextFactory<T>` 建短生命周期上下文；迁移（Migrations）绑定具体 provider，换库需重新生成，并发冲突由 `DbUpdateConcurrencyException` 暴露。

## 连接与配置

连接串例如 `Data Source=/var/lib/collector/buffer.db;Cache=Shared`；换库只改 `UseXxx` 与连接串，业务层不感知 provider。注册用 `services.AddDbContextFactory<CollectorDbContext>(o => o.UseSqlite(cs))`（`UseSqlite` 来自 SQLite provider），实体主键、索引显式声明：

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class CollectorDbContext(DbContextOptions<CollectorDbContext> options)
    : DbContext(options)
{
    public DbSet<TagSample> TagSamples => Set<TagSample>();

    protected override void OnModelCreating(ModelBuilder mb) =>
        mb.Entity<TagSample>(e =>
        {
            e.ToTable("tag_history");
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.TagId, x.SampleTime });
            e.Property(x => x.Value).HasColumnType("REAL");
        });
}

public sealed class TagSample
{
    public long Id { get; set; }
    public int TagId { get; set; }
    public DateTime SampleTime { get; set; }
    public double Value { get; set; }
    public short Quality { get; set; }
    public bool Uploaded { get; set; }
}
```

!!! warning "别把 DbContext 当单例"
    `DbContext` 非线程安全，跟踪缓存会随写入量持续膨胀。采集服务用 `IDbContextFactory<T>` 每批创建短生命周期上下文、用完即释放；UI 查询另用 `AsNoTracking()` 的只读上下文。是否存在可用的批量扩展包、其能力如何，一律「以实际安装的 NuGet 包版本为准」。

## 关键用法与代码示例

每批独立上下文，写入与查询走异步 API；批量状态更新与历史清理优先在数据库端执行，避免「查出实体再逐条保存」：

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class EfTagWriter(IDbContextFactory<CollectorDbContext> factory)
{
    public async Task<int> WriteBatchAsync(
        IReadOnlyList<TagSample> samples, CancellationToken ct = default)
    {
        if (samples.Count == 0) return 0;
        await using var db = await factory.CreateDbContextAsync(ct);
        await db.TagSamples.AddRangeAsync(samples, ct);
        return await db.SaveChangesAsync(ct);
    }

    public async Task<List<TagSample>> QueryRangeAsync(
        int tagId, DateTime from, CancellationToken ct = default)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        return await db.TagSamples.AsNoTracking()
            .Where(x => x.TagId == tagId && x.SampleTime >= from)
            .OrderBy(x => x.SampleTime)
            .ToListAsync(ct);
    }

    public static Task<int> MarkUploadedAsync(
        CollectorDbContext db, long maxId, CancellationToken ct)
        => db.TagSamples.Where(x => x.Id <= maxId)
            .ExecuteUpdateAsync(
                s => s.SetProperty(x => x.Uploaded, _ => true), ct);

    public static Task<int> PurgeAsync(CollectorDbContext db, DateTime cutoff, CancellationToken ct)
        => db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM tag_history WHERE sample_time < {cutoff}", ct);
}
```

## 常见坑与排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| 写入吞吐低 | `SaveChangesAsync` 逐行 INSERT | 批量扩展、BulkCopy 或 `ExecuteSqlInterpolatedAsync` |
| 内存增长 / N+1 | 长生命周期上下文、导航属性延迟加载 | `IDbContextFactory`、`AsNoTracking()`、`Select` 投影 |
| 迁移报错 / 并发覆盖 / 时间偏移 | 迁移绑定旧 provider、未处理并发、SQLite 无时区类型 | 重新生成迁移、配并发令牌重试、统一存 UTC |

## 信创与跨平台注意事项

- provider 需支持 .NET 8 与目标 CPU 架构；达梦、人大金仓等国产库各有 EF Core provider，批量、迁移与函数映射能力与社区 provider 不完全一致，「以实际安装的 NuGet 包版本为准」。
- 迁移脚本在 Linux 上路径、大小写敏感；`dotnet ef` 工具链需在目标环境可用，或预生成 SQL 脚本由运维执行。
- `UseSqlite` 依赖 `SQLitePCLRaw` 原生库架构，国产 CPU 上先验证，见 [SQLite](SQLite.md)。
- 表名/列名用 `ToTable` / `HasColumnName` 显式映射并统一小写；少用 `EF.Functions` 方言函数，保持 LINQ 可移植。

## 参考链接

- EF Core 官方文档：https://learn.microsoft.com/ef/core/
- NuGet `Microsoft.EntityFrameworkCore`：https://www.nuget.org/packages/Microsoft.EntityFrameworkCore/

## 相关页面

- [Oracle 19c](Oracle19c.md)
- [MySQL](MySQL.md)
- [SQLite](SQLite.md)
- [SqlSugar](SqlSugar.md)
- [返回分组首页](index.md)
