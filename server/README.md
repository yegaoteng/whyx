# NetShooter 服务端 (Windows)

独立运行的专用服务器, 部署在 `game.xfan.l.cd` 这台 **Windows** 机器上。
监听 **UDP 7777**, 玩家在客户端"服务器IP"栏填 `game.xfan.l.cd` (或内网穿透地址) 即可加入。

## 一、最快上手 (3 步)

```powershell
# 1. 放行防火墙 UDP 7777 (管理员 PowerShell)
New-NetFirewallRule -DisplayName "NetShooter UDP 7777" -Direction Inbound -LocalPort 7777 -Protocol UDP -Action Allow

# 2. 构建服务端 exe (需 Godot 4.3 + server 导出模板)
.\server\build_server.bat

# 3. 启动 (前台 / 守护 / 注册服务)
cd build\windows-server
.\start_server.bat              # 前台
.\start_server.bat --daemon     # 后台, 日志 server.log
.\start_server.bat --install    # 注册为 Windows 服务, 开机自启
```

产物 `NetShooterServer-Windows.zip` 拷到目标机器, **免装 Godot** 直接运行 (exe 内置 pck)。

## 二、目录结构

```
server/
├── server_network.gd     # 服务器权威逻辑 (伤害/得分/同步), 可被客户端动态挂载
├── start_server.bat      # Windows 启动 (--daemon / --install)
├── stop_server.bat       # 停止 / 卸载服务
├── build_server.bat      # 一键构建服务端 exe (在项目根目录运行)
└── README.md
```

## 三、关键说明

- **单一 exe**: `NetShooterServer.exe` 由 Godot `dedicated_server=true` 导出, headless 无 GPU 依赖, 可在无显卡服务器运行。
- **命令行端口**: `start_server.bat --port 8888` 可改端口 (穿透时常用不同端口映射)。
- **三模式并存**:
  - 官方服: 本 exe 部署在 `game.xfan.l.cd`, 客户端填 `game.xfan.l.cd` 直连
  - 自建主机: 客户端"创建房间"走同一份 `server_network.gd`, 无需此 exe
  - 内网穿透: 用 FRP/Tailscale 把 7777 暴露公网, 客户端填穿透地址, 见 `docs/tuowan_nat.md`
- **服务器权威**: 伤害判定、得分、重生全在服务端, 客户端改内存无效。

## 四、验证

服务端启动后应有日志:
```
[Server] ========== NetShooter Server ==========
[Server] 监听端口: 7777  最大玩家: 16
[Server] 玩家连接: 1234567 (在线: 1)
```

客户端在主菜单"加入服务器"填 `game.xfan.l.cd` → 进入游戏即成功。

## 五、域名 & 防火墙

- `game.xfan.l.cd` 的 **A 记录** 指向本机公网 IP
- 云安全组 + Windows 防火墙 + 路由器 (若在家宽) 均需放行 **UDP 7777**
- 家用宽带无公网 IP 时, 直接走 `docs/tuowan_nat.md` 的内网穿透方案
