# 变小buff的original prefab
extends Area2D

@export var mushroom_shrink_size := 0.2
@export var buff_duration := 3.0

# 用于记录玩家被改变前的原本体型限制
var _original_min_size: float
var _original_max_size: float

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is SoftPlayer:
		# 1. 禁用碰撞并隐藏图片
		collision_shape.set_deferred("disabled", true)
		sprite.hide()
		
		# 2. 强制锁定玩家体型
		_apply_shrink_lock(body)
		
		# 3. 锁定 3 秒
		await get_tree().create_timer(buff_duration).timeout
		
		# 4. 恢复玩家体型限制
		_restore_size(body)
		
		# 5. 彻底销毁蘑菇节点
		queue_free()


func _apply_shrink_lock(player: SoftPlayer) -> void:
	# 记录玩家当前的上下限，以备后续恢复
	_original_min_size = player.minimum_size_scale
	_original_max_size = player.maximum_size_scale
	
	# 将玩家的最大和最小体型都强制设为 0.2，实现彻底锁定
	player.minimum_size_scale = mushroom_shrink_size
	player.maximum_size_scale = mushroom_shrink_size
	
	# 同步修改当前和目标体型
	player.target_size_scale = mushroom_shrink_size
	# 可选：如果希望玩家“瞬间”变成0.2，可以保留下一行。
	# 如果希望是“平滑”缩短到0.2，请将下一行注释掉。
	player.current_size_scale = mushroom_shrink_size 
	
	player._time_since_click = 0.0
	player.click_frequency = 0.0


func _restore_size(player: SoftPlayer) -> void:
	# 安全检查，防止玩家在3秒内已经死亡或被销毁
	if is_instance_valid(player):
		# 恢复玩家原本的体型上限和下限
		player.minimum_size_scale = _original_min_size
		player.maximum_size_scale = _original_max_size
		
		# 将目标体型设回下限，让玩家能依靠自身 _process 里的 lerpf 平滑恢复到 0.5
		player.target_size_scale = _original_min_size
