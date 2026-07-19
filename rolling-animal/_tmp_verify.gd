extends SceneTree

func _initialize() -> void:
	print("HARNESS START")
	_run.call_deferred()

func _run() -> void:
	var ok := true
	change_scene_to_file("res://scenes/level/Minecraft.tscn")
	await create_timer(0.5).timeout

	var scene := current_scene
	if scene == null:
		print("FAIL: current_scene is null")
		quit(1)
		return
	print("Scene loaded: ", scene.name)

	var wl = scene.get_node_or_null("WinLandmark")
	print("WinLandmark present: ", wl != null)
	if wl == null:
		ok = false

	var connected: bool = wl.player_reached.is_connected(scene._on_player_reached_win) if wl else false
	print("player_reached connected to handler: ", connected)
	if not connected:
		ok = false

	print("win_popup before: ", scene.win_popup)

	if wl:
		wl.player_reached.emit()
	await create_timer(0.2).timeout

	var wp = scene.win_popup
	print("win_popup after: ", wp)
	var in_hud := false
	if is_instance_valid(wp):
		in_hud = wp.get_parent() == scene.get_node_or_null("HUD")
	print("win_popup is child of HUD: ", in_hud)
	if not is_instance_valid(wp) or not in_hud:
		ok = false

	var gs = root.get_node_or_null("GameState")
	if gs:
		print("level 2 completed: ", gs.is_level_completed(2))
		if not gs.is_level_completed(2):
			ok = false

	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
