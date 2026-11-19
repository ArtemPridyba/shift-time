@tool
class_name MechGear
extends MechPart
## A cast-iron gear, or a rail roller with `teeth` 0 (task Д2). It rolls along
## the rack, rail or chain its driven object moves: the angle is the travel
## over the radius (MechDrive.rolling_angle). A gear meshed with another gets
## `ratio` = −(its partner's radius / its own radius) of the partner's ratio.
## The tooth profile is the mock-up's: root at 0.8 of the radius, a flat tip
## over 30 % of the pitch. Lit from above: lighter at the top, darker below.

@export var radius := 36.0:
	set(value):
		radius = maxf(value, 2.0)
		queue_redraw()
## 0 draws a smooth roller.
@export var teeth := 14:
	set(value):
		teeth = maxi(value, 0)
		queue_redraw()
@export var start_angle := 0.0:
	set(value):
		start_angle = value
		queue_redraw()


func angle() -> float:
	return start_angle + MechDrive.rolling_angle(travel, radius)


func _draw() -> void:
	var a := angle()
	var light := look_color("iron_light")
	var shadow := look_color("iron_shadow")
	var dark := look_color("iron_dark")
	var points := outline_points(a)
	var colors := PackedColorArray()
	for p in points:
		colors.append(light.lerp(shadow, clampf((p.y + radius) / (2.0 * radius), 0.0, 1.0)))
	draw_polygon(points, colors)
	draw_polyline(closed(points), look_color("outline"), outline_px(), true)
	draw_circle(Vector2.ZERO, radius * 0.6, dark)
	draw_circle(Vector2.ZERO, radius * 0.52, look_color("iron"))
	if radius > 12.0:
		var holes := 5 if radius > 27.0 else 4
		for k in holes:
			draw_circle(Vector2.from_angle(a + TAU * k / holes) * radius * 0.32, radius * 0.11, dark)
	else:
		# Too small for holes: a notch shows that it turns.
		draw_line(Vector2.ZERO, Vector2.from_angle(a) * radius * 0.5, dark, maxf(radius * 0.18, 1.0))
	draw_circle(Vector2.ZERO, radius * 0.16, light)
	draw_circle(Vector2.ZERO, radius * 0.06, dark)


## The rim at angle `a`: a circle for a roller, the teeth for a gear.
func outline_points(a: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if teeth == 0:
		for k in 32:
			points.append(Vector2.from_angle(a + TAU * k / 32.0) * radius)
		return points
	var root := radius * 0.8
	var pitch := TAU / teeth
	for k in teeth:
		var base := a + k * pitch
		points.append(Vector2.from_angle(base) * root)
		points.append(Vector2.from_angle(base + 0.18 * pitch) * radius)
		points.append(Vector2.from_angle(base + 0.48 * pitch) * radius)
		points.append(Vector2.from_angle(base + 0.66 * pitch) * root)
	return points
