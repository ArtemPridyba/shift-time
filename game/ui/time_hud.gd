class_name TimeHud
extends Node2D
## The wrist device with the time-direction indicator (task 1.5). A plate pinned
## to the hero with two pins; on it two arrows, `>>` in forward time and `<<`
## while Shift is held. In rewind the light sweeps along the arrows from right
## to left, the device flickers, thin streaks run left above and below it, and
## the edges of the screen glow with the same light and the same streaks.
## Forward time has none of this. The direction never reads from color alone.
##
## It is a child of the player, so the device goes where the hero goes. The
## state lives in `TimeIndicatorState`; this node only draws it. All colors and
## numbers are in `data/time_hud.json`: the palette can change without code.
## It replaces the temporary label `ui/debug_time_label.gd` from task 1.4.

const EDGE_LAYER := 60
const GLOW_TEXTURE_SIZE := 128
const PIN_RADIUS := 2.2
const PIN_INSET := 4.0
const LANE_GAP_PX := 4.0

var state: TimeIndicatorState
var sound: TimeSound

var _accent := Color("#7FE8FF")
var _plate_color := Color("#3A3D42")
var _pin_color := Color("#9AA0A8")
var _plate := Vector2(34.0, 20.0)
var _offset := Vector2(22.0, -58.0)
var _glyph_height := 10.0
var _glow_alpha := 0.55
var _spread := 36.0
var _streak_width := 1.5
var _dash := 9.0
var _lane := 14.0
var _glow: Sprite2D
var _edges: ColorRect
var _edge_material: ShaderMaterial


func _ready() -> void:
	var config := Content.time_hud()
	state = TimeIndicatorState.new(config)
	_read_config(config)
	_build_glow()
	_build_edges(config)
	sound = TimeSound.new(config)
	add_child(sound)
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.direction_changed.connect(_on_direction_changed)
		state.set_direction(int(manager.direction))
		state.edge_amount = 1.0 if state.is_rewinding() else 0.0


func _process(delta: float) -> void:
	state.step(delta)
	var facing := 1.0
	var parent := get_parent()
	if parent != null and parent.has_method("facing"):
		facing = float(parent.call("facing"))
	position = Vector2(_offset.x * facing, _offset.y)
	_glow.modulate = Color(_accent, _glow_alpha * state.glow())
	_edge_material.set_shader_parameter("amount", state.edge_amount)
	_edge_material.set_shader_parameter("phase", state.particle_phase)
	_edges.visible = state.edge_amount > 0.001
	queue_redraw()


func _draw() -> void:
	var half := _plate / 2.0
	draw_rect(Rect2(-half, _plate), _plate_color)
	draw_rect(Rect2(-half, _plate), _pin_color, false, 1.5)
	for pin: Vector2 in [Vector2(-half.x + PIN_INSET, -half.y + PIN_INSET), Vector2(half.x - PIN_INSET, half.y - PIN_INSET)]:
		draw_circle(pin, PIN_RADIUS, _pin_color)
		draw_circle(pin, PIN_RADIUS * 0.4, _plate_color.darkened(0.5))
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
		draw_polyline(points, Color(_accent, alpha * glow), 2.5, true)


## Thin horizontal streaks above and below the plate, only in rewind: they run
## to the left and fade at both ends, like speed lines.
func _draw_streaks() -> void:
	if not state.streaks_active():
		return
	for i in state.streak_count():
		var streak := state.streak(i)
		var progress := float(streak["progress"])
		var side := 1.0 if i % 2 == 0 else -1.0
		var y := side * (_plate.y / 2.0 + LANE_GAP_PX + float(streak["lane"]) * _lane)
		var x := lerpf(-_spread, _spread, progress)
		draw_line(Vector2(x, y), Vector2(x + _dash, y), Color(_accent, float(streak["alpha"]) * 0.9), _streak_width)


func _read_config(config: Dictionary) -> void:
	var colors := config.get("colors", {}) as Dictionary
	_accent = Color.html(str(colors.get("accent", "#7FE8FF")))
	_plate_color = Color.html(str(colors.get("plate", "#3A3D42")))
	_pin_color = Color.html(str(colors.get("pin", "#9AA0A8")))
	var device := config.get("device", {}) as Dictionary
	_plate = Vector2(float(device.get("plate_width_px", 34.0)), float(device.get("plate_height_px", 20.0)))
	_offset = Vector2(float(device.get("offset_x_px", 22.0)), float(device.get("offset_y_px", -58.0)))
	_glyph_height = float(device.get("glyph_height_px", 10.0))
	_glow_alpha = float(device.get("glow_alpha", 0.55))
	var particles := config.get("particles", {}) as Dictionary
	_spread = float(particles.get("spread_px", 44.0))
	_streak_width = float(particles.get("size_px", 1.5))
	_dash = float(particles.get("dash_px", 9.0))
	_lane = float(particles.get("lane_px", 14.0))


## A soft round halo behind the plate, drawn with additive blending (cheap in
## the web build, no post-processing).
func _build_glow() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = texture
	_glow.show_behind_parent = true
	var radius := float((Content.time_hud().get("device", {}) as Dictionary).get("glow_radius_px", 46.0))
	_glow.scale = Vector2.ONE * (radius * 2.0 / float(GLOW_TEXTURE_SIZE))
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = material
	add_child(_glow)


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
