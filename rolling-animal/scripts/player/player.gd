class_name SoftPlayer
extends CharacterBody2D

signal jumped
signal landed
signal size_changed(size_scale: float)

const BASE_RADIUS := 64.0

@export_category("Size")
@export_range(0.5, 2.0, 0.01) var default_size_scale := 0.8
@export_range(0.3, 1.0, 0.01) var minimum_size_scale := 0.5
@export_range(1.0, 3.0, 0.01) var maximum_size_scale := 1.45
@export_range(0.01, 0.3, 0.01) var growth_per_click := 0.075
@export_range(0.1, 3.0, 0.01) var growth_per_second_held := 0.9
@export_range(1.0, 4.0, 0.1) var rapid_click_multiplier := 2.4
@export_range(1.0, 20.0, 0.5) var size_follow_speed := 9.0
@export_range(0.0, 2.0, 0.05) var shrink_delay := 0.35
@export_range(0.01, 1.0, 0.01) var shrink_speed := 0.7

@export_category("Jump")
@export var gravity := 5000.0
@export var jump_velocity := -1300.0
@export_range(1, 10, 1) var maximum_jump_count := 1

@export_group("Jump Forgiveness")
@export_range(0.0, 0.5, 0.01) var jump_buffer_duration := 0.15
@export_range(0.0, 0.5, 0.01) var coyote_duration := 0.10
@export_range(0.0, 0.2, 0.01) var auto_jump_retrigger_delay := 0.03

@export_category("Forward Movement")
@export var auto_forward_enabled := false
@export var base_forward_speed := 330.0
@export var minimum_forward_speed := 350.0
@export var maximum_forward_speed := 430.0
@export var size_speed_exponent := 0.75
@export var forward_acceleration := 1200.0

@onready var size_root: Node2D = $SizeRoot
@onready var growth_pulse_root: Node2D = $SizeRoot/GrowthPulseRoot
@onready var roll_visual_root: Node2D = $SizeRoot/GrowthPulseRoot/RollVisualRoot
@onready var jump_deform_root: Node2D = $SizeRoot/GrowthPulseRoot/RollVisualRoot/JumpDeformRoot
@onready var player_sprite: Sprite2D = $SizeRoot/GrowthPulseRoot/RollVisualRoot/JumpDeformRoot/PlayerSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_label: Label = $DebugLabel

var current_size_scale := 1.0
var target_size_scale := 1.0
var click_frequency := 0.0
var growth_velocity := 0.0
var jump_count := 0
var _time_since_click := 999.0
var _last_click_time := -10.0
var _deform_tween: Tween
var _growth_pulse_tween: Tween
var _damage_flash_tween: Tween
var _respawn_blink_tween: Tween
var _was_on_floor := false
var _ground_bounce_phase := 0.0
var _is_holding_growth := false
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var auto_jump_cooldown_timer := 0.0
var jump_started_this_frame := false


func _ready() -> void:
	current_size_scale = clampf(default_size_scale, minimum_size_scale, maximum_size_scale)
	target_size_scale = current_size_scale
	_update_size_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Single click still gives its instant burst; holding then grows continuously.
			_is_holding_growth = true
			_register_growth_click()
		else:
			_is_holding_growth = false
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_time_since_click += delta
	_update_forward_movement(delta)
	if is_on_floor():
		jump_count = 0
	if not is_on_floor():
		velocity.y += gravity * delta

	_update_jump_forgiveness(delta)

	_was_on_floor = is_on_floor()
	var previous_x := global_position.x
	move_and_slide()
	var moved_distance_x := global_position.x - previous_x
	_update_rolling_visual(moved_distance_x)
	if not _was_on_floor and is_on_floor():
		jump_count = 0
		_play_landing_deform()
		landed.emit()
	elif not _is_deform_tween_active():
		_update_motion_deform(delta, moved_distance_x)


