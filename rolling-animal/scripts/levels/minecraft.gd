extends Control

const WIN_SCENE := preload("res://scenes/ui/win_scene.tscn")
const LEVEL_MENU_SCENE := "res://scenes/ui/level_menu.tscn"
const LEVEL_NUMBER := 2  # Minecraft 是第 2 关（见 level_menu.gd 的 LEVEL_SCENES）

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
@onready var coin_count_label: Label = $HUD/CoinCounter/CoinCountLabel
@onready var hud: CanvasLayer = $HUD
@onready var win_landmark: WinLandmark = $WinLandmark

var win_popup: WinPopup

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

	# 让左上角的金币计数 HUD 跟随全局 GameState 实时刷新（HUD 在 CanvasLayer 中，不随相机滚动）。
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.coins_changed.connect(_update_coin_hud)
		_update_coin_hud(game_state.coin_count)

	# 应用在角色选择界面选中的角色（与第 1 关 farm_level_test 一致）。
	# 正常流程会先经过角色选择，这里据此替换主角贴图；直接运行本场景时保留场景自带的默认外观。
	if game_state and game_state.has_selected_character() \
			and game_state.selected_character_data is Dictionary:
		player.setup_character(game_state.selected_character_data.duplicate(true))

	# 抵达终点旗帜（WinLandmark）后弹出胜利界面（参考 farm_level_test 的 win landmark 逻辑）。
	win_landmark.player_reached.connect(_on_player_reached_win)

func _update_coin_hud(total: int) -> void:
	coin_count_label.text = "× %d" % total

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


# 玩家抵达终点旗帜：停下玩家、记录通关进度并弹出胜利界面。
func _on_player_reached_win() -> void:
	if is_instance_valid(win_popup):
		return
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.complete_level(LEVEL_NUMBER)
	win_popup = WIN_SCENE.instantiate()
	hud.add_child(win_popup)
	win_popup.closed.connect(_on_win_popup_closed)
	win_popup.left_button_pressed.connect(_on_win_menu_requested)
	win_popup.right_button_pressed.connect(_on_win_menu_requested)


func _on_win_menu_requested() -> void:
	get_node("/root/SceneTransition").transition_to(LEVEL_MENU_SCENE)


func _on_win_popup_closed() -> void:
	if is_instance_valid(win_popup):
		win_popup.queue_free()
		win_popup = null
	player.auto_forward_enabled = true
