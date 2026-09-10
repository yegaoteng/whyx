extends Node2D

## 游戏场景: 生成玩家, 处理得分/结束


func _ready() -> void:
	# 服务器负责为每个已连接的玩家(包括自己)生成角色
	if Network.is_server:
		for pid in Network.players:
			Network.spawn_player(pid, Network.players[pid].name, Network.players[pid].color)
	_update_score()


func _update_score() -> void:
	if has_node("HUD/ScoreLabel"):
		$HUD/ScoreLabel.text = "得分: %d" % Game.score


func _process(_delta: float) -> void:
	_update_score()
