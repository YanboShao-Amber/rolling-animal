class_name WinPopup
extends Control

signal left_button_pressed
signal right_button_pressed
signal closed

@onready var dimmer: ColorRect = $Dimmer
@onready var popup_root: Control = $PopupRoot
@onready var title_label: Label = $PopupRoot/TitleBanner/TitleLabel
@onready var body_label: Label = $PopupRoot/BodyLabel
@onready var left_button: TextureButton = $PopupRoot/ButtonRow/LeftButton
@onready var right_button: TextureButton = $PopupRoot/ButtonRow/RightButton
@onready var left_button_label: Label = $PopupRoot/ButtonRow/LeftButton/ButtonLabel
@onready var right_button_label: Label = $PopupRoot/ButtonRow/RightButton/ButtonLabel

var _animation_tween: Tween


func _ready() -> void:
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	_setup_button_feedback(left_button)
	_setup_button_feedback(right_button)
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		var elapsed_msec: int = game_state.finish_level_timer()
		body_label.text = "You cleared the stage in %s!\nWould you like to continue or go back?" % game_state.format_level_time(elapsed_msec)
	show_popup()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_popup()
		closed.emit()
		print("Closed")
		get_viewport().set_input_as_handled()


func set_title_text(value: String) -> void:
	if is_instance_valid(title_label):
		title_label.text = value


func set_body_text(value: String) -> void:
	if is_instance_valid(body_label):
		body_label.text = value


func set_left_button_text(value: String) -> void:
	if is_instance_valid(left_button_label):
		left_button_label.text = value


func set_right_button_text(value: String) -> void:
	if is_instance_valid(right_button_label):
		right_button_label.text = value


func show_popup() -> void:
	_kill_animation()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.modulate.a = 0.0
	popup_root.modulate.a = 0.0
	popup_root.scale = Vector2(0.90, 0.90)
	_animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(dimmer, "modulate:a", 1.0, 0.22)
	_animation_tween.tween_property(popup_root, "modulate:a", 1.0, 0.20)
	_animation_tween.tween_property(popup_root, "scale", Vector2.ONE, 0.22)


func hide_popup() -> void:
	if not visible:
		return
	_kill_animation()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation_tween.tween_property(dimmer, "modulate:a", 0.0, 0.17)
	_animation_tween.tween_property(popup_root, "modulate:a", 0.0, 0.16)
	_animation_tween.tween_property(popup_root, "scale", Vector2(0.92, 0.92), 0.17)
	await _animation_tween.finished
	visible = false


func _on_left_button_pressed() -> void:
	print("Left button pressed")
	left_button_pressed.emit()


func _on_right_button_pressed() -> void:
	print("Right button pressed")
	right_button_pressed.emit()


func _setup_button_feedback(button: TextureButton) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_hover(button: TextureButton, hovered: bool) -> void:
	button.self_modulate = Color(1.12, 1.12, 1.12, 1.0) if hovered else Color.WHITE


func _on_button_down(button: TextureButton) -> void:
	button.scale = Vector2(0.94, 0.94)


func _on_button_up(button: TextureButton) -> void:
	button.scale = Vector2.ONE


func _kill_animation() -> void:
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()
