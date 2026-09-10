extends CharacterBody2D

## 玩家: 移动 / 瞄准 / 射击 / 同步

var peer_id: int = 1
var speed: float = 260.0
var health: int = 100
var color: Color = Color.WHITE

# 网络插值: 其他玩家/权威状态的目标位置
var _net_target_pos: Vector2 = Vector2.ZERO
var _net_pos_dirty: bool = false

@onready var sprite: Node2D = $Sprite
@onready var label: Label = $Label
@onready var shoot_timer: Timer = $ShootTimer

const BULLET_SCENE := preload("res://scenes/bullet.tscn")


func _ready() -> void:
	$ColorRect.color = color
	label.text = name
	if peer_id != multiplayer.get_unique_id():
		# 不是本地玩家: 由网络驱动, 不走输入
		set_physics_process(false)


func set_color(c: Color) -> void:
	color = c
	if has_node("ColorRect"):
		$ColorRect.color = c


## 服务器权威状态: 设置目标位置 (客户端插值用)
func set_net_position(pos: Vector2) -> void:
	_net_target_pos = pos
	_net_pos_dirty = true


func _process(_delta: float) -> void:
	# 非本地玩家: 向权威位置插值, 平滑移动
	if peer_id != multiplayer.get_unique_id() and _net_pos_dirty:
		global_position = global_position.lerp(_net_target_pos, 0.3)
		if global_position.distance_to(_net_target_pos) < 2.0:
			_net_pos_dirty = false


func _physics_process(_delta: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	# 本地玩家输入
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input.y -= 1
	if Input.is_action_pressed("move_down"):
		input.y += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
	if Input.is_action_pressed("move_right"):
		input.x += 1
	if input.length() > 0:
		input = input.normalized()
	velocity = input * speed
	move_and_slide()

	# 瞄准: 面向鼠标
	var mouse := get_global_mouse_position()
	look_at(mouse)

	# 射击
	if Input.is_action_pressed("fire") and shoot_timer.is_stopped():
		_shoot(mouse)
		shoot_timer.start(0.15)

	# 同步位置到其他人
	if multiplayer.has_multiplayer_peer():
		rpc("sync_state", global_position, rotation, health)


func _shoot(target: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	b.global_position = global_position
	b.direction = (target - global_position).normalized()
	b.owner_peer = peer_id
	get_parent().add_child(b)
	# 通知其他人生成子弹
	if multiplayer.has_multiplayer_peer():
		rpc("spawn_bullet", global_position, b.direction, peer_id)


@rpc("authority", "call_local", "unreliable")
func sync_state(pos: Vector2, rot: float, hp: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		global_position = pos
		rotation = rot
		health = hp


@rpc("any_peer", "call_local", "reliable")
func spawn_bullet(pos: Vector2, dir: Vector2, owner_id: int) -> void:
	var b := BULLET_SCENE.instantiate()
	b.global_position = pos
	b.direction = dir
	b.owner_peer = owner_id
	get_tree().current_scene.get_node("Bullets").add_child(b)


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	health = 100
	global_position = Vector2(randf_range(100, 1100), randf_range(100, 600))
	position = global_position
	rpc("sync_state", global_position, rotation, health)
