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

var _respawn_position := Vector2.ZERO
var _current_order := -1
var _busy := false


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
	# 通用复位：让被破坏的墙等"可复位"物件恢复本段初始状态。
	get_tree().call_group("resettable", "reset_state")
	_busy = false
