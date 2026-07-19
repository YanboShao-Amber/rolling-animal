extends Node

const BUTTON_SFX := preload("res://audio/btn.ogg")
const CHECKPOINT_SFX := preload("res://audio/checkpoint.ogg")
const LOSE_SCENE_SFX := preload("res://audio/lose scene.ogg")
const PLAYER_HURT_SFX := preload("res://audio/lose.ogg")
const ROLLOVER_SFX := preload("res://audio/rollover.ogg")
const WIN_SFX := preload("res://audio/win.mp3")
const COIN_SFX := preload("res://audio/coin.mp3")

const LEVEL_MUSIC := {
	1: preload("res://audio/farm level.mp3"),
	2: preload("res://audio/Chiptune.mp3"),
	3: preload("res://audio/Industrial.mp3"),
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _last_scene: Node


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = -10.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	for index in 10:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		add_child(player)
		_sfx_players.append(player)

	get_tree().node_added.connect(_on_node_added)
	_register_existing_nodes(get_tree().root)
	set_process(true)


func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == _last_scene:
		return
	_last_scene = current_scene
	_update_level_music(current_scene)


func _on_node_added(node: Node) -> void:
	call_deferred("_register_node", node)


func _register_existing_nodes(root: Node) -> void:
	_register_node(root)
	for child in root.get_children():
		_register_existing_nodes(child)


func _register_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_button_pressed.bind(button)):
			button.pressed.connect(_on_button_pressed.bind(button))

	if node.is_in_group("checkpoints") and node.has_signal("activated"):
		if not node.is_connected("activated", _on_checkpoint_activated):
			node.connect("activated", _on_checkpoint_activated)

	if node.is_in_group("collectibles") and node.has_signal("collected"):
		if not node.is_connected("collected", _on_coin_collected):
			node.connect("collected", _on_coin_collected)

	if node.is_in_group("hazards") and node.has_signal("player_hit"):
		if not node.is_connected("player_hit", _on_player_hurt):
			node.connect("player_hit", _on_player_hurt)

	var scene_path := node.scene_file_path
	if scene_path == "res://scenes/ui/lose_scene.tscn":
		_play_sfx(LOSE_SCENE_SFX)
	elif scene_path == "res://scenes/ui/win_scene.tscn":
		_play_sfx(WIN_SFX)


func _on_button_pressed(button: BaseButton) -> void:
	if _is_character_select_arrow(button):
		_play_sfx(ROLLOVER_SFX)
	else:
		_play_sfx(BUTTON_SFX)


func _is_character_select_arrow(button: BaseButton) -> bool:
	if button.name != "LeftButton" and button.name != "RightButton":
		return false
	var current: Node = button
	while current != null:
		if current.name == "CharacterSelect":
			return true
		current = current.get_parent()
	return false


func _on_checkpoint_activated(_checkpoint: Node) -> void:
	_play_sfx(CHECKPOINT_SFX)


func _on_coin_collected(_value: int, _total: int) -> void:
	_play_sfx(COIN_SFX)


func _on_player_hurt(_player: Node) -> void:
	_play_sfx(PLAYER_HURT_SFX)


func _play_sfx(stream: AudioStream) -> void:
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	var player := _sfx_players[0]
	player.stop()
	player.stream = stream
	player.play()


func _update_level_music(scene_root: Node) -> void:
	var level_number := _get_music_level(scene_root)
	if level_number == 0:
		_music_player.stop()
		_music_player.stream = null
		return
	var requested_stream: AudioStream = LEVEL_MUSIC[level_number]
	if _music_player.stream == requested_stream and _music_player.playing:
		return
	_music_player.stop()
	_music_player.stream = requested_stream
	_music_player.play()


func _get_music_level(scene_root: Node) -> int:
	if scene_root == null:
		return 0
	if scene_root.scene_file_path == "res://scenes/farm_level_test.tscn":
		return 1
	if scene_root.scene_file_path == "res://scenes/tutorial_level.tscn":
		return 0
	if not scene_root.has_node("Player"):
		return 0
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return 0
	return clampi(int(game_state.pending_level_number), 1, 3)


func _on_music_finished() -> void:
	if _music_player.stream != null:
		_music_player.play()
