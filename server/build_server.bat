@echo off
REM ============================================================
REM  NetShooter - 服务端 (Windows) 一键构建
REM ------------------------------------------------------------
REM  产物: build\windows-server\NetShooterServer.exe  (独立, 免装 Godot)
REM         + start_server.bat / stop_server.bat
REM  部署: 拷贝整个 build\windows-server\ 到 game.xfan.l.cd 这台 Windows 机器
REM        双击 start_server.bat (或 --daemon / --install) 即开服, 监听 UDP 7777
REM
REM  注意: 导出 "Windows Server" 需要 Godot 4.3 的 *server* 导出模板
REM        (Editor > Manage Export Templates > 勾选 Server 下载)
REM ============================================================
setlocal enabledelayedexpansion
cd /d "%~dp0\.."

set "GODOT=%GODOT%"
if "%GODOT%"=="" set "GODOT=godot.exe"

echo ==^> [1/3] 校验 Godot
"%GODOT%" --version || (echo 找不到 Godot, 请设置 GODOT=路径 或加入 PATH & exit /b 1)

echo ==^> [2/3] 导出 Windows 服务端 exe (headless, 内置 pck, 免装 Godot)
"%GODOT%" --headless --path "%cd%" --export-release "Windows Server" "build\windows-server\NetShooterServer.exe"
if not exist "build\windows-server\NetShooterServer.exe" (
  echo Windows Server 导出失败. 请确保已安装 Godot 4.3 的 server 导出模板:
  echo   Editor 菜单 ^> Manage Export Templates ^> 勾选 "Server" 下载
  exit /b 1
)

echo ==^> [3/3] 打包服务端运行文件 (exe 已内置脚本, 只需启动脚本)
copy /y "server\start_server.bat" "build\windows-server\start_server.bat" >nul
copy /y "server\stop_server.bat"  "build\windows-server\stop_server.bat"  >nul

cd build
if exist NetShooterServer-Windows.zip del NetShooterServer-Windows.zip
powershell -command "Compress-Archive -Path 'windows-server\*' -DestinationPath 'NetShooterServer-Windows.zip' -Force"

echo ==^> 完成: build\NetShooterServer-Windows.zip
dir /b "NetShooterServer-Windows.zip"
endlocal
