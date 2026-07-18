# 可以被撞碎的伪装刚体/障碍
# 当玩家的大小超过1.3倍，则当前障碍被玩家撞碎。
# 如果玩家大小小于1.3，则当前障碍是一个正常的刚体
extends StaticBody2D

@export var destroy_threshold: float = 1.3

# 获取我们刚刚新建的 Area2D 节点
# 注意：确保这里节点的名字与你在场景树中创建的完全一致
@onready var detection_area: Area2D = $Area2D 

func _physics_process(_delta: float) -> void:
	# 通过子节点 Area2D 获取当前所有重叠的 Body
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# 检查重叠的 body 是不是我们的 SoftPlayer
		if body is SoftPlayer:
			# 持续读取 Player 的 current_size_scale
			# 放在 _physics_process 的好处是：即使玩家站在玻璃上时突然变大，也能立刻触发销毁
			if body.current_size_scale > destroy_threshold:
				queue_free()
				break
