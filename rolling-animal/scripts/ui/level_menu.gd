class_name LevelMenu
extends Control

const DARK_PANEL := preload("res://assets/UI/panel_grey_bolts_dark.png")
const SELECTED_PANEL := preload("res://assets/UI/panel_grey_bolts_red.png")
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"
const LEVEL_SCENES := {1: "res://scenes/farm_level_test.tscn", 2: "", 3: ""}

@onready var level_buttons: Array[TextureButton] = [$Content/LevelRow/Level1, $Content/LevelRow/Level2, $Content/LevelRow/Level3]
@onready var message_label: Label = $Content/MessageLabel
@onready var play_button: Button = $Content/ButtonRow/PlayButton
@onready var back_button: Button = $Content/ButtonRow/BackButton

var selected_level := 1


func _ready() -> void:
	for index in level_buttons.size():
		level_buttons[index].pressed.connect(_select_level.bind(index + 1))
	play_button.pressed.connect(_play_selected_level)
	back_button.pressed.connect(_go_back)
	_refresh_menu()
	level_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_select_level(wrapi(selected_level - 2, 0, 3) + 1)
	elif event.is_action_pressed("ui_right"):
		_select_level(selected_level % 3 + 1)
	elif event.is_action_pressed("ui_accept"):
		_play_selected_level()
	elif event.is_action_pressed("ui_cancel"):
		_go_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _select_level(level_number: int) -> void:
	selected_level = clampi(level_number, 1, 3)
	_refresh_menu()
	level_buttons[selected_level - 1].grab_focus()


func _refresh_menu() -> void:
	var game_state := get_node_or_null("/root/GameState")
	for index in level_buttons.size():
		var level_number := index + 1
		var button := level_buttons[index]
		var unlocked := game_state == null or game_state.is_level_unlocked(level_number)
		button.texture_normal = SELECTED_PANEL if level_number == selected_level else DARK_PANEL
		button.self_modulate = Color.WHITE if unlocked else Color(0.48, 0.52, 0.58, 1.0)
		button.get_node("StatusLabel").text = "OPEN" if unlocked else "LOCKED"
	var unlocked := game_state == null or game_state.is_level_unlocked(selected_level)
	play_button.disabled = not unlocked
	if not unlocked:
		message_label.text = "CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1)
	elif LEVEL_SCENES[selected_level].is_empty():
		message_label.text = "LEVEL %d - COMING SOON" % selected_level
	else:
		message_label.text = "FARM LEVEL TEST"


func _play_selected_level() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state and not game_state.is_level_unlocked(selected_level):
		message_label.text = "CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1)
		return
	var scene_path: String = LEVEL_SCENES[selected_level]
	if scene_path.is_empty():
		message_label.text = "LEVEL %d - COMING SOON" % selected_level
		return
	get_tree().change_scene_to_file(scene_path)


func _go_back() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
