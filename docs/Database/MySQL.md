# MySQL

| 文档信息 | 内容 |
|---|---|
| 分类 | 数据库 |
| 主题 | MySqlConnector 连接、事务、批量 INSERT 与采集数据落库 |
| 适用技术栈 | .NET 8 / 跨平台 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

- **驱动**：`MySqlConnector`（命名空间 `MySqlConnector`）纯托管、异步实现完整，不链接 `libmysqlclient`，适合 Linux 与国产 CPU；`MySql.Data` 可作备选，本文全程只用前者避免混用，具体能力「以实际安装的 NuGet 包版本为准」。
- **核心对象**：`MySqlConnection`、`MySqlCommand`、`MySqlParameter`、`MySqlTransaction`、`MySqlConnectionStringBuilder`；占位符用 `@name`（也兼容 `?`）。
- **批量写入**：采集场景优先「多值 `INSERT INTO ... VALUES (...),(...)`」或批量加载器，避免逐行往返；单批控制行数并用一个事务提交。
- **表设计与事务**：`BIGINT` 自增主键 + `(tag_id, sample_time)` 联合索引，时间列用 `DATETIME(3)`；InnoDB 行锁，事务要短。

## 连接与配置

连接串放配置里，建议用 `MySqlConnectionStringBuilder` 构造而非字符串拼接：

```json
{
  "ConnectionStrings": {
    "MySQL": "Server=10.0.0.9;Port=3306;Database=collector;User ID=collector;Password=***;Character Set=utf8mb4;Pooling=true;MaximumPoolSize=20;SslMode=Preferred;"
  }
}
```

高频表 DDL（显式字符集避免中文点位名乱码，`val` 避开关键字）：

```sql
CREATE TABLE tag_history (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tag_id INT NOT NULL, sample_time DATETIME(3) NOT NULL,
    val DOUBLE NOT NULL, quality TINYINT NOT NULL,
    KEY idx_tag_time (tag_id, sample_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

!!! warning "时区与字符集"
    连接串里的 `Character Set=utf8mb4` 只决定客户端连接字符集，库表仍需 `utf8mb4`。`DATETIME` 不带时区，`TIMESTAMP` 会按会话 `time_zone` 转换；跨现场采集建议统一存 UTC 的 `DATETIME(3)`，或连接建好后执行 `SET time_zone = '+00:00'`，别依赖服务器本地时区。

## 关键用法与代码示例

按批攒数据，用一条多值 INSERT 在单个事务里提交；参数名逐行带序号，保证与占位符一致：

```csharp
using MySqlConnector;
using System.Text;

public sealed class MySqlTagWriter
{
    private readonly string _cs;
    public MySqlTagWriter(string cs) => _cs = cs;

    public async Task<int> WriteBatchAsync(
        IReadOnlyList<TagSample> samples, CancellationToken ct = default)
    {
        if (samples.Count == 0) return 0;
        await using var conn = new MySqlConnection(_cs);
        await conn.OpenAsync(ct);
        using var tx = conn.BeginTransaction();
        await using var cmd = conn.CreateCommand();
        cmd.Transaction = tx;
        var sb = new StringBuilder(
            "INSERT INTO tag_history(tag_id, sample_time, val, quality) VALUES ");
        for (var i = 0; i < samples.Count; i++)
        {
            if (i > 0) sb.Append(',');
            sb.Append($"(@tag{i}, @ts{i}, @val{i}, @q{i})");
            var s = samples[i];
            cmd.Parameters.AddWithValue($"@tag{i}", s.TagId);
            cmd.Parameters.AddWithValue($"@ts{i}", s.Timestamp);
            cmd.Parameters.AddWithValue($"@val{i}", s.Value);
            cmd.Parameters.AddWithValue($"@q{i}", s.Quality);
        }
        cmd.CommandText = sb.ToString();
        var rows = await cmd.ExecuteNonQueryAsync(ct);
        await tx.CommitAsync(ct);
        return rows;
    }
}

public sealed record TagSample(int TagId, DateTime Timestamp, double Value, short Quality);
```

## 常见坑与排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| 中文乱码 / 表情符报错 | 用了 `utf8` 而非 `utf8mb4` | 库、表、连接串统一 `utf8mb4` |
| 时间相差 8 小时 | 会话 `time_zone` 与 `TIMESTAMP` 转换 | 统一 UTC `DATETIME(3)`，显式设会话时区 |
| 批量语句过长 / 死锁 | 超过 `max_allowed_packet`、长事务 | 限制每批行数、固定写入顺序、加重试 |
| TLS 连接失败 | 自签证书或系统 CA 缺失 | 核对 `SslMode` 与麒麟系统 CA 证书 |

## 信创与跨平台注意事项

- **纯托管无原生依赖**：`MySqlConnector` 不链接 `libmysqlclient`，国产 CPU 上不缺原生库，自包含发布按目标 RID 选择 .NET 8 运行时即可。
- **SSL 与证书**：银河麒麟 V11 上若启用 TLS，核对系统 CA 存储与 `SslMode`；内网自签证书按现场安全策略配置，不要全局关闭校验。
- **国产库适配**：达梦、人大金仓等部分兼容 MySQL 语法/协议，但驱动与连接串不同；用 [SqlSugar](SqlSugar.md) 的 `DbType` 或自定义 `ITagWriter` 抽象切换，业务层保持通用 SQL。
- **大小写与连接池**：库名、表名在 Linux 下受 `lower_case_table_names` 影响，统一小写；`MaximumPoolSize` 与超时按采集并发现场调参。

## 参考链接

- MySQL 官方文档：https://dev.mysql.com/doc/
- MySqlConnector 文档：https://mysqlconnector.net/
- 连接串选项：https://mysqlconnector.net/connection-options/
- NuGet `MySqlConnector`：https://www.nuget.org/packages/MySqlConnector/

## 相关页面

- [Oracle 19c](Oracle19c.md)
- [SQLite](SQLite.md)
- [SqlSugar](SqlSugar.md)
- [EF Core](EFCore.md)
- [返回分组首页](index.md)
