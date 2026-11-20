class_name TimeHud
extends Node2D
## The time device's indicator (task 1.5, moved onto the gauntlet in Д5): two
## arrows on the strip of the heroine's gauntlet, `>>` in forward time and `<<`
## while Shift is held. In rewind the light sweeps along the arrows from right
## to left, the device flickers and thin streaks run left above and below it.
## Forward time has none of this. The direction never reads from color alone.
## Under Shift the world behind the heroine fades a little (D86, Д5.1); the
## glow and streaks along the screen edges are gone, the heroine's threads of
## time took their place (D85).
##
## It is a child of the player and sits where the player's `device_point()`
## says, so it follows her arm; it is never mirrored, so the arrows point the
## way time runs whichever way she faces. It lights only her body, through the
## player's `show_time_light` (D76): no halo on the room. The state lives in
## `TimeIndicatorState`; this node only draws it. All colors and numbers are in
## `data/time_hud.json`: the palette can change without code.

## Above every part of the doll (their z goes up to about 15).
const DRAW_Z := 40
## The faded world is drawn at this z, above the room (z 0 and below) and under
## the player (z 2 in player.tscn), so she never fades: she lives forward.
const FADE_Z := 1
## The dark around the frame lies over the room and the heroine, under the
## breath vignette (layer 1 is the default) and the darkness of dark rooms.
const VIGNETTE_LAYER := 40
const LANE_GAP_PX := 2.0

var state: TimeIndicatorState
var sound: TimeSound

var _accent := Color("#7FE8FF")
var _glyph_color := Color("#FFFFFF")
var _offset := Vector2(22.0, -58.0)
var _glyph_height := 5.0
var _stroke := 1.0
var _spread := 36.0
var _streak_width := 1.5
var _dash := 9.0
var _lane := 14.0
var _fade: Node2D
var _fade_rect: ColorRect
var _fade_material: ShaderMaterial
var _vignette_material: ShaderMaterial
var _vignette := {}


func _ready() -> void:
	var config := Content.time_hud()
	state = TimeIndicatorState.new(config)
	_read_config(config)
	z_index = DRAW_Z
	_build_fade(config)
	_build_vignette(config)
	sound = TimeSound.new(config)
	add_child(sound)
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.direction_changed.connect(_on_direction_changed)
		state.set_direction(int(manager.direction))
		state.rewind_amount = 1.0 if state.is_rewinding() else 0.0


func _process(delta: float) -> void:
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		state.speed = float(manager.rewind_speed)
	state.step(delta)
	var parent := get_parent()
	if parent != null and parent.has_method("device_point"):
		position = parent.call("device_point")
	else:
		var facing := 1.0
		if parent != null and parent.has_method("facing"):
			facing = float(parent.call("facing"))
		position = Vector2(_offset.x * facing, _offset.y)
	if parent != null and parent.has_method("show_time_light"):
		parent.call("show_time_light", state.glow(), state.rewind_amount)
	_update_fade()
	_vignette_material.set_shader_parameter("strength", vignette_strength())
	queue_redraw()


func _draw() -> void:
	_draw_arrows()
	_draw_streaks()


func _on_direction_changed(direction: int) -> void:
	state.set_direction(direction)
	sound.play_for(direction)


## Two chevrons: they point right in forward time and left in rewind, and in
## rewind a band of light runs along them from right to left.
func _draw_arrows() -> void:
	var rewinding := state.is_rewinding()
	var half_height := _glyph_height / 2.0
	var depth := half_height * 0.8
	var gap := half_height
	var total := depth + gap
	var left := -total / 2.0
	var glow := state.glow()
	var sweep := state.sweep_position()
	for i in 2:
		var x := left + float(i) * gap
		var points := PackedVector2Array()
		if rewinding:
			points = PackedVector2Array([Vector2(x + depth, -half_height), Vector2(x, 0.0), Vector2(x + depth, half_height)])
		else:
			points = PackedVector2Array([Vector2(x, -half_height), Vector2(x + depth, 0.0), Vector2(x, half_height)])
		var alpha := 1.0
		if rewinding:
			var along := (x + depth / 2.0 - left) / total
			alpha = 0.3 + 0.7 * clampf(1.0 - absf(along - sweep) * 2.0, 0.0, 1.0)
		draw_polyline(points, Color(_glyph_color, alpha * glow), _stroke, true)


