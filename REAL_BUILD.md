# 真实构建指南（Real Build — 出 Windows EXE + Android APK）

> 沙盒环境无法访问外网下载 Godot/Android SDK，因此本工程采用 **「工程 + 一键脚本」** 的方式：你在**自己的电脑**（或 GitHub Actions CI）上，用官方 Godot 一键导出两个平台的安装包。全程免费，无需 Android Studio。

---

## 一、准备（一次性，约 10 分钟）

### 1. 安装 Godot 4.3（标准版，不是 headless）

- 下载页：https://godotengine.org/download/ → 选 **Godot 4.3 (Standard)**
  - Windows：`Godot_v4.3-stable_win64.exe.zip` → 解压得到 `godot.exe`
  - macOS：`Godot.app`
  - Linux：`Godot_v4.3-stable_linux.x86_64.zip` → 解压得到 `godot` 二进制
- 把 Godot 所在目录加入 **PATH**，或记住它的路径（后面脚本要用）。

> ✅ 推荐用 **Standard** 版：导出 Android 包需要编辑器内的模板管理功能；headless 版主要用于 CI。

### 2. 下载导出模板（Export Templates）

打开 Godot 编辑器：

```
Editor 菜单 → Manage Export Templates → Download
```

选择 **4.3-stable** → 安装。这会下载约 300MB 的各平台导出运行时（Windows / Android / Linux 等共用）。

> 安装后模板位置：
> - Windows：`%APPDATA%\Godot\export_templates\4.3.stable\`
> - Linux/macOS：`~/.local/share/godot/export_templates/4.3.stable/`

### 3.（仅 Android）准备 SDK 与签名

#### 方式 A：用 Android Studio 的 SDK（推荐，最简单）

1. 安装 [Android Studio](https://developer.android.com/studio)。
2. 打开后 `SDK Manager` → 装 **Android SDK Platform 34** + **Android SDK Build-Tools 34**。
3. 记下 SDK 路径：
   - Windows：`C:\Users\<你>\AppData\Local\Android\Sdk`
   - macOS：`~/Library/Android/sdk`
   - Linux：`~/Android/Sdk`
4. 设置环境变量：
   ```bash
   export ANDROID_HOME=~/Android/Sdk      # 或你的实际路径
   export ANDROID_SDK_ROOT=~/Android/Sdk
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   ```

#### 方式 B：只要命令行工具（轻量）

下载 [Command-line Tools](https://developer.android.com/studio)，解压后：

```bash
cd cmdline-tools && mkdir latest && mv bin lib NOTICE LICENSE latest/
export ANDROID_HOME=$PWD/..
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

#### 生成签名 keystore（发布必需）

```bash
keytool -genkeypair -v -keystore release.keystore -storepass 你的密码 \
  -alias netshooter -keypass 你的密码 -storetype PKCS12 \
  -dname "CN=NetShooter, OU=Dev, O=NetShooter, L=Unknown, S=Unknown, C=US" \
  -validity 10000
```

记下 `release.keystore` 的位置、store 密码、alias、alias 密码。

---

## 二、配置 Godot 的 Android 导出预设

1. 用 Godot 打开本工程目录（含 `project.godot`）。
2. `Project → Export` → 选 **Android** → 点右上角「铅笔」编辑预设。
3. 在 **Keystore** 区域填入：
   - Keystore：`/path/to/release.keystore`
   - Keystore Password：你的密码
   - Alias：netshooter
   - Alias Password：你的密码
4. 保存预设（写入 `export_presets.cfg`）。

> ⚠️ 若要 CI 自动构建，请把 keystore 转成 base64 存到 GitHub Secrets（见下方 CI 章节），**不要**把明文密码提交到仓库。

---

## 三、一键构建（推荐）

工程根目录已包含 `build.sh`（Linux/macOS）和 `build.bat`（Windows），自动导出两个平台：

### Linux / macOS

```bash
cd godot-shooter
chmod +x build.sh
GODOT=/path/to/godot ./build.sh
```

### Windows (PowerShell)

```powershell
cd godot-shooter
$env:GODOT = "C:\path\to\godot.exe"
.\build.bat
```

构建完成后：

```
build/windows/   →  NetShooter.exe  (Windows 64-bit)
build/android/   →  NetShooter.apk  (Android ARMv7/ARM64)
```

`build.sh` 会自动：
- ✅ 检查 Godot 是否可用
- ✅ 确认导出模板已安装
- ✅ 若没配 keystore，自动生成 **调试签名** 让包可安装测试
- ✅ 导出 EXE 并打包成 `NetShooter-windows.zip`
- ✅ 导出签名的 APK

---

## 四、手动导出（不用脚本）

### Windows EXE

```
Godot 编辑器 → Project → Export → 选 "Windows Desktop" → Export Project
→ 勾选 "Export With Debug" 去掉(发布) → 路径填 build/windows/NetShooter.exe
```

### Android APK

```
Project → Export → 选 "Android" → Export Project
→ 路径填 build/android/NetShooter.apk
```

---

## 五、GitHub Actions 自动构建发 Release

推一个 `v*` tag 即可让 CI 自动出包并发布到 GitHub Releases（用官方 `GITHUB_TOKEN`，无需你的 PAT 暴露在代码里）：

```bash
cd godot-shooter
gh repo create your-username/netshooter --public --source=. --push
git tag v1.0.0
git push origin v1.0.0     # 触发 Actions
```

（可选）若要 **签名 release APK**，在仓库 `Settings → Secrets and variables → Actions` 添加：

| Secret 名 | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` 的输出 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | `netshooter` |
| `ANDROID_KEY_ALIAS_PASSWORD` | alias 密码 |

未配置这些 Secret 时，CI 会退化为**调试签名 APK**（可装可测，但不能上 Play Store）。

---

## 六、安装与运行

### Windows

- 把 `NetShooter-windows.zip` 解压，双击 `NetShooter.exe`。
- 首次运行若提示缺 `msvcp140.dll` 等，装一下 [VC++ 运行库](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。

### Android

```bash
# 手机连电脑, 开启 USB 调试
adb install -r build/android/NetShooter.apk
```

或在手机上：设置 → 安全 → 允许「安装未知来源应用」→ 把 APK 传到手机直接点击安装。

> 联机：同一 Wi-Fi 下，一台手机/电脑点「创建服务器」，其他设备填它的 **局域网 IP**（如 `192.168.1.105`）即可加入。外网联机需服务器设备做端口转发（UDP/TCP 7777）。

---

## 七、常见问题

| 问题 | 解决 |
|---|---|
| 导出时提示「No export templates found」 | Godot 编辑器 → Manage Export Templates → Download |
| Android 导出报 SDK 找不到 | 检查 `ANDROID_HOME` 是否指向含 `platform-tools` 的目录 |
| APK 安装失败「INSTALL_FAILED_INVALID_APK」 | 确认用了**签名**（调试或 release 都行），未签名 APK 无法安装 |
| Windows 双击无反应 | 从命令行跑 `NetShooter.exe` 看报错；确认显卡驱动支持 OpenGL/Vulkan |
| 手机加入服务器超时 | 确认服务器 IP 正确、端口 7777 防火墙放行、手机与服务器同网段 |

---

## 附：目录结构

```
godot-shooter/
├── project.godot
├── export_presets.cfg
├── build.sh / build.bat        ← 一键出包
├── REAL_BUILD.md               ← 本文件
├── README.md
├── init_repo.sh
├── .github/workflows/build.yml ← CI 自动构建+发 Release
├── scripts/*.gd
└── scenes/*.tscn
```
