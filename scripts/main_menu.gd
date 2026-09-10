extends Control
## ============================================================
##  主菜单 - 双模式并存:
##    1) 联机大厅 : 连接官方服务器 game.xfan.l.cd (或自建穿透地址)
##    2) 创建房间 : 本机当主机, 其他人输入你(或穿透工具)的地址加入
## ------------------------------------------------------------
##  内网穿透说明见 docs/tuowan_nat.md
## ============================================================

@onready var name_edit: LineEdit = $Panel/VBox/NameEdit
@onready var ip_edit: LineEdit = $Panel/VBox/IpEdit
@onready var join_btn: Button = $Panel/VBox/JoinButton
@onready var host_btn: Button = $Panel/VBox/HostButton
@onready var mode_tabs: TabContainer = $Panel/VBox/ModeTabs
@onready var status: Label = $Panel/VBox/Status

const DEFAULT_SERVER := "game.xfan.l.cd"
const PORT := 7777


func _ready() -> void:
	join_btn.pressed.connect(_on_join_server)
	host_btn.pressed.connect(_on_host_room)
	ip_edit.text = DEFAULT_SERVER


# ---------- 模式1: 连接服务器 (官方 / 穿透地址均可) ----------
func _on_join_server() -> void:
	var nm := name_edit.text.strip_edges()
	if nm.is_empty():
		status.text = "请输入名字"; return
	var host := ip_edit.text.strip_edges()
	if host.is_empty():
		host = DEFAULT_SERVER
	status.text = "正在连接 " + host + ":" + str(PORT) + " ..."

	# 复用同一套客户端代码: 无论连官方服务器还是穿透地址, 协议完全一样
	var net := _attach_client()
	net.connect_to(host, PORT, nm)

	# 等待连接结果
	await get_tree().create_timer(4.0).timeout
	if status and not net.connected:
		status.text = "连接失败\n· 确认服务器在线 / 地址正确\n· 若为内网穿透, 检查穿透工具是否连上\n· 端口 UDP %d 是否放行" % PORT


# ---------- 模式2: 本机当主机 (谁开房谁当主机) ----------
func _on_host_room() -> void:
	var nm := name_edit.text.strip_edges()
	if nm.is_empty():
		nm = "Host"
	status.text = "正在创建房间 (本机 = 主机)..."

	# 客户端脚本同时具备 start_server, 一套代码两种角色
	var net := _attach_client()
	net.start_server(nm)
	# start_server 成功后直接进游戏场景


# ---------- 内部 ----------
func _attach_client() -> Node:
	# 复用 client_network.gd (含 client + host 两种角色)
	var script_res := load("res://scripts/client_network.gd")
	var old := get_tree().root.get_node_or_null("Network")
	if old:
		old.queue_free()
	var node := Node.new()
	node.set_script(script_res)
	node.name = "Network"
	get_tree().root.add_child(node)
	Game.network = node
	return node
