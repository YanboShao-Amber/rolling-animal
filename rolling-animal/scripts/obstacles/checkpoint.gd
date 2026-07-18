class_name Checkpoint
extends Area2D

## 检查点（母 scene / graybox）。玩家进入即设为当前重生点。
## 属于组 "checkpoints"，RespawnManager 自动收集，无需手动连线。

signal activated(checkpoint: Checkpoint)

## 段序号：越靠后越大。重生只前进不倒退，防止回头走触发旧检查点。
@export var order := 0

## 重生落点：留空则用检查点自身位置。放子节点 RespawnPoint(Marker2D)
## 可把落点摆到安全站立处（别让玩家重生在危险里）。
@onready var respawn_point: Marker2D = get_node_or_null("RespawnPoint")

var _active := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func get_respawn_position() -> Vector2:
	return respawn_point.global_position if respawn_point else global_position


func _on_body_entered(body: Node2D) -> void:
	if _active:
		return
	if body is SoftPlayer:
		_active = true
		modulate = Color(0.4, 1.0, 0.5)  # graybox：激活变绿，肉眼确认用
		activated.emit(self)
