# NetShooter - 简易联机枪战游戏 (Godot 4.3)

**三模式并存**的简易 2D 联机枪战:

```
┌─ 模式1 官方服务器 ──── game.xfan.l.cd:7777 (部署在 Windows 机器, 独立 exe 运行)
├─ 模式2 自建主机 ────── 谁开房谁当主机, 无需服务器 (同一套代码)
└─ 模式3 内网穿透 ────── FRP / Tailscale / Ngrok, 把 7777 暴露公网, 见 docs/tuowan_nat.md
                              │
                              ▼ (ENet / UDP 7777, 协议一致, 客户端只填地址)
              [Windows EXE] ─┐
              [Android APK] ─┴──▶  服务端 (服务器权威: 伤害/得分/同步)
```

## 三种联机方式

| 模式 | 谁当服务器 | 客户端填什么 | 适合 |
|------|-----------|-------------|------|
| **官方服** | `game.xfan.l.cd` 上的 Windows 服务端 exe | `game.xfan.l.cd` | 长期公网服 |
| **自建主机** | 房主本机 (游戏内"创建房间") | 房主 IP / 局域网 IP | 朋友开黑, 无需服务器 |
| **内网穿透** | 房主/服务器 + FRP/Tailscale | 穿透公网地址 | 无公网 IP 时 |

> 三种模式**共用同一套网络代码** (`scripts/client_network.gd`):
> - 连服务器 → `connect_to(地址, 7777)`
> - 当主机 → `start_server()` (动态挂载 `server_network.gd`, 逻辑与独立服务端完全一致)

## 目录结构

```
godot-shooter/
├── scripts/
│   ├── client_network.gd   # ★ 客户端+主机双角色 (connect_to / start_server)
│   ├── server_network.gd   # ★ 服务器权威逻辑 (伤害/得分/同步), 可独立运行也可被挂载
│   ├── player.gd / bullet.gd / game.gd / game_scene.gd / main_menu.gd
├── scenes/                 # 游戏场景 (含 server_main.tscn 服务端入口)
├── server/                 # ★ 服务端运行文件 (Windows)
│   ├── build_server.bat    #   一键构建 NetShooterServer.exe
│   ├── start_server.bat    #   启动 (--daemon 后台 / --install 服务 / --port 改端口)
│   ├── stop_server.bat     #   停止 / 卸载服务
│   └── README.md
├── docs/tuowan_nat.md      # ★ 内网穿透联机指南 (FRP/Ngrok/花生壳/Tailscale)
├── export_presets.cfg      # Windows / Android / Windows Server 三个预设
├── build.bat / build.sh    # 一键出 EXE + APK
├── .github/workflows/build.yml  # CI: push tag → EXE + APK + Server-Windows.zip → Release
└── verify.py / lint_gd.py
```

## 快速开始

### 方式 A: 连接官方服务器 / 穿透地址

1. 构建客户端: `build.bat` → 得到 `NetShooter-windows.zip` + `NetShooter.apk`
2. 打开 EXE 或安装 APK, 输入名字
3. "服务器IP"栏填 `game.xfan.l.cd` (或穿透地址 `xxx.frp.io` / `100.x.x.x`)
4. 点"加入服务器" → 进入游戏

### 方式 B: 自建主机 (谁开房谁当主机, 无需服务器)

1. 主机玩家打开游戏 → 输名字 → 点 **"创建房间(主机)"**
2. 其他人点"加入服务器", 填**主机地址:7777**
   - 同一局域网: 主机的局域网 IP (如 `192.168.1.100`)
   - 跨网络: 用 `docs/tuowan_nat.md` 的内网穿透, 填穿透公网地址
3. 进房即开打 → **零服务器成本**

### 方式 C: 部署官方服务端到 game.xfan.l.cd (Windows)

```powershell
# 1. 防火墙放行 UDP 7777 (管理员)
New-NetFirewallRule -DisplayName "NetShooter UDP 7777" -Direction Inbound -LocalPort 7777 -Protocol UDP -Action Allow

# 2. 构建服务端 exe (需 Godot 4.3 + server 导出模板)
.\server\build_server.bat

# 3. 启动 (拷 build\windows-server\ 到 game.xfan.l.cd 这台机器)
cd build\windows-server
.\start_server.bat              # 前台
.\start_server.bat --daemon     # 后台, 日志 server.log
.\start_server.bat --install    # 注册 Windows 服务, 开机自启
```

产物 `NetShooterServer-Windows.zip` = **单个 exe + 启动脚本, 免装 Godot**。
把 `game.xfan.l.cd` 的 A 记录指向该机器公网 IP, 放行 UDP 7777, 玩家直连。

## 自动构建 (GitHub Actions)

推一个 `v*` tag 自动构建并发布 Release:
- `NetShooter-windows.zip` — Windows 客户端 (.exe)
- `NetShooter.apk` — Android 客户端
- `NetShooterServer-Windows.zip` — Windows 服务端 (headless exe)

详见 `server/README.md` 与 `.github/workflows/build.yml`。

## 校验

```bash
python3 verify.py    # 结构/预设/双模式/Windows化/穿透文档
python3 lint_gd.py   # GDScript 语法近似检查 + 场景引用有效性
```

## 安全提示

- ENet 走 **UDP 7777**, 内网穿透工具务必确认**转发 UDP** (很多免费隧道只转 TCP)
- 服务器权威判定 (伤害/得分), 客户端改内存无效
- 上线前建议在服务端加玩家鉴权/防作弊 (当前为演示级)
