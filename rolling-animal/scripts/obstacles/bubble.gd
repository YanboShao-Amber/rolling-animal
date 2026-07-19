class_name Bubble
extends Node2D

## 气泡（浮力潜水版）。
##
## 生命周期：
##   1) 按钮/拉杆 set_active(true) → 气泡出现在生成点，等玩家来碰。
##   2) 玩家碰到 → 自动获取：套在玩家身上，开始 grace_time 秒无敌。
##   3) 获取后每帧：跟随球心、整体随球大小缩放(不旋转)、给玩家浮力、免疫毒水、可正常跳。
##   4) grace 过后：碰到"非水实体(陆地/平台/天花板)"就破 → 免疫解除 → 落水淹死。
##
## 大小↔深度：最小(0.5)球底齐水面；最大(2.0)完全没入。变大→下沉→跳得更低。
## 浮力只在"真泡在毒水里"时施加；水面高度默认自动读毒水(Killzone)。
##
## 【缩放】直接缩放气泡根节点，所以 Detect 和 Shell 一起随球缩放。
##   给 Shell(你的气泡图) 在编辑器里设好 scale，让它在球=1 倍时正好裹住球，之后自动跟着缩放。
## 【场景要求】子节点：Detect(Area2D + CircleShape2D，半径设 64) + Shell(Node2D 视觉，如 Sprite2D)。

# ---------------- 可调参数 ----------------
@export var grace_time := 3.0            ## 获取后无敌秒数。
@export var settle_speed := 900.0        ## 稳到目标深度的速度(px/s)，越大越快贴到浮线。
@export var auto_detect_surface := false ## true=碰毒水自动读水面；false=用下面写死的 surface_y（省心）。
@export var surface_y := 700.0           ## 手填水面 y（仅 auto_detect_surface=false 时用）。
@export var surface_offset := 0.0        ## 浮线微调：实际浮线 = 水面 + 这个。往上抬填负数(如 -50)。

# ---------------- 内部 ----------------
const BASE_RADIUS := 64.0                # 与 SoftPlayer 一致

@onready var _detect: Area2D = $Detect

var _active := false
var _acquired := false
var _player: SoftPlayer = null
var _grace_left := 0.0
var _home_pos := Vector2.ZERO
var _has_water := false
var _water_surface := 0.0


func _ready() -> void:
	_home_pos = global_position
	set_active(false)


## 供 WeightButton / Lever 的 target 调用。
func set_active(value: bool) -> void:
	_active = value
	if not value:
		_release()
		return
	_acquired = false
	_player = null
	global_position = _home_pos
	scale = Vector2.ONE
	visible = true
	_detect.monitoring = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not _acquired:
		_try_acquire()
		return
	if not is_instance_valid(_player):
		_release()
		return

	_grace_left = maxf(_grace_left - delta, 0.0)
	var size: float = _player.current_size_scale

	# 跟随球心 + 整体随球缩放（Detect 和 Shell 一起变）
	global_position = _player.global_position + Vector2(0.0, -BASE_RADIUS * size)
	scale = Vector2.ONE * size

	# 允许起跳：主角的跳跃要靠 is_on_floor 或 coyote_timer(土狼时间)，水里都没有 → 跳不了。
	# 浮着时(不上升)每帧刷新土狼时间 + 清零跳跃次数，让主角以为"站在水面上"，就能正常跳。
	if _player.velocity.y >= 0.0:
		_player.jump_count = 0
		_player.coyote_timer = 0.2

	# 水面
	if auto_detect_surface:
		var s := _detect_water_surface()
		if s != INF:
			_water_surface = s
			_has_water = true
	else:
		_water_surface = surface_y
		_has_water = true

	# 浮力只在泡进水里才托；水面上方 = 自由下落
	if _has_water:
		_apply_buoyancy(size, _water_surface + surface_offset, delta)

	# grace 过后碰到非水实体 → 破
	if _grace_left <= 0.0 and _touching_solid():
		_pop()


func _try_acquire() -> void:
	for body in _detect.get_overlapping_bodies():
		if body is SoftPlayer:
			_player = body
			_acquired = true
			_grace_left = grace_time
			_has_water = false
			body.add_to_group("bubble_immune")
			return


func _detect_water_surface() -> float:
	for area in _detect.get_overlapping_areas():
		if area is Killzone:
			return area.global_position.y   # 毒水顶左原点=水面
	return INF


func _apply_buoyancy(size: float, surface: float, delta: float) -> void:
	var f := clampf((size - 0.5) / 1.5, 0.0, 1.0)
	var target_feet_y := surface + f * (2.0 * BASE_RADIUS) * size
	# 上升(跳跃)时完全不干预 → 正常抛物线。
	if _player.velocity.y < 0.0:
		return
	# 落回/浮着：稳到目标深度（清零竖直速度 + 平滑推向浮线）。绝不会斜漂。
	_player.velocity.y = 0.0
	_player.global_position.y = move_toward(_player.global_position.y, target_feet_y, settle_speed * delta)


func _touching_solid() -> bool:
	# 1) 检测区碰到任何非玩家的实体(StaticBody 障碍等)
	for body in _detect.get_overlapping_bodies():
		if body != _player:
			return true
	# 2) 玩家自己撞到实体(含 TileMap 地形)——move_and_slide 会上报
	if _player.get_slide_collision_count() > 0:
		return true
	return false


func _pop() -> void:
	_release()


func _release() -> void:
	if is_instance_valid(_player):
		_player.remove_from_group("bubble_immune")
	_acquired = false
	_player = null
	_has_water = false
	visible = false
	if is_instance_valid(_detect):
		_detect.monitoring = false
