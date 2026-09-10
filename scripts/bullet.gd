extends Area2D

## 子弹
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var owner_peer: int = 0
var lifetime: float = 1.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.peer_id != owner_peer:
			body.take_damage(10)
			queue_free()
