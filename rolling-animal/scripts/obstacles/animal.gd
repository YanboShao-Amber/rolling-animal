class_name FoxAnimal
extends StaticBody2D

## 狐狸障碍（由 body/ear/leg/tail 拼装）。本体不移动（StaticBody2D）。
##
## - 玩家体型 > destroy_threshold(默认 1.3)：撞上即把动物撞碎（消失）。
## - 玩家体型 <= 阈值 且从侧面/正面相撞：玩家死亡（发 player_died 交给 RespawnManager）。
## - 玩家体型 <= 阈值 且从顶部跳上来：动物就是普通刚体，玩家正常站立，不死。
##
## 死亡/复位走本项目既有约定：加入 "hazards" 组由 RespawnManager 接管重生；
## 加入 "resettable" 组，玩家死亡重生时 reset_state() 让被撞碎的动物恢复。

signal player_died(player: SoftPlayer, effect: PackedScene)

@export var destroy_threshold := 1.3
## 侧面撞死的死亡特效（可选，如 StunEffect.tscn）。留空则瞬间重生。
@export var death_effect: PackedScene
## 玩家死亡重生时恢复本动物（与本关其它障碍一致）。默认开启。
@export var restore_on_respawn := true
## “站在顶部”的判定容差(px)：玩家脚底不低于动物顶面 + 此容差，视为踩在顶上（安全）。
@export var top_stand_margin := 16.0

@onready var solid_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea

var _broken := false
var _dead_triggered := false


func _ready() -> void:
	add_to_group("hazards")          # 让 RespawnManager 接管“撞死 → 重生”
	if restore_on_respawn:
		add_to_group("resettable")   # 让 RespawnManager 重生时调 reset_state() 恢复


func _physics_process(_delta: float) -> void:
	if _broken:
		return
	var player := _get_touching_player()
	if player == null:
		_dead_triggered = false      # 玩家离开（含被重生传送走）后允许再次触发
		return
	if player.get_current_size_scale() > destroy_threshold:
		_break()                     # 够大 → 撞碎动物
		return
	# 小玩家：踩顶 = 安全（靠刚体站立），正面/侧面相撞 = 死。
	if _dead_triggered:
		return
	if not _is_player_on_top(player):
		_dead_triggered = true
		player_died.emit(player, death_effect)


# 玩家原点在脚底；Y 越小越靠上。脚底不低于顶面+容差 → 视为踩在顶上。
func _is_player_on_top(player: SoftPlayer) -> bool:
	return player.global_position.y <= _solid_top_y() + top_stand_margin


func _solid_top_y() -> float:
	var rect := solid_shape.shape as RectangleShape2D
	var half_h := rect.size.y * 0.5 if rect else 0.0
	return solid_shape.global_position.y - half_h


func _get_touching_player() -> SoftPlayer:
	if not detection_area.monitoring:
		return null  # 保险：monitoring 关掉时 get_overlapping_bodies() 会报错
	for body in detection_area.get_overlapping_bodies():
		if body is SoftPlayer:
			return body
	return null


func _break() -> void:
	if restore_on_respawn:
		_broken = true
		_set_active(false)  # 隐藏+关碰撞+停检测，但不销毁，方便重生恢复
	else:
		queue_free()         # 不需要恢复时直接销毁


func _set_active(active: bool) -> void:
	visible = active
	# 物理回调里改碰撞形状要用 set_deferred，避免“正在处理查询”报错。
	solid_shape.set_deferred("disabled", not active)
	# 不切换 detection_area.monitoring：破坏时靠 _broken 提前 return 跳过检测即可。
	# 若在此 set_deferred 关掉 monitoring，重生 reset_state() 会先把 _broken 置回 false，
	# 而 monitoring 的延迟设置尚未生效，本帧 _physics_process 调 get_overlapping_bodies() 就会报错。


## 通用复位接口：玩家死亡重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	_dead_triggered = false
	if not _broken:
		return
	_broken = false
	_set_active(true)
