<a id="sukiui-中文离线开发手册"></a>
# SukiUI 中文离线开发手册
<a id="面向-avalonia-ui-net-8-桌面应用"></a>
## 面向 Avalonia UI / .NET 8 桌面应用

| 文档信息 | 内容 |
|---|---|
| 分类 | Avalonia |
| 主题 | SukiUI 中文离线开发手册（控件、主题、Host、MVVM 集成） |
| 适用技术栈 | .NET 8 / Avalonia 11 / SukiUI 6.x |
| 关联分组 | [Avalonia 首页](index.md) · [PLC / 工业控制](../PLC/index.md) · [DevOps](../DevOps/index.md) |
| 更新日期 | 2026-11-26 |

> 本页由 `mkdocs.yml` 的 `nav → Avalonia → SukiUI` 指向；同组其他页面见文末「相关页面」。

**版本说明：** 本手册以 SukiUI 6.x API 为主要讲解对象，并按 Avalonia 11 系列项目组织示例。针对 Avalonia 11.3.9 项目，建议先采用 SukiUI 6.0.3 作为参考版本；安装前仍需检查 NuGet 依赖解析结果。SukiUI 6.1.1 要求 Avalonia 组件至少 11.3.14，SukiUI 7.0.1 则面向 Avalonia 12，不能直接与 Avalonia 11.3.9 混用。

> 本文是整理后的离线开发指南，不是官方文档逐字翻译，也不保证覆盖 SukiUI 全部 API。控件具体属性以项目实际引用版本的 XML 注释、Demo 源码和 NuGet 依赖为准。

---

<a id="目录"></a>
## 目录


