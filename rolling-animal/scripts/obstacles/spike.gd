class_name Spike
extends Area2D

## 地刺（母 scene / graybox）：玩家碰到即死。
##
## 主角 SoftPlayer(CharacterBody2D) 本身没有 die()/respawn()，检查点系统也还没做，
## 所以地刺只负责“检测到玩家 -> 广播死亡信号”，不自己处理重生。
## 真正的“传送回检查点 + 重置大小”由关卡脚本接这个信号处理，
## 和 farm_level_test 里 win_landmark.player_reached 由关卡连接是同一套解耦范式。

signal player_died(player: SoftPlayer)

var _killed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	# 碰到即死，和大小无关（大小机制在别的物件上体现）。
	if _killed:
		return
	if body is SoftPlayer:
		_killed = true
		player_died.emit(body)


func _on_body_exited(body: Node2D) -> void:
	# 玩家被重生传送离开尖刺后解锁，允许再次触发。
	if body is SoftPlayer:
		_killed = false
