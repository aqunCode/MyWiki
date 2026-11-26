# 数据绑定

**文档信息**

| 项目 | 内容 |
| --- | --- |
| 分类 | Avalonia |
| 主题 | Binding / CompiledBinding / 转换器 / 集合刷新 |
| 适用技术栈 | .NET 8 / Avalonia 11 |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

Avalonia 的 `Binding` 以 `DataContext` 为根沿可视树向下继承，默认 `Mode` 由目标依赖属性决定（多数只读控件为 `OneWay`，`TextBox.Text`、`CheckBox.IsChecked` 等为 `TwoWay`）。绑定路径支持 `.` 子属性、`[index]` 索引器、`$parent[...]`、`#控件名` 与 `ElementName`。

`StyledProperty<T>` 注册的属性支持样式、动画与绑定；`DirectProperty` 少一层开销但不支持样式。跨类型展示靠 `IValueConverter`，多源聚合用 `MultiBinding`。打开 `x:CompileBindings="True"` 并配 `x:DataType` 后，`{Binding}` 编译为 `CompiledBinding`，路径与类型在构建期校验——对长期维护的 HMI 项目收益很大。

!!! note "版本与 API"
    不同 Avalonia 11 小版本对转换器、`MultiBinding`、`FallbackValue` 的支持细节略有差异；具体以当前安装版本的 XML 注释和 Demo 为准。

## 关键用法与代码示例

「通信状态 → 指示灯画刷」的转换器：

```csharp
using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace PlcHmi.Converters;

public sealed class BoolToBrushConverter : IValueConverter
{
    public IBrush On { get; set; } = Brushes.LimeGreen;
    public IBrush Off { get; set; } = Brushes.DimGray;

    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? On : Off;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
```

窗口里注册转换器、使用编译期绑定，并把寄存器列表绑到集合：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:PlcHmi.ViewModels"
        xmlns:conv="using:PlcHmi.Converters"
        x:Class="PlcHmi.Views.MainWindow"
        x:DataType="vm:MainViewModel"
        x:CompileBindings="True"
        Title="PLC 上位机">
    <Window.Resources>
        <conv:BoolToBrushConverter x:Key="StateBrush"
                                   On="LimeGreen" Off="DimGray" />
    </Window.Resources>
    <StackPanel Margin="16" Spacing="8">
        <Ellipse Width="14" Height="14"
                 Fill="{Binding IsOnline, Converter={StaticResource StateBrush}}" />
        <TextBlock Text="{Binding PlcState, StringFormat='状态：{0}'}" />
        <TextBox Text="{Binding IpAddress, Mode=TwoWay}" Watermark="PLC IP" />
        <ListBox ItemsSource="{Binding Tags}" Height="160" />
    </StackPanel>
</Window>
```

!!! warning "编译期绑定与资源类型"
    `x:DataType` 只作用于当前 XAML 作用域，嵌套 `DataTemplate` / `UserControl` 需各自声明或由 `ItemsSource` 推断。另外 `On="LimeGreen"` 依赖 `IBrush` 的类型转换器，不同版本行为可能不同，稳妥做法是在 `App.axaml` 里用 `<SolidColorBrush>` 资源引用。

信创 / Linux 下发布前自检字体与渲染（标准 fontconfig / Mesa 工具，非 Avalonia 专有 API）：

```bash
fc-list :lang=zh | head -n 10
fc-match "Noto Sans CJK SC"
LIBGL_ALWAYS_SOFTWARE=1 ./PlcHmi
```

## 典型场景（工业上位机 / 信创）

- 寄存器 / 标签值绑 `ObservableCollection<TagValue>`；100ms 级采集不要逐条触发 `PropertyChanged`，按帧批量替换或节流到 UI 刷新率，避免布局抖动。
- 通用报文解析成强类型 DTO 后再绑定，XAML 只认 DTO 属性；换成 Modbus TCP 或自定义 TCP 帧时绑定层零改动。
- 高 DPI 屏用相对尺寸与 `FontSize`，别把控件尺寸写死物理像素；`RenderScaling` 非 1 时绝对数值会偏小。

## 常见坑与排查

- 路径大小写、绑定到私有字段、`DataContext` 为 null 是最常见的三类静默失败；编译期绑定能把前两类变成构建错误。
- `ObservableCollection<T>` 从采集线程直接改会抛异常，必须封送回 UI 线程；`ReadOnlyObservableCollection` 可防止视图层误改。
- 中文输入法（fcitx5/ibus）下 `TextBox.Text` 在候选确认后才更新，别用 `KeyDown` / `TextInput` 抓汉字，否则丢字。
- 中文字体缺失渲染豆腐块：目标机需装 Noto CJK / 文泉驿，并在 `App.axaml` 给 `FontFamily` 配置 fallback。

## 参考链接

- Avalonia 官方文档：https://docs.avaloniaui.net/
- Avalonia 源码：https://github.com/AvaloniaUI/Avalonia
- CommunityToolkit.Mvvm 文档：https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/

## 相关页面

- [MVVM](MVVM.md)
- [自定义控件](CustomControls.md)
- [页面导航](Navigation.md)
- [SukiUI 中文离线开发手册](SukiUI.md)
- [返回分组首页](index.md)
