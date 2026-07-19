class_name Drawbridge
extends StaticBody2D

## 吊桥。默认升起（竖着，过不去）；拉杆拉动 → 绕右端铰链旋转放下成水平，玩家可走过。
##
## 【铰链】= 本节点的原点(0,0)。请把桥板（碰撞 + Sprite）都摆在原点**左边**，
##   把原点对准"最右侧那一格"（旋转就绕它转）。
##
## 【接线】零连线：把拉杆 Lever 的 target 拖成这个吊桥即可——拉杆拉动会调 set_active(true) 放桥。
## 【复位】进 "resettable" 组：死了重生时自动收回（升起）。
##
## 视觉务必用 Sprite2D（Node2D），不要 TextureRect——旋转要绕原点，Control 节点对不齐。

## 升起(收桥)时的角度。若转反了就把这个改成 -90。
@export var raised_deg := 90.0
## 放下(桥水平可走)时的角度。
@export var lowered_deg := 0.0
## 放/收桥的动画时长（秒）。
@export var move_time := 0.6

var _tween: Tween


func _ready() -> void:
	add_to_group("resettable")
	rotation_degrees = raised_deg   # 初始：升起


## 供 Lever 的 target 调用。true = 放桥（水平），false = 收桥（竖起）。
func set_active(value: bool) -> void:
	_rotate_to(lowered_deg if value else raised_deg)


## 重生时由 RespawnManager 通过 call_group("resettable", "reset_state") 调用：收回。
func reset_state() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	rotation_degrees = raised_deg


func _rotate_to(deg: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", deg, move_time)
