extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $UILayer/StatusLabel


func _ready() -> void:
	player.debug_label.visible = true
	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)
	status_label.text = "READY"


func _process(_delta: float) -> void:
	status_label.text = "SIZE  %.2f    TARGET  %.2f    CLICK RATE  %.1f/s" % [
		player.current_size_scale,
		player.target_size_scale,
		player.click_frequency,
	]


func _on_player_jumped() -> void:
	status_label.modulate = Color(1.0, 0.72, 0.42)


func _on_player_landed() -> void:
	var feedback := create_tween()
	feedback.tween_property(status_label, "modulate", Color.WHITE, 0.25)
