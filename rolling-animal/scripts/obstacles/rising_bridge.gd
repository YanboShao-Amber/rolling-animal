class_name RisingBridge
extends StaticBody2D

## 升起桥/平台。默认藏在下面（关碰撞，玩家过不去）；拉杆拉动 → 沿 y 升起到位、开碰撞，玩家可走。
##
## 【摆放】把节点摆在"升起到位"的位置（编辑器里看到的就是升好后的样子）。
##   运行时它会自动先落到下面 rise_height 处藏起来，拉杆拉了才升上来。
##   记得让下面的位置被地形挡住/够深，别让玩家看见它在下面待着。
##
## 【接线】零连线：把拉杆 Lever 的 target 拖成这个桥即可（拉动会调 set_active(true)）。
## 【复位】进 "resettable" 组：死了重生自动落回下面。
##
## 视觉用 Sprite2D（Node2D），跟着一起动。

## 从下面升起的高度（藏在到位处下方多远）。要够深，让它落下时被挡住/看不见。
@export var rise_height := 160.0
## 升/落动画时长（秒）。
@export var move_time := 0.5

@onready var _collision: CollisionShape2D = $CollisionShape2D

var _up_y := 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("resettable")
	_up_y = position.y            # 你摆的位置 = 升起到位的位置
	_go_down_instant()            # 初始：藏在下面


## 供 Lever 的 target 调用。true = 升起（可走），false = 落下（过不去）。
func set_active(value: bool) -> void:
	if value:
		_collision.set_deferred("disabled", false)
		_tween_to(_up_y)
	else:
		_collision.set_deferred("disabled", true)
		_tween_to(_up_y + rise_height)


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用：落回下面。
func reset_state() -> void:
	_go_down_instant()


func _go_down_instant() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	position.y = _up_y + rise_height
	_collision.set_deferred("disabled", true)


func _tween_to(y: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", y, move_time)
