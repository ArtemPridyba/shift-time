class_name WaterFloat
extends AnimatableBody2D
## A platform that floats on its parent `Water`. It has no state of its own:
## the tank puts it on the surface from the level, so it rises and sinks with
## the water both ways and never drifts from it. Place it as a child of the
## water at the x it should keep; the y is set by the water.
## With `sync_to_physics` the player rides it like a moving platform.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")


func _init() -> void:
	sync_to_physics = true


func body_size() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size
	return Vector2(192, 32)


func _draw() -> void:
	var size := body_size()
	draw_rect(Rect2(-size / 2.0, size), BODY_COLOR)
	draw_rect(Rect2(Vector2(-size.x / 2.0 + 8.0, -size.y / 2.0), Vector2(size.x - 16.0, 6.0)), ACCENT_COLOR)
