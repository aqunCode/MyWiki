# Avalonia 桌面开发

> 面向 .NET 8 / Avalonia 11 的跨平台桌面 UI 工程知识地图，重点服务信创 Linux 上的工业上位机开发。

本组记录使用 Avalonia 11 构建西门子 PLC 上位机过程中的 UI 层实践：从 MVVM 分层、数据绑定、自定义控件到页面导航，并以 SukiUI 6.x 作为主题控件库。内容默认读者已熟悉 C# / .NET 8，不解释语言基础，而聚焦绑定模型、渲染管线，以及 Linux / 银河麒麟 V11 下的字体、DPI、输入法、软件渲染与自包含发布等工程细节。通信侧坚持通用报文协议，UI 层只依赖抽象接口，避免与厂商专有协议绑定。涉及 SukiUI 与 Avalonia 的具体 API，均以当前安装版本的 XML 注释和 Demo 为准。

示例只表达工程结构与绑定 / 绘制模式，不承诺任何具体版本行为；页面之间用相对路径互链，便于整组离线阅读与检索。

## 本组文档

| 文档 | 内容 | 重点 |
| --- | --- | --- |
| [Avalonia 首页](index.md) | 分组知识地图与学习路径 | 页面之间的关系、跨分组依赖 |
| [MVVM](MVVM.md) | ObservableObject / RelayCommand / ViewModel 分层 | 采集线程与 UI 解耦、跨线程封送 |
| [数据绑定](DataBinding.md) | Binding / CompiledBinding / 转换器 / 集合刷新 | 高频标签值刷新、绑定失败排查 |
| [自定义控件](CustomControls.md) | UserControl / TemplatedControl / 自绘 Control | 仪表与趋势图、DPI 与软渲染 |
| [页面导航](Navigation.md) | ViewLocator / 区域切换 / SukiSideMenu | 多页面工控 HMI 的区域管理 |
| [SukiUI](SukiUI.md) | SukiUI 中文离线开发手册（800+ 行） | 主题、SukiWindow、Host、Toast |

## 学习路径

1. 先读 [MVVM](MVVM.md) 与 [数据绑定](DataBinding.md)，把 ViewModel、命令、绑定模型与编译期绑定（`x:CompileBindings`）跑通，这是后面所有页面的地基。
2. 再按 [自定义控件](CustomControls.md) 把寄存器仪表、告警灯、趋势曲线做成可复用控件，避免把业务逻辑堆进 AXAML。
3. 用 [页面导航](Navigation.md) 组织「总览 / 参数 / 报警 / 日志」多页面 HMI，确定 ViewModel 优先的区域切换方案。
4. 对照 [SukiUI](SukiUI.md) 配置主题、窗口与 Host，并把明暗切换、Toast 接入现有 ViewModel。
5. 最后结合 [Kylin V11](../DevOps/KylinV11.md) 做字体、输入法、渲染与自包含发布验证，完成信创目标机上线。

## 与其他分组的关系

- [PLC 首页](../PLC/index.md)：UI 层的数据来源。ViewModel 依赖 `IPlcLink` 之类的抽象与通用报文 DTO，不直接引用具体驱动；协议替换不应改动本组任何页面。
- [C# 首页](../CSharp/index.md)：`async/await`、`Channel<T>`、`PeriodicTimer`、record 等语言与运行时能力，是 MVVM 后台采集服务的基础。
- [Kylin V11](../DevOps/KylinV11.md)：中文字体（Noto CJK）、fcitx5/ibus 输入法、高 DPI 缩放、无 GPU 时的软件渲染、`linux-arm64` / `linux-loongarch64` 自包含发布都在该页落地。
- [数据库首页](../Database/index.md)：报警与历史曲线落库后，本组只负责展示，持久化与查询不放在 Avalonia 项目中。

## 参考链接

- Avalonia 官方文档：https://docs.avaloniaui.net/
- Avalonia 源码仓库：https://github.com/AvaloniaUI/Avalonia
- CommunityToolkit.Mvvm 文档：https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/
- .NET 8 文档：https://learn.microsoft.com/dotnet/
- SukiUI 仓库：https://github.com/kikipoulet/SukiUI
- Material for MkDocs：https://squidfunk.github.io/mkdocs-material/
