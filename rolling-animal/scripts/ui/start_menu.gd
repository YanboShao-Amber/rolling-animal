class_name StartMenu
extends Control

const LEVEL_MENU_SCENE := "res://scenes/ui/level_menu.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial_level.tscn"
const BROWN_BUTTON := preload("res://assets/UI/button_brown.png")
const RED_BUTTON := preload("res://assets/UI/button_red.png")

@onready var start_button: TextureButton = $MenuRoot/ButtonColumn/StartButton
@onready var tutorial_button: TextureButton = $MenuRoot/ButtonColumn/TutorialButton
@onready var credits_button: TextureButton = $MenuRoot/ButtonColumn/CreditsButton
@onready var exit_button: TextureButton = $MenuRoot/ButtonColumn/ExitButton
@onready var message_label: Label = $MenuRoot/MessageLabel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	for button in _get_buttons():
		button.texture_normal = BROWN_BUTTON
		button.mouse_entered.connect(_select_button.bind(button))
		button.focus_entered.connect(_select_button.bind(button))


func _get_buttons() -> Array[TextureButton]:
	return [start_button, tutorial_button, credits_button, exit_button]


func _select_button(selected_button: TextureButton) -> void:
	for button in _get_buttons():
		button.texture_normal = RED_BUTTON if button == selected_button else BROWN_BUTTON


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_MENU_SCENE)


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_credits_pressed() -> void:
	message_label.text = "CREDITS - COMING SOON"


func _on_exit_pressed() -> void:
	get_tree().quit()
