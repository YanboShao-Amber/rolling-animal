class_name WeightButton
extends Area2D

## 重量按钮（母本 / graybox）。
##
## 玩家“够沉”（current_size_scale >= press_threshold）压过 / 停在上面就按下；太小压不动，
## 按钮维持未按下状态。按下后（默认）锁定，并启用 target（比如气泡）。
##
## 【怎么用】
## 1. 摆在地上（顶左原点，放在地面表面 y 上）。
## 2. 把 target 拖成“按下后要出现的东西”（气泡群 / 一扇门 / 一段桥…）——按下=显示并启用，
##    未按下/复位=隐藏并停用。也可以不填 target，改用 pressed 信号自己接。
## 3. press_threshold 设成需要多大才压得动（默认 1.3，得主动变大）。
##
## 【复位】自动进 "resettable" 组：玩家重生时 RespawnManager 会调 reset_state() 把它弹回未按下，
##   所以重来一次得重新变大再压（否则过了检查点就永远是按下状态了）。
##
## 【摆放】检查点要放在按钮“之前”，这样死了重来能重新压按钮。

signal pressed
signal released

## 需要的最小大小（够沉才压得下）。
@export_range(0.5, 2.0, 0.05) var press_threshold := 1.3
## 按下后启用/显示、复位后停用/隐藏的目标（如气泡群）。可留空，改用 pressed 信号。
@export var target: Node
## true = 按一次就锁定；false = 只在“够大的玩家在上面”时才按住，离开就弹起。
@export var stay_pressed := true

var _pressed := false


func _ready() -> void:
	add_to_group("resettable")
	# 延后一帧再套用初始状态：确保 target（气泡/桥等）自己的 _ready 已跑完，
	# 否则会在它 @onready 还没就绪时调用 set_active → 崩。
	_apply.call_deferred(false)


func _physics_process(_delta: float) -> void:
	# 放 _physics_process：玩家站在按钮上才变大也能立刻按下。
	var has_big := _has_big_player()
	if has_big and not _pressed:
		_set_pressed(true)
	elif not stay_pressed and not has_big and _pressed:
		_set_pressed(false)


func _has_big_player() -> bool:
	for body in get_overlapping_bodies():
		if body is SoftPlayer and body.current_size_scale >= press_threshold:
			return true
	return false


func _set_pressed(value: bool) -> void:
	_pressed = value
	print("[WeightButton] pressed=", value, "  target=", target)  # 调试，验证后删
	_apply(value)
	if value:
		pressed.emit()
	else:
		released.emit()


func _apply(value: bool) -> void:
	modulate = Color(0.4, 1.0, 0.5) if value else Color(1, 1, 1)  # graybox：按下变绿
	if target:
		if target.has_method("set_active"):
			target.set_active(value)  # 如气泡：自己管好碰撞/视觉的启停
		else:
			target.visible = value
			target.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用。
func reset_state() -> void:
	if _pressed:
		_set_pressed(false)
