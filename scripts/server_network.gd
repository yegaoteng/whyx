extends Node
## ============================================================
##  NetShooter - 服务器权威逻辑 (可独立运行 / 也可被客户端挂载)
## ------------------------------------------------------------
##  两种运行方式:
##
##  [A] 独立专用服务器 (部署在 game.xfan.l.cd 的 Windows 机器上)
##      NetShooterServer.exe --headless --script res://scripts/server_network.gd --port 7777
##      自动监听 UDP 7777, 玩家通过客户端 "连接服务器" 加入
##
##  [B] 被客户端动态挂载 (谁开房谁当主机模式)
##      client_network.start_server() -> load 本脚本 -> start()
##      此时 multiplayer_peer 已由客户端 create_server, 本脚本直接复用
##
##  职责: 玩家注册/掉线, 输入采集, 服务器权威伤害&得分, 状态广播
## ============================================================

const PORT := 7777
const MAX_PLAYERS := 16
const TICK_RATE := 20

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var players: Dictionary = {}
var _tick := 0
var _running := false


## 读取命令行 --port 参数 (Windows 服务/穿透时可指定端口)
func _read_port() -> int:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size():
			return args[i + 1].to_int()
		if args[i].begins_with("--port="):
			return args[i].split("=")[1].to_int()
	return PORT


func _ready() -> void:
	# 独立运行时 (有场景入口) 自动 start; 被挂载时由调用方显式 start()
	if not _running:
		start()


## 启动监听 (独立服务器模式调用)
func start() -> void:
	if _running:
		return
	_running = true

	var use_port := _read_port()

	# 若尚未设置 multiplayer_peer (独立模式), 则创建服务器
	var peer := multiplayer.multiplayer_peer
	if peer == null or not peer.is_refusing_new_connections():
		var new_peer := ENetMultiplayerPeer.new()
		var err := new_peer.create_server(use_port, MAX_PLAYERS)
		if err != OK:
			printerr("[Server] 无法绑定端口 ", use_port, " 错误: ", err)
			get_tree().quit(1)
			return
		multiplayer.set_multiplayer_peer(new_peer)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_ensure_scene_tree()
	set_physics_process(true)
	print("[Server] ========== NetShooter Server ==========")
	print("[Server] 监听端口: ", use_port, "  最大玩家: ", MAX_PLAYERS)


func _ensure_scene_tree() -> void:
	var root := get_tree().root
	if root.has_node("ServerWorld"):
		return
	var world := Node2D.new(); world.name = "ServerWorld"; root.add_child(world)
	var p := Node2D.new(); p.name = "Players"; world.add_child(p)
	var b := Node2D.new(); b.name = "Bullets"; world.add_child(b)


func _players_node() -> Node2D:
	return get_tree().root.get_node_or_null("ServerWorld/Players")


# ---------- 连接事件 ----------
func _on_peer_connected(peer_id: int) -> void:
	print("[Server] 玩家连接: ", peer_id, " (在线: ", players.size() + 1, ")")


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Server] 玩家离开: ", peer_id)
	if players.has(peer_id):
		rpc("despawn_player", peer_id)
		players.erase(peer_id)
		rpc("sync_players", players)


# ---------- 主循环 (服务器权威) ----------
func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick < Engine.physics_ticks_per_second / TICK_RATE:
		return
	_tick = 0

	# 依据客户端上报的 input 推进位置 (服务器权威, 含简易边界)
	for pid in players:
		var pdata: Dictionary = players[pid]
		if pdata.has("input") and pdata.has("pos"):
			var inp: Dictionary = pdata.input
			var dir: Vector2 = inp.get("dir", Vector2.ZERO)
			var new_pos: Vector2 = pdata.pos + dir * 260.0 * (1.0 / TICK_RATE)
			new_pos.x = clamp(new_pos.x, 20, 1260)
			new_pos.y = clamp(new_pos.y, 20, 700)
			pdata.pos = new_pos

	if players.size() > 0:
		rpc("full_state", players)


# ---------- RPC: 客户端 -> 服务器 ----------
@rpc("any_peer", "call_local", "reliable")
func register_player(peer_id: int, pname: String) -> void:
	if players.has(peer_id):
		players[peer_id].name = pname
	else:
		players[peer_id] = {
			"name": pname if not pname.is_empty() else ("Player" + str(peer_id)),
			"color": _random_color(),
			"pos": Vector2(randf_range(100, 1100), randf_range(100, 600)),
			"health": 100, "score": 0,
		}
	print("[Server] 注册 ", peer_id, " = ", players[peer_id].name)
	rpc("sync_players", players)
	for pid in players:
		rpc_id(peer_id, "spawn_player", pid, players[pid].name, players[pid].color)


@rpc("any_peer", "call_local", "unreliable")
func player_input(peer_id: int, input_dir: Vector2, aiming: Vector2, shooting: bool) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["input"] = {"dir": input_dir, "aim": aiming, "fire": shooting}


@rpc("any_peer", "call_local", "reliable")
func player_shoot(peer_id: int, from: Vector2, direction: Vector2) -> void:
	if not players.has(peer_id):
		return
	rpc("spawn_bullet", peer_id, from, direction)
	# 简易服务器权威伤害判定: 前方 300px 内的其他玩家
	for vid in players:
		if vid == peer_id:
			continue
		var vpos: Vector2 = players[vid].get("pos", Vector2.ZERO)
		if vpos.distance_to(from) < 300 and (vpos - from).normalized().dot(direction) > 0.7:
			damage_player(vid, 25, peer_id)


@rpc("any_peer", "call_local", "reliable")
func damage_player(victim_id: int, amount: int, attacker_id: int) -> void:
	if not players.has(victim_id):
		return
	var p: Dictionary = players[victim_id]
	p.health -= amount
	if p.health <= 0:
		if players.has(attacker_id):
			players[attacker_id].score += 1
		p.health = 100
		p.pos = Vector2(randf_range(100, 1100), randf_range(100, 600))
		rpc("player_died", victim_id, attacker_id)
		rpc("sync_players", players)


# ---------- RPC: 服务器 -> 客户端 (authority, 空壳, 客户端侧同名 RPC 生效) ----------
@rpc("authority", "call_local", "reliable")
func sync_players(_p: Dictionary) -> void: pass

@rpc("authority", "call_local", "reliable")
func spawn_player(_pid: int, _n: String, _c: Color) -> void: pass

@rpc("authority", "call_local", "reliable")
func despawn_player(_pid: int) -> void: pass

@rpc("authority", "call_local", "reliable")
func spawn_bullet(_o: int, _f: Vector2, _d: Vector2) -> void: pass

@rpc("authority", "call_local", "reliable")
func player_died(_v: int, _a: int) -> void: pass

@rpc("authority", "call_local", "unreliable")
func full_state(_p: Dictionary) -> void: pass


func _random_color() -> Color:
	return Color(randf(), randf(), randf())