- [1. SukiUI 是什么](#1-sukiui-是什么)
  - [1.1 SukiUI 与 Avalonia 的关系](#11-sukiui-与-avalonia-的关系)
  - [1.2 推荐使用场景](#12-推荐使用场景)
- [2. 版本选择与安装](#2-版本选择与安装)
  - [2.1 版本兼容要点](#21-版本兼容要点)
  - [2.2 安装 SukiUI](#22-安装-sukiui)
  - [2.3 Fluent 主题是否需要保留](#23-fluent-主题是否需要保留)
- [3. App.axaml 全局配置](#3-appaxaml-全局配置)
  - [3.1 注册 SukiTheme](#31-注册-sukitheme)
  - [3.2 设置中文本地化](#32-设置中文本地化)
  - [3.3 建议 App.axaml 的资源组织](#33-建议-appaxaml-的资源组织)
- [4. SukiWindow 主窗口](#4-sukiwindow-主窗口)
  - [4.1 用 SukiWindow 替代 Window](#41-用-sukiwindow-替代-window)
  - [4.2 窗口背景](#42-窗口背景)
  - [4.3 什么时候仍使用普通 Window](#43-什么时候仍使用普通-window)
- [5. 主题、颜色与明暗模式](#5-主题颜色与明暗模式)
  - [5.1 主题组成](#51-主题组成)
  - [5.2 主题切换的原则](#52-主题切换的原则)
  - [5.3 语义化业务颜色](#53-语义化业务颜色)
- [6. 常用控件样式](#6-常用控件样式)
  - [6.1 Button](#61-button)
  - [6.2 GlassCard](#62-glasscard)
  - [6.3 InfoBar](#63-infobar)
  - [6.4 InfoBadge](#64-infobadge)
  - [6.5 输入控件](#65-输入控件)
- [7. 布局与导航](#7-布局与导航)
  - [7.1 基础布局仍使用 Avalonia](#71-基础布局仍使用-avalonia)
  - [7.2 SukiSideMenu](#72-sukisidemenu)
  - [7.3 TransitioningContentControl](#73-transitioningcontentcontrol)
  - [7.4 SettingsLayout](#74-settingslayout)
- [8. 对话框、消息框与 Host](#8-对话框消息框与-host)
  - [8.1 Host 概念](#81-host-概念)
  - [8.2 窗口中配置 Toast Host](#82-窗口中配置-toast-host)
  - [8.3 MessageBox 的使用建议](#83-messagebox-的使用建议)
- [9. Toast 通知](#9-toast-通知)
  - [9.1 ViewModel 管理 ToastManager](#91-viewmodel-管理-toastmanager)
  - [9.2 Toast 的常见能力](#92-toast-的常见能力)
- [10. MVVM 集成建议](#10-mvvm-集成建议)
  - [10.1 视图只负责展示](#101-视图只负责展示)
  - [10.2 命令示例](#102-命令示例)
- [11. DataGrid 与可选组件](#11-datagrid-与可选组件)
  - [11.1 DataGrid](#111-datagrid)
  - [11.2 ColorPicker](#112-colorpicker)
  - [11.3 ConditionalXAML](#113-conditionalxaml)
- [12. 自定义样式与资源](#12-自定义样式与资源)
  - [12.1 优先使用 Classes](#121-优先使用-classes)
  - [12.2 自定义 Style](#122-自定义-style)
  - [12.3 图标](#123-图标)
- [13. 性能、跨平台与发布](#13-性能跨平台与发布)
  - [13.1 动画与背景](#131-动画与背景)
  - [13.2 跨平台](#132-跨平台)
  - [13.3 发布](#133-发布)
- [14. 常见问题排查](#14-常见问题排查)
  - [14.1 SukiTheme 找不到](#141-sukitheme-找不到)
  - [14.2 SukiWindow 找不到](#142-sukiwindow-找不到)
  - [14.3 窗口/控件透明](#143-窗口控件透明)
  - [14.4 主题控件显示异常或 MissingMethodException](#144-主题控件显示异常或-missingmethodexception)
  - [14.5 DataGrid 没有 SukiUI 样式](#145-datagrid-没有-sukiui-样式)
  - [14.6 Toast 不显示](#146-toast-不显示)
  - [14.7 中文显示为问号或字体异常](#147-中文显示为问号或字体异常)
- [15. 官方资料与源码索引](#15-官方资料与源码索引)
- [附录 A：最小可运行集成检查表](#附录-a最小可运行集成检查表)

<a id="1-sukiui-是什么"></a>
## 1. SukiUI 是什么

SukiUI 是基于 Avalonia 的桌面 UI 主题和控件工具包。它提供统一的视觉风格、主题色、浅色/深色模式、窗口外观、动画控件、通知、对话框和若干布局控件。

<a id="11-sukiui-与-avalonia-的关系"></a>
### 1.1 SukiUI 与 Avalonia 的关系

- **Avalonia**：跨平台 UI 框架，提供 Window、Grid、Button、TextBox、Binding、Command 等基础能力。
- **SukiUI**：在 Avalonia 基础上提供主题、控件样式、窗口外壳和附加交互。
- **CommunityToolkit.Mvvm**：可继续负责 ViewModel、ObservableProperty、RelayCommand 等 MVVM 基础设施；SukiUI 不替代 MVVM 框架。
- **业务控件**：PLC 状态、实时曲线、设备卡片等仍建议由项目自行封装，SukiUI 主要负责统一视觉与交互。

SukiUI 官方项目定位为桌面 UI，不应把它视为移动端 UI 框架。

<a id="12-推荐使用场景"></a>
### 1.2 推荐使用场景

- 工业上位机、设备监控、生产管理客户端
- 管理类桌面软件、设置页、仪表盘
- 需要统一主题、暗色模式和现代化窗口外观的 Avalonia 应用

---

<a id="2-版本选择与安装"></a>
## 2. 版本选择与安装

<a id="21-版本兼容要点"></a>
### 2.1 版本兼容要点

截至本手册整理时，官方稳定版本线包括 SukiUI 6.x 和 7.x。主要兼容关系：

| SukiUI 版本 | Avalonia 依赖 | 说明 |
|---|---|---|
| 6.0.3 | Avalonia 11.3.4 及以上 | 可作为 Avalonia 11.3.9 项目的参考版本 |
| 6.1.1 | Avalonia 11.3.14 及以上 | 安装时 NuGet 可能升级 Avalonia 相关包 |
| 7.0.1 | Avalonia 12.0.3 及以上 | Avalonia 12 版本线 |

**重要：** 不要只看 `SukiUI` 一个包的版本。Avalonia 的 `Avalonia`、`Avalonia.Skia`、`Avalonia.Themes.Simple`、DataGrid、ColorPicker 等依赖应保持在兼容版本组内。升级前先在 Git 分支或备份项目中操作。

<a id="22-安装-sukiui"></a>
### 2.2 安装 SukiUI

在项目目录打开终端：

```bash
dotnet add package SukiUI --version 6.0.3
```

也可以在 `.csproj` 中添加：

```xml
<ItemGroup>
  <PackageReference Include="SukiUI" Version="6.0.3" />
</ItemGroup>
```

检查依赖：

```bash
dotnet list package
dotnet restore
dotnet build
```

如果使用中央包管理 `Directory.Packages.props`，在集中版本文件中声明版本，并在项目文件中只保留不带版本的 `PackageReference`。

<a id="23-fluent-主题是否需要保留"></a>
### 2.3 Fluent 主题是否需要保留

SukiUI 自带主题入口。官方安装说明建议在使用 SukiTheme 时移除默认模板中的 `Avalonia.Themes.Fluent`，避免同时加载两套主题造成样式冲突。若项目有特殊 Fluent 资源依赖，先逐项验证再移除。

---

<a id="3-appaxaml-全局配置"></a>
## 3. App.axaml 全局配置

<a id="31-注册-sukitheme"></a>
### 3.1 注册 SukiTheme

在 `App.axaml` 中添加命名空间并注册主题：

```xml
<Application
    x:Class="YourApp.App"
    xmlns="https://github.com/avaloniaui"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:suki="clr-namespace:SukiUI;assembly=SukiUI">

  <Application.Styles>
    <suki:SukiTheme ThemeColor="Blue" Locale="zh-CN" />
  </Application.Styles>
</Application>
```

常见主题色名称包括 `Blue`、`Purple`、`Red`、`Green` 等；请以当前版本 `SukiTheme.ThemeColor` 的枚举/属性提示为准。

**注意：** 官方启动文档提示，未设置主题色时，部分窗口或控件可能呈现透明效果。初次集成时建议明确设置 `ThemeColor`。

<a id="32-设置中文本地化"></a>
### 3.2 设置中文本地化

`Locale="zh-CN"` 用于 SukiUI/Avalonia 某些内置文本的本地化，例如部分默认上下文菜单。它并不会自动翻译你的业务界面。业务标题、按钮、菜单仍应使用资源文件或项目自己的本地化方案。

<a id="33-建议-appaxaml-的资源组织"></a>
### 3.3 建议 App.axaml 的资源组织

```xml
<Application.Resources>
  <ResourceDictionary>
    <ResourceDictionary.MergedDictionaries>
      <ResourceInclude Source="avares://YourApp/Styles/Colors.axaml" />
      <ResourceInclude Source="avares://YourApp/Styles/Brushes.axaml" />
    </ResourceDictionary.MergedDictionaries>
  </ResourceDictionary>
</Application.Resources>
```

项目资源文件可按 `Styles/Colors.axaml`、`Styles/Brushes.axaml`、`Styles/Controls.axaml` 分层。不要把大量业务控件样式全部堆到 `App.axaml`。

---

<a id="4-sukiwindow-主窗口"></a>
## 4. SukiWindow 主窗口

<a id="41-用-sukiwindow-替代-window"></a>
### 4.1 用 SukiWindow 替代 Window

SukiUI 的 `SukiWindow` 是其应用窗口外壳。简单应用可以直接从它开始。

`MainWindow.axaml`：

```xml
<suki:SukiWindow
    x:Class="YourApp.MainWindow"
    xmlns="https://github.com/avaloniaui"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:suki="clr-namespace:SukiUI.Controls;assembly=SukiUI"
    Title="设备管理系统"
    Width="1280"
    Height="800"
    BackgroundStyle="Flat">

  <Grid RowDefinitions="Auto,*">
    <TextBlock Text="系统首页" FontSize="24" />
    <ContentControl Grid.Row="1" Content="{Binding CurrentView}" />
  </Grid>
</suki:SukiWindow>
```

`MainWindow.axaml.cs`：

```csharp
using SukiUI.Controls;

namespace YourApp;

public partial class MainWindow : SukiWindow
{
    public MainWindow()
    {
        InitializeComponent();
    }
}
```

<a id="42-窗口背景"></a>
### 4.2 窗口背景

常见 `BackgroundStyle`：

- `Bubble`：带气泡/玻璃质感的背景。
- `Gradient`：渐变背景。
- `Flat`：平面背景，视觉干净，通常更适合工业软件和高密度数据界面。

```xml
<suki:SukiWindow BackgroundStyle="Flat">
  <!-- 页面内容 -->
</suki:SukiWindow>
```

窗口还支持 Logo、菜单区域、标题栏右侧控件等扩展区域。属性/附加属性请以当前 SukiWindow 的 IntelliSense 和 Demo 为准。

<a id="43-什么时候仍使用普通-window"></a>
### 4.3 什么时候仍使用普通 Window

- 独立工具窗、辅助窗或需要完全自定义外观的窗口
- 业务窗口不需要 SukiWindow 的标题栏和背景能力
- 项目需要兼容已有 Window 生命周期/自定义窗体逻辑

可以让主窗体使用 SukiWindow，子窗体按需求选择 Window 或 SukiWindow，避免为了统一而强制改造所有窗口。

---

<a id="5-主题颜色与明暗模式"></a>
## 5. 主题、颜色与明暗模式

SukiUI 的主题系统负责全局颜色和控件状态。建议把主题切换放到一个统一服务或 ViewModel 中，避免多个页面各自修改全局主题。

<a id="51-主题组成"></a>
### 5.1 主题组成

- **ThemeColor**：主主题色，影响按钮、选中状态等强调色。
- **Light/Dark**：浅色与深色外观。
- **BackgroundStyle**：窗口背景风格。
- **自定义资源**：业务颜色、状态颜色、图表颜色。

<a id="52-主题切换的原则"></a>
### 5.2 主题切换的原则

1. 主题状态由应用级单例/服务管理。
2. 主题切换入口集中在设置页或标题栏。
3. 业务状态色不要直接依赖主题强调色。例如 PLC “运行/故障/待机”应使用语义化资源。
4. 主题切换后检查 DataGrid、弹窗、菜单、图表和自定义控件。

SukiUI 不同版本的主题管理 API 可能变化。不要在未确认当前版本 API 的情况下照搬网络上的 `SukiTheme` / `SukiThemeManager` 示例。建议先通过 IDE 对当前包进行“转到定义”，或查看同版本 Demo 的主题切换实现。

<a id="53-语义化业务颜色"></a>
### 5.3 语义化业务颜色

建议自行定义：

```xml
<SolidColorBrush x:Key="StatusRunningBrush" Color="#2EAD66" />
<SolidColorBrush x:Key="StatusWarningBrush" Color="#E6A23C" />
<SolidColorBrush x:Key="StatusFaultBrush" Color="#E5484D" />
<SolidColorBrush x:Key="StatusOfflineBrush" Color="#909399" />
```

工业设备页面应确保颜色之外还有文字/图标/状态码，不能只靠颜色传达故障信息。

---

<a id="6-常用控件样式"></a>
## 6. 常用控件样式

SukiUI 通常沿用 Avalonia 基础控件，并通过 `Classes` 选择不同视觉样式。样式类不是新的控件类型。

<a id="61-button"></a>
### 6.1 Button

```xml
<Button Content="标准按钮" />
<Button Content="扁平按钮" Classes="Flat" />
<Button Content="圆角扁平" Classes="Flat Rounded" />
<Button Content="描边按钮" Classes="Outlined" />
<Button Content="基础按钮" Classes="Basic" />
<Button Content="强调按钮" Classes="Flat Accent" />
<Button Content="大按钮" Classes="Flat Large" />
```

使用建议：

- 主操作：一个页面只保留少量 Accent 主按钮。
- 次要操作：Flat 或 Outlined。
- 危险操作：通过语义色、确认弹窗和明确文案表达，不要仅靠红色。
- 加载状态：可使用 `ButtonExtensions.ShowProgress` 或当前版本提供的进度 API。

<a id="62-glasscard"></a>
### 6.2 GlassCard

`GlassCard` 是常用卡片容器，适合仪表盘、设备卡片、状态汇总等。

```xml
<suki:GlassCard>
  <StackPanel Spacing="8">
    <TextBlock Text="设备状态" FontSize="18" />
    <TextBlock Text="运行中" />
  </StackPanel>
</suki:GlassCard>
```

常见样式：

```xml
<suki:GlassCard Classes="Primary">...</suki:GlassCard>
<suki:GlassCard Classes="Accent">...</suki:GlassCard>
<suki:GlassCard IsOpaque="True">...</suki:GlassCard>
<suki:GlassCard IsInteractive="True">...</suki:GlassCard>
```

`IsInteractive` 用于需要交互反馈的卡片。若卡片只是信息展示，避免添加不必要的悬停/点击动画。

<a id="63-infobar"></a>
### 6.3 InfoBar

`InfoBar` 用于页面内持续显示提示或状态：

```xml
<suki:InfoBar
    Title="连接提示"
    Message="PLC 连接已恢复"
    Severity="Success"
    IsOpen="{Binding IsInfoOpen}"
    IsClosable="True" />
```

常见 Severity：`Information`、`Success`、`Warning`、`Error`。适合显示连接状态、配置校验、操作结果等；短暂操作反馈更适合 Toast。

<a id="64-infobadge"></a>
### 6.4 InfoBadge

`InfoBadge` 适合菜单角标、未读数量或异常计数。计数为 0 时是否隐藏应由 ViewModel 或样式逻辑明确控制。

<a id="65-输入控件"></a>
### 6.5 输入控件

TextBox、ComboBox、CheckBox、RadioButton、ToggleSwitch、NumericUpDown 等仍采用 Avalonia 的绑定和命令模式，SukiUI 提供统一样式。

```xml
<TextBox Watermark="请输入设备编号"
         Text="{Binding DeviceNo, Mode=TwoWay}" />

<ComboBox ItemsSource="{Binding DeviceTypes}"
          SelectedItem="{Binding SelectedDeviceType}" />

<CheckBox Content="启用自动采集"
          IsChecked="{Binding IsAutoCollect}" />
```

优先使用 `Watermark` 提示输入格式，校验错误应在控件附近显示，避免只弹窗。

---

<a id="7-布局与导航"></a>
## 7. 布局与导航

<a id="71-基础布局仍使用-avalonia"></a>
### 7.1 基础布局仍使用 Avalonia

SukiUI 不要求所有布局都换成专属控件。常用布局继续使用：

- `Grid`：主页面、表单、复杂区域布局。
- `DockPanel`：工具栏/状态栏布局。
- `StackPanel`：小规模纵向/横向排列。
- `WrapPanel`：可换行卡片。
- `ScrollViewer`：可滚动内容。

实时数据/PLC 状态卡片建议使用 `Grid` 明确行列，不要用嵌套过深的 StackPanel 造成测量开销。

<a id="72-sukisidemenu"></a>
### 7.2 SukiSideMenu

`SukiSideMenu` 用于侧边导航。典型用途是设备监控、生产管理、系统设置等主模块导航。

设计建议：

- 菜单项与页面路由分离。
- 菜单选择后更新 `CurrentView` 或路由状态。
- 页面切换不应重新创建数据库连接或 PLC 连接服务。
- 菜单图标使用统一的 Icon 控件/PathIcon 方案。
- 根据窗口宽度调整菜单展开/收起，避免小屏下内容区域过窄。

具体 Items、模板、命令参数等 API 请按当前版本 Demo 的 `SukiSideMenu` 示例实现；官方控件文档部分属性较少，建议结合源码确认。

<a id="73-transitioningcontentcontrol"></a>
### 7.3 TransitioningContentControl

用于内容切换时添加过渡效果。适合页面切换、分步向导或设置页内容变化。

注意：
- 页面切换频率高时，动画应适度。
- 不要把动画控件用于每帧刷新内容。
- ViewModel 生命周期应由应用导航层控制，而不是依赖动画控件的视觉附加/移除事件。

<a id="74-settingslayout"></a>
### 7.4 SettingsLayout

`SettingsLayout` 可根据窗口宽度调整设置项布局，适合主题设置、通信参数、用户偏好等页面。

```xml
<suki:SettingsLayout>
  <suki:SettingsLayout.Items>
    <ObservableCollection x:TypeArguments="suki:SettingsLayoutItem">
      <suki:SettingsLayoutItem Header="通信设置">
        <suki:SettingsLayoutItem.Content>
          <Border Padding="16">
            <TextBlock Text="通信参数内容" />
          </Border>
        </suki:SettingsLayoutItem.Content>
      </suki:SettingsLayoutItem>
    </ObservableCollection>
  </suki:SettingsLayout.Items>
</suki:SettingsLayout>
```

若 XAML 对泛型集合的写法在当前 Avalonia/SukiUI 版本中无法解析，可在 ViewModel 中构造 `ObservableCollection<SettingsLayoutItem>` 并绑定。

---

<a id="8-对话框消息框与-host"></a>
## 8. 对话框、消息框与 Host

SukiUI 的 Host 模式允许把 Toast、Dialog 等交互承载在窗口或局部页面中。Host 通常放在窗口的 Hosts 区域。

<a id="81-host-概念"></a>
### 8.1 Host 概念

Host 是一个“显示容器”，Manager 是对应的管理器。采用 MVVM 时，ViewModel 持有 Manager，View 负责把 Manager 绑定给 Host。

常见 Host：
- `SukiToastHost`：显示 Toast。
- `SukiDialogHost` / `SukiMessageBoxHost`：承载对话框/消息框（具体名称依版本而异）。

<a id="82-窗口中配置-toast-host"></a>
### 8.2 窗口中配置 Toast Host

```xml
<suki:SukiWindow>
  <suki:SukiWindow.Hosts>
    <suki:SukiToastHost Manager="{Binding ToastManager}" />
  </suki:SukiWindow.Hosts>

  <!-- 页面内容 -->
</suki:SukiWindow>
```

<a id="83-messagebox-的使用建议"></a>
### 8.3 MessageBox 的使用建议

消息框适用于：
- 删除、清空、重置等不可逆操作确认
- 关键配置保存失败
- 用户必须立即处理的错误

不建议把所有业务反馈都改成模态弹窗。对于“已保存”“连接恢复”等非阻断消息，优先使用 InfoBar 或 Toast。

API 名称、参数和返回值在版本间可能有变化，务必从当前安装包的 XML 注释或 Demo 中确认后再封装成项目级 `IDialogService`。

---

<a id="9-toast-通知"></a>
## 9. Toast 通知

Toast 是短暂、非阻断的消息。官方推荐将 `SukiToastHost` 放在 `SukiWindow.Hosts` 中，以便获得较完整的窗口级体验。

<a id="91-viewmodel-管理-toastmanager"></a>
### 9.1 ViewModel 管理 ToastManager

```csharp
using SukiUI.Toasts;

public class MainViewModel
{
    public ISukiToastManager ToastManager { get; } = new SukiToastManager();

    public void ShowSaved()
    {
        ToastManager.CreateToast()
            .WithTitle("保存成功")
            .WithContent("设备参数已保存")
            .Queue();
    }
}
```

> 请注意：不同 SukiUI 6.x 小版本的命名空间/构造方式可能有差异。若 IDE 无法识别 `SukiUI.Toasts` 或 `SukiToastManager`，应以安装版本的 Demo 和 IntelliSense 为准，不要直接复制其他主版本代码。

<a id="92-toast-的常见能力"></a>
### 9.2 Toast 的常见能力

- 标题与正文
- 信息/成功/警告/错误类型
- 延时关闭
- 点击关闭
- 点击回调
- 操作按钮
- 限制同时显示数量

使用 Toast 时应避免重复通知。例如后台采集每秒变化时，不要每次都弹 Toast；应在状态变化边沿或错误首次发生时通知。

---

<a id="10-mvvm-集成建议"></a>
## 10. MVVM 集成建议

对 .NET 8 + Avalonia + SukiUI 项目，推荐分层：

```text
YourApp
├─ Views
│  ├─ MainWindow.axaml
│  ├─ Pages
│  └─ Controls
├─ ViewModels
│  ├─ MainViewModel.cs
│  └─ Pages
├─ Services
│  ├─ NavigationService.cs
│  ├─ DialogService.cs
│  └─ ToastService.cs
├─ Models
└─ Styles
```

<a id="101-视图只负责展示"></a>
### 10.1 视图只负责展示

- View：XAML 布局、样式、绑定。
- ViewModel：状态、命令、页面逻辑。
- Service：导航、通知、对话框、设备通信。
- Domain/Infrastructure：PLC、Modbus、数据库等实际业务逻辑。

<a id="102-命令示例"></a>
### 10.2 命令示例

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

public partial class DeviceViewModel : ObservableObject
{
    [ObservableProperty]
    private string deviceName = "";

    [RelayCommand]
    private void Refresh()
    {
        // 调用服务刷新数据
    }
}
```

```xml
<Button Content="刷新"
        Classes="Flat Accent"
        Command="{Binding RefreshCommand}" />
```

不要在 ViewModel 中直接查找控件名称并操作控件；通过属性、Command 和服务通信。

---

<a id="11-datagrid-与可选组件"></a>
## 11. DataGrid 与可选组件

SukiUI 的核心包和附加组件是分开的。常见可选包包括：

- `SukiUI.DataGrid`：DataGrid 的 SukiUI 样式资源。
- `SukiUI.ColorPicker`：ColorPicker 的主题资源。
- `SukiUI.ConditionalXAML`：条件 XAML/辅助扩展。
- `SukiUI.Dock`：与 Dock.Avalonia 相关的停靠集成（独立包/依赖）。

<a id="111-datagrid"></a>
### 11.1 DataGrid

如果项目使用 DataGrid，先确认 Avalonia DataGrid 包与 SukiUI DataGrid 主题版本匹配，再添加对应包。样式资源一般需要在 `SukiTheme` 之后引用：

```xml
<Application.Styles>
  <suki:SukiTheme ThemeColor="Blue" Locale="zh-CN" />
  <StyleInclude Source="avares://SukiUI.DataGrid/Theme/Index.axaml" />
</Application.Styles>
```

不同版本可能调整 DataGrid 包结构或资源 URI。安装后请查看包内 README/示例，不要只凭旧文档中的 URI。

<a id="112-colorpicker"></a>
### 11.2 ColorPicker

ColorPicker 可能需要单独安装 Avalonia ColorPicker 与 SukiUI ColorPicker 主题包。按当前包版本的安装说明添加 Fluent ColorPicker 资源和 SukiUI ColorPicker 资源。

<a id="113-conditionalxaml"></a>
### 11.3 ConditionalXAML

核心包不一定包含条件 XAML 辅助功能。只有使用 `If`、`InlineSharp` 等扩展时才安装 `SukiUI.ConditionalXAML`，避免引入不必要的依赖。

---

<a id="12-自定义样式与资源"></a>
## 12. 自定义样式与资源

<a id="121-优先使用-classes"></a>
### 12.1 优先使用 Classes

若只是改变按钮、卡片的外观，优先使用 SukiUI 已提供的 Classes：

```xml
<Button Classes="Flat Accent" />
<GlassCard Classes="Primary" />
```

避免为一个按钮复制整套 ControlTheme。复制控件模板会增加升级成本。

<a id="122-自定义-style"></a>
### 12.2 自定义 Style

```xml
<Style Selector="Button.primary-action">
  <Setter Property="MinWidth" Value="120" />
  <Setter Property="FontWeight" Value="SemiBold" />
</Style>
```

使用时：

```xml
<Button Classes="Flat Accent primary-action"
        Content="开始采集" />
```

样式选择器应尽量限定范围，避免全局覆盖 SukiUI 默认样式。

<a id="123-图标"></a>
### 12.3 图标

可使用 Avalonia `PathIcon`、项目图标字体或统一的 Icon 控件。建议封装 `AppIcon`，避免每个页面重复维护 Path 数据。图标必须有明确语义，操作按钮应同时提供 ToolTip 或可读文字。

---

<a id="13-性能跨平台与发布"></a>
## 13. 性能、跨平台与发布

<a id="131-动画与背景"></a>
### 13.1 动画与背景

SukiUI 背景可使用 GPU/Shader 渲染，动画背景可能持续触发视觉树重绘。工业上位机建议：

- 默认使用 `Flat` 或低动态背景。
- 避免在高频实时数据页启用持续背景动画。
- 设备状态刷新只更新必要绑定，不要每次重建整个页面。
- 大量卡片使用虚拟化/分页或分区刷新。

<a id="132-跨平台"></a>
### 13.2 跨平台

SukiUI 面向 Avalonia 桌面。跨平台部署时仍需验证：
- Windows、Linux（含目标国产 Linux）字体、窗口装饰和输入法。
- Skia 原生依赖与 GPU/软件渲染环境。
- 高 DPI、触摸屏、系统缩放。
- DataGrid、弹窗、标题栏在目标桌面环境的行为。

<a id="133-发布"></a>
### 13.3 发布

```bash
dotnet publish -c Release -r win-x64 --self-contained true
```

Linux 示例：

```bash
dotnet publish -c Release -r linux-x64 --self-contained true
```

实际 RID 应按部署环境选择。SukiUI 本身不替代 Avalonia 的发布流程。发布后务必在干净机器/目标系统测试，特别是字体、图形依赖、弹窗、主题和高 DPI。

---

<a id="14-常见问题排查"></a>
## 14. 常见问题排查

<a id="141-sukitheme-找不到"></a>
### 14.1 SukiTheme 找不到

检查：
1. NuGet 是否安装正确。
2. `xmlns:suki="clr-namespace:SukiUI;assembly=SukiUI"` 是否正确。
3. 是否引用了与当前 Avalonia 兼容的 SukiUI 版本。
4. `dotnet restore` 后清理并重新生成。

<a id="142-sukiwindow-找不到"></a>
### 14.2 SukiWindow 找不到

确认窗口命名空间：

```xml
xmlns:suki="clr-namespace:SukiUI.Controls;assembly=SukiUI"
```

并确认 Code-behind 继承 `SukiWindow`，AXAML 根元素和代码后置类一致。

<a id="143-窗口控件透明"></a>
### 14.3 窗口/控件透明

- 检查 `SukiTheme` 是否设置 `ThemeColor`。
- 检查是否同时加载 Fluent 与 SukiUI 的冲突主题。
- 检查是否错误覆盖 Background、Opacity 或主题资源。

<a id="144-主题控件显示异常或-missingmethodexception"></a>
### 14.4 主题控件显示异常或 MissingMethodException

通常与 Avalonia、SukiUI、Skia 相关包版本不一致有关。处理顺序：
1. 查看 `dotnet list package`。
2. 统一 Avalonia 相关包版本。
3. 检查 SukiUI 依赖最低版本。
4. 删除 `bin`、`obj` 后重新 restore/build。
5. 不要将 Avalonia 11 和 SukiUI 7（Avalonia 12）混用。

<a id="145-datagrid-没有-sukiui-样式"></a>
### 14.5 DataGrid 没有 SukiUI 样式

检查是否安装了对应的 `SukiUI.DataGrid`，并在 `SukiTheme` 后加载正确主题资源；确认 Avalonia DataGrid 与 SukiUI.DataGrid 版本相容。

<a id="146-toast-不显示"></a>
### 14.6 Toast 不显示

检查：
- 窗口是否配置 `SukiToastHost`。
- ViewModel 的 Manager 是否与 Host 使用同一个实例。
- 是否调用 `.Queue()`。
- Host 是否被其他布局遮挡或未加入视觉树。

<a id="147-中文显示为问号或字体异常"></a>
### 14.7 中文显示为问号或字体异常

- 确认系统安装中文字体。
- 指定支持中文的 FontFamily，例如目标系统已安装的 Noto Sans CJK / 微软雅黑等。
- 检查文件编码为 UTF-8。
- Linux 下确认字体缓存与应用运行用户环境一致。

---

<a id="15-官方资料与源码索引"></a>
## 15. 官方资料与源码索引

以下链接可在有网络时访问；本手册内容已整理为离线阅读，但链接可用于查阅对应版本的最新 API。

- 官方文档（英文）：https://kikipoulet.github.io/SukiUI/documentation/
- 官方文档（中文）：https://kikipoulet.github.io/SukiUI/zh/documentation/
- GitHub 源码与 Demo：https://github.com/kikipoulet/SukiUI
- Releases：https://github.com/kikipoulet/SukiUI/releases
- NuGet SukiUI：https://www.nuget.org/packages/SukiUI/
- 安装说明：https://kikipoulet.github.io/SukiUI/zh/documentation/getting-started/installation.html
- 启动应用：https://kikipoulet.github.io/SukiUI/zh/documentation/getting-started/launch.html
- SukiWindow：https://kikipoulet.github.io/SukiUI/documentation/controls/layout/sukiwindow.html
- GlassCard：https://kikipoulet.github.io/SukiUI/zh/documentation/controls/layout/glasscard.html
- Button：https://kikipoulet.github.io/SukiUI/zh/documentation/controls/inputs/button.html
- Toast：https://kikipoulet.github.io/SukiUI/documentation/hosts/toast.html
- 背景与 Shader：https://kikipoulet.github.io/SukiUI/documentation/theming/background.html

---

<a id="附录-a最小可运行集成检查表"></a>
## 附录 A：最小可运行集成检查表

- [ ] 项目目标框架为 `net8.0` 或符合包要求的版本。
- [ ] Avalonia 与 SukiUI 版本依赖已统一。
- [ ] 安装 SukiUI NuGet 包。
- [ ] `App.axaml` 注册 `SukiTheme`，设置 `ThemeColor`。
- [ ] 中文界面需要时设置 `Locale="zh-CN"`。
- [ ] 主窗口 AXAML 根元素与 Code-behind 的 `SukiWindow` 继承一致。
- [ ] 已验证 Button、TextBox、ComboBox、DataGrid 的样式。
- [ ] Toast/Dialog Host 与 Manager 使用同一个实例。
- [ ] 已在实际目标操作系统验证字体、DPI、窗口和图形渲染。
- [ ] 已执行 `dotnet publish` 并在干净环境完成测试。

---

**编写日期：2026-11-26**  
**建议维护方式：** 将本手册放入项目的 `docs/SukiUI-中文离线手册.md`，每次升级 SukiUI/Avalonia 后更新“版本兼容表”和“可选组件”章节。

---

## 相关页面

- [返回 Avalonia 分组首页](index.md)
- [MVVM](MVVM.md)：ViewModel、命令与 SukiUI 的分层建议
- [数据绑定](DataBinding.md)：绑定模式、集合刷新与上位机实时数据
- [自定义控件](CustomControls.md)：样式类、ControlTheme 与设备状态控件
- [页面导航](Navigation.md)：SukiSideMenu、内容切换与 ViewModel 生命周期
- [MyWiki 首页](../index.md) · [DevOps / Kylin V11](../DevOps/KylinV11.md)：目标系统上的字体与渲染验证