extends Node
## ============================================================
##  全局游戏状态 (autoload Game)
## ============================================================

const SERVER_HOST := "game.xfan.l.cd"   # 官方服务器地址 (客户端默认填入)
const SERVER_PORT := 7777

var my_peer_id: int = 1
var players: Dictionary = {}
var score: int = 0

# 网络核心节点引用 (main_menu 中挂载的 Network)
var network: Node = null
