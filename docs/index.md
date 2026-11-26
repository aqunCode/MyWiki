# MyWiki · 个人技术知识库

> 面向 .NET 8 / Avalonia / 工业上位机的离线技术笔记，重点覆盖信创环境下的跨平台 PLC 通信、数据采集与工程化落地。

| 项目 | 说明 |
|---|---|
| 站点名称 | MyWiki |
| 主题 | Material for MkDocs（中文，`font: false`，离线友好） |
| 构建工具 | MkDocs 1.6.1 + mkdocs-material 9.8.2 |
| 文档目录 | `docs/`（`mkdocs.yml` 与之同级） |
| 更新日期 | 2026-11-26 |

---

## 快速开始

虚拟环境建在 `E:\Pro\Personal\DocHub\.venv`（在 DocHub 目录下执行 `python -m venv .venv` 创建）。

```powershell
# 1. 激活虚拟环境（在 DocHub 目录下）
.\.venv\Scripts\Activate.ps1

# 2. 进入 MkDocs 项目目录
cd .\mywiki

# 3. 本地预览：http://127.0.0.1:8000
mkdocs serve

# 4. 构建静态站点到 site/
mkdocs build --clean
```

!!! note "nav 路径写法"
    `mkdocs.yml` 里 `nav` 的路径都是**相对于 `docs/` 目录**的，例如 `PLC/Modbus.md` 对应磁盘上的 `docs/PLC/Modbus.md`，不要写成 `docs/PLC/Modbus.md`。新增或修改页面后，先在 `nav` 对应分组下登记，再执行 `mkdocs build` 检查是否有 404 或警告。

---

## 知识地图

左侧导航按「一级分组 → 二级页面」组织，共 6 个分组：

| 分组 | 入口 | 覆盖内容 | 主要页面 |
|---|---|---|---|
| C# / .NET | [C# 基础](CSharp/index.md) | 语言与运行时、LINQ、异步、反射、性能 | `LINQ` · `异步编程` · `反射` · `性能优化` |
| Avalonia | [Avalonia 首页](Avalonia/index.md) | 跨平台桌面 UI、MVVM、绑定、自定义控件、导航、SukiUI | [SukiUI 中文离线手册](Avalonia/SukiUI.md) · `MVVM` · `数据绑定` |
| PLC / 工业控制 | [PLC 首页](PLC/index.md) | 通用报文协议、Modbus、西门子 PLC、串口、数据采集 | `Modbus` · `西门子 PLC` · `数据采集` |
| 数据库 | [数据库首页](Database/index.md) | Oracle / MySQL / SQLite 与 ORM 落库 | `Oracle 19c` · `SqlSugar` · `EF Core` |
| DevOps | [DevOps 首页](DevOps/index.md) | Git、Docker、Linux、银河麒麟 V11 部署 | `Linux` · `Kylin V11` · `Docker` |
| 工具 | [工具首页](Tools/index.md) | Visual Studio、PowerShell、MkDocs 本身 | `PowerShell` · `MkDocs` |

!!! tip "导航层级"
    `navigation.sections` 会把分组渲染成区块标题；Material 默认会抵消子页面的左缩进，本项目通过 `docs/stylesheets/extra.css` 恢复了二级/三级缩进并加了层级引导线。桌面宽度（≥ 1220px）下可见，移动端仍为逐层下钻。

---

## 当前技术主线

本知识库围绕一条主线组织：**在信创软硬件栈上，用通用报文协议实现跨平台西门子 PLC 通信**。

1. **协议层**：以 Modbus TCP、ISO-on-TCP（RFC 1006）之上的开放帧、OPC UA 等标准化方案为主，避免绑定 S7 等厂商私有协议；通过 `IPlcClient` / `IPlcFrameCodec` 一类接口把「报文编解码」与「传输通道」解耦，便于替换驱动与适配国产 CPU/操作系统。
2. **采集层**：异步任务调度、超时与重连、线程安全的数据缓冲、采集数据落库（[数据采集](PLC/DataAcquisition.md) → [数据库首页](Database/index.md)）。
3. **表现层**：[Avalonia](Avalonia/index.md) + MVVM 构建跨平台上位机，在[银河麒麟 V11](DevOps/KylinV11.md) 上验证字体、输入法、DPI 与渲染。
4. **交付层**：[Git](DevOps/Git.md) → `dotnet publish` → [Linux](DevOps/Linux.md) systemd 服务 / [Docker](DevOps/Docker.md) → 日志与回滚。

---

## 文档约定

- 全部文档为 UTF-8 编码的中文 Markdown，页面首行是一级标题，标题与 `mkdocs.yml` 中 `nav` 的显示名一致。
- 每篇子页开头有「文档信息」表，结尾有「相关页面」小节，用相对路径互相链接。
- 涉及版本号、NuGet 包、API 名称时以「实际安装版本 / 官方 XML 注释与 Demo」为准，不照抄未经核实的示例。
- 提示框使用 MkDocs `admonition` 语法；代码块一律标注语言，便于复制与高亮。
- 站点配置、主题样式、导航缩进规则见 [MkDocs](Tools/MkDocs.md)。

---

## 最近更新

| 日期 | 变更 |
|---|---|
| 2026-11-26 | 建立 6 个分组、32 篇页面的完整骨架并按主题补齐内容；修复左侧导航层级缩进；补齐 `extra.css` 与 `mathjax.js`；清理 `mkdocs.yml` 无效配置项。 |
