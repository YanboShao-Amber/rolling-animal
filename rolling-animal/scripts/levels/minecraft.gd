extends Control

@export_category("Camera Settings")
@export var camera_look_ahead_x := 180.0  # 让相机视口稍微超前于玩家
@export var camera_offset_y := -80.0      # 让玩家在屏幕视野偏下方
@export var camera_speed_x := 15.0        # X轴跟随速度（数值越大，跟得越紧，保持同速）
@export var camera_speed_y := 2.5         # Y轴跟随速度（数值越小，跳跃时相机的上下起伏越轻微、平滑）

@export_category("Jump Override")
# 仅在本关卡（Minecraft）提高跳跃高度。数值越负，跳得越高。
# 玩家默认值为 -1300，这里覆盖为更高的跳跃力度；其他场景不受影响。
@export var player_jump_velocity := -1800.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# 开启玩家的自动向前移动（调用玩家代码里的逻辑）
	player.auto_forward_enabled = true
	# 只在本场景覆盖跳跃力度，让玩家跳得更高（不改动共享的玩家脚本/场景）。
	player.jump_velocity = player_jump_velocity
	
	# 初始化时，直接将相机吸附到正确位置，防止画面一进入时有剧烈滑动
	camera.global_position = Vector2(
		player.global_position.x + camera_look_ahead_x,
		player.global_position.y + camera_offset_y
	)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
		
	# --- 1. X轴平滑跟随 ---
	# 使用较高的平滑速度，使相机几乎与玩家保持同速向前滚动
	var target_x := player.global_position.x + camera_look_ahead_x
	camera.global_position.x = lerpf(
		camera.global_position.x, 
		target_x, 
		1.0 - exp(-camera_speed_x * delta)
	)
	
	# --- 2. Y轴轻微跟随 ---
	# 使用较低的平滑速度，这样当玩家剧烈跳跃或下落时，相机只会慵懒、轻微地上下浮动
	var target_y := player.global_position.y + camera_offset_y
	camera.global_position.y = lerpf(
		camera.global_position.y, 
		target_y, 
		1.0 - exp(-camera_speed_y * delta)
	)
