extends Control

## 临时测试台：只把主角调到方便测试的状态。
## 死亡 / 检查点重生交给场景里的 RespawnManager 节点，这里不掺和。

## 地刺 / 检查点测试：开（主角自动向右滚过关）。风扇浮力测试：关（原地测上下）。
## 注意主角没有手动左右键，横向移动只靠自动前进，所以走位测试必须开这个。
@export var auto_forward := true

@onready var player: SoftPlayer = $Player


func _ready() -> void:
	player.debug_label.visible = true          # 屏幕上看实时 SIZE
	player.auto_forward_enabled = auto_forward
	# 应用在角色选择界面选中的角色（与第 1 关 farm_level_test 一致）。
	# 正常流程会先经过角色选择，这里据此替换主角贴图；直接运行本场景时保留场景自带的默认外观。
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		player.setup_character(game_state.selected_character_data.duplicate(true))
