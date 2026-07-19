class_name SizeJumper
extends StaticBody2D

signal player_bounced(player: SoftPlayer, upward_speed: float)
signal player_rejected(player: SoftPlayer)

@export_range(0.4, 1.45, 0.01) var minimum_bounce_size := 0.8
@export_range(100.0, 3000.0, 10.0) var medium_bounce_speed := 1500.0
@export_range(100.0, 3500.0, 10.0) var maximum_bounce_speed := 2250.0
@export_range(0.03, 0.5, 0.01) var compression_duration := 0.08

@onready var detection_area: Area2D = $DetectionArea
@onready var spring_out: Sprite2D = $SpringOut
@onready var spring_in: Sprite2D = $SpringIn

var _contact_locked := false


func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _contact_locked or not (body is SoftPlayer):
		return
	var player := body as SoftPlayer
	if player.velocity.y < 0.0:
		return
	_contact_locked = true
	if player.get_current_size_scale() <= minimum_bounce_size:
		player_rejected.emit(player)
		return

	var size_weight := inverse_lerp(
		minimum_bounce_size,
		player.maximum_size_scale,
		player.get_current_size_scale()
	)
	var upward_speed := lerpf(
		medium_bounce_speed,
		maximum_bounce_speed,
		clampf(size_weight, 0.0, 1.0)
	)
	_play_compression()
	player.apply_external_bounce(upward_speed)
	player_bounced.emit(player, upward_speed)


func _on_body_exited(body: Node2D) -> void:
	if body is SoftPlayer:
		_contact_locked = false


func _play_compression() -> void:
	spring_out.visible = false
	spring_in.visible = true
	await get_tree().create_timer(compression_duration).timeout
	if is_inside_tree():
		spring_in.visible = false
		spring_out.visible = true
