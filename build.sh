#!/bin/bash
# NetShooter - 一键导出 Windows EXE + Android APK
# 用法:
#   ./build.sh                 # 使用环境变量里已配置的 Godot/SDK
#   GODOT=/path/to/godot ./build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
mkdir -p "$BUILD/windows" "$BUILD/android"

GODOT="${GODOT:-godot}"

echo "==> [1/5] 校验 Godot"
"$GODOT" --version || { echo "找不到可用 Godot, 请设置 GODOT= 或放进 PATH"; exit 1; }

echo "==> [2/5] 确保导出模板就绪"
"$GODOT" --headless --quit 2>/dev/null || true
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates"
if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "未检测到导出模板, 请在 Godot 编辑器中: Editor > Manage Export Templates > Download"
fi

echo "==> [3/5] 导出 Windows EXE"
"$GODOT" --headless --path "$ROOT" \
  --export-release "Windows Desktop" "$BUILD/windows/NetShooter.exe"
( cd "$BUILD/windows" && zip -r "$ROOT/NetShooter-windows.zip" . )

echo "==> [4/5] 导出 Android APK"
# 若未配置签名 keystore, 则自动生成调试 keystore, 让包可安装
if ! grep -q "keystore/release" "$ROOT/export_presets.cfg"; then
  echo "未检测到 release keystore, 生成调试签名..."
  KEYSTORE="$ROOT/debug.keystore"
  keytool -genkeypair -v -keystore "$KEYSTORE" -storepass android \
    -alias netshooter -keypass android -storetype PKCS12 \
    -dname "CN=NetShooter, OU=Dev, O=NetShooter, L=Unknown, S=Unknown, C=US" \
    -validity 10000 2>/dev/null || true
  # 插入到 Android preset 的 options 段, 紧跟 [preset.1.options]
  python3 - "$ROOT/export_presets.cfg" "$KEYSTORE" <<'PY'
import sys
p, ks = sys.argv[1], sys.argv[2]
lines = open(p).read().splitlines(keepends=True)
out, done = [], False
for ln in lines:
    out.append(ln)
    if not done and ln.strip() == "[preset.1.options]":
        out.append(f"keystore/release={ks}\n")
        out.append("keystore/release_password=android\n")
        out.append("keystore/release_alias=netshooter\n")
        out.append("keystore/release_alias_password=android\n")
        done = True
open(p, "w").writelines(out)
PY
fi
"$GODOT" --headless --path "$ROOT" \
  --export-release "Android" "$BUILD/android/NetShooter.apk"

echo "==> [5/5] 完成"
ls -lh "$ROOT/NetShooter-windows.zip" "$BUILD/android/NetShooter.apk"
