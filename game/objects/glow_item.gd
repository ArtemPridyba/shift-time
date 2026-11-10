class_name GlowItem
extends Node2D
## A special item. Its glow shows only where a lamp lights it: in the dark it
## draws nothing. Decoration, not a temporal object: it is never recorded and
## affects nothing.

const GLOW_COLOR := Color("#7FE8FF")
const BODY_COLOR := Color("#3a4048")
const SIZE := 18.0


## True while a lit lamp of this room lights the item well enough.
func is_glowing() -> bool:
	return LightField.is_lit(position, _sources())


## How brightly the item is lit, 0..1.
func brightness() -> float:
	return LightField.brightness(position, _sources())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, SIZE, BODY_COLOR)
	var sources := _sources()
	if LightField.is_lit(position, sources):
		var glow := Color(GLOW_COLOR, clampf(LightField.brightness(position, sources) * 1.4, 0.0, 1.0))
		draw_circle(Vector2.ZERO, SIZE * 0.6, glow)
		draw_arc(Vector2.ZERO, SIZE * 1.4, 0.0, TAU, 32, glow, 2.0)


func _sources() -> Array:
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
