@tool
class_name MechChain
extends MechPart
## A chain looped over two drums (task Д2): the first drum at the node, the
## second at `to`. The links run along the loop by the driven object's travel
## (MechDrive.link_offset) and the drums turn with them, so a platform on a
## chain pulls it forward and Shift pulls it back. Links alternate: a ring seen
## flat, then one seen edge-on, as in the mock-up's hook chain.

## The second drum, in this node's coordinates.
@export var to := Vector2(0, 300):
	set(value):
		to = value
		queue_redraw()
@export var drum_radius := 15.0:
	set(value):
		drum_radius = maxf(value, 1.0)
		queue_redraw()
## Length of one link along the chain; rounded so the loop closes.
@export var pitch := 13.5:
	set(value):
		pitch = maxf(value, 2.0)
		queue_redraw()
@export var link_width := 9.0:
	set(value):
		link_width = value
		queue_redraw()
@export var drums := true:
	set(value):
		drums = value
		queue_redraw()


func loop_length() -> float:
	return 2.0 * to.length() + TAU * drum_radius


## The link pitch that closes the loop.
func link_step() -> float:
	var perimeter := loop_length()
	return perimeter / maxi(int(round(perimeter / pitch)), 2)


## Where the links start along the loop, 0 ≤ offset < link_step().
func links_offset() -> float:
	return MechDrive.link_offset(travel, link_step())


func _draw() -> void:
	var span := to.length()
	if span <= 0.0:
		return
	var dark := look_color("iron_dark")
	if drums:
		var turn := MechDrive.rolling_angle(travel, drum_radius)
		for center in [Vector2.ZERO, to]:
			draw_circle(center, drum_radius, look_color("iron"))
			draw_arc(center, drum_radius, 0.0, TAU, 32, look_color("outline"), outline_px(), true)
			for k in 3:
				draw_line(center, center + Vector2.from_angle(turn + TAU * k / 3.0) * drum_radius * 0.8, dark, 2.0)
			draw_circle(center, drum_radius * 0.25, look_color("iron_light"))
	var step := link_step()
	var count := int(round(loop_length() / step))
	var offset := links_offset()
	var ring := look_color("iron_light").lerp(dark, 0.45)
	for k in count:
		var s := k * step + offset
		var p := point_at(s)
		var along := (point_at(s + 0.5) - point_at(s - 0.5)).normalized()
		if k % 2 == 0:
			var oval := PackedVector2Array()
			for j in 13:
				var t := TAU * j / 12.0
				oval.append(p + along * cos(t) * step * 0.55 + along.orthogonal() * sin(t) * link_width * 0.5)
			draw_polyline(oval, ring, 2.6, true)
		else:
			draw_line(p - along * step * 0.4, p + along * step * 0.4, dark, link_width * 0.35)


## The point at `s` along the loop: down the first strand, round the second
## drum, back up the other strand, round the first drum.
func point_at(s: float) -> Vector2:
	var span := to.length()
	var d := to / span
	var n := d.orthogonal() * -1.0
	var r := drum_radius
	var half := PI * r
	s = fposmod(s, loop_length())
	if s < span:
		return n * r + d * s
	s -= span
	if s < half:
		return to + Vector2.from_angle(n.angle() - s / r) * r
	s -= half
	if s < span:
		return to - n * r - d * s
	s -= span
	return Vector2.from_angle((-n).angle() - s / r) * r
