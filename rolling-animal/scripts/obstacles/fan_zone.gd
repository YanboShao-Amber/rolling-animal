@tool
class_name FanZone
extends Area2D

## 风扇区（母 scene / graybox）。
##
## 砖块约定：装置本体是 1 个 128×128 方块（顶左为原点，占据一个 tile 格）。
## 但风的作用区往上延伸 wind_height_tiles 格 —— 竖井里要把小球托高一段，
## 只有 128 高的风区托不动，所以风柱高度单独可调，且用 @tool 在编辑器里实时可见。
##
## 施力：主角 SoftPlayer 是 CharacterBody2D，直接改 velocity.y。
## 力与大小成反比（越小飘越高），以 player.gravity 为基准自平衡：
##   size == neutral_size -> 升力=重力 -> 悬停
##   size <  neutral_size -> 升力>重力 -> 净上升
##   size >  neutral_size -> 升力<重力 -> 净下沉（大了压不住）

const TILE := 128.0

## 风柱高度（单位=128 格），从装置底部向上延伸。1 格几乎托不住，竖井里给 4~6。
@export_range(1, 20, 1) var wind_height_tiles := 5:
	set(value):
		wind_height_tiles = maxi(value, 1)
		_rebuild_zone()

## 中性大小：此大小升力与重力平衡。比它小往上飘，比它大往下沉。
@export_range(0.4, 2.0, 0.01) var neutral_size := 1.0
## 升力总强度倍率。1.0 = 中性大小时正好抵消主角自身重力；调大整体更冲。
@export_range(0.1, 4.0, 0.05) var lift_multiplier := 1.0
## 向上速度上限，避免长竖井里无限加速冲顶。
@export var max_rise_speed := 1100.0


func _ready() -> void:
	_rebuild_zone()


func _rebuild_zone() -> void:
	# 顶左原点：装置格 = 局部 [0,128]x[0,128]；风柱从底(y=128)向上到 y=128-H。
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return  # 加载早期子节点还没就绪，_ready 会再刷一次
	var h := wind_height_tiles * TILE
	var rect := shape_node.shape as RectangleShape2D
	if rect:
		rect.size = Vector2(TILE, h)
		shape_node.position = Vector2(TILE * 0.5, TILE - h * 0.5)
	var column := get_node_or_null("WindColumn") as Polygon2D
	if column:
		column.polygon = PackedVector2Array([
			Vector2(0, TILE), Vector2(TILE, TILE),
			Vector2(TILE, TILE - h), Vector2(0, TILE - h),
		])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return  # @tool：编辑器里不施力
	for body in get_overlapping_bodies():
		if body is SoftPlayer:
			_apply_lift(body, delta)


func _apply_lift(player: SoftPlayer, delta: float) -> void:
	var size := maxf(player.current_size_scale, 0.01)
	var lift_accel := player.gravity * lift_multiplier * (neutral_size / size)
	player.velocity.y -= lift_accel * delta
	# 只夹上升速度，不干预下沉（大体型该沉就让它沉）。
	if player.velocity.y < -max_rise_speed:
		player.velocity.y = -max_rise_speed
