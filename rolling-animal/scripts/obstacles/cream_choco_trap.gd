class_name CreamChocoTrap
extends Area2D

signal player_hit(player: SoftPlayer)

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is SoftPlayer):
		return
	_triggered = true
	monitoring = false
	player_hit.emit(body as SoftPlayer)
