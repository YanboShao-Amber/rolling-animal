extends Node2D

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"

@onready var player: SoftPlayer = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D
@onready var completion_label: Label = $HUD/CompletionLabel

var _completed := false


func _ready() -> void:
	var character_data: Dictionary = {"portrait_path": "res://assets/player/penguin.png"}
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		character_data = game_state.selected_character_data.duplicate(true)
	player.setup_character(character_data)
	player.global_position = player_spawn.global_position
	player.auto_forward_enabled = true


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
