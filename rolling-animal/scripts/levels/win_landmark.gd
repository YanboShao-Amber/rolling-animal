class_name WinLandmark
extends Node2D

signal player_reached

@export var trigger_once := true
@export_range(0.05, 1.0, 0.01) var flag_animation_speed := 0.16
@export_range(0.1, 2.0, 0.05) var flag_raise_duration := 0.65

const UPPER_CELL := Vector2i(0, -1)
const LOWER_CELL := Vector2i(0, 0)
const FLAG_RAISED_TILE := Vector2i(11, 6)
const FLAG_FRAME_A := Vector2i(11, 5)
const FLAG_FRAME_B := Vector2i(12, 5)

var _has_triggered := false
var _flag_frame := false

@onready var landmark_layer: TileMapLayer = $LandmarkLayer
@onready var flag_animation_timer: Timer = $FlagAnimationTimer


func _ready() -> void:
	$WinTrigger.body_entered.connect(_on_body_entered)
	flag_animation_timer.timeout.connect(_on_flag_animation_timeout)
	flag_animation_timer.wait_time = flag_animation_speed
	_set_initial_flag_tiles()


func reset_landmark() -> void:
	_has_triggered = false
	_flag_frame = false
	flag_animation_timer.stop()
	_set_initial_flag_tiles()
	$WinTrigger.set_deferred("monitoring", true)


func _on_body_entered(body: Node2D) -> void:
	if _has_triggered or not (body is SoftPlayer):
		return
	_has_triggered = true
	if trigger_once:
		$WinTrigger.set_deferred("monitoring", false)
	_start_flag_raise_animation()
	var player := body as SoftPlayer
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	await get_tree().create_timer(flag_raise_duration).timeout
	if _has_triggered and is_instance_valid(player):
		player_reached.emit()


func _set_initial_flag_tiles() -> void:
	landmark_layer.clear()
	landmark_layer.set_cell(UPPER_CELL, 0, FLAG_RAISED_TILE)
	landmark_layer.set_cell(LOWER_CELL, 0, FLAG_FRAME_A)


func _start_flag_raise_animation() -> void:
	landmark_layer.set_cell(LOWER_CELL, 0, FLAG_RAISED_TILE)
	_flag_frame = false
	landmark_layer.set_cell(UPPER_CELL, 0, FLAG_FRAME_A)
	flag_animation_timer.wait_time = flag_animation_speed
	flag_animation_timer.start()


func _on_flag_animation_timeout() -> void:
	_flag_frame = not _flag_frame
	landmark_layer.set_cell(
		UPPER_CELL,
		0,
		FLAG_FRAME_B if _flag_frame else FLAG_FRAME_A
	)
