# PowerShell

| 字段 | 内容 |
| :--- | :--- |
| 分类 | 工具 |
| 主题 | Windows PowerShell 5.1 与 PowerShell 7 的差异、虚拟环境激活与自动化脚本 |
| 适用技术栈 | Windows PowerShell 5.1、PowerShell 7（pwsh）、.NET 8 / Python venv；Windows 开发机 + 银河麒麟 V11 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

PowerShell 有两个并行分支，写脚本前必须先明确目标，否则「本机跑得通、麒麟侧跑不通」几乎必然发生。

| 维度 | Windows PowerShell 5.1 | PowerShell 7 |
| :--- | :--- | :--- |
| 可执行文件 | `powershell.exe` | `pwsh` |
| 运行时 | .NET Framework | .NET（本机为 .NET 8 线） |
| 平台 | 仅 Windows，随系统内置 | Windows / Linux / macOS 跨平台 |
| 维护状态 | 仅安全修复，不再加新功能 | 持续迭代 |
| 典型命令差异 | `Get-WmiObject` 可用 | 改用 `Get-CimInstance` |

核心概念：一切皆「对象」而非文本管道；cmdlet 采用 `动词-名词` 命名；`.ps1` 脚本受执行策略（ExecutionPolicy）约束；`$PSVersionTable` 可判断当前会话版本与 `PSEdition`（5.1 为 `Desktop`，7 为 `Core`）。本知识库的构建脚本在 Windows 上可能由 5.1 执行，在麒麟 V11 上只能由 PowerShell 7 执行。

!!! note "脚本头部标注目标版本"
    用 `#requires -Version 7.0` 明确声明依赖，或在 README 里注明「仅 5.1」「仅 pwsh」。跨版本脚本避免使用 5.1 专有 WMI/模块与 7 专有语法，必要时按 `$PSVersionTable.PSEdition` 分支。

## 关键用法与示例

查看版本与环境（两个分支通用）：

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition
Get-Command python
```

本仓库虚拟环境位于项目上一级 `E:\Pro\Personal\DocHub\.venv`，在 DocHub 目录下创建与激活：

```powershell
Set-Location 'E:\Pro\Personal\DocHub'
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version
pip show mkdocs mkdocs-material
```

venv 相关常用操作：

```powershell
# 用 venv 内解释器执行，不依赖当前会话是否已激活
.\.venv\Scripts\python.exe -m pip list
# 停用（Activate.ps1 注入到当前会话的函数）
deactivate
# 查看解释器实际路径，避免命中系统 python 或商店别名
(Get-Command python).Source
```

执行策略（5.1 上激活 `.ps1` 常被拦截时）：

```powershell
Get-ExecutionPolicy -List
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

PowerShell 7 跨平台调用与新增语法（麒麟侧用 `pwsh`）：

```bash
pwsh -File ./scripts/build.ps1
pwsh -Command '$PSVersionTable.PSVersion'
```

```powershell
# 7 特有：管道链运算符、并行 ForEach、JSON 转哈希表
dotnet build -c Release && dotnet test --no-build
1, 2, 3 | ForEach-Object -Parallel { $_ * 2 }
Get-Content config.json -Raw | ConvertFrom-Json -AsHashtable
```

## 典型场景

- **Windows 端预览知识库**：5.1 或 7 会话里 `.\.venv\Scripts\Activate.ps1` → `mkdocs serve`；脚本要 `Set-Location` 到 `mywiki`，因为 `mkdocs.yml` 在那一层。
- **构建失败即中止**：调用外部程序后用 `$LASTEXITCODE` 判断，不要用 `$?` 判断 `dotnet` 这类原生命令。

```powershell
dotnet publish -c Release -r linux-arm64 --self-contained true
if ($LASTEXITCODE -ne 0) { throw "publish 失败，退出码 $LASTEXITCODE" }
```

- **处理含中文的 PLC 日志 / CSV**：`Import-Csv -Encoding UTF8`，输出时显式指定编码，见下方坑位。
- **跨平台脚本**：路径用 `Join-Path`，不要硬编码 `\`；行尾交给 Git 的 `eol=lf` 处理。

## 常见坑与排查

| 现象 | 原因 | 处理 |
| :--- | :--- | :--- |
| 生成的配置/脚本在 Linux 带乱码或 `^M` | 5.1 的 `>` / `Out-File` 默认 UTF-16LE | 显式 `-Encoding utf8`；7 默认 UTF-8 无 BOM，需统一 |
| `Activate.ps1` 无法加载 | 执行策略为 `Restricted` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`，或直接用 `.\.venv\Scripts\python.exe` |
| `python` 指向错误解释器 | 商店别名 / PATH 顺序 | `Get-Command python` 与 `(Get-Command python).Source` 核对 |
| `Get-WmiObject` 在 7 报「无法识别」 | 5.1 专有 cmdlet 被移除 | 改用 `Get-CimInstance` |
| 路径拼接在 Linux 失败 | 硬编码反斜杠 | `Join-Path $dir $name` |

!!! warning "5.1 与 7 的默认编码不一致"
    5.1 重定向默认 UTF-16LE，PowerShell 7 默认 UTF-8（无 BOM）。凡是生成给麒麟侧或 MkDocs 使用的文本，一律显式 `-Encoding utf8`，否则中文文档、YAML 和 shell 脚本都可能带 BOM 导致解析失败。

## 参考链接

- PowerShell 文档：https://learn.microsoft.com/zh-cn/powershell/
- 5.1 与 7 差异：https://learn.microsoft.com/zh-cn/powershell/scripting/whats-new/differences-from-windows-powershell
- 执行策略：https://learn.microsoft.com/zh-cn/powershell/module/microsoft.powershell.core/about/about_execution_policies
- Python venv：https://docs.python.org/zh-cn/3/library/venv.html

## 相关页面

- [Visual Studio](VisualStudio.md)：`dotnet` 构建与按 RID 发布
- [MkDocs](MkDocs.md)：激活 venv 后执行 `mkdocs serve` / `build`
- [返回分组首页](index.md)
