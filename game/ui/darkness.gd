class_name Darkness
extends CanvasLayer
## Dark room: a black mask over the room with a round hole under every lit
## lamp (a simple mask, no Light2D, so the web build stays light). A faint
## outline marks the player so the controls stay usable, but it shows nothing
## of the room around: the dark is the difficulty.
##
## Put it as a direct child of the room, next to the lamps and the player.

const MAX_LIGHTS := 8

@export var player_path: NodePath

var _mask: ColorRect
var _outline: Control
var _material: ShaderMaterial
var _outline_alpha := 0.3


func _ready() -> void:
	layer = 50
	var data := Content.objects().get("darkness", {}) as Dictionary
	_outline_alpha = float(data.get("player_outline_alpha", 0.3))
	_material = ShaderMaterial.new()
	_material.shader = load("res://ui/darkness.gdshader") as Shader
	_material.set_shader_parameter("falloff_power", LightField.FALLOFF_POWER)
	_material.set_shader_parameter("ambient", float(data.get("ambient", 0.02)))
	_mask = ColorRect.new()
	_mask.material = _material
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mask)
	_outline = Control.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.draw.connect(_draw_outline)
	add_child(_outline)


func _process(_delta: float) -> void:
	var to_screen := get_viewport().get_canvas_transform()
	var scale := to_screen.get_scale().x
	var lights := PackedVector4Array()
	for source: Dictionary in light_sources():
		if lights.size() >= MAX_LIGHTS:
			break
		var screen := to_screen * (source["position"] as Vector2)
		lights.append(Vector4(screen.x, screen.y, float(source["radius"]) * scale, float(source.get("intensity", 1.0))))
	var count := lights.size()
	lights.resize(MAX_LIGHTS)
	_material.set_shader_parameter("mask_size", _mask.size)
	_material.set_shader_parameter("lights", lights)
	_material.set_shader_parameter("light_count", count)
	_outline.queue_redraw()


## The light of every lit lamp in this room.
func light_sources() -> Array:
	var sources: Array = []
	var room := get_parent()
	if room == null or not is_inside_tree():
		return sources
	for node: Variant in get_tree().get_nodes_in_group("light_source"):
		if not room.is_ancestor_of(node as Node):
			continue
		var source: Dictionary = (node as Node).call("light_source")
		if not source.is_empty():
			sources.append(source)
	return sources


func _draw_outline() -> void:
	var player := get_node_or_null(player_path)
	if player == null or not player.has_method("body_rect"):
		return
	var rect: Rect2 = player.call("body_rect")
	var to_screen := get_viewport().get_canvas_transform()
	var top_left := to_screen * rect.position
	var screen_rect := Rect2(top_left, rect.size * to_screen.get_scale())
	_outline.draw_rect(screen_rect, Color(1.0, 1.0, 1.0, _outline_alpha), false, 2.0)
