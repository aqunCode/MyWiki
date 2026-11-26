# 工具首页

> 面向 .NET 8 / Avalonia 工业上位机开发的本地工具链笔记：IDE、Shell 与文档站点。

本组收录日常开发直接依赖、却不属于业务代码的三类工具：**Visual Studio**（Windows 端 .NET / Avalonia 主力 IDE）、**PowerShell**（Windows 自动化、虚拟环境激活）、**MkDocs**（本知识库自身的构建与预览）。读者默认熟悉 C# 与命令行，内容只讲「在本项目里怎么配、怎么用、哪里踩坑」，不重复官方入门教程。工程背景为 .NET 8 / Avalonia、跨平台西门子 PLC 上位机，部署侧是银河麒麟桌面 V11（国产 CPU、Linux），因此凡涉及 Windows 侧工具与 Linux 侧目标的差异都会单独标注；组内跳转一律使用相对路径，方便整站迁移或离线托管。

## 本组文档

| 文档 | 内容 | 重点 |
| :--- | :--- | :--- |
| [工具首页](index.md) | 本组知识地图、命令速查、跨分组关系 | 快速定位该读哪一页 |
| [Visual Studio](VisualStudio.md) | 解决方案组织、工作负载、调试、按 RID 发布 | 面向麒麟 V11 的 `dotnet publish` |
| [PowerShell](PowerShell.md) | 5.1 与 7 的差异、venv 激活、执行策略、脚本 | 本仓库 `.venv` 的真实操作 |
| [MkDocs](MkDocs.md) | 本知识库目录、`mkdocs.yml`、构建与新增文档清单 | `nav` / 插件 / 已知坑 |

## 常用速查

| 工具 | 常用命令 | 说明 |
| :--- | :--- | :--- |
| .NET CLI | `dotnet --info` | 核对 SDK 与运行时，排查 `global.json` 不一致 |
| .NET CLI | `dotnet build -c Release` | 命令行构建，与 IDE 共用 csproj |
| .NET CLI | `dotnet publish -c Release -r linux-arm64 --self-contained true` | 按目标 CPU 架构出包（RID 依实机选） |
| Visual Studio | `devenv /edit <file>`、`Ctrl+.` | 打开文件、快速操作与重构 |
| PowerShell | `.\.venv\Scripts\Activate.ps1` | 在 `E:\Pro\Personal\DocHub` 下激活虚拟环境 |
| PowerShell 7 | `pwsh -File .\scripts\build.ps1` | 跨平台脚本入口（`pwsh` 而非 `powershell.exe`） |
| MkDocs | `mkdocs serve` | 本地预览，默认 http://127.0.0.1:8000 |
| MkDocs | `mkdocs build --clean` | 清理后输出到 `site/` |
| Git | `git status`、`git diff` | 提交前核对文档改动 |

## 与其他分组的关系

- 工具命令与脚本都落在版本库里，提交规范与分支策略见 [Git](../DevOps/Git.md)。
- Windows 写好的脚本最终要在信创环境执行，路径、换行、编码与权限差异见 [Kylin V11](../DevOps/KylinV11.md)。
- `dotnet` / MSBuild 背后的语言与运行时语义，配合 [C# / .NET 分组首页](../CSharp/index.md) 一起读。
- 本组 [MkDocs](MkDocs.md) 页专门记录知识库自身的构建配置，与站点内容分组相互独立。
- 信创目标可能是 ARM64 等非 x64 架构，发布 RID 与自包含运行时的选择要和 [Kylin V11](../DevOps/KylinV11.md) 页的架构说明对齐。

## 参考链接

- Visual Studio 文档：https://learn.microsoft.com/zh-cn/visualstudio/
- .NET CLI：https://learn.microsoft.com/zh-cn/dotnet/core/tools/
- PowerShell 文档：https://learn.microsoft.com/zh-cn/powershell/
- MkDocs 官方：https://www.mkdocs.org/
- Material for MkDocs：https://squidfunk.github.io/mkdocs-material/
