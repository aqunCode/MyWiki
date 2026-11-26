# Visual Studio

| 字段 | 内容 |
| :--- | :--- |
| 分类 | 工具 |
| 主题 | 基于 Visual Studio 的 .NET 8 / Avalonia 工业上位机开发、调试与跨平台发布 |
| 适用技术栈 | .NET 8、C#、Avalonia、MSBuild、NuGet；Windows 开发机 + 银河麒麟 V11 部署目标 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Visual Studio 是 Windows 端的主力 IDE，但它并不是构建系统本身：真正的构建单元是解决方案（`.sln`）与项目文件（`.csproj`），背后由 MSBuild 驱动。Visual Studio 的「生成」与命令行 `dotnet build` 读的是同一份 `.csproj`，因此凡是能在 CI 或麒麟侧复现的操作，都应落成命令行脚本，而不是只依赖 IDE 菜单。

- **工作负载**：安装时勾选「.NET 桌面开发」即可获得 .NET SDK 与桌面模板；Avalonia 不是 VS 内置模板，需要通过官方扩展获得 AXAML 预览器与项目模板。
- **项目分层**：工业上位机建议拆为 `HMI`（Avalonia UI）、`Core`（业务与状态机）、`Infrastructure`（S7/串口/数据库）、`Tests`，避免把 PLC 通信代码写进 ViewModel。
- **目标框架**：统一 `net8.0`，跨项目保持一致；不要把界面层和通信层设成不同 TFM 后再靠引用硬连。
- **开发与部署分离**：本机 Windows 开发、麒麟 V11（国产 CPU、Linux）部署，靠 `dotnet publish -r <RID>` 产出目标平台可执行文件。

!!! note "IDE 与 CLI 要输出一致"
    提交前用 `dotnet build -c Release` 在干净终端跑一遍。IDE 里「能跑」不代表 CI 里「能构建」，差异通常来自 SDK 版本、`global.json` 或仅在 IDE 中设置的生成配置。

## 关键用法与示例

从零组织一个解决方案（命令真实可用，路径按项目实际调整）：

```bash
dotnet new sln -n PlcHmi
dotnet new classlib -n PlcHmi.Core -o src/PlcHmi.Core
dotnet sln add src/PlcHmi.Core/PlcHmi.Core.csproj
dotnet restore
dotnet build -c Release
```

一个典型的 `.csproj`（Avalonia 版本用浮动版本，具体以项目统一依赖解析结果为准）：

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.*" />
  </ItemGroup>
</Project>
```

面向信创目标发布：

```bash
dotnet publish src/PlcHmi/PlcHmi.csproj -c Release -r linux-arm64 --self-contained true
```

RID 必须按目标机器 CPU 架构选择，可用 `dotnet --info` 查看 SDK，再用 `--self-contained true` 把运行时一并带出，避免目标机缺少 .NET 运行时。

## 典型场景

- **远程调试 PLC 采集服务**：服务在麒麟侧运行，Windows 端用「调试 → 附加到进程」（`Ctrl+Alt+P`）连接，或在目标机部署 `vsdbg` 做跨平台远程调试；采集线程建议加条件断点，避免每帧刷新都命中。
- **离线/内网 NuGet**：在解决方案根放 `NuGet.Config`，指向本地或内网源，保证 CI 与麒麟侧 `dotnet restore` 不依赖公网。
- **平台差异条件编译**：串口设备名（Windows `COM3` vs Linux `/dev/ttyS0`）、路径分隔符、配置文件位置用 `#if` 或运行时 `OperatingSystem.IsLinux()` 分支封装到 Infrastructure 层。
- **发布前自检**：`dotnet list package` 核对依赖版本，`dotnet build -warnaserror` 把警告暴露在早期。

```csharp
// 平台相关路径集中处理，别散落在 UI 层
public static string SerialPortName => OperatingSystem.IsLinux()
    ? "/dev/ttyS0"
    : "COM3";
```

## 常见坑与排查

| 现象 | 常见原因 | 处理 |
| :--- | :--- | :--- |
| VS 能编译、`dotnet build` 失败 | SDK 版本或 `global.json` 不一致 | `dotnet --info` 对比，统一 SDK 或调整 `global.json` |
| Avalonia XAML 预览器空白 | 预览器加载编译后程序集 | 先成功 `build` 一次，再打开 AXAML 预览 |
| `linux-x64` 产物在国产机器无法执行 | 目标 CPU 非 x64 | 按实机架构改用 `linux-arm64` 等 RID |
| 脚本在 Linux 上 `^M: bad interpreter` | 文件是 CRLF 换行 | 用 `.gitattributes` 固定 `*.sh eol=lf` |
| 发布向导与 CLI 产物不一致 | 向导默认 `self-contained`/裁剪选项不同 | 统一用 CLI 脚本发布，不依赖 GUI 向导 |

!!! warning "不要在未确认 CPU 架构时套用 x64 RID"
    信创平台国产 CPU 可能是 ARM64 或其他架构。`linux-x64` 产物在这些机器上无法运行，且 `--self-contained true` 会把 x64 运行时一起打包，错误更隐蔽。先 `uname -m` 确认架构再选 RID。

## 参考链接

- Visual Studio 文档：https://learn.microsoft.com/zh-cn/visualstudio/
- dotnet publish：https://learn.microsoft.com/zh-cn/dotnet/core/tools/dotnet-publish
- .NET RID 目录：https://learn.microsoft.com/zh-cn/dotnet/core/rid-catalog
- Avalonia 官方文档：https://docs.avaloniaui.net/

## 相关页面

- [PowerShell](PowerShell.md)：构建/发布脚本与本仓库虚拟环境激活
- [MkDocs](MkDocs.md)：本知识库的构建配置与新增文档流程
- [返回分组首页](index.md)
