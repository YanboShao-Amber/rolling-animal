class_name WinLandmark
extends Node2D

signal player_reached

@export var trigger_once := true

@onready var landmark_layer: TileMapLayer = $LandmarkLayer

var _has_triggered := false


func _ready() -> void:
	$WinTrigger.body_entered.connect(_on_body_entered)
	_set_lowered_flag()


func reset_landmark() -> void:
	_has_triggered = false
	$WinTrigger.set_deferred("monitoring", true)
	_set_lowered_flag()


func _on_body_entered(body: Node2D) -> void:
	if _has_triggered or not (body is SoftPlayer):
		return
	_has_triggered = true
	if trigger_once:
		$WinTrigger.set_deferred("monitoring", false)
	await _raise_flag()
	player_reached.emit()


func _set_lowered_flag() -> void:
	landmark_layer.clear()
	landmark_layer.set_cell(Vector2i(0, -1), 0, Vector2i(11, 6), 0)
	landmark_layer.set_cell(Vector2i(0, 0), 0, Vector2i(11, 5), 0)


func _raise_flag() -> void:
	landmark_layer.set_cell(Vector2i(0, 0), 0, Vector2i(11, 6), 0)
	for frame in 6:
		var atlas := Vector2i(11, 5) if frame % 2 == 0 else Vector2i(12, 5)
		landmark_layer.set_cell(Vector2i(0, -1), 0, atlas, 0)
		await get_tree().create_timer(0.12).timeout
	landmark_layer.set_cell(Vector2i(0, -1), 0, Vector2i(11, 5), 0)
