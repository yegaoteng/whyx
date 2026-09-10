extends Node
## ============================================================
##  NetShooter - 网络核心 (一脚本承担两种角色)
## ------------------------------------------------------------
##  角色 A - 客户端:
##      connect_to(host, port, name)
##      连接官方服务器 game.xfan.l.cd, 或任意内网穿透地址
##      (frp / ngrok / 花生壳 / Tailscale 等, 协议不变, 只需 TCP+UDP 穿透)
##
##  角色 B - 主机 (谁开房谁当主机):
##      start_server(name)  -> 本机监听 -> 其他玩家 connect_to(你的地址)
##
##  ★ 服务器权威判定 (伤害/得分) 在 server 端 server_network.gd 中,
##    本脚本只负责: 建连 / 注册 / 输入上报 / 状态渲染.
## ============================================================

const PORT := 7777
const DEFAULT_HOST := "game.xfan.l.cd"

const PLAYER_SCENE := preload("res://scenes/player.tscn")

# ---------- 状态 ----------
var players: Dictionary = {}
var my_name: String = "Player"
var connected: bool = false
var is_host: bool = false          # 本机是否为主机
var my_peer_id: int = 1

# 主机模式下的本地"服务器逻辑"引用 (由 server_network.gd 驱动)
var _server_logic: Node = null

@onready var players_node: Node = $"/root/Game/Players"


# ============================================================
#  角色 A: 连接服务器
# ============================================================
func connect_to(host: String, port: int = PORT, player_name: String = "") -> void:
	my_name = player_name if not player_name.is_empty() else my_name
	if host.strip_edges().is_empty():
		host = DEFAULT_HOST

	var peer := ENetMultiplayerPeer.new()
	# ENet 同时支持 ipv4 / 域名, 穿透工具给的地址(如 xxx.frp.io)直接填
	var err := peer.create_client(host, port)
	if err != OK:
		printerr("[Net] 创建连接失败: ", err)
		return
	multiplayer.set_multiplayer_peer(peer)
	connected = true
	print("[Net] 正在连接 ", host, ":", port)


# ============================================================
#  角色 B: 本机当主机 (谁开房谁当主机, 无需官方服务器)
# ============================================================
func start_server(player_name: String = "") -> void:
	my_name = player_name if not player_name.is_empty() else my_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 8)
	if err != OK:
		printerr("[Net] 主机启动失败(端口被占用?): ", err)
		return
	multiplayer.set_multiplayer_peer(peer)
	is_host = true
	my_peer_id = 1
	Game.my_peer_id = 1
	print("[Net] 本机已成为主机, 端口 ", PORT)

	# 挂载主机权威逻辑 (同一份 server_network.gd, 与独立服务端完全一致)
	_attach_server_logic()

	# 主机自己也作为一个玩家加入
	players[1] = {"name": my_name, "color": _random_color(), "pos": Vector2(400, 300), "health": 100, "score": 0}
	Game.players = players
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _attach_server_logic() -> void:
	if _server_logic and is_instance_valid(_server_logic):
		return
	var script_res := load("res://scripts/server_network.gd")
	var node := Node.new()
	node.set_script(script_res)
	node.name = "ServerLogic"
	get_tree().root.add_child(node)
	_server_logic = node
	# 让服务器逻辑立即开始监听
	if node.has_method("start"):
		node.start()


# ============================================================
#  连接回调
# ============================================================
func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.peer_connected.connect(_on_peer_joined)
	multiplayer.peer_disconnected.connect(_on_peer_left)


func _on_connected() -> void:
	my_peer_id = multiplayer.get_unique_id()
	Game.my_peer_id = my_peer_id
	print("[Net] 已连接, peer_id=", my_peer_id)
	rpc_id(1, "register_player", my_peer_id, my_name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_failed() -> void:
	connected = false
	printerr("[Net] 连接失败 (地址/端口/防火墙/穿透通道)")


func _on_peer_joined(peer_id: int) -> void:
	print("[Net] 玩家加入: ", peer_id)


func _on_peer_left(peer_id: int) -> void:
	print("[Net] 玩家离开: ", peer_id)
	if is_host and _server_logic and _server_logic.has_method("_on_peer_disconnected"):
		_server_logic._on_peer_disconnected(peer_id)


# ============================================================
#  服务器 -> 客户端 RPC (authority)
# ============================================================
@rpc("authority", "call_local", "reliable")
func sync_players(p: Dictionary) -> void:
	players = p
	if Game:
		Game.players = p
	_refresh_players()


@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, pname: String, color: Color) -> void:
	if not players_node:
		players_node = get_tree().current_scene.get_node_or_null("Players")
	if not players_node:
		return
	if players_node.has_node(str(peer_id)):
		return
	var inst := PLAYER_SCENE.instantiate()
	inst.name = str(peer_id)
	inst.peer_id = peer_id
	if inst.has_method("set_color"):
		inst.set_color(color)
	players_node.add_child(inst)
	if not players.has(peer_id):
		players[peer_id] = {"name": pname, "color": color}


@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	if players_node and players_node.has_node(str(peer_id)):
		players_node.get_node(str(peer_id)).queue_free()
	players.erase(peer_id)


@rpc("authority", "call_local", "reliable")
func spawn_bullet(owner_id: int, from: Vector2, dir: Vector2) -> void:
	if not players_node:
		players_node = get_tree().current_scene.get_node_or_null("Players")
	if not players_node:
		return
	var b := preload("res://scenes/bullet.tscn").instantiate()
	b.global_position = from
	if b.has_method("setup"):
		b.setup(dir, owner_id)
	players_node.add_child(b)


@rpc("authority", "call_local", "reliable")
func player_died(victim: int, attacker: int) -> void:
	print("[Net] ", victim, " 被 ", attacker, " 击杀")


@rpc("authority", "call_local", "unreliable")
func full_state(p: Dictionary) -> void:
	players = p
	_refresh_players()


# ============================================================
#  客户端 -> 服务器 输入上报
# ============================================================
func send_input(dir: Vector2, aim: Vector2, fire: bool) -> void:
	if not _is_online():
		return
	rpc_id(1, "player_input", my_peer_id, dir, aim, fire)


func send_shoot(from: Vector2, dir: Vector2) -> void:
	if not _is_online():
		return
	rpc_id(1, "player_shoot", my_peer_id, from, dir)


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() != 0


# ============================================================
#  本地
# ============================================================
func _refresh_players() -> void:
	if not players_node:
		players_node = get_tree().current_scene.get_node_or_null("Players")
	if not players_node:
		return
	for pid in players:
		var data: Dictionary = players[pid]
		var node: Node = players_node.get_node_or_null(str(pid))
		if not node:
			call_deferred("spawn_player", pid, data.get("name", str(pid)), data.get("color", Color.WHITE))


func _random_color() -> Color:
	return Color(randf(), randf(), randf())
