@tool
class_name MechRack
extends MechPart
## A toothed bar (task Д2): the column a platform's gear climbs, the rack on
## the side of a gate. A rack fixed to a moving object is its child and moves
## with it; a rack seen through a slot can instead slide its teeth by the
## driven object's travel (`scroll`). Numbers as in the mock-up, times 1.5:
## pitch 15, tooth depth 9, bar 21 px.

@export var length := 300.0:
	set(value):
		length = maxf(value, 1.0)
		queue_redraw()
@export var pitch := 15.0:
	set(value):
		pitch = maxf(value, 2.0)
		queue_redraw()
@export var depth := 9.0:
	set(value):
		depth = value
		queue_redraw()
@export var width := 21.0:
	set(value):
		width = value
		queue_redraw()
## Along x instead of along y.
@export var horizontal := false:
	set(value):
		horizontal = value
		queue_redraw()
## The side of the teeth: −1 left (or top when horizontal), 1 right (or bottom).
@export var teeth_side := -1:
	set(value):
		teeth_side = -1 if value < 0 else 1
		queue_redraw()
## Teeth slide along the bar by the travel instead of standing still.
@export var scroll := false:
	set(value):
		scroll = value
		queue_redraw()


## Where the teeth start along the bar, 0 ≤ offset < pitch.
func teeth_offset() -> float:
	return MechDrive.link_offset(travel, pitch) if scroll else 0.0


func _draw() -> void:
	var iron := look_color("iron")
	var outline := look_color("outline")
	var half := width * 0.5
	var bar := _quad(0.0, length, -half, half)
	draw_colored_polygon(bar, iron)
	draw_colored_polygon(_quad(0.0, length, half * 0.4, half * 0.4 + 3.0), look_color("iron_light"))
	draw_polyline(closed(bar), outline, outline_px(), true)
	var edge := teeth_side * half
	var tip := teeth_side * (half + depth)
	var u := teeth_offset() - pitch
	var shadow := look_color("iron_shadow")
	while u < length:
		if u >= 0.0 and u + 0.7 * pitch <= length:
			var tooth := PackedVector2Array([
				_p(u, edge), _p(u + 0.2 * pitch, tip), _p(u + 0.5 * pitch, tip), _p(u + 0.7 * pitch, edge)])
			draw_colored_polygon(tooth, shadow)
			draw_polyline(tooth, outline, outline_px(), true)
		u += pitch


## A point `u` along the bar and `v` across it.
func _p(u: float, v: float) -> Vector2:
	return Vector2(u, v) if horizontal else Vector2(v, u)


func _quad(u0: float, u1: float, v0: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([_p(u0, v0), _p(u1, v0), _p(u1, v1), _p(u0, v1)])
