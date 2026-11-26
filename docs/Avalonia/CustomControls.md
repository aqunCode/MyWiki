# 自定义控件

**文档信息**

| 项目 | 内容 |
| --- | --- |
| 分类 | Avalonia |
| 主题 | UserControl / TemplatedControl / 自绘 Control |
| 适用技术栈 | .NET 8 / Avalonia 11 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Avalonia 自定义控件分三层，选错层级是后期返工的主要原因：

- `UserControl`：组合现有控件 + 后台逻辑，适合「某设备参数面板」这类一次性业务视图，不追求换肤。
- `TemplatedControl`：注册 `StyledProperty<T>`，视觉由 `ControlTheme` / `ControlTemplate` 提供，支持样式、伪类（`:pointerover` 等）与主题切换，适合告警灯、状态条等可复用控件。
- `Control` 子类重写 `Render(DrawingContext)`：完全自绘，适合趋势曲线、仪表盘等高频刷新、无大量子控件的场景。

`StyledProperty<T>` 支持样式 / 动画 / 绑定但有一层间接开销；`DirectProperty` 更快却不支持样式。属性变化需触发重绘时用 `AffectsRender<T>(...)` 或手动 `InvalidateVisual()`。`ControlTheme` 用 `TargetType` 匹配，`Style Selector` 里命名空间控件写作 `ctrl|PlcGauge`。

!!! note "版本与 API"
    `ControlTheme`、`PseudoClasses`、`Render` 相关 API 在 Avalonia 11 各小版本间有调整，SukiUI 6.x 也有自己的主题资源；具体以当前安装版本的 XML 注释和 Demo 为准。

## 关键用法与代码示例

自绘「压力条」，用 `AffectsRender` 把属性变化接到重绘（示例把量程固定为 100 以压缩篇幅）：

```csharp
using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace PlcHmi.Controls;

public sealed class PlcGauge : Control
{
    public static readonly StyledProperty<double> ValueProperty =
        AvaloniaProperty.Register<PlcGauge, double>(nameof(Value));

    static PlcGauge() => AffectsRender<PlcGauge>(ValueProperty);

    public double Value
    {
        get => GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }

    public override void Render(DrawingContext context)
    {
        var w = Bounds.Width * Math.Clamp(Value / 100d, 0, 1);
        context.FillRectangle(Brushes.DimGray, new Rect(0, 0, Bounds.Width, 8));
        context.FillRectangle(Brushes.LimeGreen, new Rect(0, 0, w, 8));
    }
}
```

在窗口里用样式设外观，并以编译期绑定喂数据：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ctrl="using:PlcHmi.Controls"
        xmlns:vm="using:PlcHmi.ViewModels"
        x:Class="PlcHmi.Views.MainWindow"
        x:DataType="vm:MainViewModel"
        x:CompileBindings="True"
        Title="PLC 上位机">
    <Window.Styles>
        <Style Selector="ctrl|PlcGauge">
            <Setter Property="Height" Value="24" />
            <Setter Property="Margin" Value="0,4" />
        </Style>
    </Window.Styles>
    <StackPanel Margin="16" Spacing="6">
        <TextBlock Text="压力" />
        <ctrl:PlcGauge Value="{Binding Pressure}" />
    </StackPanel>
</Window>
```

!!! warning "自绘坐标是 DIP，不是物理像素"
    `Bounds` 与 `Render` 里的坐标是设备无关像素，高 DPI 下 `RenderScaling` 可能为 1.5 / 2。别把物理像素数直接写进去，也别在 `Render` 里做耗时分配；高频刷新优先复用画刷与 `Geometry` 对象。

信创目标机自包含发布，RID 按实际 CPU 选择（海光/兆芯 x64、鲲鹏/飞腾 arm64、龙芯 loongarch64），具体支持以当前 .NET SDK 为准：

```bash
dotnet publish ./PlcHmi/PlcHmi.csproj -c Release -r linux-arm64 \
  --self-contained true -p:PublishSingleFile=true
```

## 典型场景（工业上位机 / 信创）

- 趋势曲线、棒图用 `Control` 自绘，避免为几百个点各建一个控件；配合 `InvalidateVisual` 按帧刷新，比绑定集合轻得多。
- 通信指示灯、报警条做成 `TemplatedControl`，用伪类切换颜色，主题随 [SukiUI](SukiUI.md) 明暗模式统一。
- 国产 CPU 无独立 GPU 时，减少 `RenderTargetBitmap` 截图与透明层叠；软渲染下这些操作开销被放大。

## 常见坑与排查

- 改了属性不重绘：忘注册 `AffectsRender` 或漏 `InvalidateVisual()`；`DirectProperty` 需自己在 setter 里触发。
- `TemplatedControl` 必须有无参构造，`ControlTheme` 的 `TargetType` 与 `Style Selector` 写错会静默不生效。
- Linux 下 `FormattedText` / `DrawingContext.DrawText` 找不到中文字体会出现豆腐块，用 `FontManager` 配 fallback 字族。
- 发布后控件样式丢失：确认 `App.axaml` 的 `StyleInclude` 已打进程序集资源，且自包含包带了 Skia 原生库。

## 参考链接

- Avalonia 官方文档：https://docs.avaloniaui.net/
- Avalonia 源码：https://github.com/AvaloniaUI/Avalonia
- SukiUI 仓库：https://github.com/kikipoulet/SukiUI

## 相关页面

- [MVVM](MVVM.md)
- [数据绑定](DataBinding.md)
- [页面导航](Navigation.md)
- [SukiUI 中文离线开发手册](SukiUI.md)
- [返回分组首页](index.md)
