# MVVM

**文档信息**

| 项目 | 内容 |
| --- | --- |
| 分类 | Avalonia |
| 主题 | MVVM 分层与 CommunityToolkit.Mvvm 源生成器 |
| 适用技术栈 | .NET 8 / Avalonia 11 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Avalonia 的绑定契约只有三条：`INotifyPropertyChanged` 驱动属性刷新、`ICommand` 驱动动作、依赖属性（`StyledProperty` / `DirectProperty`）驱动控件状态。ViewModel 不应引用 `Window`、`Control` 等 Avalonia 类型——PLC 采集服务在信创目标机上常以无界面后台方式自检，纯 POCO ViewModel 才能被单元测试直接覆盖。

CommunityToolkit.Mvvm 用源生成器替代样板代码：`ObservableObject` 实现通知，`[ObservableProperty]` 从字段生成分部属性，`[RelayCommand]` 生成 `ICommand`（异步为 `AsyncRelayCommand`）。`WeakReferenceMessenger` 负责跨 ViewModel 通信且不会因订阅泄漏内存。`DataContext` 由视图或 `ViewLocator` 装配，见 [页面导航](Navigation.md)。

!!! note "版本与 API"
    CommunityToolkit.Mvvm 与 SukiUI 6.x 的生成器特性、命令签名会随版本变化；具体以当前安装版本的 XML 注释和 Demo 为准，不要照抄本文里的命名空间假设。

## 关键用法与代码示例

「连接 PLC / 轮询状态」的最小 ViewModel，其中 `IPlcLink` 是项目内定义的通用报文通信接口：

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PlcHmi.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IPlcLink _link;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(ConnectCommand))]
    private bool _isBusy;

    [ObservableProperty]
    private string _plcState = "未连接";

    public MainViewModel(IPlcLink link) => _link = link;

    [RelayCommand(CanExecute = nameof(CanConnect))]
    private async Task ConnectAsync(CancellationToken ct)
    {
        try
        {
            IsBusy = true;
            await _link.OpenAsync(ct);
            var value = await _link.ReadAsync("DB1.DBD0", ct);
            PlcState = $"在线 / 压力={value}";
        }
        finally { IsBusy = false; }
    }

    private bool CanConnect() => !IsBusy;
}
```

视图只做绑定，`Design.DataContext` 让预览有数据，编译期绑定把路径错误提前到构建期：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:PlcHmi.ViewModels"
        x:Class="PlcHmi.Views.MainWindow"
        x:DataType="vm:MainViewModel"
        x:CompileBindings="True"
        Title="PLC 上位机">
    <Design.DataContext>
        <vm:MainViewModel />
    </Design.DataContext>
    <StackPanel Margin="16" Spacing="8">
        <TextBlock Text="{Binding PlcState, FallbackValue='未连接'}" />
        <Button Content="连接" Command="{Binding ConnectCommand}" />
        <ProgressBar IsIndeterminate="{Binding IsBusy}" />
    </StackPanel>
</Window>
```

!!! warning "设计期实例要求无参构造"
    `Design.DataContext` 会调用 `MainViewModel()`，而真实构造依赖 `IPlcLink`。生产项目应改用 `d:DataContext` + `d:DesignInstance` 或提供设计期无参重载，否则预览报构造异常。`x:CompileBindings="True"` 下 `{Binding}` 走编译期检查，路径写错会在构建时暴露。

## 典型场景（工业上位机 / 信创）

- 采集用 `PeriodicTimer` + `Channel<T>` 跑在后台，结果经 `Dispatcher.UIThread.Post` 或 messenger 推给 ViewModel；ViewModel 绝不阻塞 UI 线程。
- 通信抽象成 `IPlcLink`（Open / Read / Write + 通用帧 DTO），UI 不引用 S7 专有协议类型；换成 Modbus TCP 或自定义 TCP 帧时只改驱动层。
- 银河麒麟 V11 无 XAML 设计器，`d:DataContext`、编译期绑定与 ViewModel 单测是主要验证手段；中文输入依赖 fcitx5/ibus，ViewModel 层不要假设 `KeyDown` 能拿到汉字。

## 常见坑与排查

- `[ObservableProperty]` 字段必须是 `partial` 类的私有字段且小写，生成的是大写属性；漏 `partial` 或拼错字段名是编译期最常见错误。
- `ObservableCollection<T>` 非线程安全：采集线程直接 `Add` 会崩，必须封送回 UI 线程，或按帧批量提交。
- `AsyncRelayCommand` 默认禁止并发，`IsBusy` 置位时机要与 `CanExecute` 同步，避免按钮永久灰掉。
- 绑定失败默认静默：开启 `x:CompileBindings` 并查看 Avalonia 日志，可快速定位 `DataContext` 为 null 或路径大小写错误。

## 参考链接

- Avalonia 官方文档：https://docs.avaloniaui.net/
- CommunityToolkit.Mvvm 文档：https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/
- Avalonia 源码：https://github.com/AvaloniaUI/Avalonia

## 相关页面

- [数据绑定](DataBinding.md)
- [自定义控件](CustomControls.md)
- [页面导航](Navigation.md)
- [SukiUI 中文离线开发手册](SukiUI.md)
- [返回分组首页](index.md)
