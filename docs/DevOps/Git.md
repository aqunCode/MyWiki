# Git

| 项目 | 内容 |
| --- | --- |
| 分类 | DevOps / 部署 |
| 主题 | 工业上位机交付中的版本基线与可复现构建 |
| 适用技术栈 | .NET 8 / Linux / 信创 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

对 .NET 8 + Avalonia 上位机，Git 的价值不止「存代码」，而是**让现场任何一个二进制都能反查到确定的源码状态**。核心是把构建输入一并纳入版本控制：`*.csproj`、`Directory.Packages.props`、`global.json`、`NuGet.config`、`Directory.Build.props`、发布脚本与 systemd unit 模板。

- **版本基线**：`main` 只保留可交付状态，现场版本用带注释的 `git tag -a` 固化，禁止「在某台机器上改完直接拷走」。
- **制品不入库**：`bin/`、`obj/`、publish 输出、日志、PLC 采集报文、字体包与镜像 tar 全部忽略；离线交付靠「tag 源码 + 离线依赖源 + 发布脚本」复现，而非提交二进制。
- **版本号可追溯**：把 `git describe` 结果经 `-p:Version` 或 `AssemblyInformationalVersion` 注入程序集，现场 `--version` 即可确认运行版本，便于与 PLC 事件日志对齐。
- **换行与路径**：Windows 开发、Linux 运行，必须用 `.gitattributes` 锁定 `*.sh` / `*.service` 为 LF，避免脚本到目标机报 `^M`。

## 关键用法与命令示例

初始化与基础配置：

```bash
git init
git config core.autocrlf input
git config core.quotepath false
git config user.name "build"
git config user.email "build@intranet"
```

`.gitattributes` 与忽略规则（随仓库提交）：

```text
* text=auto
*.sh        text eol=lf
*.service   text eol=lf
*.cs        text eol=lf
*.sln       text eol=crlf
*.png       binary
*.tar.gz    binary
```

```text
# .gitignore
bin/
obj/
artifacts/
*.user
.vs/
*.log
appsettings.Production.json
```

定版、注入版本并交叉发布：

```bash
git tag -a v1.4.2 -m "信创现场交付基线"
VERSION=$(git describe --tags --always --dirty)
dotnet publish PlcHmi.csproj -c Release -r linux-arm64 \
  --self-contained true -p:PublishSingleFile=true \
  -p:Version="${VERSION#v}" -o ./artifacts/plc-hmi-${VERSION}
```

现场问题回溯：

```bash
git log --oneline --decorate --graph -20
git show --stat v1.4.2
git bisect start; git bisect bad; git bisect good v1.4.0
```

## 典型场景（.NET 8 上位机部署到信创 Linux）

目标机通常不通公网，也不应把生产机当构建机。用 `git bundle` 把某个 tag 的完整历史打包带走，配合离线 NuGet 源或自包含发布完成可复现构建：

```bash
git bundle create release-v1.4.2.bundle v1.4.2
# 现场：从 bundle 检出并构建
git clone release-v1.4.2.bundle plc-hmi-src
cd plc-hmi-src && git checkout v1.4.2
```

随制品附带 `version.json`（tag、commit sha、RID、构建时间、发布脚本版本），现场 `cat version.json` 即可确认版本。配置分离：`appsettings.Production.json` 只提交占位符模板，现场 IP、串口路径 `/dev/ttyS0`、PLC 站点号由部署脚本渲染，绝不硬编码进仓库。发布脚本、systemd unit 与字体清单全部入库，保证换一台机器也能产出同一份制品。

## 常见坑与排查

- **`bad interpreter: /bin/bash^M`**：CRLF 导致。用 `.gitattributes` 固定 LF，并执行 `git add --renormalize .`。
- **中文路径显示为转义码**：设置 `core.quotepath=false`。
- **现场配置被提交**：模板与实值分离，`.gitignore` 屏蔽 `appsettings.Production.json`。
- **大文件撑爆仓库**：字体包、离线镜像 tar 走制品库或 `tar` 离线传递，不进 Git；优先「清单 + 校验和」而非 Git LFS。
- **tag 与制品对不上**：发布脚本统一从 `git describe` 取版本号，禁止手填。
- **子模块恢复失败**：离线环境尽量不用 submodule，改用 vendored 依赖或私有 NuGet 源。

!!! warning "生产机不要执行 git pull"
    信创内网现场常无外网，且生产目录应交由 systemd 只读取用。用 `git bundle` / `git archive` 携带确定 tag 的源码，在受控构建机产出制品后再部署；生产机只接收制品与校验和。

## 参考链接

- Pro Git 中文版：`https://git-scm.com/book/zh/v2`
- `git bundle` 文档：`https://git-scm.com/docs/git-bundle`
- `dotnet publish`：`https://learn.microsoft.com/dotnet/core/tools/dotnet-publish`
- `.gitattributes`：`https://git-scm.com/docs/gitattributes`

## 相关页面

- [返回分组首页](index.md)
- [Docker](Docker.md)
- [Linux](Linux.md)
- [Kylin V11](KylinV11.md)
