@echo off
REM 停止 NetShooter 服务端 (停止后台/服务)
setlocal
cd /d "%~dp0"

where nssm >nul 2>&1
if not errorlevel 1 (
  nssm stop NetShooterServer
  nssm remove NetShooterServer confirm
  echo 已停止并移除 Windows 服务
) else (
  REM 直接按端口杀进程 (需管理员权限)
  for /f "tokens=5" %%a in ('netstat -ano ^| findstr :7777 ^| findstr LISTENING') do (
    taskkill /PID %%a /F >nul 2>&1
  )
  echo 已尝试停止监听 7777 的进程
)
endlocal
