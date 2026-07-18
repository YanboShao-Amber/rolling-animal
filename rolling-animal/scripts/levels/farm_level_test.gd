extends Node2D

const TILE_WORLD_SIZE := 54.0
const LEVEL_TILE_COUNT := 150
const WIN_SCENE := preload("res://scenes/ui/win_scene.tscn")
const LOSE_SCENE := preload("res://scenes/ui/lose_scene.tscn")
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"

@export var show_debug_hud := true
@export var camera_look_ahead := 180.0
@export var camera_follow_speed := 5.0
@export var fall_fail_margin := 96.0

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera_rig: Node2D = $CameraRig
@onready var hud: CanvasLayer = $HUD
@onready var current_test_label: Label = $HUD/DebugPanel/Margin/VBox/CurrentTestLabel
@onready var size_label: Label = $HUD/DebugPanel/Margin/VBox/SizeLabel
@onready var target_speed_label: Label = $HUD/DebugPanel/Margin/VBox/TargetSpeedLabel
@onready var actual_speed_label: Label = $HUD/DebugPanel/Margin/VBox/ActualSpeedLabel
@onready var grounded_label: Label = $HUD/DebugPanel/Margin/VBox/GroundedLabel
@onready var growth_label: Label = $HUD/DebugPanel/Margin/VBox/GrowthLabel
@onready var measurement_label: Label = $HUD/DebugPanel/Margin/VBox/MeasurementLabel
@onready var instruction_label: Label = $HUD/InstructionPanel/InstructionLabel
@onready var restart_label: Label = $HUD/RestartLabel
@onready var win_landmark: WinLandmark = $WinLandmark

var current_test := "FREE RUN"
var win_popup: WinPopup
var lose_popup: LosePopup


func _ready() -> void:
	hud.visible = show_debug_hud
	var selected_character: Dictionary = {"portrait_path": "res://assets/player/duck.png"}
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		selected_character = game_state.selected_character_data.duplicate(true)
	player.setup_character(selected_character)
	player.auto_forward_enabled = true
	player.global_position = player_spawn.global_position
	camera_rig.global_position = Vector2(player_spawn.global_position.x + camera_look_ahead, 360.0)
	win_landmark.player_reached.connect(_on_player_reached_win)
	_update_instruction()


func _physics_process(delta: float) -> void:
	var desired_x := player.global_position.x + camera_look_ahead
	desired_x = clampf(desired_x, 640.0, LEVEL_TILE_COUNT * TILE_WORLD_SIZE - 640.0)
	camera_rig.global_position.x = lerpf(
		camera_rig.global_position.x,
		desired_x,
		1.0 - exp(-camera_follow_speed * delta)
	)
	camera_rig.global_position.y = 360.0
	_check_player_fell_out_of_screen()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_test"):
		_restart_test()
		get_viewport().set_input_as_handled()


func _respawn_at(respawn_position: Vector2) -> void:
	player.auto_forward_enabled = false
	player.global_position = respawn_position
	player.reset_size()
	player.reset_motion_visuals()
	player.auto_forward_enabled = true


func _restart_test() -> void:
	current_test = "FREE RUN"
	restart_label.visible = false
	player.set_physics_process(true)
	win_landmark.reset_landmark()
	if is_instance_valid(win_popup):
		win_popup.queue_free()
		win_popup = null
	if is_instance_valid(lose_popup):
		lose_popup.queue_free()
		lose_popup = null
	_respawn_at(player_spawn.global_position)
	camera_rig.global_position = Vector2(player_spawn.global_position.x + camera_look_ahead, 360.0)
	_update_instruction()


func _update_instruction() -> void:
	instruction_label.text = "LEFT CLICK: GROW   STOP: SHRINK   SPACE: JUMP   R: RESTART"


func _update_hud() -> void:
	if not show_debug_hud:
		return
	current_test_label.text = "CURRENT TEST: " + current_test
	size_label.text = "SIZE: %.2f" % player.get_current_size_scale()
	target_speed_label.text = "TARGET SPEED: %.0f" % player.get_target_forward_speed()
	actual_speed_label.text = "ACTUAL SPEED: %.0f" % player.get_current_forward_speed()
	grounded_label.text = "GROUNDED: %s" % str(player.is_on_floor()).to_upper()
	growth_label.text = "GROWTH VELOCITY: %.3f" % player.growth_velocity
	measurement_label.text = "R: RESTART FROM PLAYER SPAWN"


func _on_player_reached_win() -> void:
	if is_instance_valid(win_popup) or is_instance_valid(lose_popup):
		return
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	win_popup = WIN_SCENE.instantiate()
	hud.add_child(win_popup)
	win_popup.closed.connect(_on_win_popup_closed)


func _on_win_popup_closed() -> void:
	if is_instance_valid(win_popup):
		win_popup.queue_free()
		win_popup = null
	player.auto_forward_enabled = true


# The fail line follows the visible viewport bottom, so it also works after resizing.
func _check_player_fell_out_of_screen() -> void:
	if is_instance_valid(win_popup) or is_instance_valid(lose_popup):
		return
	var viewport_half_height := get_viewport_rect().size.y * 0.5
	var fail_y := camera_rig.global_position.y + viewport_half_height + fall_fail_margin
	if player.global_position.y > fail_y:
		_show_lose_popup()


func _show_lose_popup() -> void:
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	lose_popup = LOSE_SCENE.instantiate()
	hud.add_child(lose_popup)
	lose_popup.retry_pressed.connect(_restart_test)
	lose_popup.menu_pressed.connect(_on_lose_menu_pressed)
	lose_popup.closed.connect(_restart_test)


func _on_lose_menu_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
