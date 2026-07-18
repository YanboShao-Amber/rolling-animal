extends StaticBody2D # 注意这里改为了 StaticBody2D

## 可破坏障碍（玻璃 / 墙）。够大（current_size_scale > destroy_threshold）撞上去就碎。
##
## 可选 stun_if_too_small：太小撞墙先给一点“原地变大”的宽限，没长够就发 player_died
##   → 交给 RespawnManager 播眩晕特效并重生。
## 可选 restore_on_respawn：破坏后不销毁，只隐藏+关碰撞；重生时由 RespawnManager 通过
##   call_group("resettable", "reset_state") 恢复——这样死了重来，这堵墙还在。
##
## 两个开关都默认关，关掉时行为和原版完全一样（老的 minecraft 玻璃不受影响）。

signal player_died(player: SoftPlayer, effect: PackedScene)

@export var destroy_threshold: float = 1.3
## 开启后：太小撞墙 → 宽限内没长够就眩晕重生。
@export var stun_if_too_small := false
## 太小撞墙后允许原地狂点变大的宽限时间；这段时间内长到够大仍可撞碎。0 = 一碰就眩晕。
@export var grow_grace_time := 0.4
## 眩晕/死亡特效（把 StunEffect.tscn 拖进来）。留空则瞬间重生。
@export var death_effect: PackedScene
## 开启后：破坏时不销毁只失效，重生时恢复（需要场景里有 RespawnManager）。
@export var restore_on_respawn := false

@onready var detection_area: Area2D = $Area2D
@onready var solid_shape: CollisionShape2D = $CollisionShape2D

var _too_small_time := 0.0
var _triggered := false
var _broken := false


func _ready() -> void:
	if stun_if_too_small:
		add_to_group("hazards")     # 让 RespawnManager 接管“眩晕 → 重生”
	if restore_on_respawn:
		add_to_group("resettable")  # 让 RespawnManager 重生时调 reset_state() 恢复


func _physics_process(delta: float) -> void:
	if _broken:
		return
	var player := _get_touching_player()
	if player == null:
		# 玩家离开（含被重生传送走）后复位，允许再次触发。
		_too_small_time = 0.0
		_triggered = false
		return
	if _triggered:
		return
	# 放在 _physics_process：即使玩家贴着墙时才变大，也能立刻触发销毁。
	if player.current_size_scale > destroy_threshold:
		_break()  # 够大，撞碎
		return
	if stun_if_too_small:
		_too_small_time += delta
		if _too_small_time >= grow_grace_time:
			_triggered = true
			player_died.emit(player, death_effect)


## 通用复位接口：重生时被 RespawnManager 用 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if not _broken:
		return
	_broken = false
	_triggered = false
	_too_small_time = 0.0
	_set_active(true)


func _break() -> void:
	if restore_on_respawn:
		_broken = true
		_set_active(false)  # 隐藏+关碰撞，但不销毁，方便重生恢复
	else:
		queue_free()         # 老行为：直接销毁


func _set_active(active: bool) -> void:
	visible = active
	# 在物理回调里改碰撞形状要用 set_deferred，避免“正在处理查询”报错。
	solid_shape.set_deferred("disabled", not active)


func _get_touching_player() -> SoftPlayer:
	for body in detection_area.get_overlapping_bodies():
		if body is SoftPlayer:
			return body
	return null
