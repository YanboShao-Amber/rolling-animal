class_name Lever
extends Area2D

## 拉杆（54×54）。和 WeightButton 同款逻辑，只是包装成拉杆 + 两张图切换。
##
## · 玩家不够大路过 → 没反应。
## · 玩家够大（current_size_scale ≥ pull_size）路过 → 拉杆往右掰、锁定，并启用 target。
##
## 视觉：两个子节点 HandleLeft（未掰，默认显示）/ HandleRight（掰动后显示），脚本切换谁可见。
##   给这两个 Sprite2D 各设一张你的拉杆图即可（左图 / 右图）。
##
## 接线：进 "resettable" 组 → 死了重生时自动复位回左（未掰）。
##   想联动别的东西：把 target 拖成要启用/显示的节点（门 / 延伸平台 / 气泡…），
##   或连 pulled / reset_back 信号自己接。

signal pulled       # 掰动时
signal reset_back   # 复位回左时

## 掰动所需的最小体型。
@export var pull_size := 1.3
## 掰动时启用/显示、复位时停用/隐藏的目标（可留空，改用 pulled 信号）。
@export var target: Node
## true = 掰一次就锁定；false = 只在够大玩家在上面时保持掰动，离开就弹回左。
@export var stay_pulled := true

@onready var _left: CanvasItem = $HandleLeft
@onready var _right: CanvasItem = $HandleRight

var _pulled := false


func _ready() -> void:
	add_to_group("resettable")
	_apply(false)


func _physics_process(_delta: float) -> void:
	# 和按钮一样逐帧检测：贴着拉杆时才变大也能立刻掰动。
	var big := _has_big_player()
	if big and not _pulled:
		_set_pulled(true)
	elif not stay_pulled and not big and _pulled:
		_set_pulled(false)


func _has_big_player() -> bool:
	for body in get_overlapping_bodies():
		if body is SoftPlayer and body.current_size_scale >= pull_size:
			return true
	return false


func _set_pulled(value: bool) -> void:
	_pulled = value
	_apply(value)
	if value:
		pulled.emit()
	else:
		reset_back.emit()


func _apply(value: bool) -> void:
	# 两张图切换：未掰=左，掰了=右。
	if _left:
		_left.visible = not value
	if _right:
		_right.visible = value
	# 联动 target（如门/平台/气泡）——和 WeightButton 完全一致。
	if target:
		if target.has_method("set_active"):
			target.set_active(value)
		else:
			target.visible = value
			target.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if _pulled:
		_set_pulled(false)
