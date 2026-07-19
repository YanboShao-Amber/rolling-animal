extends Node

signal coins_changed(total: int)

var selected_character_data: Variant = null
var selected_character_id := ""
var selected_character_name := ""
var selected_portrait_path := ""
var coin_count := 0
var collected_level_coins: Dictionary = {}


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
