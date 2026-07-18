class_name Bubble
extends Node2D

## 气泡（graybox 占位版）。
## 按下按钮 → 气泡立刻出现在岸边（可见、静止）。玩家滚进去被“裹住”，气泡跟着一起横穿毒池，
## 玩家在里面自转前进、外壳不转。到对岸上岸 → 气泡消失。没按钮 → 没气泡 → 掉进毒水。
##
## 由 WeightButton 的 target 调 set_active(true/false) 控制出现/消失。
## ⚠️ 占位实现（把玩家钳在水面 y）。等 §2 气泡机制定稿再换正式版。

const SHELL_OFFSET := Vector2(0, -70)  # 外壳抬到球身中心，别贴在脚下

@export var surface_y := 700.0   ## 托住玩家的水面高度（=毒池所在地面 y）
@export var pool_end_x := 0.0     ## 玩家 x 到这里=上岸，气泡消失（设成毒池对岸 x）

var _active := false
var _player: SoftPlayer = null

@onready var _board: Area2D = $BoardArea
@onready var _shell: Node2D = $Shell


func _ready() -> void:
	_board.body_entered.connect(_on_board)
	set_active(false)


## 供 WeightButton 调用。true=在岸边出现气泡可上；false=消失。
func set_active(value: bool) -> void:
	print("[Bubble] set_active ", value)  # 调试，验证后删
	_active = value
	_board.monitoring = value
	_player = null
	_shell.position = SHELL_OFFSET   # 回到岸边 home 位
	_shell.visible = value            # 关键：按下按钮就在岸边显示气泡（之前漏了这行）
	visible = value


func _on_board(body: Node2D) -> void:
	if _active and body is SoftPlayer:
		print("[Bubble] 玩家上泡")  # 调试，验证后删
		_player = body


func _physics_process(_delta: float) -> void:
	if not _active or _player == null:
		return
	# 裹住玩家：钳在水面、抵消下坠；玩家靠自动前进横穿
	if _player.velocity.y > 0.0:
		_player.velocity.y = 0.0
	_player.global_position.y = surface_y
	_shell.global_position = _player.global_position + SHELL_OFFSET  # 外壳跟随、不随玩家自转
	# 上岸 → 气泡用掉、消失（按钮仍按下，重生才会刷新）
	if pool_end_x != 0.0 and _player.global_position.x >= pool_end_x:
		_active = false
		_board.monitoring = false
		_player = null
		_shell.visible = false
		visible = false
