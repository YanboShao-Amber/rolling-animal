class_name RespawnManager
extends Node

## 逐检查点重生（每关放一个）。
## “一命通关”= 死亡不回起点，回最近激活的检查点，无限重试直到通关。
##
## 解耦方式：危险物发 player_died 信号（组 "hazards"）、检查点发 activated 信号
## （组 "checkpoints"），本节点在 _ready 自动收集连接。加新地刺/检查点无需改这里。
## 重生只调用主角已有的公开原语：reset_size() / reset_motion_visuals() + 设位置。
##
## 死亡特效：危险物可在信号里带一个 effect(PackedScene)。带了就先冻住玩家播完特效再重生
## （比如撞墙眩晕的星星），不带就瞬间重生（比如毒水）。

@export var player: SoftPlayer
@export var default_spawn: Marker2D  ## 起点 = 0 号检查点（留空则自动用玩家初始位置）
## 死亡特效相对玩家（脚底为原点）的位置——放头顶。
@export var death_effect_offset := Vector2(0, -150)

@export_category("Fall Death")
## 坠落死亡：玩家掉出屏幕底部即死亡并重生到最近检查点。逐关开启，默认关闭，其他关卡不受影响。
@export var fall_death_enabled := false
## 判定线：玩家 global_position.y（脚底）超过此值即算掉出屏幕。
## 本作视口高 1080、相机 limit_bottom≈1080，取 1300 表示已完全落到可视区下方。
@export var fall_death_y := 1300.0

@export_category("Anti-Stuck")
## 防卡死：玩家原地不动（且体型不变）超过 stuck_duration 秒 → 回最近检查点。
@export var stuck_death_enabled := true
@export var stuck_duration := 2.0
## 判定"动了"的最小位移(px)：这段时间内位移小于它就算没动。
@export var stuck_move_threshold := 6.0

var _respawn_position := Vector2.ZERO
var _current_order := -1
var _busy := false
var _stuck_time := 0.0
var _stuck_last_pos := Vector2.INF
var _stuck_last_size := -1.0


func _ready() -> void:
	if player == null:
		player = _find_soft_player()  # 兜底：手写 .tscn 的导出引用没解析时也能找到玩家
	if default_spawn:
		_respawn_position = default_spawn.global_position
	elif player:
		_respawn_position = player.global_position
		push_warning("RespawnManager: 未设置 default_spawn，改用玩家初始位置作为起点重生点。")

	# 等一帧：确保用 Scene Paint / 瓦片实例化的物件也已进入场景树再连线。
	await get_tree().process_frame

	for hazard in get_tree().get_nodes_in_group("hazards"):
		if hazard.has_signal("player_died"):
			hazard.player_died.connect(_on_player_died)
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp.has_signal("activated"):
			cp.activated.connect(_on_checkpoint_activated)

	if player and default_spawn:
		player.global_position = _respawn_position


func _physics_process(delta: float) -> void:
	if _busy or not is_instance_valid(player):
		return
	# 坠落死亡：玩家掉出屏幕底部（Y 超过判定线）即重生到最近检查点。
	if fall_death_enabled and player.global_position.y > fall_death_y:
		_on_player_died(player)  # 不带特效 → 立即重生（与毒水一致）
		return
	# 防卡死：原地不动太久 → 重生。
	if stuck_death_enabled:
		_check_stuck(delta)


func _check_stuck(delta: float) -> void:
	# 只在"应该往前走"时判卡：auto_forward 关掉的段落=故意静止，不算卡。
	if not player.auto_forward_enabled:
		_stuck_time = 0.0
		_stuck_last_pos = player.global_position
		return
	var pos := player.global_position
	var size: float = player.current_size_scale
	# 位置或体型有明显变化 → 算"在动/在长大"，清零计时（贴墙狂点变大砸墙不算卡）。
	if _stuck_last_pos.distance_to(pos) > stuck_move_threshold or absf(size - _stuck_last_size) > 0.02:
		_stuck_last_pos = pos
		_stuck_last_size = size
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= stuck_duration:
		_stuck_time = 0.0
		_on_player_died(player)  # 卡住 → 回最近检查点（瞬间、无特效）


func _find_soft_player() -> SoftPlayer:
	for node in get_tree().get_nodes_in_group("player"):
		if node is SoftPlayer:
			return node
	var scene := get_tree().current_scene
	if scene:
		for node in scene.find_children("*", "CharacterBody2D", true, false):
			if node is SoftPlayer:
				return node
	return null


func _on_checkpoint_activated(cp: Checkpoint) -> void:
	if cp.order < _current_order:
		return  # 只前进不倒退
	_current_order = cp.order
	_respawn_position = cp.get_respawn_position()


func _on_player_died(who: SoftPlayer, effect: PackedScene = null) -> void:
	# 用信号传来的 who（实际撞到的玩家），不依赖 export 的 player 是否解析成功。
	if _busy:
		return
	_busy = true
	if effect:
		# 死亡特效（比如撞墙眩晕的星星）：先冻住玩家播完，再重生。
		who.set_physics_process(false)
		who.set_process(false)
		who.velocity = Vector2.ZERO
		var fx := effect.instantiate()
		who.add_child(fx)
		if fx is Node2D:
			(fx as Node2D).position = death_effect_offset
		if fx.has_signal("finished"):
			await fx.finished
		else:
			await get_tree().create_timer(0.8).timeout
		who.set_process(true)
		who.set_physics_process(true)
	who.global_position = _respawn_position
	who.reset_size()          # 回默认大小
	who.reset_motion_visuals()
	who.play_respawn_blink()  # 重生瞬间闪烁几下，给玩家“我复活了”的反馈
	# 通用复位：让被破坏的墙等"可复位"物件恢复本段初始状态。
	get_tree().call_group("resettable", "reset_state")
	_busy = false
