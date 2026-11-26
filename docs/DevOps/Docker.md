# Docker

| 项目 | 内容 |
| --- | --- |
| 分类 | DevOps / 部署 |
| 主题 | 后台采集 / 协议网关容器化与国产 CPU 多架构镜像 |
| 适用技术栈 | .NET 8 / Linux / 信创 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

容器在本知识库的定位要克制：**Avalonia 桌面 GUI 依赖 X11 / Wayland、字体与输入法，容器化收益低、坑多，通常直接由 systemd 托管**；真正适合容器的是无界面部分——PLC 采集 worker、协议网关、数据上报、MQTT / 数据库边车。由于 PLC 侧采用通用 TCP / 串口报文帧，容器只需网络设备或串口映射，不依赖厂商 Windows 专有驱动。

- **架构对齐是第一位**：x86_64 开发机构建的镜像不能直接跑在 arm64 / 国产 CPU 目标机上。`docker buildx` 配合 `$TARGETARCH` 产出多架构镜像，RID 与镜像清单架构必须一致。
- **基础镜像可用性需实测**：.NET 官方镜像对主流 `amd64` / `arm64` 提供多架构支持；其它国产指令集的基础镜像或运行时以实际可用镜像、自编译运行时为准，不预设「官方已适配」。
- **离线交付**：现场无公网，用 `docker save` / `docker load` 或内网 registry，绝不依赖目标机 `pull` 公网。
- **设备与权限**：串口用 `--device` 映射并加入 `dialout` 组；PLC TCP 用 `--network host` 最省事。

## 关键用法与命令示例

多阶段 `Dockerfile`，用 `TARGETARCH` 让同一份文件适配多架构：

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG TARGETARCH
WORKDIR /src
COPY . .
RUN dotnet restore PlcGateway.csproj -a $TARGETARCH
RUN dotnet publish PlcGateway.csproj -c Release -a $TARGETARCH \
    --self-contained false -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime:8.0
WORKDIR /app
COPY --from=build /app/publish .
ENV TZ=Asia/Shanghai
ENTRYPOINT ["dotnet", "PlcGateway.dll"]
```

构建多架构镜像并离线导出目标架构制品：

```bash
docker buildx create --use --name sc-builder
docker buildx build --platform linux/amd64,linux/arm64 \
  -t registry.intranet/plc-gateway:1.4.2 --push .
# 在可访问内网仓库的机器导出 arm64 镜像
docker pull --platform linux/arm64 registry.intranet/plc-gateway:1.4.2
docker save -o plc-gateway-1.4.2-arm64.tar registry.intranet/plc-gateway:1.4.2
# 目标机：
docker load -i plc-gateway-1.4.2-arm64.tar
```

运行（网络 + 串口 + 只读配置 + 持久化日志）：

```bash
docker run -d --name plc-gateway \
  --network host \
  --device=/dev/ttyS0:/dev/ttyS0 \
  --group-add dialout \
  -v /etc/plc-gateway:/app/config:ro \
  -v /var/log/plc-gateway:/app/logs \
  -v /etc/localtime:/etc/localtime:ro \
  --restart unless-stopped \
  registry.intranet/plc-gateway:1.4.2
```

## 典型场景（.NET 8 上位机部署到信创 Linux）

先在目标机 `uname -m` 与 `docker version` 确认架构，再决定镜像标签与是否自编译运行时。后台网关容器化、Avalonia 桌面程序留在宿主机 systemd，两者通过本机 TCP / Unix socket 通信，避免把 GUI 塞进容器。离线现场以 `docker save` 生成的 tar 连同 `sha256sum` 校验和交付，配合固定 tag（如 `1.4.2`）而非 `latest`。多机一致性与快速回滚靠镜像 tag 与 `docker compose` 的 `image:` 版本切换实现；PLC 报文日志与容器日志时间统一 `Asia/Shanghai`，便于与设备事件对齐。

## 常见坑与排查

- **`exec format error`**：镜像架构与 CPU 不匹配，用 `docker inspect --format '{{.Architecture}}'` 核对。
- **串口打不开**：`--device` 已映射但容器内用户无 `dialout` 权限；或 udev 把 `/dev/ttyS0` 重命名，改用固定 `by-id` 路径。
- **容器时区 / 日志时间偏差**：挂载 `/etc/localtime` 或设 `TZ`。
- **GUI / 报表缺中文字体**：容器内装 `fonts-noto-cjk` 并 `fc-cache -fv`。
- **同一服务被双重拉起**：systemd 与容器只选其一。
- **非主流架构无基础镜像**：以实际可用镜像或自编译运行时为准，先做最小 `hello` 镜像验证再上业务。

!!! note "通用报文协议让容器更轻"
    PLC 通信走标准 TCP / 串口字节帧时，容器不需要厂商私有 SDK 或 Windows 驱动，只需网络与设备映射，这正是「避免厂商专有协议绑定」在工程部署上的直接收益。

## 参考链接

- Docker 官方文档：`https://docs.docker.com/`
- buildx 多平台构建：`https://docs.docker.com/build/building/multi-platform/`
- .NET 容器镜像：`https://learn.microsoft.com/dotnet/core/docker/`
- `docker save` / `docker load`：`https://docs.docker.com/reference/cli/docker/image/save/`

## 相关页面

- [返回分组首页](index.md)
- [Git](Git.md)
- [Linux](Linux.md)
- [Kylin V11](KylinV11.md)
