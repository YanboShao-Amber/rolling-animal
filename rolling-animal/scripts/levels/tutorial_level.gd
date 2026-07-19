extends Node2D

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const LEVEL_ONE_SCENE := "res://scenes/farm_level_test.tscn"

@onready var player: SoftPlayer = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D
@onready var completion_label: Label = $HUD/CompletionLabel
@onready var start_level_button: TextureButton = $HUD/StartLevelButton
@onready var grow_tutorial_area: Area2D = $GrowTutorialArea
@onready var jump_tutorial_area: Area2D = $JumpTutorialArea
@onready var grow_sign: Node2D = $Camera2D/TutorialSigns/GrowSign
@onready var jump_control_sign: Node2D = $Camera2D/TutorialSigns/JumpControlSign
@onready var win_landmark: WinLandmark = $WinLandmark

var _completed := false
var _active_sign_tweens: Dictionary = {}

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
	player.auto_forward_enabled = false
	grow_tutorial_area.body_entered.connect(_on_grow_tutorial_entered)
	jump_tutorial_area.body_entered.connect(_on_jump_tutorial_entered)
	win_landmark.player_reached.connect(_on_player_reached_win_landmark)
	start_level_button.pressed.connect(_on_start_level_button_pressed)
	player.jumped.connect(_on_player_jumped)
	_start_after_countdown()


func _start_after_countdown() -> void:
	var transition := get_node("/root/SceneTransition")
	await transition.wait_until_transition_finished()
	await transition.play_countdown()
	if is_instance_valid(player) and not _completed:
		player.auto_forward_enabled = true


func _physics_process(delta: float) -> void:
	camera.global_position.x = lerpf(camera.global_position.x, player.global_position.x + 180.0, 1.0 - exp(-6.0 * delta))
	if player.global_position.y > 900.0:
		_respawn()


func _unhandled_input(event: InputEvent) -> void:
	if _completed and event.is_action_pressed("ui_cancel"):
		get_node("/root/SceneTransition").transition_to(START_MENU_SCENE)
		get_viewport().set_input_as_handled()


func _on_player_reached_win_landmark() -> void:
	if _completed:
		return
	_completed = true
	player.auto_forward_enabled = false
	completion_label.visible = true
	start_level_button.visible = true
	start_level_button.grab_focus()


func _on_start_level_button_pressed() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_pending_level"):
		game_state.set_pending_level(1, LEVEL_ONE_SCENE)
	get_node("/root/SceneTransition").transition_to(LEVEL_ONE_SCENE)


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


func _on_player_jumped() -> void:
	# A successful jump proves the instruction was understood; clear the prompt
	# immediately so it cannot cover the three-jump section.
	if jump_control_sign.visible:
		_dismiss_sign(jump_control_sign)


# Plane and banner fly in slowly, pause at center for reading, then leave left.
func _fly_sign_in_from_right(sign: Node2D) -> void:
	var target_position := sign.position
	sign.set_meta("rest_position", target_position)
	sign.position = target_position + Vector2(900.0, 0.0)
	sign.visible = true
	var tween := create_tween()
	_active_sign_tweens[sign] = tween
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
		_active_sign_tweens.erase(sign)
	)


func _dismiss_sign(sign: Node2D) -> void:
	var active_tween: Tween = _active_sign_tweens.get(sign) as Tween
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	_active_sign_tweens.erase(sign)
	var rest_position: Vector2 = sign.get_meta("rest_position", sign.position)
	var dismiss_tween := create_tween()
	dismiss_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dismiss_tween.tween_property(
		sign,
		"position",
		sign.position - Vector2(900.0, 0.0),
		0.35
	)
	dismiss_tween.tween_callback(func() -> void:
		sign.visible = false
		sign.position = rest_position
	)