func _update_jump_forgiveness(delta: float) -> void:
	jump_started_this_frame = false
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	auto_jump_cooldown_timer = maxf(auto_jump_cooldown_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = coyote_duration

	# Only a new press fills the buffer; holding does not refresh it forever.
	if Input.is_action_just_pressed("player_jump"):
		jump_buffer_timer = jump_buffer_duration

	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		if _try_start_jump():
			return

	# Preserve automatic repeated jumping while Space remains held.
	if Input.is_action_pressed("player_jump") and is_on_floor() \
			and auto_jump_cooldown_timer <= 0.0:
		_try_start_jump()

	# Consume the current air frame after checking input, so the configured
	# 0.10 seconds is not shortened by one physics tick.
	if not is_on_floor():
		coyote_timer = maxf(coyote_timer - delta, 0.0)


func _try_start_jump() -> bool:
	if jump_started_this_frame:
		return false
	if _get_size_weight() >= 1.0:
		_clear_jump_requests()
		auto_jump_cooldown_timer = auto_jump_retrigger_delay
		return false
	if not _start_jump():
		return false

	jump_started_this_frame = true
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	auto_jump_cooldown_timer = auto_jump_retrigger_delay
	return true


func _clear_jump_requests() -> void:
	jump_buffer_timer = 0.0


func _process(delta: float) -> void:
	if _is_holding_growth:
		# Holding the left button keeps feeding growth so the ball keeps expanding.
		_time_since_click = 0.0
		target_size_scale = clampf(
			target_size_scale + growth_per_second_held * delta,
			minimum_size_scale,
			maximum_size_scale
		)
	# After a short grace period the desired size continuously returns to minimum.
	if _time_since_click > shrink_delay:
		target_size_scale = move_toward(target_size_scale, minimum_size_scale, shrink_speed * delta)
		click_frequency = move_toward(click_frequency, 0.0, 3.0 * delta)

	var previous_scale := current_size_scale
	current_size_scale = lerpf(
		current_size_scale,
		target_size_scale,
		1.0 - exp(-size_follow_speed * delta)
	)
	current_size_scale = clampf(current_size_scale, minimum_size_scale, maximum_size_scale)
	growth_velocity = (current_size_scale - previous_scale) / maxf(delta, 0.0001)
	_update_size_visual()
	if not is_equal_approx(previous_scale, current_size_scale):
		size_changed.emit(current_size_scale)
	_update_debug_label()


func _register_growth_click() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var interval := now - _last_click_time
	_last_click_time = now
	_time_since_click = 0.0

	if interval > 0.0 and interval < 1.0:
		var instantaneous_frequency := clampf(1.0 / interval, 0.0, 12.0)
		click_frequency = lerpf(click_frequency, instantaneous_frequency, 0.55)
	else:
		click_frequency = 1.0

	var frequency_ratio := clampf(click_frequency / 10.0, 0.0, 1.0)
	var click_multiplier := lerpf(1.0, rapid_click_multiplier, frequency_ratio)
	target_size_scale = clampf(
		target_size_scale + growth_per_click * click_multiplier,
		minimum_size_scale,
		maximum_size_scale
	)
	_play_growth_pulse()


func calculate_target_forward_speed() -> float:
	var safe_size := maxf(current_size_scale, 0.01)
	return clampf(
		base_forward_speed / pow(safe_size, size_speed_exponent),
		minimum_forward_speed,
		maximum_forward_speed
	)


func _update_forward_movement(delta: float) -> void:
	var target_speed := calculate_target_forward_speed() if auto_forward_enabled else 0.0
	velocity.x = move_toward(velocity.x, target_speed, forward_acceleration * delta)


func _update_rolling_visual(moved_distance_x: float) -> void:
	var rolling_radius := maxf(BASE_RADIUS * current_size_scale, 1.0)
	roll_visual_root.rotation += moved_distance_x / rolling_radius
	roll_visual_root.rotation = wrapf(roll_visual_root.rotation, -PI, PI)


func _play_growth_pulse() -> void:
	if _growth_pulse_tween and _growth_pulse_tween.is_valid():
		_growth_pulse_tween.kill()
	growth_pulse_root.scale = Vector2.ONE
	_growth_pulse_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_growth_pulse_tween.tween_property(growth_pulse_root, "scale", Vector2(1.07, 1.07), 0.06)
	_growth_pulse_tween.tween_property(growth_pulse_root, "scale", Vector2.ONE, 0.12)


func _start_jump() -> bool:
	if jump_count >= maximum_jump_count:
		return false

	# Farm 的连续平台以 54px 为一格。限制体积带来的力度差距，
	# 避免高速小体积一次越过太多平台。
	var size_weight := _get_size_weight()
	if size_weight >= 1.0:
		return false
	var jump_strength := lerpf(0.75, 0.35, size_weight)
	velocity.y = jump_velocity * jump_strength
	jump_count += 1

	_play_jump_deform()
	jumped.emit()
	return true


func _play_jump_deform() -> void:
	_kill_deform_tween()
	var size_weight := _get_size_weight()
	var squash := Vector2(
		lerpf(1.14, 1.10, size_weight),
		lerpf(0.86, 0.90, size_weight)
	)
	var stretch := Vector2(
		lerpf(0.80, 0.86, size_weight),
		lerpf(1.22, 1.17, size_weight)
	)
	var squash_time := lerpf(0.045, 0.065, size_weight)
	var stretch_time := lerpf(0.085, 0.115, size_weight)
	_deform_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(jump_deform_root, "scale", squash, squash_time)
	_deform_tween.tween_property(jump_deform_root, "scale", stretch, stretch_time)
	_deform_tween.tween_property(jump_deform_root, "scale", Vector2(0.96, 1.04), 0.10)


func _play_landing_deform() -> void:
	_kill_deform_tween()
	var size_weight := _get_size_weight()
	var impact := Vector2(
		lerpf(1.28, 1.18, size_weight),
		lerpf(0.72, 0.82, size_weight)
	)
	var rebound := Vector2(
		lerpf(0.91, 0.94, size_weight),
		lerpf(1.11, 1.08, size_weight)
	)
	var settle := Vector2(
		lerpf(1.05, 1.03, size_weight),
		lerpf(0.96, 0.98, size_weight)
	)
	var time_scale := lerpf(0.85, 1.25, size_weight)
	_deform_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(jump_deform_root, "scale", impact, 0.07 * time_scale)
	_deform_tween.tween_property(jump_deform_root, "scale", rebound, 0.09 * time_scale).set_trans(Tween.TRANS_BACK)
	_deform_tween.tween_property(jump_deform_root, "scale", settle, 0.08 * time_scale)
	_deform_tween.tween_property(jump_deform_root, "scale", Vector2.ONE, 0.12 * time_scale).set_trans(Tween.TRANS_BACK)


# Air deformation follows real vertical speed after the short jump impulse tween.
func _update_motion_deform(delta: float, moved_distance_x: float) -> void:
	var target_deform := Vector2.ONE
	if not is_on_floor():
		if velocity.y < -200.0:
			var rise_strength := clampf((-velocity.y - 200.0) / 600.0, 0.0, 1.0)
			target_deform = Vector2(lerpf(0.98, 0.94, rise_strength), lerpf(1.02, 1.06, rise_strength))
		elif absf(velocity.y) <= 140.0:
			target_deform = Vector2(1.03, 0.97)
		else:
			var fall_strength := clampf((velocity.y - 140.0) / 760.0, 0.0, 1.0)
			target_deform = Vector2(lerpf(0.97, 0.88, fall_strength), lerpf(1.03, 1.13, fall_strength))
	else:
		# A tiny contact pulse keeps a rolling ball from feeling mechanically rigid.
		_ground_bounce_phase += absf(moved_distance_x) / maxf(BASE_RADIUS * current_size_scale, 1.0)
		var contact_amount := sin(_ground_bounce_phase * 2.0) * 0.012 if absf(moved_distance_x) > 0.01 else 0.0
		target_deform = Vector2(1.0 + contact_amount, 1.0 - contact_amount)
	jump_deform_root.scale = jump_deform_root.scale.lerp(
		target_deform,
		1.0 - exp(-10.0 * delta)
	)


func _get_size_weight() -> float:
	# 当体型上下限被锁成同一个值时（例如吃到变小蘑菇），inverse_lerp 会得到
	# 0/0 = NaN，进而让跳跃 velocity.y 变成 NaN，导致 move_and_slide() 报错。
	# 这里做保护：区间为 0 时视为最小体型（weight = 0），并把结果夹在 [0, 1] 内。
	if maximum_size_scale - minimum_size_scale <= 0.0:
		return 0.0
	return clampf(
		inverse_lerp(minimum_size_scale, maximum_size_scale, current_size_scale),
		0.0,
		1.0
	)


func _is_deform_tween_active() -> bool:
	return _deform_tween != null and _deform_tween.is_valid()


func _kill_deform_tween() -> void:
	if _deform_tween and _deform_tween.is_valid():
		_deform_tween.kill()
	jump_deform_root.scale = Vector2.ONE


func _update_size_visual() -> void:
	size_root.scale = Vector2.ONE * current_size_scale
	# Resize the existing local shape; keep the CollisionShape2D node unscaled.
	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape:
		circle_shape.radius = BASE_RADIUS * current_size_scale
		collision_shape.position.y = -circle_shape.radius
	collision_shape.scale = Vector2.ONE


func _update_debug_label() -> void:
	if debug_label.visible:
		debug_label.text = "SIZE %.2f\nCLICK %.1f / s\nJUMPS %d / %d\nON FLOOR %s\nCOYOTE %.3f\nBUFFER %.3f\nJUMPED NOW %s" % [
			current_size_scale,
			click_frequency,
			jump_count,
			maximum_jump_count,
			str(is_on_floor()).to_upper(),
			coyote_timer,
			jump_buffer_timer,
			str(jump_started_this_frame).to_upper(),
		]


func setup_character(character_data: Dictionary) -> void:
	var portrait_path: String = character_data.get("portrait_path", "")
	if not portrait_path.is_empty():
		player_sprite.texture = load(portrait_path)


func play_damage_flash() -> void:
	if _damage_flash_tween and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()
	player_sprite.modulate = Color.WHITE
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(player_sprite, "modulate", Color(1.0, 0.18, 0.18, 1.0), 0.06)
	_damage_flash_tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.10)


