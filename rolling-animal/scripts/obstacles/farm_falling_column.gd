class_name FarmFallingColumn
extends StaticBody2D

signal knocked_down(player: SoftPlayer)
signal player_stunned(player: SoftPlayer)

const STUN_EFFECT := preload("res://scenes/effects/StunEffect.tscn")

@export_range(0.4, 1.45, 0.01) var knockdown_size_threshold := 1.1
@export_range(0.1, 1.5, 0.05) var fall_duration := 0.45

@onready var detection_area: Area2D = $DetectionArea
@onready var solid_shape: CollisionShape2D = $CollisionShape2D

var _fallen := false
var _stunning := false
var _fall_tween: Tween


func _ready() -> void:
	add_to_group("resettable")
	add_to_group("stun_fail_obstacles")
	detection_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fallen or not (body is SoftPlayer):
		return
	var player := body as SoftPlayer
	if player.get_current_size_scale() >= knockdown_size_threshold:
		_knock_down(player)
	else:
		_stun_player(player)


func _knock_down(player: SoftPlayer) -> void:
	_fallen = true
	_stunning = false
	detection_area.set_deferred("monitoring", false)
	solid_shape.set_deferred("disabled", true)
	if _fall_tween and _fall_tween.is_valid():
		_fall_tween.kill()
	_fall_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_fall_tween.tween_property(self, "rotation", PI * 0.5, fall_duration)
	await _fall_tween.finished
	if is_inside_tree() and _fallen:
		solid_shape.set_deferred("disabled", false)
		knocked_down.emit(player)


func _stun_player(player: SoftPlayer) -> void:
	if _stunning:
		return
	_stunning = true
	var resume_auto_forward := player.auto_forward_enabled
	player.auto_forward_enabled = false
	player.velocity.x = 0.0
	var effect := STUN_EFFECT.instantiate() as StunEffect
	player.add_child(effect)
	var radius := SoftPlayer.BASE_RADIUS * player.get_current_size_scale()
	effect.position = Vector2(0.0, -radius * 2.0 - 16.0)
	player_stunned.emit(player)
	await effect.finished
	if is_instance_valid(player) and not _fallen:
		player.auto_forward_enabled = resume_auto_forward
	_stunning = false


func reset_state() -> void:
	if _fall_tween and _fall_tween.is_valid():
		_fall_tween.kill()
	_fallen = false
	_stunning = false
	rotation = 0.0
	visible = true
	detection_area.set_deferred("monitoring", true)
	solid_shape.set_deferred("disabled", false)
