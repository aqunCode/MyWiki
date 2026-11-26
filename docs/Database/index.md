# 数据库首页

> 面向 .NET 8 工业上位机的数据落库知识地图：选型、连接、事务、批量写入与信创适配。

本组围绕「信创平台上跨平台西门子 PLC 通信与数据采集」场景组织，覆盖从连接串与客户端依赖、事务与并发控制、高频采集批量写入，到银河麒麟桌面 V11 / 国产 CPU / Linux 上的驱动适配与国产数据库迁移。内容以工程实践为主，示例统一基于 .NET 8；涉及具体包版本、驱动能力时，一律「以实际安装的 NuGet 包版本为准」。采集链路建议采用通用报文协议与通用 SQL，避免把业务逻辑绑死在厂商专有协议或专有数据库对象上。

## 本组文档

| 文档 | 内容 | 重点 |
|---|---|---|
| [数据库首页](index.md) | 本组知识地图、选型建议、学习路径 | 按场景选库、按链路定位文档 |
| [Oracle 19c](Oracle19c.md) | ODP.NET 托管驱动、连接串、数组绑定批量写入 | 免 Instant Client 部署、国产库兼容改造 |
| [MySQL](MySQL.md) | MySqlConnector 连接、事务、批量 INSERT 与批量加载 | Linux 纯托管驱动、字符集与时区 |
| [SQLite](SQLite.md) | Microsoft.Data.Sqlite、文件库、WAL 与写锁 | 边缘缓冲、路径大小写、原生库架构 |
| [SqlSugar](SqlSugar.md) | SqlSugarClient、IAdo、Fastest 批量与多库切换 | 国产数据库 provider 适配、批量落库 |
| [EF Core](EFCore.md) | DbContext/DbSet、异步 API、迁移与批量策略 | 跟踪开销、跨库 provider 切换 |

## 选型建议

| 方案 | 适用场景 | 信创适配要点 |
|---|---|---|
| Oracle 19c | 对接既有 MES/ERP、存量库、强一致事务 | 用 `Oracle.ManagedDataAccess.Core` 纯托管驱动免装客户端；迁移达梦/人大金仓时先剥离 PL/SQL 专有对象 |
| MySQL / MariaDB | 新建中心库、部署简单、与采集服务同机 | 用 `MySqlConnector` 纯托管驱动，不依赖 `libmysqlclient`；统一 `utf8mb4` 与会话时区 |
| SQLite | 边缘侧缓存、单机配置、断网续传缓冲 | 无服务端；核对 Linux 路径大小写、WAL 文件权限与国产 CPU 上 `SQLitePCLRaw` 原生库架构 |
| SqlSugar（ORM） | 需快速切换多库、批量写入优先、国产库适配 | 通过 `DbType` 切换达梦/人大金仓等 provider，业务 SQL 保持通用 |
| EF Core（ORM） | 领域模型清晰、需要 Code First 迁移与 LINQ | 换 provider 需重建迁移；默认逐行 INSERT，高频写入须配合批量扩展或原生 SQL |

!!! note "一条主链路"
    典型组合是「边缘 SQLite 缓冲 + 中心库批量落库 + 上层 Avalonia 查询」。把数据访问收敛到独立的 Infrastructure 项目，换库时只改 provider 与连接串，业务层与 PLC 报文解析层不动。具体包版本「以实际安装的 NuGet 包版本为准」。

## 学习路径

1. 读本页「选型建议」，确定中心库与边缘缓冲的组合，明确哪些表属于高频写入表。
2. 按所选库精读对应子页的「连接与配置」，在目标信创机器上跑通首个连接与一次参数化写入。
3. 结合 [数据采集](../PLC/DataAcquisition.md) 的采样频率，设计攒批窗口、事务边界与失败重传（见各页「关键用法与代码示例」）。
4. 用 [异步编程](../CSharp/Async.md) 规范把同步落库改成异步，传递 `CancellationToken`，避免阻塞采集循环与 UI 线程。
5. 参照 [Kylin V11 部署](../DevOps/KylinV11.md) 验证客户端依赖、文件路径大小写、原生库架构与自包含发布结果。

## 与其他分组的关系

- [PLC / 数据采集](../PLC/DataAcquisition.md)：定义点位、时间戳、采样周期与断网续传，是落库链路的上游。
- [C# 异步编程](../CSharp/Async.md)：`OpenAsync` / `ExecuteNonQueryAsync` / `SaveChangesAsync` 的取消、并发与异常传播。
- [DevOps / Kylin V11](../DevOps/KylinV11.md)：国产 CPU、驱动原生依赖、中文字体/字符集、文件路径与运行时发布。

## 参考链接

- Oracle Database 19c 文档：https://docs.oracle.com/en/database/oracle/oracle-database/19/
- MySQL 文档：https://dev.mysql.com/doc/
- MySqlConnector：https://mysqlconnector.net/
- SQLite 文档：https://www.sqlite.org/docs.html
- Microsoft.Data.Sqlite：https://learn.microsoft.com/dotnet/standard/data/sqlite/
- SqlSugar 文档：https://www.donet5.com/Home/Doc
- EF Core 文档：https://learn.microsoft.com/ef/core/
- MkDocs Material：https://squidfunk.github.io/mkdocs-material/
