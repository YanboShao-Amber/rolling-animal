class_name StunEffect
extends Node2D

## 眩晕特效母本 scene：几颗星星在头顶沿椭圆轨道转圈，转一小段后自毁。
##
## 【用法】实例化后 add_child 到要眩晕的对象（比如玩家），放到头顶偏移处。
## 播放结束会发 finished 信号——调用方 await 它再做后续（比如重生）。
## RespawnManager 已支持把它当作 death_effect：死亡时先播它、再传送重生。
##
## 【换成你的星星素材】打开本母本 StunEffect.tscn，在根节点检查器里把 star_texture
## 设成你的星星贴图即可（留空时用生成的黄色占位星）。

signal finished

@export var star_texture: Texture2D        ## 星星贴图；留空则用生成的黄色占位星
@export_range(1, 6, 1) var star_count := 2
@export var radius_x := 44.0               ## 椭圆横向半径（宽）
@export var radius_y := 15.0               ## 椭圆纵向半径（扁，营造俯视透视感）
@export var spin_speed := 9.0              ## 转速（弧度/秒）
@export var duration := 0.8                ## 持续时间（秒），到点自毁

var _stars: Array[Node2D] = []
var _angle := 0.0
var _elapsed := 0.0


func _ready() -> void:
	for i in star_count:
		var star := _make_star()
		add_child(star)
		_stars.append(star)
	_update_stars(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_angle += spin_speed * delta
	_update_stars(delta)
	# 结尾 0.2 秒淡出，别硬切。
	modulate.a = clampf((duration - _elapsed) / 0.2, 0.0, 1.0)
	if _elapsed >= duration:
		finished.emit()
		queue_free()


func _update_stars(delta: float) -> void:
	var count := _stars.size()
	for i in count:
		var phase := _angle + TAU * float(i) / float(count)
		var star := _stars[i]
		star.position = Vector2(cos(phase) * radius_x, sin(phase) * radius_y)
		# 椭圆下半(靠前)放大、置顶；上半(靠后)缩小、变暗、置底——假装前后深度。
		var depth := (sin(phase) + 1.0) * 0.5      # 0=后, 1=前
		var s := lerpf(0.7, 1.05, depth)
		star.scale = Vector2(s, s)
		star.modulate.a = lerpf(0.55, 1.0, depth)
		star.z_index = 1 if sin(phase) >= 0.0 else -1
		star.rotation += delta * 6.0               # 星星自转一点，更活


func _make_star() -> Node2D:
	if star_texture:
		var spr := Sprite2D.new()
		spr.texture = star_texture
		return spr
	# 没贴图时的占位：代码生成一个黄色五角星。
	var poly := Polygon2D.new()
	poly.color = Color(1.0, 0.85, 0.2)
	var pts := PackedVector2Array()
	var outer := 12.0
	var inner := 5.0
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := -PI / 2.0 + float(i) * PI / 5.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	poly.polygon = pts
	return poly
