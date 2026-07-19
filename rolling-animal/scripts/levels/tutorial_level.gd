extends Node2D

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"

@onready var player: SoftPlayer = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D
@onready var completion_label: Label = $HUD/CompletionLabel
@onready var grow_tutorial_area: Area2D = $GrowTutorialArea
@onready var jump_tutorial_area: Area2D = $JumpTutorialArea
@onready var grow_sign: Node2D = $TutorialSigns/GrowSign
@onready var jump_control_sign: Node2D = $TutorialSigns/JumpControlSign

var _completed := false

const SIGN_FLY_IN_DURATION := 2.0
const SIGN_HOLD_DURATION := 3.0
const SIGN_FLY_OUT_DURATION := 1.5


func _ready() -> void:
	var character_data: Dictionary = {"portrait_path": "res://assets/player/penguin.png"}
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		character_data = game_state.selected_character_data.duplicate(true)
	player.setup_character(character_data)
	player.global_position = player_spawn.global_position
	player.auto_forward_enabled = true
	grow_tutorial_area.body_entered.connect(_on_grow_tutorial_entered)
	jump_tutorial_area.body_entered.connect(_on_jump_tutorial_entered)


func _physics_process(delta: float) -> void:
	camera.global_position.x = lerpf(camera.global_position.x, player.global_position.x + 180.0, 1.0 - exp(-6.0 * delta))
	if player.global_position.y > 900.0:
		_respawn()
	if not _completed and player.global_position.x >= 4500.0:
		_completed = true
		player.auto_forward_enabled = false
		completion_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(START_MENU_SCENE)
		get_viewport().set_input_as_handled()


func _respawn() -> void:
	player.auto_forward_enabled = false
	player.global_position = player_spawn.global_position
	player.reset_size()
	player.reset_motion_visuals()
	player.auto_forward_enabled = true


func _on_grow_tutorial_entered(body: Node2D) -> void:
	if body != player:
		return
	grow_tutorial_area.set_deferred("monitoring", false)
	_fly_sign_in_from_right(grow_sign)


func _on_jump_tutorial_entered(body: Node2D) -> void:
	if body != player:
		return
	jump_tutorial_area.set_deferred("monitoring", false)
	_fly_sign_in_from_right(jump_control_sign)


# Plane and banner fly in slowly, pause at center for reading, then leave left.
func _fly_sign_in_from_right(sign: Node2D) -> void:
	var target_position := sign.position
	sign.position = target_position + Vector2(900.0, 0.0)
	sign.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sign, "position", target_position, SIGN_FLY_IN_DURATION)
	tween.tween_interval(SIGN_HOLD_DURATION)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		sign,
		"position",
		target_position - Vector2(900.0, 0.0),
		SIGN_FLY_OUT_DURATION
	)
	tween.tween_callback(func() -> void:
		sign.visible = false
		sign.position = target_position
	)
