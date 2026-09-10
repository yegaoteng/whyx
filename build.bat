@echo off
REM NetShooter - Windows 一键导出 EXE + APK (Windows 版)
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "GODOT=%GODOT%"
if "%GODOT%"=="" set "GODOT=godot.exe"

echo ==^> [1/4] 校验 Godot
"%GODOT%" --version || (echo 找不到 Godot, 请先设置环境变量 GODOT=路径 或把 godot.exe 放进 PATH & exit /b 1)

echo ==^> [2/4] 导出 Windows EXE
"%GODOT%" --headless --path "%cd%" --export-release "Windows Desktop" "build\windows\NetShooter.exe"
if not exist "build\windows\NetShooter.exe" (echo Windows 导出失败 & exit /b 1)

echo ==^> [3/4] 检查/生成 Android 签名
if not exist "release.keystore" (
  echo 未检测到 keystore, 生成调试签名...
  keytool -genkeypair -v -keystore "release.keystore" -storepass android -alias netshooter -keypass android -storetype PKCS12 -dname "CN=NetShooter,OU=Dev,O=NetShooter,L=Unknown,S=Unknown,C=US" -validity 10000
  REM 追加签名配置到 Android preset
  echo.>> export_presets.cfg
  echo keystore/release=%cd%\release.keystore>> export_presets.cfg
  echo keystore/release_password=android>> export_presets.cfg
  echo keystore/release_alias=netshooter>> export_presets.cfg
  echo keystore/release_alias_password=android>> export_presets.cfg
)

echo ==^> [4/4] 导出 Android APK
"%GODOT%" --headless --path "%cd%" --export-release "Android" "build\android\NetShooter.apk"
if not exist "build\android\NetShooter.apk" (echo Android 导出失败 & exit /b 1)

echo ==^> [4/4] 完成
dir /b build\windows\NetShooter.exe build\android\NetShooter.apk
endlocal
