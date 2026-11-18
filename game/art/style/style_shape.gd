class_name StyleShape
extends Sprite2D
## A shape painted by the shared material (task Д1) in the colours of one
## palette role. Give it a mask (`set_svg`) and a role; it repaints when the
## palette changes and keeps its light on top when it turns. Decoration only:
## it records nothing and changes no rule.

const MATERIAL := preload("res://art/style/material.gdshader")
## Towards the light, in the world (top left).
const LIGHT := Vector2(-0.45, -0.9)
## Roles whose chips show their own material, not steel under paint.
const BARE_ROLES: Array[String] = ["steel", "mechanism", "rust", "wood"]

## A role of `Content.ART_ROLES`.
@export var role := "steel":
	set(value):
		role = value
		_paint()
## 0 is clean, 1 is fully worn (chips, dust, dirt).
@export_range(0.0, 1.0) var wear := 1.0:
	set(value):
		wear = value
		_set_param("wear", value)
## 0 is no rust; only old iron gets rust (columns, chains, bolts).
@export_range(0.0, 1.0) var rust := 0.0:
	set(value):
		rust = value
		_set_param("rust", value)
## Gives each object its own chips and dust.
@export var wear_seed := 0.0:
	set(value):
		wear_seed = value
		_set_param("seed", value)

var _material: ShaderMaterial
var _last_rotation := INF


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = MATERIAL
	material = _material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for key: String in Content.ART_MATERIAL_KEYS:
		_material.set_shader_parameter(key, float(Content.art_material()[key]))
	_set_param("wear", wear)
	_set_param("rust", rust)
	_set_param("seed", wear_seed)


func _enter_tree() -> void:
	var art := _art()
	if art != null and not art.palette_changed.is_connected(_on_palette_changed):
		art.palette_changed.connect(_on_palette_changed)
	_paint()


func _exit_tree() -> void:
	var art := _art()
	if art != null and art.palette_changed.is_connected(_on_palette_changed):
		art.palette_changed.disconnect(_on_palette_changed)


func _process(_delta: float) -> void:
	var turn := global_rotation
	if turn != _last_rotation:
		_last_rotation = turn
		_material.set_shader_parameter("light_dir", LIGHT.rotated(-turn))
		_material.set_shader_parameter("down_dir", Vector2.DOWN.rotated(-turn))


## Use the SVG document `svg` (see StyleMask) as the shape.
func set_svg(svg: String) -> void:
	texture = StyleMask.texture(svg)


func _on_palette_changed(_palette: ArtPalette) -> void:
	_paint()


func _paint() -> void:
	var art := _art()
	if _material == null or art == null:
		return
	var p: ArtPalette = art.palette
	_material.set_shader_parameter("ramp", p.ramp(role))
	_material.set_shader_parameter("rust_ramp", p.ramp("rust"))
	_material.set_shader_parameter("dark_color", p.dark())
	# Chips show what is under the paint: bare metal or raw wood is the
	# lightest shade of its own ramp; painted things show a light steel.
	var bare := p.shade(role, 4) if role in BARE_ROLES else p.shade("steel", 3)
	_material.set_shader_parameter("bare_color", bare)


func _set_param(key: String, value: float) -> void:
	if _material != null:
		_material.set_shader_parameter(key, value)


func _art() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Art")
