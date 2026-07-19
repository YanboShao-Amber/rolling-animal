class_name CollectibleCoin
extends Area2D

signal collected(value: int, total: int)

@export_range(1, 100, 1) var value := 1
@export_range(0.05, 1.0, 0.01) var collect_animation_duration := 0.22
@export var level_id := ""
@export var coin_id := ""
@export var display_only := false

var _collected := false
var _resolved_level_id := ""
var _resolved_coin_id := ""


func _ready() -> void:
	if display_only:
		monitoring = false
		return
	_resolve_persistence_ids()
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("is_level_coin_collected") \
			and game_state.is_level_coin_collected(_resolved_level_id, _resolved_coin_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _resolve_persistence_ids() -> void:
	_resolved_level_id = level_id
	if _resolved_level_id.is_empty() and get_tree().current_scene:
		_resolved_level_id = get_tree().current_scene.scene_file_path
	_resolved_coin_id = coin_id if not coin_id.is_empty() else str(get_path())


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is SoftPlayer):
		return
	_collected = true
	set_deferred("monitoring", false)
	var total := value
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("collect_level_coin"):
		total = game_state.collect_level_coin(_resolved_level_id, _resolved_coin_id, value)
	collected.emit(value, total)

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 18.0, collect_animation_duration)
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, collect_animation_duration)
	tween.tween_property(self, "modulate:a", 0.0, collect_animation_duration)
	await tween.finished
	queue_free()