# 重生瞬间的“无敌闪烁”：透明度快速闪几下再恢复。只动 alpha，RGB 保持白色。
func play_respawn_blink() -> void:
	if _respawn_blink_tween and _respawn_blink_tween.is_valid():
		_respawn_blink_tween.kill()
	if _damage_flash_tween and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()
	player_sprite.modulate = Color.WHITE
	_respawn_blink_tween = create_tween()
	for _i in 6:
		_respawn_blink_tween.tween_property(player_sprite, "modulate:a", 0.15, 0.1)
		_respawn_blink_tween.tween_property(player_sprite, "modulate:a", 1.0, 0.1)


func apply_external_bounce(upward_speed: float) -> void:
	if upward_speed <= 0.0:
		return
	velocity.y = -upward_speed
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	auto_jump_cooldown_timer = auto_jump_retrigger_delay
	_play_jump_deform()
	jumped.emit()


func reset_size() -> void:
	current_size_scale = clampf(default_size_scale, minimum_size_scale, maximum_size_scale)
	target_size_scale = current_size_scale
	click_frequency = 0.0
	growth_velocity = 0.0
	_time_since_click = 999.0
	_is_holding_growth = false
	_update_size_visual()


func reset_motion_visuals() -> void:
	_kill_deform_tween()
	velocity = Vector2.ZERO
	jump_count = 0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	auto_jump_cooldown_timer = 0.0
	jump_started_this_frame = false
	_ground_bounce_phase = 0.0
	roll_visual_root.rotation = 0.0
	growth_pulse_root.scale = Vector2.ONE
	jump_deform_root.scale = Vector2.ONE
	player_sprite.modulate = Color.WHITE


func get_current_size_scale() -> float:
	return current_size_scale


func get_target_forward_speed() -> float:
	return calculate_target_forward_speed()


func get_current_forward_speed() -> float:
	return absf(velocity.x)
