class_name CollectibleCoin
extends Area2D

signal collected(value: int, total: int)

@export_range(1, 100, 1) var value := 1
@export_range(0.05, 1.0, 0.01) var collect_animation_duration := 0.22

var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is SoftPlayer):
		return
	_collected = true
	set_deferred("monitoring", false)
	var total := value
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("add_coins"):
		total = game_state.add_coins(value)
	collected.emit(value, total)

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 18.0, collect_animation_duration)
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, collect_animation_duration)
	tween.tween_property(self, "modulate:a", 0.0, collect_animation_duration)
	await tween.finished
	queue_free()

