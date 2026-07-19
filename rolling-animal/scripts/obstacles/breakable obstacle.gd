# 可以被撞碎的伪装刚体/障碍
# 当玩家的大小超过1.3倍，则当前障碍被玩家撞碎。
# 如果玩家大小小于1.3，则当前障碍是一个正常的刚体
extends StaticBody2D

@export var destroy_threshold: float = 1.3
## 开启后：撞碎时不销毁，只隐藏+关碰撞；玩家死亡重生时由 RespawnManager 通过
## call_group("resettable", "reset_state") 恢复。默认关闭，其他场景行为不变。
@export var restore_on_respawn := false

# 获取我们刚刚新建的 Area2D 节点
# 注意：确保这里节点的名字与你在场景树中创建的完全一致
@onready var detection_area: Area2D = $Area2D
@onready var solid_shape: CollisionShape2D = $CollisionShape2D

var _broken := false


func _ready() -> void:
	if restore_on_respawn:
		add_to_group("resettable")  # 让 RespawnManager 重生时调 reset_state() 恢复


func _physics_process(_delta: float) -> void:
	if _broken:
		return
	# 通过子节点 Area2D 获取当前所有重叠的 Body
	var overlapping_bodies = detection_area.get_overlapping_bodies()

	for body in overlapping_bodies:
		# 检查重叠的 body 是不是我们的 SoftPlayer
		if body is SoftPlayer:
			# 持续读取 Player 的 current_size_scale
			# 放在 _physics_process 的好处是：即使玩家站在玻璃上时突然变大，也能立刻触发销毁
			if body.current_size_scale > destroy_threshold:
				_break()
				break


func _break() -> void:
	if restore_on_respawn:
		_broken = true
		_set_active(false)  # 隐藏+关碰撞，但不销毁，方便重生恢复
	else:
		queue_free()         # 老行为：直接销毁


func _set_active(active: bool) -> void:
	visible = active
	# 物理回调里改碰撞形状要用 set_deferred，避免“正在处理查询”报错。
	solid_shape.set_deferred("disabled", not active)


## 通用复位接口：玩家死亡重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if not _broken:
		return
	_broken = false
	_set_active(true)
