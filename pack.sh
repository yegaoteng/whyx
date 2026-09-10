#!/bin/bash
# 打包: NetShooter.zip (完整工程) + NetShooter-Server.zip (独立服务端运行文件)
set -e
cd "$(dirname "$0")"
rm -f ../NetShooter.zip ../NetShooter-Server.zip

# 完整工程
zip -rq ../NetShooter.zip . \
  -x "*.git*" "build/*" "*.zip" "pack.sh" \
  -x "server/__pycache__/*" "scripts/__pycache__/*"

# 服务端独立包 (部署到 game.xfan.l.cd 的 Windows 机器)
# 运行时需先 build_server.bat 生成 NetShooterServer.exe (内置 pck, 免装 Godot)
mkdir -p /tmp/netshooter-server
cp server/server_network.gd     /tmp/netshooter-server/ 2>/dev/null || true
cp server/start_server.bat      /tmp/netshooter-server/
cp server/stop_server.bat       /tmp/netshooter-server/
cp server/build_server.bat      /tmp/netshooter-server/
cp server/README.md             /tmp/netshooter-server/
cp docs/tuowan_nat.md           /tmp/netshooter-server/
cp scripts/server_network.gd     /tmp/netshooter-server/ 2>/dev/null || true
# 生成一个最小 server-project, 让 build_server.bat 可在服务端机器上重跑
cat > /tmp/netshooter-server/BUILD_INSTRUCTIONS.txt <<'EOF'
NetShooter 专用服务端 (Windows)
================================
方式1 (推荐): 在开发机上跑 build_server.bat -> NetShooterServer.exe, 拷 exe+启动脚本即可.
方式2: 把这整个文件夹放到服务端机器, 装 Godot 4.3, 跑 build_server.bat.
启动: start_server.bat [--daemon | --install | --port 8888]
详情: README.md 与 docs/tuowan_nat.md (内网穿透)
EOF
cd /tmp && zip -rq /data/workspace/NetShooter-Server.zip netshooter-server

echo "=== 产物 ==="
ls -la ../NetShooter.zip /data/workspace/NetShooter-Server.zip
