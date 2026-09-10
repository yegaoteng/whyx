import os, re, sys

ROOT = os.path.dirname(os.path.abspath(__file__))

REQ = [
    # 工程核心
    "project.godot", "export_presets.cfg", "README.md",
    "REAL_BUILD.md", "build.sh", "build.bat", "init_repo.sh",
    "verify.py", ".github/workflows/build.yml", "server/README.md",
    "docs/tuowan_nat.md",
    # 服务端 (部署到 game.xfan.l.cd, Windows)
    "server/server_network.gd",
    "server/start_server.bat", "server/stop_server.bat",
    "server/build_server.bat",
    # 客户端 (官方服 / 自建主机 双模式)
    "scripts/client_network.gd", "scripts/player.gd", "scripts/bullet.gd",
    "scripts/game_scene.gd", "scripts/main_menu.gd", "scripts/game.gd",
    "scenes/main_menu.tscn", "scenes/game.tscn",
    "scenes/player.tscn", "scenes/bullet.tscn",
]
print("=== 必需文件 ===")
miss = 0
for f in REQ:
    if not os.path.exists(os.path.join(ROOT, f)):
        print("MISS " + f); miss += 1
print(f"共 {len(REQ)} 项, 缺失 {miss}")

print("\n=== GDScript 括号/缩进检查 ===")
ok = True
for dirpath, _, files in os.walk(ROOT):
    if "/." in dirpath or "\\." in dirpath:
        continue
    for fn in files:
        if fn.endswith(".gd"):
            p = os.path.join(dirpath, fn)
            raw = open(p, encoding="utf-8").read().split("\n")
            # 去掉注释后的代码部分再数括号 (避免注释里的自然语言括号误报)
            code = ""
            for line in raw:
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                # 去掉行内注释 (简单处理: 首个 # 之后)
                idx = -1; q = None
                for i, ch in enumerate(line):
                    if ch in ('"', "'"):
                        q = ch if q is None else (None if q == ch else q)
                    elif ch == "#" and q is None:
                        idx = i; break
                code += (line[:idx] if idx >= 0 else line) + "\n"
            if code.count("(") != code.count(")") or code.count("[") != code.count("]") or code.count("{") != code.count("}"):
                print("BRACKETS BAD:", fn); ok = False
            bad = False
            for line in raw:
                ls = line.lstrip()
                lead = line[:len(line) - len(ls)]
                if "\t" in lead and " " in lead:
                    bad = True; break
            if bad:
                print("MIXED INDENT:", fn); ok = False
print("all scripts clean" if ok else "PROBLEMS FOUND")

print("\n=== 导出预设 (CI 用) ===")
cfg = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
for needle in ['name="Windows Desktop"', 'name="Android"', 'name="Windows Server"']:
    print(("OK  " if needle in cfg else "MISS") + " " + needle)

print("\n=== 默认服务器地址 (应为 game.xfan.l.cd) ===")
for f in ["scripts/client_network.gd", "scripts/game.gd"]:
    s = open(os.path.join(ROOT, f), encoding="utf-8").read()
    print(("OK  " if "game.xfan.l.cd" in s else "MISS") + " " + f)

print("\n=== 双模式并存校验 ===")
cli = open(os.path.join(ROOT, "scripts/client_network.gd"), encoding="utf-8").read()
has_join = "connect_to" in cli and "DEFAULT_HOST" in cli
has_host = "start_server" in cli and "_attach_server_logic" in cli
print(("OK  " if has_join else "MISS") + " 模式1: 连官方服/穿透地址 (connect_to)")
print(("OK  " if has_host else "MISS") + " 模式2: 自建主机 (start_server 挂载 server_network)")

print("\n=== 服务端 Windows 化校验 ===")
ss = open(os.path.join(ROOT, "server/start_server.bat"), encoding="utf-8").read()
print(("OK  " if "--headless" in ss and "7777" in ss else "MISS") + " start_server.bat 用 headless + 端口")

print("\n=== 内网穿透文档 ===")
tw = open(os.path.join(ROOT, "docs/tuowan_nat.md"), encoding="utf-8").read()
print(("OK  " if "UDP" in tw and "7777" in tw and "FRP" in tw and "Tailscale" in tw else "MISS") + " docs/tuowan_nat.md 含 UDP/FRP/Tailscale")

sys.exit(0 if (ok and miss == 0) else 1)
