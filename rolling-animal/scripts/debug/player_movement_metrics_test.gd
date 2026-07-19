extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TILE_SIZE := 54.0
const GROUND_Y := 900.0
const JUMP_REPETITIONS := 10

var _failed := false


func _ready() -> void:
	print("=== PLAYER MOVEMENT METRICS TEST (1 TILE = 54 px) ===")
	await get_tree().physics_frame
	var probe: SoftPlayer = PLAYER_SCENE.instantiate()
	add_child(probe)
	await get_tree().process_frame
	var sizes := [
		{"label": "MIN", "scale": probe.minimum_size_scale},
		{"label": "DEFAULT", "scale": probe.default_size_scale},
		{"label": "MAX", "scale": probe.maximum_size_scale},
	]
	probe.queue_free()
	await get_tree().process_frame

	for size_case: Dictionary in sizes:
		await _measure_size_case(size_case.label, size_case.scale)

	print("=== METRICS TEST COMPLETE ===")
	get_tree().quit(1 if _failed else 0)


func _measure_size_case(label: String, size_scale: float) -> void:
	var player: SoftPlayer = PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false) # Hold the requested size; physics remains the production code.
	player.current_size_scale = size_scale
	player.target_size_scale = size_scale
	player.default_size_scale = size_scale
	player.auto_forward_enabled = true
	player.global_position = Vector2(0.0, GROUND_Y)
	player._update_size_visual()

	var target_speed := player.calculate_target_forward_speed()
	for frame in 600:
		await get_tree().physics_frame
		if player.is_on_floor() and absf(player.velocity.x - target_speed) < 0.1:
			break

	var radius := SoftPlayer.BASE_RADIUS * size_scale
	var actual_speed := player.velocity.x
	var single := await _measure_one_jump(player)
	var continuous := await _measure_repeated_jumps(player, JUMP_REPETITIONS)

	print("METRIC|%s|scale=%.3f|radius_px=%.3f|diameter_px=%.3f|diameter_tiles=%.4f|target_speed=%.3f|actual_speed=%.3f|tiles_per_second=%.4f" % [
		label, size_scale, radius, radius * 2.0, radius * 2.0 / TILE_SIZE,
		target_speed, actual_speed, actual_speed / TILE_SIZE,
	])
	print("JUMP|%s|jumped=%s|height_px=%.3f|height_tiles=%.4f|rise_s=%.4f|fall_s=%.4f|airtime_s=%.4f|distance_px=%.3f|distance_tiles=%.4f" % [
		label, str(single.jumped), single.height_px, single.height_px / TILE_SIZE,
		single.rise_s, single.fall_s, single.airtime_s,
		single.distance_px, single.distance_px / TILE_SIZE,
	])
	print("REPEAT|%s|successful=%d/%d|average_period_s=%.4f|average_distance_px=%.3f|average_distance_tiles=%.4f|total_distance_px=%.3f|stable=%s" % [
		label, continuous.successful, JUMP_REPETITIONS, continuous.average_period_s,
		continuous.average_distance_px, continuous.average_distance_px / TILE_SIZE,
		continuous.total_distance_px, str(continuous.stable),
	])
	player.queue_free()
	await get_tree().process_frame


func _measure_one_jump(player: SoftPlayer) -> Dictionary:
	var physics_delta := 1.0 / float(Engine.physics_ticks_per_second)
	var start_position := player.global_position
	var peak_y := start_position.y
	var elapsed := 0.0
	var rise_time := 0.0
	var left_floor := false
	player._start_jump()
	var jumped := player.velocity.y < 0.0
	if not jumped:
		return _empty_jump_result()

	for frame in 600:
		await get_tree().physics_frame
		elapsed += physics_delta
		peak_y = minf(peak_y, player.global_position.y)
		if player.velocity.y < 0.0:
			rise_time = elapsed
		if not player.is_on_floor():
			left_floor = true
		elif left_floor:
			break

	return {
		"jumped": true,
		"height_px": start_position.y - peak_y,
		"rise_s": rise_time,
		"fall_s": maxf(elapsed - rise_time, 0.0),
		"airtime_s": elapsed,
		"distance_px": player.global_position.x - start_position.x,
	}


func _measure_repeated_jumps(player: SoftPlayer, count: int) -> Dictionary:
	var periods: Array[float] = []
	var distances: Array[float] = []
	var total_start_x := player.global_position.x
	var physics_delta := 1.0 / float(Engine.physics_ticks_per_second)
	var jump_start_time := 0.0
	var jump_start_x := player.global_position.x
	var elapsed := 0.0
	var was_airborne := false
	var jump_started := false
	Input.action_press("player_jump")
	for frame in 10000:
		await get_tree().physics_frame
		elapsed += physics_delta
		if not jump_started and player.velocity.y < 0.0:
			jump_started = true
			was_airborne = true
			jump_start_time = elapsed
			jump_start_x = player.global_position.x
		elif jump_started and not player.is_on_floor():
			was_airborne = true
		elif jump_started and was_airborne and player.is_on_floor():
			periods.append(elapsed - jump_start_time)
			distances.append(player.global_position.x - jump_start_x)
			jump_started = false
			was_airborne = false
			if periods.size() >= count:
				break
		if frame > 180 and periods.is_empty() and not jump_started:
			break
	Input.action_release("player_jump")

	var average_period := _average(periods)
	var average_distance := _average(distances)
	var stable := periods.size() == count and _maximum_relative_deviation(periods, average_period) <= 0.05 \
		and _maximum_relative_deviation(distances, average_distance) <= 0.05
	return {
		"successful": periods.size(),
		"average_period_s": average_period,
		"average_distance_px": average_distance,
		"total_distance_px": player.global_position.x - total_start_x,
		"stable": stable,
	}


func _empty_jump_result() -> Dictionary:
	return {
		"jumped": false,
		"height_px": 0.0,
		"rise_s": 0.0,
		"fall_s": 0.0,
		"airtime_s": 0.0,
		"distance_px": 0.0,
	}


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


func _maximum_relative_deviation(values: Array[float], average: float) -> float:
	if values.is_empty() or is_zero_approx(average):
		return 0.0
	var maximum := 0.0
	for value in values:
		maximum = maxf(maximum, absf(value - average) / average)
	return maximum
