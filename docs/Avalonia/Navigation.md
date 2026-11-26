# 页面导航

**文档信息**

| 项目 | 内容 |
| --- | --- |
| 分类 | Avalonia |
| 主题 | ViewLocator / 区域切换 / 多页面 HMI |
| 适用技术栈 | .NET 8 / Avalonia 11 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Avalonia 没有强制的导航框架，常见三条路线：`ContentControl` + `DataTemplate`（ViewModel 优先的 `ViewLocator`）、`TransitioningContentControl`（带转场），以及框架级路由（ReactiveUI 的 `RoutingState`，或 [SukiUI](SukiUI.md) 的 `SukiSideMenu`）。CommunityToolkit.Mvvm 本身不提供导航，靠 `CurrentPage` 属性 + `WeakReferenceMessenger` 即可。

推荐 ViewModel 优先：ViewModel 持有 `CurrentPage`（`ObservableObject`），视图通过 `IDataTemplate` 按命名约定 `XxxViewModel → XxxView` 解析并赋 `DataContext`。这样视图不反向依赖具体页面类型，页面切换与 PLC 采集状态解耦，也便于单元测试。

!!! note "版本与 API"
    `TransitioningContentControl`、`SukiSideMenu` 的可用属性与转场类型随 Avalonia 11 / SukiUI 6.x 版本变化；具体以当前安装版本的 XML 注释和 Demo 为准。

## 关键用法与代码示例

`ViewLocator` 按约定解析视图，在 `App.axaml` 的 `<Application.DataTemplates>` 中注册 `<local:ViewLocator />`：

```csharp
using System;
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PlcHmi;

public sealed class ViewLocator : IDataTemplate
{
    public Control? Build(object? data)
    {
        var name = data!.GetType().FullName!
            .Replace("ViewModels.", "Views.")
            .Replace("ViewModel", "View");
        if (Type.GetType(name) is { } type && Activator.CreateInstance(type) is Control control)
        {
            control.DataContext = data;
            return control;
        }
        return new TextBlock { Text = $"未找到视图：{name}" };
    }

    public bool Match(object? data) => data is ObservableObject;
}
```

`MainViewModel` 只暴露当前页与切换命令：

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PlcHmi.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty]
    private ObservableObject _currentPage = new OverviewViewModel();
    [RelayCommand]
    private void Go(string page) => CurrentPage = page switch
    {
        "alarm" => new AlarmViewModel(),
        _ => new OverviewViewModel()
    };
}
```

窗口用 `TransitioningContentControl` 承载区域：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:PlcHmi.ViewModels"
        x:Class="PlcHmi.Views.MainWindow"
        x:DataType="vm:MainViewModel"
        x:CompileBindings="True"
        Title="PLC 上位机">
    <DockPanel>
        <StackPanel DockPanel.Dock="Left" Width="160" Margin="8" Spacing="4">
            <Button Content="总览" Command="{Binding GoCommand}" CommandParameter="overview" />
            <Button Content="报警" Command="{Binding GoCommand}" CommandParameter="alarm" />
        </StackPanel>
        <TransitioningContentControl Content="{Binding CurrentPage}" />
    </DockPanel>
</Window>
```

!!! warning "转场控件与命令参数"
    `TransitioningContentControl` 每次 `Content` 变化都会重建内容并释放旧视图，别把采集订阅放在视图构造函数里（应放在 ViewModel）。`CommandParameter` 是 `string`，`x:CompileBindings` 下 `RelayCommand` 的参数类型要与之匹配，否则构建期报错。

## 典型场景（工业上位机 / 信创）

- 「总览 / 参数 / 报警 / 日志」多页面 HMI：左侧 `SukiSideMenu`，右侧 `TransitioningContentControl`，`CurrentPage` 由导航 ViewModel 统一持有。
- 切换页面不中断 PLC 采集：采集服务是单例后台服务，页面 ViewModel 通过 messenger 订阅数据快照，避免每页各自开连接；协议切换只影响数据 DTO，导航结构无需改动。

## 常见坑与排查

- `ViewLocator` 用 `Type.GetType` 只能解析已加载程序集类型；视图类型跨程序集时改用程序集扫描，且别在视图构造里再 `new` ViewModel 覆盖 `DataContext`。
- 切页后内存不释放：视图订阅了 messenger / 事件却没退订，优先用 `WeakReferenceMessenger` 或在 `DetachedFromVisualTree` 里清理。
- 信创目标机输入法：侧边栏按钮获得焦点时，中文候选窗位置依赖 IM 与窗口焦点，导航切换后记得把焦点交还内容区。

## 参考链接

- Avalonia 官方文档：https://docs.avaloniaui.net/
- Avalonia 源码：https://github.com/AvaloniaUI/Avalonia
- SukiUI 仓库：https://github.com/kikipoulet/SukiUI

## 相关页面

- [MVVM](MVVM.md)
- [数据绑定](DataBinding.md)
- [自定义控件](CustomControls.md)
- [SukiUI 中文离线开发手册](SukiUI.md)
- [返回分组首页](index.md)
