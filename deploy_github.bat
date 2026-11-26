@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem MyWiki 一键部署：构建站点并推送到 GitHub Pages 的 gh-pages 分支

set "SCRIPT_DIR=%~dp0"
set "MKDOCS_EXE=%SCRIPT_DIR%..\.venv\Scripts\mkdocs.exe"
set "PAGES_URL=https://aquncode.github.io/MyWiki/"

cd /d "%SCRIPT_DIR%"
for %%i in ("%MKDOCS_EXE%") do set "MKDOCS_EXE=%%~fi"

if not exist "%MKDOCS_EXE%" (
    echo [错误] 找不到 mkdocs.exe：%MKDOCS_EXE%
    pause
    exit /b 1
)

echo [信息] 正在构建并部署到 GitHub Pages ...
echo [信息] 目标分支：gh-pages
echo [信息] 站点地址：%PAGES_URL%
"%MKDOCS_EXE%" gh-deploy --clean
if errorlevel 1 (
    echo [错误] 部署失败，请检查 Git 凭据、网络与仓库权限。
    pause
    exit /b 1
)

echo [完成] 部署成功：%PAGES_URL%
echo [提示] 首次部署后，请在 GitHub 仓库 Settings - Pages 中将 Source 设为 gh-pages 分支。
pause
exit /b 0
