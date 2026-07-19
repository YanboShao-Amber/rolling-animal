extends Node

signal coins_changed(total: int)
signal level_progress_changed(highest_unlocked_level: int)

const TIMED_LEVEL_SCENES := {
	"res://scenes/farm_level_test.tscn": true,
	"res://scenes/level/Minecraft.tscn": true,
	"res://scenes/Factory.tscn": true,
}

var selected_character_data: Variant = null
var selected_character_id := ""
var selected_character_name := ""
var selected_portrait_path := ""
var coin_count := 0
var collected_level_coins: Dictionary = {}
var committed_level_coins: Dictionary = {}  # 经过检查点后"锁定"的金币：死亡重生不退还
var highest_unlocked_level := 1
var completed_levels: Dictionary = {}
var pending_level_number := 1
var pending_level_scene_path := "res://scenes/farm_level_test.tscn"
var _level_start_msec := 0
var _level_elapsed_msec := 0
var _level_timer_running := false
var _level_timer_label: Label


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_on_scene_changed")


func _process(_delta: float) -> void:
	if not _level_timer_running:
		return
	_level_elapsed_msec = Time.get_ticks_msec() - _level_start_msec
	_update_level_timer_label()


func _on_scene_changed(_scene: Node = null) -> void:
	_level_timer_label = null
	var current_scene := get_tree().current_scene
	if current_scene == null or not TIMED_LEVEL_SCENES.has(current_scene.scene_file_path):
		_level_timer_running = false
		return
	_level_start_msec = Time.get_ticks_msec()
	_level_elapsed_msec = 0
	_level_timer_running = false
	_add_level_timer(current_scene)


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
	collected_level_coins[key] = true
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
