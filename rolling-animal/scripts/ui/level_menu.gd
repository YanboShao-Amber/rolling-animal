class_name LevelMenu
extends Control

const DARK_PANEL := preload("res://assets/UI/panel_grey_bolts_dark.png")
const SELECTED_PANEL := preload("res://assets/UI/panel_grey_bolts_red.png")
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"
const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const LEVEL_SCENES := {
	1: "res://scenes/farm_level_test.tscn",
	2: "",
	3: "",
}

@onready var level_buttons: Array[TextureButton] = [
	$Content/LevelRow/Level1,
	$Content/LevelRow/Level2,
	$Content/LevelRow/Level3,
]
@onready var message_label: Label = $Content/MessageLabel

var selected_level := 1


func _ready() -> void:
	for index in level_buttons.size():
		level_buttons[index].pressed.connect(_on_level_clicked.bind(index + 1))
	_refresh_menu()
	level_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_select_level(wrapi(selected_level - 2, 0, 3) + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select_level(selected_level % 3 + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_play_selected_level()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _select_level(level_number: int) -> void:
	selected_level = clampi(level_number, 1, 3)
	_refresh_menu()
	level_buttons[selected_level - 1].grab_focus()


func _on_level_clicked(level_number: int) -> void:
	_select_level(level_number)
	_play_selected_level()


func _refresh_menu() -> void:
	for index in level_buttons.size():
		var level_number := index + 1
		var button := level_buttons[index]
		var unlocked := _is_level_unlocked(level_number)
		button.texture_normal = SELECTED_PANEL if level_number == selected_level else DARK_PANEL
		button.self_modulate = Color.WHITE if unlocked else Color(0.48, 0.52, 0.58, 1.0)
		button.get_node("StatusLabel").text = "OPEN" if unlocked else "LOCKED"

	var unlocked := _is_level_unlocked(selected_level)
	if not unlocked:
		message_label.text = "CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1)
	elif LEVEL_SCENES[selected_level].is_empty():
		message_label.text = "LEVEL %d — COMING SOON" % selected_level
	else:
		message_label.text = "FARM LEVEL TEST"


func _play_selected_level() -> void:
	if not _is_level_unlocked(selected_level):
		message_label.text = "CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1)
		return
	var scene_path: String = LEVEL_SCENES[selected_level]
	if scene_path.is_empty():
		message_label.text = "LEVEL %d — COMING SOON" % selected_level
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.call("set_pending_level", selected_level, scene_path)
	get_node("/root/SceneTransition").transition_to(CHARACTER_SELECT_SCENE)


func _is_level_unlocked(level_number: int) -> bool:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return level_number == 1
	return bool(game_state.call("is_level_unlocked", level_number))


func _go_back() -> void:
	get_node("/root/SceneTransition").transition_to(START_MENU_SCENE)
