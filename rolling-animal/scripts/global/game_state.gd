extends Node

signal coins_changed(total: int)
signal level_progress_changed(highest_unlocked_level: int)

const TIMED_LEVEL_SCENES := {
	"res://scenes/farm_level_test.tscn": true,
	"res://scenes/level/Minecraft.tscn": true,
	"res://scenes/Factory.tscn": true,
}
const MAIN_MENU_SCENE := "res://scenes/ui/start_menu.tscn"

var selected_character_data: Variant = null
var selected_character_id := ""
var selected_character_name := ""
var selected_portrait_path := ""
var coin_count := 0
var collected_level_coins: Dictionary = {}
var committed_level_coins: Dictionary = {}  # 经过检查点后"锁定"的金币：死亡重生不退还
var highest_unlocked_level := 1
var completed_levels: Dictionary = {}
var best_level_times_msec: Dictionary = {}
var pending_level_number := 1
var pending_level_scene_path := "res://scenes/farm_level_test.tscn"
var _level_start_msec := 0
var _level_elapsed_msec := 0
var _level_timer_running := false
var _level_timer_label: Label
var _timed_level_scene_path := ""
var _exit_menu: Control
var _exit_menu_pause_started_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_exit_menu()
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_on_scene_changed")


func _process(_delta: float) -> void:
	if not _level_timer_running or (is_instance_valid(_exit_menu) and _exit_menu.visible):
		return
	_level_elapsed_msec = Time.get_ticks_msec() - _level_start_msec
	_update_level_timer_label()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(_exit_menu) and _exit_menu.visible:
		_close_exit_menu()
	elif _level_timer_running:
		_open_exit_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_scene_changed(_scene: Node = null) -> void:
	if is_instance_valid(_exit_menu):
		_exit_menu.visible = false
	get_tree().paused = false
	_level_timer_label = null
	var current_scene := get_tree().current_scene
	if current_scene == null or not TIMED_LEVEL_SCENES.has(current_scene.scene_file_path):
		_level_timer_running = false
		_timed_level_scene_path = ""
		return
	_timed_level_scene_path = current_scene.scene_file_path
	_level_start_msec = Time.get_ticks_msec()
	_level_elapsed_msec = 0
	_level_timer_running = false
	_add_level_timer(current_scene)


func _build_exit_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)

	_exit_menu = Control.new()
	_exit_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_menu.visible = false
	layer.add_child(_exit_menu)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.62)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_menu.add_child(dimmer)

	var panel := NinePatchRect.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310.0, -165.0)
	panel.size = Vector2(620.0, 330.0)
	panel.texture = load("res://assets/UI/panel_grey_bolts_dark.png") as Texture2D
	panel.patch_margin_left = 28
	panel.patch_margin_top = 28
	panel.patch_margin_right = 28
	panel.patch_margin_bottom = 28
	_exit_menu.add_child(panel)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 48)
	content.add_theme_constant_override("separation", 44)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)

	var question := Label.new()
	question.add_theme_font_override("font", load("res://assets/Fonts/Kenney Future.ttf") as Font)
	question.add_theme_font_size_override("font_size", 27)
	question.text = "RETURN TO MAIN MENU?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(question)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 42)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(button_row)

	var yes_button := _create_exit_button("YES", "res://assets/UI/button_red.png")
	var no_button := _create_exit_button("NO", "res://assets/UI/button_grey.png")
	button_row.add_child(yes_button)
	button_row.add_child(no_button)
	yes_button.pressed.connect(_on_exit_yes_pressed)
	no_button.pressed.connect(_close_exit_menu)


func _create_exit_button(text: String, texture_path: String) -> TextureButton:
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(180.0, 72.0)
	button.texture_normal = load(texture_path) as Texture2D
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", load("res://assets/Fonts/Kenney Future.ttf") as Font)
	label.add_theme_font_size_override("font_size", 23)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	return button


func _open_exit_menu() -> void:
	_exit_menu_pause_started_msec = Time.get_ticks_msec()
	_exit_menu.visible = true
	get_tree().paused = true


func _close_exit_menu() -> void:
	if not is_instance_valid(_exit_menu) or not _exit_menu.visible:
		return
	if _level_timer_running:
		_level_start_msec += Time.get_ticks_msec() - _exit_menu_pause_started_msec
	_exit_menu.visible = false
	get_tree().paused = false


func _on_exit_yes_pressed() -> void:
	_exit_menu.visible = false
	get_tree().paused = false
	get_node("/root/SceneTransition").transition_to(MAIN_MENU_SCENE)


func _add_level_timer(level: Node) -> void:
	var timer_layer := CanvasLayer.new()
	timer_layer.layer = 100
	timer_layer.name = "LevelTimerLayer"
	level.add_child(timer_layer)

	_level_timer_label = Label.new()
	_level_timer_label.name = "LevelTimerLabel"
	_level_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_level_timer_label.offset_top = 18.0
	_level_timer_label.offset_bottom = 58.0
	_level_timer_label.add_theme_font_override(
		"font", load("res://assets/Fonts/Kenney Future.ttf") as Font
	)
	_level_timer_label.add_theme_font_size_override("font_size", 28)
	_level_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_level_timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_level_timer_label.add_theme_constant_override("shadow_offset_x", 2)
	_level_timer_label.add_theme_constant_override("shadow_offset_y", 2)
	_level_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_layer.add_child(_level_timer_label)
	_update_level_timer_label()


