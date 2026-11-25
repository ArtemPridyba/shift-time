class_name Rails
extends Node2D
## The rails of level 04 (D168): the segments of `RailTrack` as data, drawn on
## trestles over the pit, with buffers at the stops and the hoist line under
## the walkway. Decoration and data only: nothing here is recorded and nothing
## collides. The cart (`Minecart`) reads `track()`.

const RAIL_COLOR := Color("#8a8f96")
const SLEEPER_COLOR := Color("#5b4632")
const TRESTLE_COLOR := Color("#3c4148")
const BUFFER_COLOR := Color("#b8352a")
const HOIST_COLOR := Color("#5a5f66")

## The segments, in the format of `RailTrack.from_data`, in the parent's pixels.
@export var segments: Array = []
## The y of the hoist line the hooked cart hangs from (its wheels), and how far
## up from there its rail runs.
@export var hoist_y := 0.0
@export var hoist_rail_y := 0.0
## The x the hoist line runs between.
@export var hoist_from_x := 0.0
@export var hoist_to_x := 0.0
## Trestles reach down to this y.
@export var ground_y := 0.0

var _track: RailTrack


func track() -> RailTrack:
	if _track == null:
		_track = RailTrack.from_data(segments)
	return _track


func _ready() -> void:
	z_index = -2
	queue_redraw()


func _draw() -> void:
	var rails := track()
	if hoist_to_x > hoist_from_x:
		draw_line(Vector2(hoist_from_x, hoist_rail_y), Vector2(hoist_to_x, hoist_rail_y), HOIST_COLOR, 6.0)
	for id: String in rails.ids():
		var pts := rails.points(id)
		var length := rails.length(id)
		# Trestles every two cells down to the ground, then sleepers and the rail.
		var d := 0.0
		while d <= length:
			var p := rails.point_at(id, d)
			if ground_y > p.y:
				draw_line(p + Vector2(0, 10), Vector2(p.x, ground_y), TRESTLE_COLOR, 6.0)
			d += 128.0
		d = 0.0
		while d <= length:
			var p := rails.point_at(id, d)
			draw_rect(Rect2(p + Vector2(-10, 0), Vector2(20, 8)), SLEEPER_COLOR)
			d += 32.0
		draw_polyline(pts, RAIL_COLOR, 6.0)
		var end := rails.end_of(id)
		if str(end.get("kind", "")) == RailTrack.END_STOP:
			var last := pts[pts.size() - 1]
			var back := (pts[pts.size() - 2] - last).normalized()
			# The buffer stands a little past the end, where the cart's nose stops.
			var at := last - back * 100.0
			draw_rect(Rect2(at + Vector2(-12, -44), Vector2(24, 44)), BUFFER_COLOR)
			draw_rect(Rect2(at + Vector2(-12, -44), Vector2(24, 44)), TRESTLE_COLOR, false, 3.0)
