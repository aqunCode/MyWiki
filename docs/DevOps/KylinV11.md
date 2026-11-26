# Kylin V11

| 项目 | 内容 |
| --- | --- |
| 分类 | DevOps / 部署 |
| 主题 | 银河麒麟桌面操作系统 V11 平台事实与上位机适配清单 |
| 适用技术栈 | .NET 8 / Linux / 信创 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

本页只记录**已核实的平台事实**，并把它们转成 .NET 8 上位机的适配动作；不把「操作系统 / 硬件层面的认证」推导成「.NET 8 运行时已获认证」。V11 于 2025 年 8 月 26 日在 2025 中国操作系统产业大会发布，是国内首个基于 Linux 6.6 内核的商用桌面 / 服务器操作系统系列，桌面版与服务器版同步推出。

| 平台事实 | 对上位机工程的含义（需实测） |
| --- | --- |
| 采用「磐石架构」，通过 KARE、开明包兼容 V10 生态 | 依赖 V10 上的库 / 驱动时，确认在 V11 上的提供方式并实测，不等于 .NET 免适配 |
| 自研显示框架 KylinWlcom 兼容 X11 生态并融合 Wayland 优势 | Avalonia 的窗口、输入法、DPI 需按 X11 / Wayland 两条路径分别验证 |
| 引入可编程安全框架 KSAF、算力共享，原生支持 MCP 协议 | 设备访问 / 服务自启可能受安全策略影响，联调时纳入排查 |
| 提供 Kylin SDK（官方称超过 2200 个开发接口） | 如需系统调用 / 硬件能力，优先查官方 SDK 而非照搬通用 Linux 假设 |
| 2026 年 3 月通过《操作系统政府采购需求标准》认证 | 属 OS 层认证，与 .NET 运行时适配无直接对应 |
| 2026 年 11 月推出硬件高质量认证体系 KHQL（覆盖桌面与服务器平台） | 硬件选型参考，不等于软件运行时认证 |

!!! warning "不要断言「.NET 8 已获官方认证」"
    上述政采标准认证与 KHQL 均为操作系统 / 硬件层面的认证。.NET 8 运行时能否在该信创 Linux 上运行，一律以目标机的实际适配、自编译运行时或容器镜像验证结果为准。

## 关键用法与命令示例

在 V11 目标机采集平台基线，作为交付与排障依据：

```bash
uname -r
uname -m
cat /etc/os-release
ldd --version | head -1
echo "$XDG_SESSION_TYPE"
```

验证 .NET 8 运行时 / 自包含应用能否启动（来源以现场实际情况为准）：

```bash
dotnet --info                       # 仅当系统已提供运行时
./artifacts/plc-hmi-linux-arm64/PlcHmi --version
DOTNET_EnableDiagnostics=0 ./PlcHmi
```

探测显示、字体与串口设备：

```bash
fc-match "sans:lang=zh-cn"
ls -l /dev/ttyS* /dev/ttyUSB* 2>/dev/null
ip -brief address
```

!!! note "探测命令是通用 Linux 命令"
    以上命令用于采集「这台目标机」的真实状态，不是对 V11 内部实现或认证结论的断言。任何结论都应来自这些命令在目标机上的实际输出。

## 典型场景（.NET 8 上位机部署到信创 Linux）

交付前在 V11 目标机跑一张适配验证清单：内核与系统版本、CPU 架构对应 RID、C 库版本、.NET 运行时来源（系统包 / 自编译 / 容器镜像）、串口与网口权限、中文字体、显示协议路径、安全框架是否拦截设备访问。PLC 侧坚持通用 TCP / 串口报文帧，不依赖厂商 Windows 专有驱动，使业务层不被目标 OS 绑定。若项目用到 V10 生态里的库或驱动，先确认 KARE / 开明包在 V11 上的兼容方式并实测，不要把「兼容 V10 生态」等同于「无需重新验证」。KSAF 等安全能力若影响串口 / 网络访问或服务自启，通过审计日志定位并按需申请策略白名单，而不是关闭安全框架。

## 常见坑与排查

- **把政采认证 / KHQL 误读为运行时认证**：两者都不覆盖 .NET 8，适配结论必须来自目标机实测。
- **预设只有 X11**：KylinWlcom 兼容 X11 并融合 Wayland，Avalonia 在两种会话下的表现要分别测。
- **架构与 RID 不匹配**：`uname -m` 与 `-r linux-arm64` 等 RID 对齐，避免 x86 制品误投国产 CPU。
- **自包含仍缺系统库**：`ldd` 核对 `libicu`、`libssl`、`libX11`、`fontconfig` 等基础依赖。
- **安全策略拦截设备**：出现 `Permission denied` 时，除 `dialout` 组外还要查安全框架审计日志。
- **中文显示异常**：确认字体安装与 `fc-cache`，并确认运行用户的字体缓存可见。

## 参考链接

- 银河麒麟官方站点：[https://www.kylinos.cn/](https://www.kylinos.cn/)
- V11 发布新闻：[https://www.kylinos.cn/about/news/1960318011530870785.html](https://www.kylinos.cn/about/news/1960318011530870785.html)
- Kylin SDK 与开发者资料入口见官方站点（具体以官方发布为准）。

## 相关页面

- [返回分组首页](index.md)
- [Git](Git.md)
- [Docker](Docker.md)
- [Linux](Linux.md)
