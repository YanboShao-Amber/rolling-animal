class_name StunWall
extends StaticBody2D

## 眩晕墙（独立母本，不依赖 glass.gd / breakable obstacle.gd —— 别人改那些不影响它）。
##
## 玩家撞上来时：
##   · 体型 > smash_size(默认 1.3) → 撞碎穿过（墙隐藏+关碰撞，重生时恢复）。
##   · 体型不够大 → 给 grow_grace_time 秒原地狂点变大的机会；没长够 → 眩晕 + 回检查点重来。
##
## 接线（零连线，只要场景里有 RespawnManager）：
##   进 "hazards" 组 → 眩晕死亡由 RespawnManager 接管（传送重生 + 播 death_effect）；
##   进 "resettable" 组 → 重生时墙自动长回来。
## 墙做得很高（跳不过去），所以太小的玩家躲不掉，只能变大砸穿、否则被眩晕——就是"不够大就重来"的墙。

signal player_died(player: SoftPlayer, effect: PackedScene)

## 撞碎所需的最小体型；不到就得眩晕重来（或在宽限内长够）。
@export var smash_size := 1.3
## 太小撞墙后允许原地狂点变大的宽限秒数。0 = 一碰就眩晕、没有补救。
@export var grow_grace_time := 0.3
## 眩晕特效（把 StunEffect.tscn 拖进来）。留空 = 瞬间重生、无特效。
@export var death_effect: PackedScene
## 级联半径：一块墙被砸碎时，原点距离在此之内的其它 StunWall 会一起碎。
## 54 砖相邻≈54，默认 64 刚好只连"紧挨着的"、不会跨 1 格空隙（想跨更大空隙就调大）。
@export var neighbor_radius := 64.0

@onready var _detect: Area2D = $Area2D
@onready var _solid: CollisionShape2D = $CollisionShape2D

var _too_small_time := 0.0
var _triggered := false
var _broken := false


func _ready() -> void:
	add_to_group("hazards")
	add_to_group("resettable")
	add_to_group("stun_walls")   # 用于"砸碎级联"：互相查找相邻的墙


func _physics_process(delta: float) -> void:
	if _broken:
		return
	var player := _touching_player()
	if player == null:
		# 玩家离开（含被重生传走）后复位，允许再次触发。
		_too_small_time = 0.0
		_triggered = false
		return
	if _triggered:
		return
	# 放 _physics_process：贴着墙时才变大也能立刻砸穿。
	if player.current_size_scale > smash_size:
		_smash()
		return
	_too_small_time += delta
	if _too_small_time >= grow_grace_time:
		_triggered = true
		player_died.emit(player, death_effect)


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if not _broken:
		return
	_broken = false
	_triggered = false
	_too_small_time = 0.0
	_set_active(true)


func _smash() -> void:
	if _broken:
		return
	_broken = true
	_set_active(false)  # 隐藏+关碰撞，重生时恢复
	# 级联：把紧挨着的墙也一起砸掉。_broken 守卫保证每块只处理一次、不会无限递归。
	for other in get_tree().get_nodes_in_group("stun_walls"):
		if other != self and other is StunWall and not other._broken:
			if global_position.distance_to(other.global_position) <= neighbor_radius:
				other._smash()


func _set_active(active: bool) -> void:
	visible = active
	# 物理回调里改碰撞用 set_deferred，避免报错。
	_solid.set_deferred("disabled", not active)


func _touching_player() -> SoftPlayer:
	for body in _detect.get_overlapping_bodies():
		if body is SoftPlayer:
			return body
	return null
