@echo off
REM ============================================================
REM  NetShooter 服务端 - Windows 启动脚本 (部署在 game.xfan.l.cd)
REM ------------------------------------------------------------
REM  用法:
REM      start_server.bat             前台运行 (关闭窗口即停)
REM      start_server.bat --daemon    后台守护 (推荐)
REM      start_server.bat --install   注册为 Windows 服务, 开机自启
REM      start_server.bat --port 8888 指定端口 (穿透映射常用)
REM
REM  前提: 已运行 build_server.bat 生成 NetShooterServer.exe
REM        (exe 内置 pck, 免装 Godot, 双击即用)
REM  UDP 7777 需在防火墙放行 (见 docs/tuowan_nat.md)
REM ============================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PORT=7777"
set "EXE=NetShooterServer.exe"

if not exist "%EXE%" (
  echo 找不到 %EXE%. 请先运行 build_server.bat 构建服务端.
  exit /b 1
)

REM ---- 提取 --port xxx 参数 ----
set "EXTRA_ARGS=--script res://scripts/server_network.gd"
set "ARG1=%~1"
if "%ARG1%"=="--port" set "EXTRA_ARGS=--script res://scripts/server_network.gd --port %~2"

if "%ARG1%"=="--daemon" goto daemon
if "%ARG1%"=="--install" goto install

REM ---- 前台运行 (默认) ----
echo 启动 NetShooter 服务端 (端口 UDP %PORT%, 可用 --port 指定)
"%EXE%" --headless %EXTRA_ARGS%
goto :eof

:daemon
REM 后台运行, 日志写 server.log
start "" /b "%EXE%" --headless %EXTRA_ARGS% > "%cd%\server.log" 2>&1
echo 服务端已在后台启动, 日志: server.log
goto :eof

:install
where nssm >nul 2>&1
if errorlevel 1 (
  echo 未找到 nssm. 请下载 https://nssm.cc 放入 PATH 后重试 --install
  goto :eof
)
nssm install NetShooterServer "%cd%\%EXE%" --headless %EXTRA_ARGS%
nssm set NetShooterServer AppStdout "%cd%\server.log"
nssm set NetShooterServer AppStderr "%cd%\server.log"
nssm start NetShooterServer
echo 已注册并启动 Windows 服务: NetShooterServer
goto :eof
