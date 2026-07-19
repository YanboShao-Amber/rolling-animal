class_name CreamChocoTrap
extends Area2D

signal player_hit(player: SoftPlayer)

@export var active := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if active and body is SoftPlayer:
		player_hit.emit(body as SoftPlayer)

