extends Node

signal coins_changed(total: int)
signal level_progress_changed(highest_unlocked_level: int)

var selected_character_data: Variant = null
var selected_character_id := ""
var selected_character_name := ""
var selected_portrait_path := ""
var coin_count := 0
var collected_level_coins: Dictionary = {}
var highest_unlocked_level := 1
var completed_levels: Dictionary = {}
var pending_level_number := 1
var pending_level_scene_path := "res://scenes/farm_level_test.tscn"


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


## 撤销一枚金币的收集（玩家死亡刷新时用）：清掉记录并把计数退回去。
func uncollect_level_coin(level_id: String, coin_id: String, amount: int = 1) -> int:
	var key := "%s::%s" % [level_id, coin_id]
	if not collected_level_coins.has(key):
		return coin_count
	collected_level_coins.erase(key)
	return add_coins(-amount)


func clear_coins() -> void:
	coin_count = 0
	collected_level_coins.clear()
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
