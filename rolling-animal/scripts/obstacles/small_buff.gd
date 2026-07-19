# 变小buff的original prefab
extends Area2D

@export var mushroom_shrink_size := 0.2
@export var buff_duration := 3.0

# 记录玩家被改变前的原本体型限制
var _original_min_size := 0.5
var _original_max_size := 2.0
var _eaten := false
var _player: SoftPlayer = null
var _buff_left := 0.0            # >0 表示 buff 进行中（用它当计时器，可随时取消）

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# 加入 "resettable" 组：玩家死亡重生时 RespawnManager 会调 reset_state() 复位。
	add_to_group("resettable")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _buff_left > 0.0:
		_buff_left -= delta
		if _buff_left <= 0.0:
			_end_buff()           # 时间到 → 正常解锁


func _on_body_entered(body: Node2D) -> void:
	if _eaten or not (body is SoftPlayer):
		return
	_eaten = true
	collision_shape.set_deferred("disabled", true)
	sprite.hide()
	_apply_shrink_lock(body)
	_player = body
	_buff_left = buff_duration     # 开始计时（不再用 await，方便重生时取消）


func _apply_shrink_lock(player: SoftPlayer) -> void:
	_original_min_size = player.minimum_size_scale
	_original_max_size = player.maximum_size_scale
	# 上下限都锁成 0.2，彻底钉住体型
	player.minimum_size_scale = mushroom_shrink_size
	player.maximum_size_scale = mushroom_shrink_size
	player.target_size_scale = mushroom_shrink_size
	player.current_size_scale = mushroom_shrink_size
	player._time_since_click = 0.0
	player.click_frequency = 0.0


func _end_buff() -> void:
	# 解除锁定，恢复体型上下限，让玩家能重新变大变小。
	if is_instance_valid(_player):
		_player.minimum_size_scale = _original_min_size
		_player.maximum_size_scale = _original_max_size
		_player.target_size_scale = _original_min_size
	_buff_left = 0.0
	_player = null


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	# 关键修复：如果是在 buff 进行中死的，立刻解锁体型上下限，别让缩小状态继承到下一条命。
	if _buff_left > 0.0 and is_instance_valid(_player):
		_player.minimum_size_scale = _original_min_size
		_player.maximum_size_scale = _original_max_size
		_player.reset_size()      # 用恢复后的上下限，把玩家重新设回默认大小
	_buff_left = 0.0
	_player = null
	# 让蘑菇重新出现，可再次吃。
	_eaten = false
	sprite.show()
	collision_shape.set_deferred("disabled", false)
