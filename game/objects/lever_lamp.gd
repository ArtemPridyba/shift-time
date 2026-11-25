class_name LeverLamp
extends Node2D
## A signal lamp that shows a lever's state (level 02, D161): red while the
## lever is off, green once it is on. One hangs over the lever behind the bars,
## one over the gate it opens, so the pair reads as one circuit. It follows the
## recorded lever on every frame, so under Shift it turns back with it. It
## keeps no history and changes nothing. Not cyan: cyan is the time device's.

const OFF_COLOR := Color("#d23a2a")
const ON_COLOR := Color("#5fd35a")
const HOUSING_COLOR := Color("#2b2b30")
const RADIUS := 6.0
const GLOW_RADIUS := 26.0

## The lever, by path from this node.
@export var lever_path: NodePath

var _glow: Node2D


func _ready() -> void:
	_glow = Node2D.new()
	_glow.name = "Glow"
	var glow_material := CanvasItemMaterial.new()
	glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_material
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _process(_delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()


func is_on() -> bool:
	var lever := get_node_or_null(lever_path) as Lever
	return lever != null and lever.on


func _color() -> Color:
	return ON_COLOR if is_on() else OFF_COLOR


func _draw() -> void:
	draw_rect(Rect2(Vector2(-RADIUS - 3.0, -RADIUS - 3.0), Vector2(RADIUS + 3.0, RADIUS + 3.0) * 2.0), HOUSING_COLOR)
	draw_circle(Vector2.ZERO, RADIUS, _color())


func _draw_glow() -> void:
	for i in 4:
		var r := GLOW_RADIUS * (1.0 - i * 0.22)
		_glow.draw_circle(Vector2.ZERO, r, Color(_color(), 0.08))
	_glow.draw_circle(Vector2.ZERO, RADIUS * 0.6, Color(_color().lightened(0.5), 0.9))