## Thin horizontal streaks above and below the plate, only in rewind: they run
## to the left and fade at both ends, like speed lines.
func _draw_streaks() -> void:
	if not state.streaks_active():
		return
	for i in state.streak_count():
		var streak := state.streak(i)
		var progress := float(streak["progress"])
		var side := 1.0 if i % 2 == 0 else -1.0
		var y := side * (_glyph_height / 2.0 + LANE_GAP_PX + float(streak["lane"]) * _lane)
		var x := lerpf(-_spread, _spread, progress)
		draw_line(Vector2(x, y), Vector2(x + _dash, y), Color(_accent, float(streak["alpha"]) * 0.9), _streak_width)


func _read_config(config: Dictionary) -> void:
	var colors := config.get("colors", {}) as Dictionary
	_accent = Color.html(str(colors.get("accent", "#7FE8FF")))
	_glyph_color = Color.html(str(colors.get("glyph", "#FFFFFF")))
	var device := config.get("device", {}) as Dictionary
	_offset = Vector2(float(device.get("offset_x_px", 22.0)), float(device.get("offset_y_px", -58.0)))
	_glyph_height = float(device.get("glyph_height_px", 5.0))
	_stroke = float(device.get("stroke_px", 1.0))
	var particles := config.get("particles", {}) as Dictionary
	_spread = float(particles.get("spread_px", 44.0))
	_streak_width = float(particles.get("size_px", 1.5))
	_dash = float(particles.get("dash_px", 9.0))
	_lane = float(particles.get("lane_px", 14.0))


## The world fades a little under Shift (D86): a layer over the whole screen
## that reads the picture drawn so far, the room, and lays it back with less
## colour (see `time_fade.gdshader`). The heroine is drawn after it.
func _build_fade(config: Dictionary) -> void:
	var rewind := config.get("rewind", {}) as Dictionary
	_fade = Node2D.new()
	_fade.name = "WorldFade"
	_fade.top_level = true
	_fade.z_as_relative = false
	_fade.z_index = FADE_Z
	add_child(_fade)
	_fade_material = ShaderMaterial.new()
	_fade_material.shader = load("res://ui/time_fade.gdshader") as Shader
	_fade_material.set_shader_parameter("saturation", float(rewind.get("world_saturation", 1.0)))
	_fade_material.set_shader_parameter("brightness", float(rewind.get("world_brightness", 1.0)))
	_fade_material.set_shader_parameter("amount", 0.0)
	_fade_rect = ColorRect.new()
	_fade_rect.material = _fade_material
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_fade.add_child(_fade_rect)


func _update_fade() -> void:
	_fade_material.set_shader_parameter("amount", state.rewind_amount)
	_fade_rect.visible = state.rewind_amount > 0.001
	if _fade_rect.visible and is_inside_tree():
		var screen := get_viewport().get_visible_rect()
		_fade.global_transform = get_viewport().get_canvas_transform().affine_inverse()
		_fade_rect.position = screen.position
		_fade_rect.size = screen.size


## A soft dark around the edges of the frame (D87; Boris, 20.11: "not enough
## darkening near the edges"); a little deeper under Shift, so the threads
## come out of the dark. Numbers: `vignette` in time_hud.json.
func _build_vignette(config: Dictionary) -> void:
	_vignette = config.get("vignette", {}) as Dictionary
	var layer := CanvasLayer.new()
	layer.name = "FrameVignette"
	layer.layer = VIGNETTE_LAYER
	add_child(layer)
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = load("res://ui/frame_vignette.gdshader") as Shader
	_vignette_material.set_shader_parameter("inner", float(_vignette.get("inner", 0.5)))
	_vignette_material.set_shader_parameter("outer", float(_vignette.get("outer", 1.1)))
	_vignette_material.set_shader_parameter("strength", vignette_strength())
	var rect := ColorRect.new()
	rect.material = _vignette_material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)


## How dark the corners of the frame are now (0..1).
func vignette_strength() -> float:
	var amount := state.rewind_amount if state != null else 0.0
	return lerpf(float(_vignette.get("forward", 0.0)), float(_vignette.get("rewind", 0.0)), amount)


## A parameter of the world fade, for tests.
func fade_parameter(parameter: StringName) -> Variant:
	return _fade_material.get_shader_parameter(parameter)


## True while the world is drawn faded.
func world_faded() -> bool:
	return _fade_rect.visible
