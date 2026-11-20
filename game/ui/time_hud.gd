class_name TimeHud
extends Node2D
## The time device's indicator (task 1.5, moved onto the gauntlet in Д5): two
## arrows on the strip of the heroine's gauntlet, `>>` in forward time and `<<`
## while Shift is held. In rewind the light sweeps along the arrows from right
## to left, the device flickers, thin streaks run left above and below it, and
## the edges of the screen glow with the same light and the same streaks.
## Forward time has none of this. The direction never reads from color alone.
##
## It is a child of the player and sits where the player's `device_point()`
## says, so it follows her arm; it is never mirrored, so the arrows point the
## way time runs whichever way she faces. It lights only her body, through the
## player's `show_time_light` (D76): no halo on the room. The state lives in
## `TimeIndicatorState`; this node only draws it. All colors and numbers are in
## `data/time_hud.json`: the palette can change without code.

## Above every part of the doll (their z goes up to about 15).
const EDGE_LAYER := 60
const DRAW_Z := 40
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
var _edges: ColorRect
var _edge_material: ShaderMaterial


func _ready() -> void:
	var config := Content.time_hud()
	state = TimeIndicatorState.new(config)
	_read_config(config)
	z_index = DRAW_Z
	_build_edges(config)
	sound = TimeSound.new(config)
	add_child(sound)
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.direction_changed.connect(_on_direction_changed)
		state.set_direction(int(manager.direction))
		state.edge_amount = 1.0 if state.is_rewinding() else 0.0


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
		parent.call("show_time_light", state.glow(), state.edge_amount)
	_edge_material.set_shader_parameter("amount", state.edge_amount)
	_edge_material.set_shader_parameter("phase", state.particle_phase)
	_edges.visible = state.edge_amount > 0.001
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


## The glow and the streaks along the screen edges: a full-screen layer above
## the room, added over the picture (see `time_edges.gdshader`).
func _build_edges(config: Dictionary) -> void:
	var edges := config.get("edges", {}) as Dictionary
	var layer := CanvasLayer.new()
	layer.name = "Edges"
	layer.layer = EDGE_LAYER
	add_child(layer)
	_edge_material = ShaderMaterial.new()
	_edge_material.shader = load("res://ui/time_edges.gdshader") as Shader
	_edge_material.set_shader_parameter("glow_color", _accent)
	for key: String in ["glow_strength", "width", "streak_strength", "streak_density", "streak_length", "streak_rows", "streak_thickness"]:
		if edges.has(key):
			_edge_material.set_shader_parameter(key, float(edges[key]))
	_edge_material.set_shader_parameter("amount", 0.0)
	_edge_material.set_shader_parameter("phase", 0.0)
	_edges = ColorRect.new()
	_edges.material = _edge_material
	_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edges.visible = false
	layer.add_child(_edges)


## A parameter of the edge shader, for tests.
func edge_parameter(parameter: StringName) -> Variant:
	return _edge_material.get_shader_parameter(parameter)
