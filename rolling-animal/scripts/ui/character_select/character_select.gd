class_name CharacterSelect
extends Control

signal character_changed(character_data: Dictionary)
signal character_confirmed(character_data: Dictionary)
signal back_requested

const AVATAR_SCENE := preload("res://scenes/ui/character_select/character_avatar.tscn")
const CharacterData := preload("res://resources/characters/character_select_data.gd")
const FARM_LEVEL_SCENE := "res://scenes/farm_level_test.tscn"
const ANIMATION_DURATION := 0.3
const MIN_CAROUSEL_SLOT := -4
const MAX_CAROUSEL_SLOT := 4
const SLOT_SCALES := {
	0: 1.12,
	1: 0.78,
	2: 0.58,
	3: 0.44,
	4: 0.34,
}
const SLOT_ALPHAS := {
	0: 1.0,
	1: 0.72,
	2: 0.46,
	3: 0.26,
	4: 0.12,
}
const ROLL_DEGREES_PER_STEP := 360.0

@export_range(0, 8) var default_character_index := 0
@export_range(0.0, 100.0, 1.0) var avatar_visual_gap := 42.0
@export_range(1.0, 512.0, 1.0) var avatar_base_diameter := 132.0

@onready var carousel_area: Control = $CarouselArea
@onready var avatar_layer: Control = $CarouselArea/AvatarLayer
@onready var selected_character_frame: TextureRect = $CarouselArea/SelectedCharacterFrame
@onready var character_name_label: Label = $CharacterNamePlate/CharacterNameLabel
@onready var left_button: TextureButton = $CarouselArea/LeftArrowButton
@onready var right_button: TextureButton = $CarouselArea/RightArrowButton
@onready var confirm_button: TextureButton = $SelectButton
@onready var back_button: TextureButton = $BackButton

var selected_index := 0
var is_animating := false
var avatars: Array[Control] = []
var slot_center_x: Dictionary = {}
var _move_tween: Tween
var _rotation_step_degrees := 0.0


func _ready() -> void:
	selected_index = wrapi(default_character_index, 0, CharacterData.CHARACTERS.size())
	_create_avatars()
	left_button.pressed.connect(_select_next)
	right_button.pressed.connect(_select_previous)
	confirm_button.pressed.connect(_confirm_selection)
	back_button.pressed.connect(_request_back)
	avatar_layer.resized.connect(_on_carousel_resized)
	_setup_button_feedback()
	rebuild_slot_positions()
	refresh_avatar_positions(false)
	_update_character_info()
	character_changed.emit(get_selected_character())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_select_confirm"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character_select_back"):
		_request_back()
		get_viewport().set_input_as_handled()
	elif not is_animating and event.is_action_pressed("character_select_left"):
		_select_next()
		get_viewport().set_input_as_handled()
	elif not is_animating and event.is_action_pressed("character_select_right"):
		_select_previous()
		get_viewport().set_input_as_handled()


func _create_avatars() -> void:
	for index in CharacterData.CHARACTERS.size():
		var data: Dictionary = CharacterData.CHARACTERS[index]
		var avatar: Control = AVATAR_SCENE.instantiate()
		avatar_layer.add_child(avatar)
		avatar.setup(data)
		avatar.carousel_slot = get_wrapped_relative_index(index)
		avatars.append(avatar)


## Converts an array index to the nearest cyclic slot around the center.
func get_wrapped_relative_index(character_index: int, center_index := selected_index) -> int:
	var count := CharacterData.CHARACTERS.size()
	var relative := wrapi(character_index - center_index, 0, count)
	if relative > count / 2:
		relative -= count
	return relative


func get_target_position(character_index: int, center_index := selected_index) -> Vector2:
	var relative := get_wrapped_relative_index(character_index, center_index)
	return get_slot_position(relative)


func get_slot_diameter(slot: int) -> float:
	return avatar_base_diameter * get_slot_scale(slot).x


## Builds mirrored centers from the actual neighboring visual radii and one fixed edge gap.
func rebuild_slot_positions() -> void:
	slot_center_x.clear()
	var center_x := avatar_layer.size.x * 0.5
	slot_center_x[0] = center_x

	var right_x := center_x
	for slot in range(1, MAX_CAROUSEL_SLOT + 1):
		var previous_slot := slot - 1
		right_x += get_slot_diameter(previous_slot) * 0.5 \
			+ avatar_visual_gap \
			+ get_slot_diameter(slot) * 0.5
		slot_center_x[slot] = right_x

	var left_x := center_x
	for slot in range(-1, MIN_CAROUSEL_SLOT - 1, -1):
		var previous_slot := slot + 1
		left_x -= get_slot_diameter(previous_slot) * 0.5 \
			+ avatar_visual_gap \
			+ get_slot_diameter(slot) * 0.5
		slot_center_x[slot] = left_x


func get_temporary_slot_center_x(slot: int) -> float:
	if slot == MAX_CAROUSEL_SLOT + 1:
		return slot_center_x[MAX_CAROUSEL_SLOT] \
			+ get_slot_diameter(MAX_CAROUSEL_SLOT) * 0.5 \
			+ avatar_visual_gap \
			+ get_slot_diameter(MAX_CAROUSEL_SLOT) * 0.5
	if slot == MIN_CAROUSEL_SLOT - 1:
		return slot_center_x[MIN_CAROUSEL_SLOT] \
			- get_slot_diameter(MIN_CAROUSEL_SLOT) * 0.5 \
			- avatar_visual_gap \
			- get_slot_diameter(MIN_CAROUSEL_SLOT) * 0.5
	return slot_center_x.get(slot, avatar_layer.size.x * 0.5)


