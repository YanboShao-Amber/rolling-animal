extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FLOOR_Y := 700.0

var failed := false
var jump_events := 0


func _ready() -> void:
	await _test_jump_buffer()
	await _test_coyote_time()
	print("FORGIVENESS_TEST_%s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _make_floor(center_x: float, width: float) -> StaticBody2D:
	var floor := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 80.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position = Vector2(center_x, FLOOR_Y + 40.0)
	add_child(floor)
	return floor


func _make_player(start_x: float) -> SoftPlayer:
	var player := PLAYER_SCENE.instantiate() as SoftPlayer
	add_child(player)
	player.set_process(false)
	player.current_size_scale = player.default_size_scale
	player.target_size_scale = player.default_size_scale
	player.global_position = Vector2(start_x, FLOOR_Y)
	player._update_size_visual()
	return player


func _wait_for_floor(player: SoftPlayer) -> void:
	for frame in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			return


func _test_jump_buffer() -> void:
	var floor := _make_floor(0.0, 2000.0)
	var player := _make_player(0.0)
	await _wait_for_floor(player)
	jump_events = 0
	player.jumped.connect(_count_jump)
	player._start_jump()

	for frame in 240:
		await get_tree().physics_frame
		var distance_to_floor := FLOOR_Y - player.global_position.y
		if player.velocity.y > 0.0 and distance_to_floor <= 35.0:
			Input.action_press("player_jump")
			await get_tree().physics_frame
			Input.action_release("player_jump")
			break

	for frame in 60:
		await get_tree().physics_frame
		if jump_events >= 2:
			break
	var passed := jump_events == 2
	failed = failed or not passed
	print("BUFFER_TEST|pressed_before_landing<=0.15s|jumps=%d|pass=%s" % [jump_events, passed])
	player.queue_free()
	floor.queue_free()
	await get_tree().physics_frame


func _test_coyote_time() -> void:
	var floor := _make_floor(0.0, 400.0)
	var player := _make_player(80.0)
	player.auto_forward_enabled = true
	await _wait_for_floor(player)
	jump_events = 0
	player.jumped.connect(_count_jump)

	for frame in 240:
		await get_tree().physics_frame
		if not player.is_on_floor():
			for delay_frame in 3: # 0.05 seconds at 60 physics FPS.
				await get_tree().physics_frame
			Input.action_press("player_jump")
			await get_tree().physics_frame
			Input.action_release("player_jump")
			break

	for frame in 30:
		await get_tree().physics_frame
		if jump_events >= 1:
			break
	var passed := jump_events == 1
	failed = failed or not passed
	print("COYOTE_TEST|pressed_after_edge=0.05s|jumps=%d|pass=%s" % [jump_events, passed])
	player.queue_free()
	floor.queue_free()


func _count_jump() -> void:
	jump_events += 1
