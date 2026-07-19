class_name CharacterAvatar
extends Control

@onready var portrait: TextureRect = $Portrait

var character_data: Dictionary = {}
var carousel_slot := 0


func setup(data: Dictionary) -> void:
	character_data = data
	portrait.texture = load(data["portrait_path"])
	tooltip_text = data["display_name"]


func set_selected(is_selected: bool, immediate := false) -> void:
	var target_alpha := 1.0 if is_selected else 0.76
	if immediate:
		modulate.a = target_alpha
		return
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(self, "modulate:a", target_alpha, 0.3)