func finish_level_timer() -> int:
	if _level_timer_running:
		_level_elapsed_msec = Time.get_ticks_msec() - _level_start_msec
		_level_timer_running = false
		if not _timed_level_scene_path.is_empty():
			var previous_best := int(best_level_times_msec.get(_timed_level_scene_path, 0))
			if previous_best == 0 or _level_elapsed_msec < previous_best:
				best_level_times_msec[_timed_level_scene_path] = _level_elapsed_msec
	_update_level_timer_label()
	return _level_elapsed_msec


func start_level_timer() -> void:
	if not is_instance_valid(_level_timer_label):
		return
	_level_start_msec = Time.get_ticks_msec()
	_level_elapsed_msec = 0
	_level_timer_running = true
	_update_level_timer_label()


func format_level_time(elapsed_msec: int) -> String:
	var minutes := elapsed_msec / 60000
	var seconds := (elapsed_msec / 1000) % 60
	var milliseconds := elapsed_msec % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]


func get_best_level_time(scene_path: String) -> int:
	return int(best_level_times_msec.get(scene_path, 0))


func get_level_coin_count(scene_path: String) -> int:
	var count := 0
	var prefix := scene_path + "::"
	for key in collected_level_coins:
		if str(key).begins_with(prefix):
			count += int(collected_level_coins[key])
	return count


func _update_level_timer_label() -> void:
	if is_instance_valid(_level_timer_label):
		_level_timer_label.text = format_level_time(_level_elapsed_msec)


func set_pending_level(level_number: int, scene_path: String) -> void:
	pending_level_number = level_number
	pending_level_scene_path = scene_path


func get_pending_level_scene_path() -> String:
	return pending_level_scene_path


func complete_level(level_number: int) -> void:
	if level_number < 1 or level_number > 3:
		return
	completed_levels[level_number] = true
	var new_highest: int = mini(level_number + 1, 3)
	if new_highest > highest_unlocked_level:
		highest_unlocked_level = new_highest
		level_progress_changed.emit(highest_unlocked_level)


func is_level_unlocked(level_number: int) -> bool:
	return level_number >= 1 and level_number <= highest_unlocked_level


func is_level_completed(level_number: int) -> bool:
	return completed_levels.has(level_number)


func add_coins(amount: int = 1) -> int:
	coin_count = maxi(coin_count + amount, 0)
	coins_changed.emit(coin_count)
	return coin_count


func collect_level_coin(level_id: String, coin_id: String, amount: int = 1) -> int:
	var key := "%s::%s" % [level_id, coin_id]
	if collected_level_coins.has(key):
		return coin_count
	collected_level_coins[key] = amount
	return add_coins(amount)


func is_level_coin_collected(level_id: String, coin_id: String) -> bool:
	return collected_level_coins.has("%s::%s" % [level_id, coin_id])


## 把某枚已收集的金币"锁定"：玩家经过检查点后调用，之后即使死亡也不退还。
func commit_level_coin(level_id: String, coin_id: String) -> void:
	var key := "%s::%s" % [level_id, coin_id]
	if collected_level_coins.has(key):
		committed_level_coins[key] = true


func is_level_coin_committed(level_id: String, coin_id: String) -> bool:
	return committed_level_coins.has("%s::%s" % [level_id, coin_id])


## 撤销一枚金币的收集（玩家死亡刷新时用）：清掉记录并把计数退回去。
## 已锁定（检查点之前吃到）的金币不退还，保持计数。
func uncollect_level_coin(level_id: String, coin_id: String, amount: int = 1) -> int:
	var key := "%s::%s" % [level_id, coin_id]
	if not collected_level_coins.has(key):
		return coin_count
	if committed_level_coins.has(key):
		return coin_count
	collected_level_coins.erase(key)
	return add_coins(-amount)


func clear_coins() -> void:
	coin_count = 0
	collected_level_coins.clear()
	committed_level_coins.clear()
	coins_changed.emit(coin_count)


func set_selected_character(character_data: Variant) -> void:
	clear_selected_character()
	if character_data is Dictionary:
		selected_character_data = character_data.duplicate(true)
		selected_character_id = str(character_data.get("id", ""))
		selected_character_name = str(character_data.get("display_name", character_data.get("name", "")))
		selected_portrait_path = str(character_data.get("portrait_path", character_data.get("texture_path", "")))
	elif character_data is Resource:
		selected_character_data = character_data
		selected_character_id = str(character_data.get("id"))
		selected_character_name = str(character_data.get("display_name"))
		selected_portrait_path = str(character_data.get("portrait_path"))


func has_selected_character() -> bool:
	return selected_character_data != null and not selected_portrait_path.is_empty()


func clear_selected_character() -> void:
	selected_character_data = null
	selected_character_id = ""
	selected_character_name = ""
	selected_portrait_path = ""
