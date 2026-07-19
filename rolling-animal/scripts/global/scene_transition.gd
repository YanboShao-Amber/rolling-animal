extends CanvasLayer

const FALLBACK_PORTRAIT := "res://assets/player/penguin.png"
const COVER_RADIUS := 1.15

var _overlay: Control
var _black_circle: ColorRect
var _portrait: TextureRect
var _countdown_label: Label
var _transitioning := false
var _countdown_active := false


func _ready() -> void:
	layer = 120
	_build_overlay()
	get_viewport().size_changed.connect(_update_aspect)


func transition_to(scene_path: String) -> void:
	if _transitioning or scene_path.is_empty():
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("Transition target scene does not exist: " + scene_path)
		return
	_transitioning = true
	_set_portrait_texture()
	_update_aspect()
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_black_circle.material.set_shader_parameter("radius", 0.0)
	_portrait.scale = Vector2.ONE * 0.45
	_portrait.modulate = Color.WHITE

	var cover := create_tween().set_parallel(true)
	cover.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	cover.tween_property(
		_black_circle.material, "shader_parameter/radius", COVER_RADIUS, 0.7
	)
	cover.tween_property(_portrait, "scale", Vector2.ONE * 1.65, 0.7)
	cover.tween_property(_portrait, "modulate:a", 0.18, 0.7)
	await cover.finished

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not change scene to: " + scene_path)
		_finish_immediately()
		return
	await get_tree().process_frame

	var reveal := create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(
		_black_circle.material, "shader_parameter/radius", 0.0, 0.65
	)
	reveal.tween_property(_portrait, "scale", Vector2.ONE * 0.45, 0.65)
	reveal.tween_property(_portrait, "modulate:a", 1.0, 0.65)
	await reveal.finished
	_finish_immediately()


func wait_until_transition_finished() -> void:
	while _transitioning:
		await get_tree().process_frame


func play_countdown() -> void:
	if _countdown_active:
		return
	_countdown_active = true
	_countdown_label.visible = true
	for number in ["3", "2", "1"]:
		_countdown_label.text = number
		_countdown_label.scale = Vector2.ONE * 0.55
		_countdown_label.modulate = Color(1, 1, 1, 0)
		var appear := create_tween().set_parallel(true)
		appear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		appear.tween_property(_countdown_label, "scale", Vector2.ONE, 0.22)
		appear.tween_property(_countdown_label, "modulate:a", 1.0, 0.16)
		await appear.finished
		await get_tree().create_timer(0.45).timeout
		var fade := create_tween()
		fade.tween_property(_countdown_label, "modulate:a", 0.0, 0.16)
		await fade.finished
	_countdown_label.visible = false
	_countdown_active = false


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	_black_circle = ColorRect.new()
	_black_circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float radius : hint_range(0.0, 1.2) = 0.0;
uniform float aspect = 1.7777778;
void fragment() {
	vec2 centered = UV - vec2(0.5);
	centered.x *= aspect;
	float distance_from_center = length(centered);
	float feather = 0.075;
	float alpha = 1.0 - smoothstep(radius - feather, radius, distance_from_center);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_black_circle.material = material
	_black_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_black_circle)

	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_CENTER)
	_portrait.position = Vector2(-90.0, -90.0)
	_portrait.size = Vector2(180.0, 180.0)
	_portrait.pivot_offset = _portrait.size * 0.5
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_portrait)

	_countdown_label = Label.new()
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_countdown_label.position = Vector2(-100.0, 52.0)
	_countdown_label.size = Vector2(200.0, 130.0)
	_countdown_label.pivot_offset = _countdown_label.size * 0.5
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_override(
		"font", load("res://assets/Fonts/Kenney Future.ttf") as Font
	)
	_countdown_label.add_theme_font_size_override("font_size", 78)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_countdown_label.add_theme_constant_override("outline_size", 12)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.visible = false
	add_child(_countdown_label)


func _set_portrait_texture() -> void:
	var portrait_path := FALLBACK_PORTRAIT
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and not str(game_state.selected_portrait_path).is_empty():
		portrait_path = str(game_state.selected_portrait_path)
	var texture := load(portrait_path) as Texture2D
	if texture == null:
		texture = load(FALLBACK_PORTRAIT) as Texture2D
	_portrait.texture = texture


func _update_aspect() -> void:
	if not is_instance_valid(_black_circle):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_black_circle.material.set_shader_parameter(
		"aspect", viewport_size.x / maxf(viewport_size.y, 1.0)
	)


func _finish_immediately() -> void:
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
