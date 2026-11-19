@tool
class_name MechValveWheel
extends MechPart
## A red cast-iron valve wheel (task Д2): the handwheel of the hermetic exit
## door and of the gate. It makes `turns` turns while its object goes from
## closed to open (MechDrive.wheel_angle): 2.5 for the exit door (D66).
## Mock-up numbers times 1.5: radius 33, five spokes, knobs on the rim.

@export var radius := 33.0:
	set(value):
		radius = maxf(value, 4.0)
		queue_redraw()
@export var spokes := 5:
	set(value):
		spokes = maxi(value, 1)
		queue_redraw()
## Negative turns the other way.
@export var turns := 2.5:
	set(value):
		turns = value
		queue_redraw()
@export var start_angle := 0.0:
	set(value):
		start_angle = value
		queue_redraw()


func angle() -> float:
	return start_angle + MechDrive.wheel_angle(fraction, turns)


func _draw() -> void:
	var a := angle()
	var valve := look_color("valve")
	var dark := look_color("iron_dark")
	var rim := radius * 0.23
	var mid := radius - rim * 0.5
	for k in spokes:
		var dir := Vector2.from_angle(a + TAU * k / spokes)
		draw_line(dir * radius * 0.2, dir * mid, dark, radius * 0.16)
	draw_arc(Vector2.ZERO, mid, 0.0, TAU, 48, valve, rim, true)
	draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 48, look_color("valve_light"), 1.8, true)
	draw_arc(Vector2.ZERO, mid - rim * 0.5, 0.0, TAU, 48, look_color("outline"), 1.2, true)
	for k in spokes:
		draw_circle(Vector2.from_angle(a + TAU * (k + 0.5) / spokes) * mid, radius * 0.14, valve.lightened(0.12))
	draw_circle(Vector2.ZERO, radius * 0.27, dark)
	draw_circle(Vector2.ZERO, radius * 0.1, look_color("iron_light"))
