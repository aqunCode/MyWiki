# SQLite

| 文档信息 | 内容 |
|---|---|
| 分类 | 数据库 |
| 主题 | Microsoft.Data.Sqlite、文件库、WAL、事务与边缘缓冲落库 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

- **驱动**：`Microsoft.Data.Sqlite`（命名空间 `Microsoft.Data.Sqlite`），底层由 `SQLitePCLRaw` 提供原生 `e_sqlite3`，具体包与能力「以实际安装的 NuGet 包版本为准」。
- **定位**：边缘采集机上的断网续传缓冲、本地配置、单机历史缓存；不适合多进程高并发写中心库。
- **并发模型**：单文件库、无服务端，同一时刻仅一个写事务；`PRAGMA journal_mode=WAL` 改善读写并发，`busy_timeout` 避免锁等待立即抛错。
- **落库模型**：SQLite 动态类型，时间建议存 ISO 8601 文本或 Unix 毫秒整数；采集循环写入 `tag_buffer` 置 `uploaded=0`，上传成功后按批次标记或删除。

## 连接与配置

连接串使用绝对路径，避免相对路径依赖进程工作目录：

```json
{
  "ConnectionStrings": {
    "SqliteBuffer": "Data Source=/var/lib/collector/buffer.db;Cache=Shared;Pooling=True;Default Timeout=5;"
  }
}
```

初始化 PRAGMA 与表结构（`sample_time` 存 UTC 的 ISO 8601 字符串）：

```sql
PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=5000;
CREATE TABLE IF NOT EXISTS tag_buffer (
    id INTEGER PRIMARY KEY AUTOINCREMENT, tag_id INTEGER NOT NULL,
    sample_time TEXT NOT NULL, val REAL NOT NULL,
    quality INTEGER NOT NULL, uploaded INTEGER NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS idx_buffer_uploaded ON tag_buffer(uploaded, sample_time);
```

!!! warning "原生库架构必须匹配"
    `Microsoft.Data.Sqlite` 通过 `SQLitePCLRaw` 携带原生 `e_sqlite3`，国产 CPU（arm64 / loongarch64 等）上必须确认对应 RID 有可用原生库，否则运行时抛 `DllNotFoundException`。现场可改用系统自带 `libsqlite3` 的动态 provider；可用包与初始化方式「以实际安装的 NuGet 包版本为准」。

## 关键用法与代码示例

单事务批量追加缓冲数据；时间显式转 UTC 的 ISO 8601，避免时区歧义：

```csharp
using Microsoft.Data.Sqlite;

public sealed class SqliteBuffer
{
    private readonly string _cs;
    public SqliteBuffer(string cs) => _cs = cs;

    public async Task<int> AppendAsync(
        IReadOnlyList<TagSample> samples, CancellationToken ct = default)
    {
        if (samples.Count == 0) return 0;
        await using var conn = new SqliteConnection(_cs);
        await conn.OpenAsync(ct);
        using var tx = conn.BeginTransaction();
        await using var cmd = conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText =
            "INSERT INTO tag_buffer(tag_id, sample_time, val, quality) " +
            "VALUES($tag, $ts, $val, $q)";
        foreach (var s in samples)
        {
            cmd.Parameters.Clear();
            cmd.Parameters.AddWithValue("$tag", s.TagId);
            cmd.Parameters.AddWithValue("$ts",
                s.Timestamp.ToUniversalTime().ToString("O"));
            cmd.Parameters.AddWithValue("$val", s.Value);
            cmd.Parameters.AddWithValue("$q", s.Quality);
            await cmd.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        return samples.Count;
    }
}

public sealed record TagSample(int TagId, DateTime Timestamp, double Value, short Quality);
```

读取待上传批次可用 `SqliteConnectionStringBuilder` 构造连接串，并用 `DateTimeStyles.RoundtripKind` 还原 UTC 时间。

## 常见坑与排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| `database is locked` | 多写者 / 长事务 | 开启 WAL 与 `busy_timeout`，串行化写入，缩短事务 |
| `no such table` / 删除 .db 失败 | 路径写错、连接池仍持有句柄 | 用绝对路径；先 `SqliteConnection.ClearAllPools()` 再删文件 |
| 时间解析偏移 | 存了本地时区字符串 | 统一 `ToUniversalTime().ToString("O")`，按 `RoundtripKind` 读回 |
| 多线程崩溃 | 共享同一 `SqliteConnection` | 每次操作新建连接，连接不是线程安全的 |

## 信创与跨平台注意事项

- **原生库与 CPU 架构**：见上方 warning；国产平台上先跑最小控制台程序验证 `e_sqlite3` 能加载，再接入采集服务。
- **目录权限与 WAL 文件**：`/var/lib/collector` 需运行用户可写；WAL 会生成 `-wal` / `-shm` 附属文件，备份时先 checkpoint 或整组一起拷贝。
- **路径大小写**：Linux 下路径、文件名严格区分大小写，统一小写命名；用 `Path.Combine` 拼接，不要写死 `\\` 分隔符。
- **掉电安全与国产中心库**：`synchronous=NORMAL` 提升吞吐但极端掉电可能丢最近事务，按现场要求权衡；SQLite 仅作缓冲，上传达梦/人大金仓成功后按批次清理。

## 参考链接

- SQLite 官方文档：https://www.sqlite.org/docs.html
- WAL 模式：https://www.sqlite.org/wal.html
- Microsoft.Data.Sqlite 文档：https://learn.microsoft.com/dotnet/standard/data/sqlite/
- NuGet `Microsoft.Data.Sqlite`：https://www.nuget.org/packages/Microsoft.Data.Sqlite/

## 相关页面

- [Oracle 19c](Oracle19c.md)
- [MySQL](MySQL.md)
- [SqlSugar](SqlSugar.md)
- [EF Core](EFCore.md)
- [返回分组首页](index.md)
