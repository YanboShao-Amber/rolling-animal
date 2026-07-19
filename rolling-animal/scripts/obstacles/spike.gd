class_name SpikeHazard
extends Area2D

signal player_hit(player: SoftPlayer)
signal player_died(player: SoftPlayer, effect: PackedScene)

@export var death_effect: PackedScene
var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is SoftPlayer):
		return
	_triggered = true
	player_hit.emit(body as SoftPlayer)
	player_died.emit(body as SoftPlayer, death_effect)


func _on_body_exited(body: Node2D) -> void:
	# 玩家被重生传送离开后解锁，允许再次触发（否则同一根刺只杀一次）。
	if body is SoftPlayer:
		_triggered = false
