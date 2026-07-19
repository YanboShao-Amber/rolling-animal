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
var _initial_position := Vector2.ZERO
var _initial_scale := Vector2.ONE
var _initial_modulate := Color.WHITE
var _collect_tween: Tween


func _ready() -> void:
	if display_only:
		monitoring = false
		return
	# 记录初始外观，供死亡刷新时还原（收集动画会改动 position/scale/modulate）。
	_initial_position = position
	_initial_scale = scale
	_initial_modulate = modulate
	_resolve_persistence_ids()
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("is_level_coin_collected") \
			and game_state.is_level_coin_collected(_resolved_level_id, _resolved_coin_id):
		queue_free()
		return
	# 加入 "resettable" 组：玩家死亡重生时 RespawnManager 会调 reset_state() 让金币重新出现。
	add_to_group("resettable")
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

	# 收集动画结束后只隐藏、不销毁——这样死亡重生时能被 reset_state() 复原。
	if _collect_tween and _collect_tween.is_valid():
		_collect_tween.kill()
	_collect_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_collect_tween.tween_property(self, "position:y", _initial_position.y - 18.0, collect_animation_duration)
	_collect_tween.tween_property(self, "scale", _initial_scale * 1.25, collect_animation_duration)
	_collect_tween.tween_property(self, "modulate:a", 0.0, collect_animation_duration)
	_collect_tween.finished.connect(_on_collect_finished)


func _on_collect_finished() -> void:
	if _collected:
		visible = false


## 通用复位接口：玩家死亡重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if not _collected:
		return
	if _collect_tween and _collect_tween.is_valid():
		_collect_tween.kill()
	# 退还金币计数与“已收集”记录，让死亡后能重新吃到并再次计分。
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("uncollect_level_coin"):
		game_state.uncollect_level_coin(_resolved_level_id, _resolved_coin_id, value)
	_collected = false
	position = _initial_position
	scale = _initial_scale
	modulate = _initial_modulate
	visible = true
	set_deferred("monitoring", true)
