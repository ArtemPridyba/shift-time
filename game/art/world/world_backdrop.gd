class_name WorldBackdrop
extends Node2D
## The painted room (D131): one Gemini picture of the whole room in place of
## the kit pieces of `WorldBack` and `WorldGround`. It lies on a canvas layer of
## its own behind the level, so the room's darkness (`CanvasModulate` of
## `WorldLight`) does not dim it twice: the picture is already dark. Its light
## is its own: the dark picture everywhere, the lit picture through a soft cone
## under every lamp, as bright as `WorldLight` says the lamp is now — it
## flickers, dies when the lamp falls and comes back under Shift. Nodes of the
## level whose still parts the picture already has (`painted` of
## `world.backdrop`) are told to draw only what moves (`use_backdrop`); those
## drawn by code get the picture's light too (`use_picture_light`, the shader
## `object_light.gdshader`, numbers `kit_objects.picture_light` of look.json):
## dim like the wall behind them in the dark, warm under a lamp's cone, a
## little soft like the picture (24.11, level 01 notes).
## Decoration only: nothing is recorded, nothing collides.

const MAX_LAMPS := 8
const SHADER := preload("res://art/world/backdrop.gdshader")
const OBJECT_SHADER := preload("res://art/world/object_light.gdshader")

## The level's id in levels.json.
@export var level_id := ""
## The room's lamps (their brightness lights the cones).
@export var light_path := NodePath("../../WorldLight")

var layer: CanvasLayer
var picture: Node2D
var _data: Dictionary
var _lit: Texture2D
var _rect := Rect2()
var _material: ShaderMaterial
var _bulbs := PackedVector2Array()
## The light of the picture for the objects drawn over it (`use_picture_light`).
var object_material: ShaderMaterial


func _ready() -> void:
	var layout := WorldData.layout(WorldData.entry(level_id))
	_data = WorldData.backdrop(layout)
	if _data.is_empty():
		return
	_lit = load(str(_data.get("lit", ""))) as Texture2D
	var r: Array = _data.get("rect", [0, 0, 1, 1])
	_rect = Rect2(Vector2(float(r[0]), float(r[1])) * WorldData.CELL, Vector2(float(r[2]), float(r[3])) * WorldData.CELL)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("dark_picture", load(str(_data.get("dark", ""))) as Texture2D)
	var cone: Dictionary = _data.get("cone", {})
	for key: String in ["top_px", "spread", "length_px", "soft", "above_px"]:
		if cone.has(key):
			_material.set_shader_parameter(key, float(cone[key]))
	var ceiling := WorldData.ceiling(layout)
	for lamp: Variant in layout.get("lamps", []):
		if _bulbs.size() < MAX_LAMPS and lamp is Dictionary:
			_bulbs.append(WorldData.lamp_at(lamp, ceiling))
	_material.set_shader_parameter("lamp_count", _bulbs.size())
	_material.set_shader_parameter("lamp_at", _padded(_bulbs, Vector2.ZERO))
	object_material = ShaderMaterial.new()
	object_material.shader = OBJECT_SHADER
	for key: String in ["top_px", "spread", "length_px", "soft", "above_px", "lamp_count", "lamp_at"]:
		object_material.set_shader_parameter(key, _material.get_shader_parameter(key))
	var look := ObjectLook.of("picture_light")
	object_material.set_shader_parameter("dark", ObjectLook.number(look, "dark", 0.35))
	object_material.set_shader_parameter("lit_color", ObjectLook.color(look, "lit_color", Color.WHITE))
	object_material.set_shader_parameter("soft_px", ObjectLook.number(look, "soft_px", 0.0))
	object_material.set_shader_parameter("lit_gain", ObjectLook.number(look, "lit_gain", 1.0))
	object_material.set_shader_parameter("haze_color", ObjectLook.color(look, "haze_color", Color.BLACK))
	object_material.set_shader_parameter("haze", ObjectLook.number(look, "haze", 0.0))
	# Behind the level, moving with its camera, out of reach of its darkness.
	layer = CanvasLayer.new()
	layer.name = "BackdropLayer"
	layer.layer = -1
	layer.follow_viewport_enabled = true
	add_child(layer)
	picture = Node2D.new()
	picture.name = "Picture"
	picture.material = _material
	picture.draw.connect(_draw_picture)
	layer.add_child(picture)
	_follow_level.call_deferred()
	_paint_nodes()
	_shine()


func _process(_delta: float) -> void:
	_shine()


## How bright the cone of every lamp is now, 0..1 (what the shader gets).
func lamp_weights() -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	var light := get_node_or_null(light_path) as WorldLight
	for i in _bulbs.size():
		weights.append(clampf(light.shine(i), 0.0, 1.0) if light != null else 1.0)
	return weights


func _shine() -> void:
	if _material == null:
		return
	var weights := lamp_weights()
	var padded := PackedFloat32Array()
	padded.resize(MAX_LAMPS)
	for i in weights.size():
		padded[i] = weights[i]
	_material.set_shader_parameter("lamp_shine", padded)
	object_material.set_shader_parameter("lamp_shine", padded)


func _draw_picture() -> void:
	if _lit != null:
		picture.draw_texture_rect(_lit, _rect, false)


## The layer has no parent transform: it takes the level's own.
func _follow_level() -> void:
	var level := get_parent() as Node2D
	if level != null and picture != null:
		picture.transform = level.global_transform
		object_material.set_shader_parameter("level_origin", level.global_position)


func _paint_nodes() -> void:
	var nodes: Variant = _data.get("painted", {})
	var level := get_parent().get_parent() if get_parent() != null else null
	if not nodes is Dictionary or level == null:
		return
	for path: Variant in nodes:
		var node := level.get_node_or_null(NodePath(str(path)))
		if node != null and node.has_method("use_backdrop"):
			node.call("use_backdrop", nodes[path] as Dictionary)
			if node is CanvasItem and node.has_method("use_picture_light"):
				node.call("use_picture_light", object_material)
		else:
			push_error("world.backdrop.painted: %s is not a node of the level with use_backdrop" % path)


func _padded(points: PackedVector2Array, fill: Vector2) -> PackedVector2Array:
	var out := points.duplicate()
	while out.size() < MAX_LAMPS:
		out.append(fill)
	return out
