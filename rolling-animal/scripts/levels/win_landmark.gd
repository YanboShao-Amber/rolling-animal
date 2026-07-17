class_name WinLandmark
extends Node2D

signal player_reached

@export var trigger_once := true

var _has_triggered := false


func _ready() -> void:
	$WinTrigger.body_entered.connect(_on_body_entered)


func reset_landmark() -> void:
	_has_triggered = false
	$WinTrigger.set_deferred("monitoring", true)


func _on_body_entered(body: Node2D) -> void:
	if _has_triggered or not (body is SoftPlayer):
		return
	_has_triggered = true
	if trigger_once:
		$WinTrigger.set_deferred("monitoring", false)
	player_reached.emit()
