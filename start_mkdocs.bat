@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem MyWiki 一键启动：启动 MkDocs 本地预览并自动打开浏览器
rem 虚拟环境位于上级目录 DocHub\.venv，本脚本在 mywiki 目录下运行

set "SCRIPT_DIR=%~dp0"
set "MKDOCS_EXE=%SCRIPT_DIR%..\.venv\Scripts\mkdocs.exe"
set "SITE_URL=http://127.0.0.1:8000/"

cd /d "%SCRIPT_DIR%"
for %%i in ("%MKDOCS_EXE%") do set "MKDOCS_EXE=%%~fi"

if not exist "%MKDOCS_EXE%" (
    echo [错误] 找不到 mkdocs.exe：%MKDOCS_EXE%
    echo 请先在 DocHub 目录执行：python -m venv .venv
    echo 再用 pip install mkdocs mkdocs-material 安装依赖
    pause
    exit /b 1
)

echo [信息] 正在启动 MkDocs 本地预览：%SITE_URL%
echo [信息] 服务窗口标题为 "MyWiki MkDocs"，关闭该窗口即可停止服务。
start "MyWiki MkDocs" cmd /k ""%MKDOCS_EXE%" serve -a 127.0.0.1:8000"

set /a TRIES=0
:WAIT_READY
curl.exe -s -o nul --max-time 2 "%SITE_URL%"
if not errorlevel 1 goto OPEN_BROWSER
set /a TRIES+=1
if %TRIES% GEQ 30 (
    echo [错误] 30 秒内服务未就绪，请查看 "MyWiki MkDocs" 窗口中的报错。
    pause
    exit /b 1
)
timeout /t 1 /nobreak >nul
goto WAIT_READY

:OPEN_BROWSER
start "" "%SITE_URL%"
echo [完成] 已自动打开浏览器：%SITE_URL%
exit /b 0
