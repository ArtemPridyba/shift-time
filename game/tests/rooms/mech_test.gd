extends Node2D
## The showcase of task Д2 (open in the editor and press F6): mechanisms drawn
## by code and particles that run backwards, on a dark Night Hall wall. A gate
## climbs a rack between two gears and turns a valve wheel; a lift rides a
## toothed column on a chain; a sliding door runs on rail rollers and turns its
## handwheel 2.5 times. Dust drifts in the lamp's light, ash falls, a wire
## sparks, a pipe drips, shards burst on the floor. Hold Shift: everything runs
## back from the recorded history, nothing glows (D60).

const FLOOR_Y := 900.0
const WALL := Color("#74382a")
const MORTAR := Color("#2e201c")
const LAMP_LIGHT := Color("#ffb060")
const LAMP_AT := Vector2(1200, 118)
const LAMP_SPREAD := 0.45
const LAMP_LENGTH := 720.0
const BRICK := Vector2(64, 24)
## Night: the wall is this much of its colour.
const NIGHT := 0.32


func _draw() -> void:
	var size := Vector2(1920, 1080)
	draw_rect(Rect2(Vector2.ZERO, size), MORTAR.darkened(0.4))
	var brick := WALL.darkened(1.0 - NIGHT)
	var row := 0
	var y := 0.0
	while y < FLOOR_Y:
		var x := -BRICK.x * 0.5 * (row % 2)
		while x < size.x:
			var k := ParticleField.rand01(7, row * 64 + int(x), 0)
			draw_rect(Rect2(Vector2(x + 2, y + 2), BRICK - Vector2(4, 4)), brick.darkened(k * 0.35))
			x += BRICK.x
		y += BRICK.y
		row += 1
	# The lamp's cone: light only, the dust inside it is the TimeParticles node.
	var reach := Vector2(tan(LAMP_SPREAD) * LAMP_LENGTH, LAMP_LENGTH)
	var glow := LAMP_LIGHT
	glow.a = 0.22
	var clear := LAMP_LIGHT
	clear.a = 0.0
	draw_polygon(PackedVector2Array([LAMP_AT, LAMP_AT + Vector2(-reach.x, reach.y), LAMP_AT + reach]),
		PackedColorArray([glow, clear, clear]))
	draw_line(Vector2(LAMP_AT.x, 0), LAMP_AT - Vector2(0, 14), Color("#2a2a30"), 3.0)
	draw_colored_polygon(PackedVector2Array([LAMP_AT + Vector2(-46, 8), LAMP_AT + Vector2(-14, -14),
		LAMP_AT + Vector2(14, -14), LAMP_AT + Vector2(46, 8)]), Color("#4c4c53"))
	draw_circle(LAMP_AT + Vector2(0, 6), 9.0, Color("#ffe0b0"))
	# The rail of the sliding door, the drip pipe and the sparking wire.
	draw_rect(Rect2(1340, 708, 520, 12), Color("#2a2a30"))
	draw_rect(Rect2(1340, 708, 520, 3), Color("#6c6c72"))
	draw_rect(Rect2(150, 352, 130, 26), Color("#35353a"))
	draw_rect(Rect2(232, 346, 40, 38), Color("#4c4c53"))
	draw_polyline(PackedVector2Array([Vector2(1920, 250), Vector2(1790, 268), Vector2(1712, 300)]), Color("#1c1c20"), 4.0)
	# The floor is a node above the objects: it hides the lower end of the
	# gate's rack.
