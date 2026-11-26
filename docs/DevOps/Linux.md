# Linux

| 项目 | 内容 |
| --- | --- |
| 分类 | DevOps / 部署 |
| 主题 | .NET 8 上位机的系统级部署、权限与服务托管 |
| 适用技术栈 | .NET 8 / Linux / 信创 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

目标机是最小安装的国产 Linux / 银河麒麟 V11：无外网、常无完整桌面。部署问题集中在五处——**运行用户与权限、串口 / 网口、字体、服务托管、日志与回滚**。

- **发布模型**：`framework-dependent` 需目标机预装 .NET 运行时；信创离线现场更常用 `--self-contained true` + 单文件，把运行时一起带走，代价是体积大。用 `ldd` 确认自包含程序仍依赖的系统库（`libicu`、`libssl`、`libX11`、`fontconfig`）。
- **非 root 运行**：建专用用户，串口访问靠加入 `dialout` 组，避免整服务以 root 跑。
- **systemd**：`Type=simple`、`Restart=on-failure`、日志走 journald；`After=network-online.target` 保证网口就绪后再连 PLC。
- **字体**：Avalonia / Skia 依赖 fontconfig，中文需 Noto Sans CJK 或文泉驿，`fc-cache` 刷新。
- **时间**：时区统一 `Asia/Shanghai`，否则 PLC 事件时间戳与日志对不上。

## 关键用法与命令示例

交叉发布自包含单文件：

```bash
dotnet publish PlcHmi.csproj -c Release -r linux-arm64 \
  --self-contained true -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -o ./artifacts/plc-hmi-linux-arm64
chmod +x ./artifacts/plc-hmi-linux-arm64/PlcHmi
```

systemd 单元（此例为无界面采集 / 网关服务）：

```ini
[Unit]
Description=PLC HMI Gateway (.NET 8)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=plcapp
Group=plcapp
WorkingDirectory=/opt/plc-hmi
ExecStart=/opt/plc-hmi/PlcHmi
Environment=DOTNET_EnableDiagnostics=0
Environment=TZ=Asia/Shanghai
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

建用户、授权串口、装字体并启用服务：

```bash
sudo useradd -r -s /usr/sbin/nologin plcapp
sudo usermod -aG dialout plcapp
sudo mkdir -p /opt/plc-hmi /var/log/plc-hmi
sudo cp ./fonts/NotoSansCJKsc-Regular.otf /usr/share/fonts/
fc-cache -fv && fc-match "sans:lang=zh-cn"
sudo cp plc-hmi.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now plc-hmi.service
sudo journalctl -u plc-hmi.service -f --since "10 min ago"
```

## 典型场景（.NET 8 上位机部署到信创 Linux）

完整链路：x86 开发机交叉发布 → `tar czf` 连同 `version.json`、字体、unit 模板离线拷贝 → 目标机建用户 / 授权 / 装字体 → 解包到带版本号目录 `/opt/plc-hmi-1.4.2` 并用 `current` 软链指向 → `systemctl enable --now` 托管 → `journalctl` 验证。Avalonia 桌面程序不能只靠上面这个 unit：还需在 `[Service]` 增加 `Environment=DISPLAY=:0`、`Environment=XAUTHORITY=/home/plcapp/.Xauthority`，或改用桌面会话的 autostart；在 KylinWlcom 这类兼容 X11 又融合 Wayland 的显示框架下，X11 与 Wayland 两条路径都要实测。回滚时 `systemctl stop` → 把 `current` 软链切回 `/opt/plc-hmi-1.4.1` → `systemctl start`，并再次核对版本标识。

## 常见坑与排查

- **`error while loading shared libraries: libicu...`**：自包含仍链接系统库。用 `ldd PlcHmi` 定位缺项并补装；`DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` 只是临时绕开，会破坏中文排序 / 格式化，慎用。
- **GUI 起不来**：检查 `DISPLAY` / `XAUTHORITY` / `XDG_SESSION_TYPE`，确认显示服务协议与运行用户一致。
- **串口 `Permission denied`**：确认 `dialout` 组生效（`id plcapp`）、设备未被占用、安全框架 / SELinux 未拦截。
- **中文方框或问号**：`fc-match` 无中文字体，安装字体后 `fc-cache -fv`。
- **服务反复重启**：`journalctl -xeu plc-hmi.service` 看退出码；多为配置路径、权限或 PLC 连接失败。
- **日志时间对不上设备**：统一时区，必要时启用 NTP / chrony。

!!! warning "别用 invariant globalization 掩盖依赖问题"
    为绕开 libicu 而全局开启 `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`，会让中文排序、日期与数字格式化退化。现场应补齐系统库，把它只当作诊断手段而非交付配置。

## 参考链接

- .NET 应用发布：`https://learn.microsoft.com/dotnet/core/tools/dotnet-publish`
- 自包含部署：`https://learn.microsoft.com/dotnet/core/deploying/`
- systemd.service 手册：`https://www.freedesktop.org/software/systemd/man/systemd.service.html`
- fontconfig / `fc-cache`：`https://www.freedesktop.org/wiki/Software/fontconfig/`

## 相关页面

- [返回分组首页](index.md)
- [Git](Git.md)
- [Docker](Docker.md)
- [Kylin V11](KylinV11.md)
