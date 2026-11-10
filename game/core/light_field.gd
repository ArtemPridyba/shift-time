class_name LightField
extends RefCounted
## Plain rules of light: which points a set of light sources reaches. A source is
## a Dictionary `{ "position": Vector2, "radius": float }` in the room's
## coordinates. No nodes, no drawing: the darkness mask and the glow items ask
## this class.


## True when `point` is inside the circle of at least one source.
static func is_lit(point: Vector2, sources: Array) -> bool:
	for source: Variant in sources:
		var s := source as Dictionary
		if point.distance_to(s["position"] as Vector2) <= float(s["radius"]):
			return true
	return false
