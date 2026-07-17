class_name LosePopup
extends Control

signal retry_pressed
signal menu_pressed
signal closed

@onready var dimmer: ColorRect = $Dimmer
@onready var popup_root: Control = $PopupRoot
@onready var title_label: Label = $PopupRoot/TitleLabel
@onready var body_label: Label = $PopupRoot/MessagePanel/BodyLabel
@onready var close_button: Button = $PopupRoot/CloseButton
@onready var retry_button: TextureButton = $PopupRoot/ButtonRow/RetryButton
@onready var menu_button: TextureButton = $PopupRoot/ButtonRow/MenuButton
@onready var retry_button_label: Label = $PopupRoot/ButtonRow/RetryButton/ButtonLabel
@onready var menu_button_label: Label = $PopupRoot/ButtonRow/MenuButton/ButtonLabel

var _animation_tween: Tween


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_setup_button_feedback(retry_button)
	_setup_button_feedback(menu_button)
	show_popup()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()


func set_title_text(value: String) -> void:
	if is_instance_valid(title_label):
		title_label.text = value


func set_body_text(value: String) -> void:
	if is_instance_valid(body_label):
		body_label.text = value


func set_retry_button_text(value: String) -> void:
	if is_instance_valid(retry_button_label):
		retry_button_label.text = value


func set_menu_button_text(value: String) -> void:
	if is_instance_valid(menu_button_label):
		menu_button_label.text = value


func show_popup() -> void:
	_kill_animation()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.modulate.a = 0.0
	popup_root.modulate.a = 0.0
	popup_root.scale = Vector2(0.92, 0.92)
	_animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(dimmer, "modulate:a", 1.0, 0.22)
	_animation_tween.tween_property(popup_root, "modulate:a", 1.0, 0.18)
	_animation_tween.tween_property(popup_root, "scale", Vector2.ONE, 0.22)


func hide_popup() -> void:
	if not visible:
		return
	_kill_animation()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation_tween.tween_property(dimmer, "modulate:a", 0.0, 0.16)
	_animation_tween.tween_property(popup_root, "modulate:a", 0.0, 0.14)
	_animation_tween.tween_property(popup_root, "scale", Vector2(0.94, 0.94), 0.16)
	await _animation_tween.finished
	visible = false


func _on_retry_pressed() -> void:
	print("Retry pressed")
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	print("Menu pressed")
	menu_pressed.emit()


func _on_close_pressed() -> void:
	_close_popup()


func _close_popup() -> void:
	hide_popup()
	closed.emit()
	print("Lose popup closed")


func _setup_button_feedback(button: TextureButton) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_hover(button: TextureButton, hovered: bool) -> void:
	button.self_modulate = Color(1.14, 1.14, 1.14, 1.0) if hovered else Color.WHITE


func _on_button_down(button: TextureButton) -> void:
	button.scale = Vector2(0.94, 0.94)


func _on_button_up(button: TextureButton) -> void:
	button.scale = Vector2.ONE


func _kill_animation() -> void:
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()

