extends Node

var selected_character_data: Variant = null
var selected_character_id := ""
var selected_character_name := ""
var selected_portrait_path := ""


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

