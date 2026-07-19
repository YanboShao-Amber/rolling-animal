class_name LevelMenu
extends Control

const DARK_PANEL := preload("res://assets/UI/panel_grey_bolts_dark.png")
const SELECTED_PANEL := preload("res://assets/UI/panel_grey_bolts_red.png")
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"
const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const LEVEL_SCENES := {
	1: "res://scenes/farm_level_test.tscn",
	2: "res://scenes/level/Minecraft.tscn",
	3: "res://scenes/Factory.tscn",
}

@onready var level_buttons: Array[TextureButton] = [
	find_child("Level1", true, false) as TextureButton,
	find_child("Level2", true, false) as TextureButton,
	find_child("Level3", true, false) as TextureButton,
]
@onready var message_label: Label = find_child("MessageLabel", true, false) as Label

var selected_level := 1


func _ready() -> void:
	for index in level_buttons.size():
		if is_instance_valid(level_buttons[index]):
			level_buttons[index].pressed.connect(_on_level_clicked.bind(index + 1))
	_refresh_menu()
	if is_instance_valid(level_buttons[0]):
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
	if is_instance_valid(level_buttons[selected_level - 1]):
		level_buttons[selected_level - 1].grab_focus()


func _on_level_clicked(level_number: int) -> void:
	_select_level(level_number)
	_play_selected_level()


func _refresh_menu() -> void:
	for index in level_buttons.size():
		var level_number := index + 1
		var button := level_buttons[index]
		if not is_instance_valid(button):
			continue
		var unlocked := _is_level_unlocked(level_number)
		button.texture_normal = SELECTED_PANEL if level_number == selected_level else DARK_PANEL
		button.self_modulate = Color.WHITE if unlocked else Color(0.48, 0.52, 0.58, 1.0)
		button.get_node("StatusLabel").text = "OPEN" if unlocked else "LOCKED"
		var scene_path: String = LEVEL_SCENES[level_number]
		var column := button.get_parent()
		var coin_count := 0
		var best_time := 0
		var game_state := get_node_or_null("/root/GameState")
		if game_state:
			coin_count = game_state.get_level_coin_count(scene_path)
			best_time = game_state.get_best_level_time(scene_path)
		var coin_count_label := column.get_node_or_null("CoinRow/CoinCount") as Label
		var best_time_label := column.get_node_or_null("BestTime") as Label
		if is_instance_valid(coin_count_label):
			coin_count_label.text = "%d/20" % mini(coin_count, 20)
		if is_instance_valid(best_time_label):
			best_time_label.text = (
				game_state.format_level_time(best_time) if best_time > 0 else "--:--.---"
			)

	var unlocked := _is_level_unlocked(selected_level)
	if not unlocked:
		_set_message("CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1))
	elif LEVEL_SCENES[selected_level].is_empty():
		_set_message("LEVEL %d — COMING SOON" % selected_level)
	else:
		_set_message("FARM LEVEL TEST")


func _play_selected_level() -> void:
	if not _is_level_unlocked(selected_level):
		_set_message("CLEAR LEVEL %d TO UNLOCK" % (selected_level - 1))
		return
	var scene_path: String = LEVEL_SCENES[selected_level]
	if scene_path.is_empty():
		_set_message("LEVEL %d — COMING SOON" % selected_level)
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


func _set_message(value: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = value


func _go_back() -> void:
	get_node("/root/SceneTransition").transition_to(START_MENU_SCENE)
