# MkDocs

| 字段 | 内容 |
| :--- | :--- |
| 分类 | 工具 |
| 主题 | 本知识库（MyWiki）的 MkDocs + Material 构建、配置与日常维护 |
| 适用技术栈 | MkDocs 1.6.1、mkdocs-material 9.8.2、Python 3.15（venv）、YAML、Markdown |
| 更新日期 | 2026-11-26 |

## 概述与核心概念

MkDocs 是静态站点生成器：输入 `docs/` 下的 Markdown 与一份 `mkdocs.yml`，输出 `site/` 里的静态 HTML。Material for MkDocs 是主题，提供导航、搜索、admonition、代码块复制等能力。本站是纯本地 / 内网知识库，`font: false` 不加载 Google Fonts，断网也能正常渲染。

项目真实结构（`mkdocs.yml` 与 `docs/` 同级，虚拟环境在上一级 `DocHub` 目录）：

```text
E:\Pro\Personal\DocHub\
├─ .venv\                 # 虚拟环境（项目上一级）
└─ mywiki\
   ├─ mkdocs.yml
   ├─ docs\  (index.md、stylesheets\extra.css、javascripts\mathjax.js、Tools\...)
   └─ site\               # mkdocs build 产物
```

- 已装版本：mkdocs 1.6.1、mkdocs-material 9.8.2、Python 3.15（venv）。
- 插件只启用了 `search`（Material 自带的 `material/search`），未引入第三方插件。
- `extra_css` 指向 `docs/stylesheets/extra.css`，`extra_javascript` 指向 `docs/javascripts/mathjax.js`，两个文件都必须真实存在，否则构建告警。

!!! note "venv 不在项目根，而在上一级"
    虚拟环境在 `E:\Pro\Personal\DocHub\.venv`：在该目录下执行 `python -m venv .venv` 创建，再用 `.\.venv\Scripts\Activate.ps1` 激活；但 `mkdocs` 命令必须在 `mywiki`（含 `mkdocs.yml` 的那一层）执行，两者目录不要混。

## 关键用法与示例

激活环境并核对版本：

```powershell
Set-Location 'E:\Pro\Personal\DocHub'
.\.venv\Scripts\Activate.ps1
python --version
mkdocs --version
pip show mkdocs mkdocs-material
Set-Location 'E:\Pro\Personal\DocHub\mywiki'
```

常用命令（在 `mywiki` 下执行）：

```bash
mkdocs serve            # 本地预览，默认 http://127.0.0.1:8000，改文件自动重载
mkdocs build            # 输出到 site/
mkdocs build --clean    # 先清空 site/ 再构建，避免残留旧页面
```

`mkdocs.yml` 关键配置摘录（真实值）：

```yaml
site_name: MyWiki
docs_dir: docs
site_dir: site
use_directory_urls: true
strict: false
theme:
  name: material
  language: zh
  font: false            # 不加载 Google Fonts，离线友好
plugins:
  - search:
      lang: zh
extra_css:
  - stylesheets/extra.css
extra_javascript:
  - javascripts/mathjax.js
```

`nav` 路径一律相对 `docs_dir`，**不能**写 `docs/` 前缀：

```yaml
nav:
  - 首页: index.md
  - 工具:
      - 工具首页: Tools/index.md
      - MkDocs: Tools/MkDocs.md
```

### 新增一篇文档的操作清单

- [ ] 在 `docs/` 对应分组下新建 UTF-8 的 `.md`，按本组子页结构写好标题、文档信息与章节。
- [ ] 在 `mkdocs.yml` 的 `nav` 对应分组下加一行 `- 页面标签: 分组/文件.md`（路径相对 `docs/`，不带 `docs/` 前缀）。
- [ ] `mkdocs serve` 打开 http://127.0.0.1:8000，检查导航层级、相对链接、提示框与代码块渲染。
- [ ] `mkdocs build`（或 `mkdocs build --clean`）确认无 WARNING，再提交改动。

## 典型场景

- **本地写作**：`mkdocs serve` 常开，保存即刷新，适合边写边核对 admonition 缩进与表格。
- **交付静态站点**：`mkdocs build --clean` 后用 `python -m http.server 8000 --directory site` 在本地 HTTP 服务验证；`use_directory_urls: true` 依赖目录 URL，直接双击 `file://` 打开容易 404。
- **信创离线部署**：`font: false` 且 CSS/JS 均为本地文件，无外部 CDN，断网环境可直接托管 `site/`。
- **多分组维护**：靠 `nav` 分组 + 各分组 `index.md` 知识地图组织，新增页面遵循上面的清单。

## 常见坑与排查

| 坑 | 表现 | 处理 |
| :--- | :--- | :--- |
| `nav` 引用不存在的 `.md` | build 报 WARNING，点击该导航 404 | 先建文件再加 nav，或先删 nav 项 |
| 把 `clean` 写进 `mkdocs.yml` | `Unrecognised configuration name: clean` | `clean` 是 CLI 参数，用 `mkdocs build --clean` |
| 给 `material/search` 配 `min_search_length` | `Unsupported option` 警告 | 该插件不支持；如需最小长度改用 MkDocs 内置 search |
| 启用 `navigation.sections` | 子页面被「反缩进」，层级不清 | 在 `docs/stylesheets/extra.css` 写样式恢复嵌套缩进 |
| 单独启用 `navigation.tabs.sticky` | 完全不生效 | 必须同时启用 `navigation.tabs`；本站为保留左侧层级，两者都未启用 |
| `extra_css` / `extra_javascript` 文件缺失 | build 告警、样式或公式失效 | 确保 `stylesheets/extra.css`、`javascripts/mathjax.js` 存在 |

!!! warning "改完 nav 一定要 build 验证"
    由于 `strict: false`，`nav` 里的坏链接只会给 WARNING 而不中断构建，`site/` 照样生成，问题很容易被带到交付之后。新增 / 重命名页面后固定跑一次 `mkdocs build --clean`，把警告清零再提交。

## 参考链接

- MkDocs 官方：https://www.mkdocs.org/
- 配置说明：https://www.mkdocs.org/user-guide/configuration/
- CLI 命令：https://www.mkdocs.org/user-guide/cli/
- Material for MkDocs：https://squidfunk.github.io/mkdocs-material/

## 相关页面

- [Visual Studio](VisualStudio.md)：.NET 项目结构与按 RID 发布
- [PowerShell](PowerShell.md)：激活 `.venv` 与执行构建脚本
- [返回分组首页](index.md)
