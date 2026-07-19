class_name SpikeHazard
extends Area2D

signal player_hit(player: SoftPlayer)
signal player_died(player: SoftPlayer, effect: PackedScene)

@export var death_effect: PackedScene
var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is SoftPlayer):
		return
	_triggered = true
	player_hit.emit(body as SoftPlayer)
	player_died.emit(body as SoftPlayer, death_effect)
