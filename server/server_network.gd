extends Node
## ============================================================
##  NetShooter - 专用服务器 (DEDICATED SERVER / Headless)
## ------------------------------------------------------------
##  部署在 game.xfan.l.cd, 以无界面守护进程运行:
##      godot --headless --main-pack NetShooter.pck --server
##  或 (源码运行):
##      godot --headless -s scripts/server_main.gd
##
##  监听 UDP/ENet 端口 7777, 接受客户端连接, 负责:
##      - 玩家注册 / 掉线
##      - 玩家位置/颜色同步
##      - 服务器权威: 伤害判定, 得分, 重生
## ============================================================

const PORT := 7777
const MAX_PLAYERS := 16
const TICK_RATE := 20  # 服务器逻辑帧率 (Hz)

const PLAYER_SCENE := preload("res://scenes/player.tscn")

# 所有玩家状态: { peer_id: {name, color, pos, health, score, input} }
var players: Dictionary = {}
var _tick := 0


func _ready() -> void:
	# 允许作为子节点运行, 也可独立运行
	start()


## 启动服务器监听
func start() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		printerr("[Server] 无法绑定端口 ", PORT, " 错误: ", err)
		get_tree().quit(1)
		return
	multiplayer.set_multiplayer_peer(peer)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_relayed.connect(_on_server_relayed)

	# 服务端也需要场景树节点来实例化玩家/子弹 (权威逻辑)
	_ensure_scene_tree()

	# 服务器逻辑循环 (固定步长)
	set_physics_process(true)
	print("[Server] ========== NetShooter Dedicated Server ==========")
	print("[Server] 监听端口: ", PORT, "  最大玩家: ", MAX_PLAYERS)
	print("[Server] 等待客户端连接...")


## 在服务器端构建简易场景树, 供权威逻辑实例化玩家/子弹
func _ensure_scene_tree() -> void:
	var root := get_tree().root
	if not root.has_node("ServerWorld"):
		var world := Node2D.new()
		world.name = "ServerWorld"
		root.add_child(world)
		var players_n := Node2D.new()
		players_n.name = "Players"
		var bullets_n := Node2D.new()
		bullets_n.name = "Bullets"
		world.add_child(players_n)
		world.add_child(bullets_n)


func _players_node() -> Node2D:
	return get_tree().root.get_node_or_null("ServerWorld/Players")


func _bullets_node() -> Node2D:
	return get_tree().root.get_node_or_null("ServerWorld/Bullets")


# ---------- 连接事件 ----------

func _on_peer_connected(peer_id: int) -> void:
	print("[Server] 玩家连接: ", peer_id, " (当前在线: ", players.size() + 1, ")")


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Server] 玩家离开: ", peer_id)
	if players.has(peer_id):
		# 通知其他人该玩家离开
		rpc("despawn_player", peer_id)
		players.erase(peer_id)
		rpc("sync_players", players)


func _on_server_relayed(_peer: int) -> void:
	pass


# ---------- 主逻辑循环 (服务器权威) ----------

func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick < Engine.physics_ticks_per_second / TICK_RATE:
		return
	_tick = 0

	# 服务器模拟: 位置插值/验证、子弹生命周期、判定等
	for pid in players:
		var pdata: Dictionary = players[pid]
		# 可在 pdata 里读取 input 做验证
		pass

	# 每 tick 向所有人广播完整状态 (小游戏够用)
	if players.size() > 0:
		rpc("full_state", players)


# ---------- RPC: 客户端 -> 服务器 ----------

## 客户端注册 (any_peer, 服务器执行)
@rpc("any_peer", "call_local", "reliable")
func register_player(peer_id: int, pname: String) -> void:
	if players.has(peer_id):
		players[peer_id].name = pname
	else:
		players[peer_id] = {
			"name": pname if not pname.is_empty() else ("Player" + str(peer_id)),
			"color": _random_color(),
			"pos": Vector2(randf_range(100, 700), randf_range(100, 500)),
			"health": 100,
			"score": 0,
		}
	print("[Server] 注册玩家 ", peer_id, " = ", players[peer_id].name)
	# 把完整玩家列表同步给所有人
	rpc("sync_players", players)
	# 通知新玩家生成所有现有玩家 (含自己)
	for pid in players:
		rpc_id(peer_id, "spawn_player", pid, players[pid].name, players[pid].color)


## 客户端上报输入 (unreliable 高速)
@rpc("any_peer", "call_local", "unreliable")
func player_input(peer_id: int, input_dir: Vector2, aiming: Vector2, shooting: bool) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["input"] = {"dir": input_dir, "aim": aiming, "fire": shooting}


## 客户端开火 (服务器权威判定)
@rpc("any_peer", "call_local", "reliable")
func player_shoot(peer_id: int, from: Vector2, direction: Vector2) -> void:
	if not players.has(peer_id):
		return
	# 服务器验证后广播 (真实项目在此做射线/碰撞判定)
	rpc("spawn_bullet", peer_id, from, direction)


## 玩家受伤 (服务器权威扣血)
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
		p.pos = Vector2(randf_range(100, 700), randf_range(100, 500))  # 重生
		rpc("player_died", victim_id, attacker_id)
		rpc("sync_players", players)


# ---------- RPC: 服务器 -> 客户端 (authority) ----------

@rpc("authority", "call_local", "reliable")
func sync_players(p: Dictionary) -> void:
	players = p


@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, pname: String, color: Color) -> void:
	pass  # 客户端侧实现见 client_network.gd


@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	pass


@rpc("authority", "call_local", "reliable")
func spawn_bullet(_owner_id: int, _from: Vector2, _dir: Vector2) -> void:
	pass


@rpc("authority", "call_local", "reliable")
func player_died(_victim: int, _attacker: int) -> void:
	pass


@rpc("authority", "call_local", "unreliable")
func full_state(p: Dictionary) -> void:
	players = p


# ---------- 工具 ----------

func _random_color() -> Color:
	return Color(randf(), randf(), randf())
