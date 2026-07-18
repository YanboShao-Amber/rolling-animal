class_name RespawnManager
extends Node

## 逐检查点重生（每关放一个）。
## “一命通关”= 死亡不回起点，回最近激活的检查点，无限重试直到通关。
##
## 解耦方式：危险物发 player_died 信号（组 "hazards"）、检查点发 activated 信号
## （组 "checkpoints"），本节点在 _ready 自动收集连接。加新地刺/检查点无需改这里。
## 重生只调用主角已有的公开原语：reset_size() / reset_motion_visuals() + 设位置。

@export var player: SoftPlayer
@export var default_spawn: Marker2D  ## 起点 = 0 号检查点（留空则用玩家初始位置）

var _respawn_position := Vector2.ZERO
var _current_order := -1


func _ready() -> void:
	if default_spawn:
		_respawn_position = default_spawn.global_position
	elif player:
		_respawn_position = player.global_position

	# 等一帧：确保用 Scene Paint / 瓦片实例化的物件也已进入场景树再连线。
	if default_spawn == null:
		push_warning("RespawnManager: 未设置 default_spawn，第一个检查点之前死亡会重生到 (0,0)。请在检查器里指定。")

	await get_tree().process_frame

	for hazard in get_tree().get_nodes_in_group("hazards"):
		if hazard.has_signal("player_died"):
			hazard.player_died.connect(_on_player_died)
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp.has_signal("activated"):
			cp.activated.connect(_on_checkpoint_activated)

	if player and default_spawn:
		player.global_position = _respawn_position


func _on_checkpoint_activated(cp: Checkpoint) -> void:
	if cp.order < _current_order:
		return  # 只前进不倒退
	_current_order = cp.order
	_respawn_position = cp.get_respawn_position()


func _on_player_died(who: SoftPlayer) -> void:
	# 用信号传来的 who（实际撞刺的玩家），不依赖 export 的 player 是否解析成功。
	who.global_position = _respawn_position
	who.reset_size()          # 回默认大小
	who.reset_motion_visuals()
