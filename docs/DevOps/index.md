# DevOps 首页

> 面向 .NET 8 / Avalonia 工业上位机的信创 Linux 交付工程：从 Git 提交到银河麒麟 V11 目标机稳定运行的构建、发布、托管与回滚。

本组服务于一个具体场景：把 .NET 8 + Avalonia 的西门子 PLC 上位机，从 Windows 开发机交付到国产 CPU、银河麒麟 V11 的离线现场。PLC 侧倾向通用 TCP / 串口报文帧，避免厂商专有协议与 Windows 驱动绑定，因此部署面的主要风险不在业务逻辑，而在**架构对齐、运行时依赖、设备权限、字体显示、服务托管与可复现回滚**。五篇文档按「源码 → 制品 → 系统 → 容器 → 目标 OS」组织，命令均可直接复制执行。

本组所有命令默认面向「x86_64 开发机 + 国产 CPU 目标机」这一对环境：架构用 `uname -m` 现场核对，依赖用 `ldd` 现场确认，不假设目标机可访问公网。内容聚焦能带进离线现场、最小可复现的一套动作，不展开 CI/CD 平台选型与流水线搭建。

> 阅读约定：代码块中的版本号（如 `1.4.2`）与路径（如 `/opt/plc-hmi`）是示例占位，落地时替换为项目实际值。

## 本组文档

| 文档 | 内容 | 重点 |
| --- | --- | --- |
| [DevOps 首页](index.md) | 本组知识地图、交付链路与学习路径 | 把 5 篇串成一条可落地的流水线 |
| [Git](Git.md) | 版本基线、tag、离线源码传递与可复现构建 | 现场版本可追溯、制品不入库 |
| [Docker](Docker.md) | 后台采集 / 协议网关容器化与多架构镜像 | arm64 / 国产 CPU 架构对齐、设备映射、离线导入 |
| [Linux](Linux.md) | systemd 托管、串口 / 网络权限、字体、离线部署 | 非 root 运行、journald 日志、版本回滚 |
| [Kylin V11](KylinV11.md) | 银河麒麟 V11 平台事实与上位机适配清单 | 以目标机实测为准，不预设运行时认证 |

## 一条典型交付链路

1. **提交与定版**：`main` 上打 `git tag -a v1.4.2`，把版本号经 `-p:Version` 注入程序集，确保现场跑的二进制能反查到提交。
2. **交叉发布**：在 x86 开发机执行 `dotnet publish -c Release -r linux-arm64 --self-contained true -p:PublishSingleFile=true -o ./artifacts/...`；RID 必须与目标机 `uname -m` 对齐。
3. **形成制品**：产物目录连同 `version.json`（git sha、tag、RID、构建时间）、`appsettings.Production.json` 模板、中文字体包、systemd unit 一起打成 `tar.gz`，经 U 盘 / 内网离线拷贝到目标机。
4. **目标机准备**：建专用运行用户并加入 `dialout`，安装 Noto Sans CJK 并 `fc-cache`，确认 `/dev/ttyS*`、网口固定 IP 与时区 `Asia/Shanghai`。
5. **服务托管**：部署到 `/opt/plc-hmi`，执行 `systemctl daemon-reload && systemctl enable --now plc-hmi.service`，日志统一进 `journalctl -u plc-hmi.service`。
6. **联调验证**：核对 PLC 报文日志时间戳、串口读写、Avalonia 窗口在 KylinWlcom / X11 兼容环境下的显示与输入法、高 DPI。
7. **回滚**：保留上一版目录或 `current` 软链，异常时 `systemctl stop` → 切回旧版本 → `systemctl start`，回滚后再次核对版本标识。

!!! note "桌面 GUI 与后台服务分开托管"
    Avalonia 桌面程序建议直接由 systemd / 桌面自启托管；容器更适合无界面的采集网关、协议转换与数据边车。同一进程不要既被 systemd 又被容器拉起。

## 学习路径

1. 先用 [Git](Git.md) 固化版本基线，保证任何一次交付都能复现。
2. 再用 [Linux](Linux.md) 打通单台目标机的发布、权限、字体与 systemd 托管。
3. 读 [Kylin V11](KylinV11.md) 了解目标平台约束，形成适配验证清单。
4. 需要横向扩展或多机一致性时，再引入 [Docker](Docker.md) 做多架构镜像。
5. 最后回到本页，把每一步串成可回滚的标准化流水线。

## 与其他分组的关系

- [PLC / 工业控制](../PLC/index.md)：通信协议、串口与报文帧定义是部署时设备权限与网络策略的输入。
- [Avalonia](../Avalonia/index.md)：桌面程序的字体、渲染、输入法与 DPI 问题需要在目标 OS 上实测。
- [MkDocs](../Tools/MkDocs.md)：本知识库自身的构建、离线预览与站点生成方式。

## 参考链接

- .NET 应用发布：`https://learn.microsoft.com/dotnet/core/tools/dotnet-publish`
- .NET RID 目录：`https://learn.microsoft.com/dotnet/core/rid-catalog`
- systemd 单元手册：`https://www.freedesktop.org/software/systemd/man/systemd.service.html`
- Git 官方文档：`https://git-scm.com/docs`
- Docker 官方文档：`https://docs.docker.com/`
- fontconfig / `fc-cache`：`https://www.freedesktop.org/wiki/Software/fontconfig/`
- 银河麒麟官方站点：[https://www.kylinos.cn/](https://www.kylinos.cn/)
