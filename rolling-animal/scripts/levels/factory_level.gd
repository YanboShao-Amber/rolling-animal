extends Control

## Factory（第 3 关）关卡脚本。
##
## 职责只有两个时机：进关倒计时后"开跑"、抵达终点旗帜后弹"通关界面"。
## best time 本身由全局 GameState 自动记录，这里不存不算：
##   · 倒计时结束时 → SceneTransition 调 GameState.start_level_timer() 开始计时；
##   · 通关界面(win_scene) 弹出的 _ready 里 → 调 GameState.finish_level_timer()，
##     它会和 best_level_times_msec 里的旧纪录比较，更快就刷新最佳成绩；
##   · 选关界面(level_menu) 再用 get_best_level_time() 把它读出来显示。
## Factory 已登记在 game_state.gd 的 TIMED_LEVEL_SCENES 里，所以进关会自动出现计时 Label。
##
## 注意：本脚本只给 Factory 用；测试台 obstacle_test.gd 被 Stage1/ObstacleTest 共用，故另起一份。

const WIN_SCENE := preload("res://scenes/ui/win_scene.tscn")
const LEVEL_MENU_SCENE := "res://scenes/ui/level_menu.tscn"
const LEVEL_NUMBER := 3  # Factory 是第 3 关（见 level_menu.gd / game_state.gd 的关卡表）

## 自动向前：真=主角自动向右滚（正式过关）。保留这个开关是为了和旧测试台行为兼容、方便调试。
@export var auto_forward := true

@onready var player: SoftPlayer = $Player
@onready var win_landmark: WinLandmark = $Mechanics/Status/WinLandmark

var win_popup: WinPopup
var _popup_layer: CanvasLayer  # 装通关界面用，代码里现建，不依赖场景里的任何 UI 节点


func _ready() -> void:
	# 先按住主角别动，等倒计时结束再开跑——这样"开跑"和"开始计时"同步，成绩才准。
	player.auto_forward_enabled = false
	if is_instance_valid(win_landmark):
		win_landmark.player_reached.connect(_on_player_reached_win)
	_start_after_countdown()


func _start_after_countdown() -> void:
	var transition := get_node_or_null("/root/SceneTransition")
	if transition:
		# 等转场动画放完，确保 GameState 已经建好计时 Label；再放 3-2-1 倒计时。
		await transition.wait_until_transition_finished()
		await transition.play_countdown()   # 倒计时结束时内部会调 GameState.start_level_timer()
	if is_instance_valid(player) and not is_instance_valid(win_popup):
		player.auto_forward_enabled = auto_forward


func _on_player_reached_win() -> void:
	if is_instance_valid(win_popup):
		return
	player.auto_forward_enabled = false
	player.velocity = Vector2.ZERO
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		game_state.complete_level(LEVEL_NUMBER)  # 标记通关（第 3 关是最后一关）
	# 弹通关界面：它在自己的 _ready 里调 finish_level_timer() → 自动记录/刷新 best time。
	# 自己建个 CanvasLayer 来装，避免依赖场景里可能被删掉的 UI 节点。
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 90  # 盖在关卡上方；GameState 的计时 Label 在 100，仍然可见
	add_child(_popup_layer)
	win_popup = WIN_SCENE.instantiate()
	_popup_layer.add_child(win_popup)
	win_popup.closed.connect(_on_win_popup_closed)
	win_popup.left_button_pressed.connect(_on_win_menu_requested)
	win_popup.right_button_pressed.connect(_on_win_menu_requested)


func _on_win_menu_requested() -> void:
	get_node("/root/SceneTransition").transition_to(LEVEL_MENU_SCENE)


func _on_win_popup_closed() -> void:
	if is_instance_valid(win_popup):
		win_popup.queue_free()
		win_popup = null
	if is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
		_popup_layer = null
	player.auto_forward_enabled = auto_forward
