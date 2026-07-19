extends Node2D

const TILE_WORLD_SIZE := 54.0
const LEVEL_TILE_COUNT := 150
const CAMERA_Y := 468.0
const WIN_SCENE := preload("res://scenes/ui/win_scene.tscn")
const LOSE_SCENE := preload("res://scenes/ui/lose_scene.tscn")
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"
const LEVEL_MENU_SCENE := "res://scenes/ui/level_menu.tscn"

@export var show_debug_hud := false
@export var camera_look_ahead := 180.0
@export var camera_follow_speed := 5.0
@export var camera_vertical_offset := 126.0
@export var fall_fail_margin := 96.0

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera_rig: Node2D = $CameraRig
@onready var camera: Camera2D = $CameraRig/Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var coin_count_label: Label = $HUD/CoinCounter/CoinCountLabel
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
var _trap_hit_in_progress := false
var _current_respawn_position := Vector2.ZERO
var _current_checkpoint_order := -1


func _ready() -> void:
	hud.visible = true
	$HUD/DebugPanel.visible = false
	$HUD/InstructionPanel.visible = false
	var selected_character: Dictionary = {"portrait_path": "res://assets/player/duck.png"}
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.coins_changed.connect(_update_coin_hud)
		_update_coin_hud(game_state.coin_count)
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		selected_character = game_state.selected_character_data.duplicate(true)
	player.setup_character(selected_character)
	player.auto_forward_enabled = true
	_current_respawn_position = player_spawn.global_position
	player.global_position = player_spawn.global_position
	camera.enabled = true
	camera.make_current()
	camera_rig.global_position = Vector2(player_spawn.global_position.x + camera_look_ahead, CAMERA_Y)
	win_landmark.player_reached.connect(_on_player_reached_win)
	_connect_traps()
	call_deferred("_connect_checkpoints")
	_update_instruction()


func _update_coin_hud(total: int) -> void:
	coin_count_label.text = "× %d" % total


func _physics_process(delta: float) -> void:
	var desired_x := player.global_position.x + camera_look_ahead
	camera_rig.global_position.x = lerpf(
		camera_rig.global_position.x,
		desired_x,
		1.0 - exp(-camera_follow_speed * delta)
	)
	# Follow upward motion and raised platforms, but never chase a falling
	# player downward; the latter keeps the out-of-screen lose rule valid.
	var desired_y := minf(CAMERA_Y, player.global_position.y - camera_vertical_offset)
	camera_rig.global_position.y = lerpf(
		camera_rig.global_position.y,
		desired_y,
		1.0 - exp(-camera_follow_speed * delta)
	)
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
	_trap_hit_in_progress = false
	restart_label.visible = false
	player.set_physics_process(true)
	win_landmark.reset_landmark()
	if is_instance_valid(win_popup):
		win_popup.queue_free()
		win_popup = null
	if is_instance_valid(lose_popup):
		lose_popup.queue_free()
		lose_popup = null
	get_tree().call_group("resettable", "reset_state")
	_respawn_at(_current_respawn_position)
	camera_rig.global_position = Vector2(_current_respawn_position.x + camera_look_ahead, CAMERA_Y)
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
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.complete_level(1)
	win_popup = WIN_SCENE.instantiate()
	hud.add_child(win_popup)
	win_popup.closed.connect(_on_win_popup_closed)
	win_popup.left_button_pressed.connect(_on_win_menu_requested)
	win_popup.right_button_pressed.connect(_on_win_menu_requested)


func _on_win_menu_requested() -> void:
	get_tree().change_scene_to_file(LEVEL_MENU_SCENE)


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
	if is_instance_valid(win_popup) or is_instance_valid(lose_popup):
		return
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	lose_popup = LOSE_SCENE.instantiate()
	hud.add_child(lose_popup)
	lose_popup.retry_pressed.connect(_restart_test)
	lose_popup.menu_pressed.connect(_on_lose_menu_pressed)
	lose_popup.closed.connect(_restart_test)


func _connect_traps() -> void:
	for hazard in get_tree().get_nodes_in_group("hazards"):
		if hazard.has_signal("player_hit") and not hazard.player_hit.is_connected(_on_trap_player_hit):
			hazard.player_hit.connect(_on_trap_player_hit)
	for obstacle in get_tree().get_nodes_in_group("stun_fail_obstacles"):
		if obstacle.has_signal("player_stunned") \
				and not obstacle.player_stunned.is_connected(_on_stun_obstacle_player_hit):
			obstacle.player_stunned.connect(_on_stun_obstacle_player_hit)


func _connect_checkpoints() -> void:
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		if checkpoint.has_signal("activated") \
				and not checkpoint.activated.is_connected(_on_checkpoint_activated):
			checkpoint.activated.connect(_on_checkpoint_activated)


func _on_checkpoint_activated(checkpoint: Checkpoint) -> void:
	if checkpoint.order < _current_checkpoint_order:
		return
	_current_checkpoint_order = checkpoint.order
	_current_respawn_position = checkpoint.get_respawn_position()


func _on_stun_obstacle_player_hit(hit_player: SoftPlayer) -> void:
	_on_trap_player_hit(hit_player)


func _on_trap_player_hit(hit_player: SoftPlayer) -> void:
	if hit_player != player or _trap_hit_in_progress \
			or is_instance_valid(win_popup) or is_instance_valid(lose_popup):
		return
	_trap_hit_in_progress = true
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	player.play_damage_flash()
	await get_tree().create_timer(0.16).timeout
	_show_lose_popup()


func _on_lose_menu_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_MENU_SCENE)