func get_slot_position(slot: int) -> Vector2:
	var center_x := get_temporary_slot_center_x(slot)
	var center_y := avatar_layer.size.y * 0.5
	return Vector2(
		center_x - avatar_base_diameter * 0.5,
		center_y - avatar_base_diameter * 0.5
	)


func get_slot_scale(slot: int) -> Vector2:
	var scale_value: float = SLOT_SCALES.get(mini(absi(slot), MAX_CAROUSEL_SLOT), SLOT_SCALES[MAX_CAROUSEL_SLOT])
	return Vector2.ONE * scale_value


func get_slot_alpha(slot: int) -> float:
	return SLOT_ALPHAS.get(mini(absi(slot), MAX_CAROUSEL_SLOT), SLOT_ALPHAS[MAX_CAROUSEL_SLOT])


func refresh_avatar_positions(animated: bool) -> void:
	for index in avatars.size():
		var avatar: Control = avatars[index]
		var target_position := get_slot_position(avatar.carousel_slot)
		var target_scale := get_slot_scale(avatar.carousel_slot)
		var target_alpha := get_slot_alpha(avatar.carousel_slot)
		if animated:
			_move_tween.tween_property(avatar, "position", target_position, ANIMATION_DURATION)
			_move_tween.tween_property(avatar, "scale", target_scale, ANIMATION_DURATION)
			_move_tween.tween_property(avatar, "modulate:a", target_alpha, ANIMATION_DURATION)
			_move_tween.tween_property(
				avatar.avatar_visual,
				"rotation_degrees",
				avatar.avatar_visual.rotation_degrees + _rotation_step_degrees,
				ANIMATION_DURATION
			)
		else:
			avatar.position = target_position
			avatar.scale = target_scale
			avatar.modulate.a = target_alpha


## Positive direction moves the row left and selects the character on the right.
func _change_selection(direction: int) -> void:
	if is_animating:
		return
	is_animating = true
	_set_controls_enabled(false)
	selected_character_frame.visible = false
	selected_character_frame.modulate.a = 0.0
	var count := CharacterData.CHARACTERS.size()
	# Every persistent avatar advances exactly one slot; no texture swapping or recreation.
	for avatar in avatars:
		avatar.carousel_slot -= direction

	selected_index = wrapi(selected_index + direction, 0, count)
	# Moving left rolls counterclockwise; moving right rolls clockwise.
	_rotation_step_degrees = -direction * ROLL_DEGREES_PER_STEP
	_move_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	refresh_avatar_positions(true)
	await _move_tween.finished

	# The single off-screen item wraps only after it has fully exited the clipped area.
	for avatar in avatars:
		# A full turn ends visually upright; exact zero prevents accumulated drift.
		avatar.avatar_visual.rotation_degrees = 0.0
		if avatar.carousel_slot < MIN_CAROUSEL_SLOT:
			avatar.carousel_slot = MAX_CAROUSEL_SLOT
		elif avatar.carousel_slot > MAX_CAROUSEL_SLOT:
			avatar.carousel_slot = MIN_CAROUSEL_SLOT
	# Exact assignment prevents floating-point drift over repeated cycles.
	refresh_avatar_positions(false)
	_update_character_info()
	_rotation_step_degrees = 0.0
	selected_character_frame.visible = true
	var frame_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	frame_tween.tween_property(selected_character_frame, "modulate:a", 1.0, 0.12)
	await frame_tween.finished
	is_animating = false
	_set_controls_enabled(true)
	character_changed.emit(get_selected_character())


func _select_next() -> void:
	_change_selection(1)


func _select_previous() -> void:
	_change_selection(-1)


func _set_controls_enabled(enabled: bool) -> void:
	left_button.disabled = not enabled
	right_button.disabled = not enabled
	left_button.modulate.a = 1.0 if enabled else 0.45
	right_button.modulate.a = 1.0 if enabled else 0.45


func _update_character_info() -> void:
	var data := get_selected_character()
	character_name_label.text = data["display_name"].to_upper()


func get_selected_character() -> Dictionary:
	return CharacterData.CHARACTERS[selected_index].duplicate(true)


func _confirm_selection() -> void:
	if is_animating:
		return
	var data := get_selected_character()
	print("Selected character: ", data["id"])
	print("Selected character name: ", data["display_name"])
	print("Selected texture: ", data["portrait_path"])
	GameState.set_selected_character(data)
	character_confirmed.emit(data)
	get_tree().change_scene_to_file(FARM_LEVEL_SCENE)


func _request_back() -> void:
	if not is_animating:
		print("Back requested")
		back_requested.emit()


func _on_carousel_resized() -> void:
	if is_node_ready() and not is_animating:
		rebuild_slot_positions()
		refresh_avatar_positions(false)


## Adds lightweight feedback without replacing the supplied pixel-art textures.
func _setup_button_feedback() -> void:
	for button: TextureButton in [left_button, right_button, back_button, confirm_button]:
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		button.button_down.connect(_on_button_pressed.bind(button))
		button.button_up.connect(_on_button_released.bind(button))


func _on_button_hover(button: TextureButton, hovered: bool) -> void:
	button.self_modulate = Color(1.12, 1.12, 1.12, button.self_modulate.a) if hovered else Color.WHITE


func _on_button_pressed(button: TextureButton) -> void:
	button.scale = Vector2(0.94, 0.94)


func _on_button_released(button: TextureButton) -> void:
	button.scale = Vector2.ONE
