# 内网穿透联机指南 (陶瓦/FRP/Ngrok/花生壳/Tailscale)

NetShooter 用 **ENet (UDP)** 传输。内网穿透工具把本机 `7777` 端口暴露到公网，
其他玩家在客户端"服务器IP"栏填入**穿透后的公网地址**即可，游戏协议完全不用改。

> 核心：客户端只认"地址:端口"。官方服 `game.xfan.l.cd:7777` 是一种地址；
> 穿透工具给的公网地址 `xxx.frp.io:7777` 是另一种，代码里走的是同一套 `connect_to()`。

---

## 一、协议要求：必须支持 UDP

ENet 走 **UDP**。选穿透工具时务必确认它**转发 UDP 7777**（很多免费隧道只转 TCP，会连不上）。

| 工具 | UDP 支持 | 适合场景 |
|------|----------|---------|
| **FRP** (自建) | ✅ 完整 UDP | 有公网服务器, 最推荐 |
| **Tailscale / ZeroTier** | ✅ 虚拟局域网 | 最简, 不用公网 IP, 纯 P2P |
| **Ngrok** | ⚠️ 需付费版才支持 UDP | 临时演示 |
| **花生壳 / cpolar / 路由侠** | ⚠️ 看套餐 | 国内家用宽带 |

---

## 二、方案 A：FRP (推荐, 自建公网中转)

### 服务端机器 (`game.xfan.l.cd` 或任意一台 Windows)

1. 下载 frp: https://github.com/fatedier/frp/releases (选 windows_amd64)
2. 服务端 `frps.ini`:
   ```ini
   [common]
   bind_port = 7000        # frp 控制端口
   bind_udp_port = 7001    # ★ UDP 穿透必须
   ```
   ```powershell
   .\frps.exe -c frps.ini
   ```

### 主机玩家 (开房间的那台, 即"谁开房谁当主机")

`frpc.ini` (把 `公网服务器IP` 换成你的 frps 所在 IP):
```ini
[common]
server_addr = 公网服务器IP
server_port = 7000

[NetShooter-udp]
type = udp
local_ip = 127.0.0.1
local_port = 7777
remote_port = 7777        # 公网暴露的 UDP 端口
```
```powershell
.\frpc.exe -c frpc.ini
# 同时照常启动游戏, 选 "创建房间(主机)" 监听本地 7777
```

### 其他玩家加入
客户端"服务器IP"填: `公网服务器IP:7777` 或直接 `公网服务器IP` (端口默认 7777)。
连的就是开房主机的游戏 → **这就是"自建主机 + 穿透"并存**。

---

## 三、方案 B：Tailscale / ZeroTier (最简单, 免公网 IP)

1. 所有玩家 (主机 + 加入者) 装 Tailscale, 登录同一账号, 组成虚拟局域网。
2. 主机启动游戏 → "创建房间"。
3. 其他人客户端填**主机在 Tailscale 里的虚拟 IP** (形如 `100.x.x.x`), 端口 7777。
   → 完全 P2P, 不消耗服务器流量, 天然穿透 NAT。

**这是最推荐给"朋友间开黑"的方式**, 不用任何公网服务器。

---

## 四、方案 C：连官方服务器 (不穿透)

客户端默认地址 = `game.xfan.l.cd:7777`。
把 `game.xfan.l.cd` 的 **A 记录**指向部署了 `NetShooterServer.exe` 的 Windows 机器公网 IP,
云防火墙 + Windows 防火墙放行 **UDP 7777**, 玩家直接连即可。

---

## 五、三模式对照 (客户端主菜单)

```
┌────────────────────────────────────────────┐
│  模式1 联机大厅                            │
│    名字: ____   服务器IP: game.xfan.l.cd   │  ← 官方服
│              [ 加入服务器 ]                │
│  ── 或填穿透地址 xxx.frp.io / 100.x.x.x ──│  ← 穿透服
│                                            │
│  模式2 创建房间 (本机=主机)                │
│    名字: ____  [ 创建房间 ]                │  ← 谁开房谁当主机
└────────────────────────────────────────────┘
```

三种模式**共用同一套网络代码** (`client_network.gd`):
- 模式1 → `connect_to(地址, 7777)` → 连官方服 / 穿透服 / 朋友的房, 皆可
- 模式2 → `start_server()` → 本机监听, 别人用上面的穿透地址连你

---

## 六、排错清单

- [ ] 服务端/主机 Windows 防火墙放行 **UDP 7777** (入站规则)
- [ ] 云安全组 / 路由器端口转发 UDP 7777 (有公网 IP 时)
- [ ] 穿透工具**确认 UDP 转发生效** (很多只转 TCP)
- [ ] 客户端填地址时 `ip:port`, 端口默认 7777 可省略
- [ ] 主机模式下, 主机自己也算 1 名玩家, 房间满 8 人即止
- [ ] 连不上时先用 `Test-NetConnection 地址 -Port 7777` (PowerShell) 测连通

---

## 七、一键命令速查

```powershell
# 主机 (Windows): 启动游戏服务端 + frpc 穿透
start_server.bat --daemon
frpc.exe -c frpc.ini

# 玩家: 客户端 → 创建房间 IP 栏填 公网地址:7777 或 100.x.x.x:7777
```
