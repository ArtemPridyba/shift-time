class_name WallClock
extends Node2D
## The factory clock on a column (task Д4): its hands show the world time of
## the room (`RoomTime.world_seconds`), so under Shift they run back and at
## frame 0 they stand. The minute hand makes a turn in `minute_turn_seconds`
## world seconds, so the rewind shows in the hand; the hour hand moves
## `hours_per_minute_turn` hours meanwhile. It keeps no history: it reads the
## recorded time. Numbers: `kit_objects.clock` of `data/look.json`.

var _look := {}
var _room_time: RoomTime
var _seconds := -1.0


func _ready() -> void:
	_look = ObjectLook.of("clock")
	_room_time = WallClock.find_room_time(self)


func _process(_delta: float) -> void:
	var now := _room_time.world_seconds() if _room_time != null else 0.0
	if now != _seconds:
		_seconds = now
		queue_redraw()


## The minute hand's angle from twelve, clockwise, at world second `seconds`.
func minute_angle(seconds: float) -> float:
	var turn := maxf(ObjectLook.number(_look, "minute_turn_seconds", 60.0), 0.001)
	var start := ObjectLook.number(_look, "start_minutes", 0.0) / 60.0
	return (start + seconds / turn) * TAU


func hour_angle(seconds: float) -> float:
	return minute_angle(seconds) * ObjectLook.number(_look, "hours_per_minute_turn", 1.0) / 12.0


## The room's RoomTime: a child named RoomTime of this node or of a parent.
static func find_room_time(node: Node) -> RoomTime:
	var at := node
	while at != null:
		var found := at.get_node_or_null("RoomTime") as RoomTime
		if found != null:
			return found
		at = at.get_parent()
	return null


func _draw() -> void:
	var d := ObjectLook.number(_look, "diameter_px", 44.0)
	var face := ObjectLook.picture("clock")
	if face != null:
		draw_texture_rect(face, Rect2(Vector2(-d, -d) / 2.0, Vector2(d, d)), false)
	else:
		draw_circle(Vector2.ZERO, d / 2.0, Color("#d8d0b8"))
	var seconds := maxf(_seconds, 0.0)
	_hand("clock_hand_hour", d * 0.3, hour_angle(seconds))
	_hand("clock_hand_minute", d * 0.42, minute_angle(seconds))
	draw_circle(Vector2.ZERO, maxf(d * 0.04, 1.0), Color("#1c1c20"))


## A hand from the centre, `length` long, turned clockwise from twelve. The
## pictures stand upright with the pivot near their lower end.
func _hand(name: String, length: float, angle: float) -> void:
	var hand := ObjectLook.picture(name)
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	if hand != null:
		var w := length * float(hand.get_width()) / float(hand.get_height())
		draw_texture_rect(hand, Rect2(-w / 2.0, -length * 0.88, w, length), false)
	else:
		draw_line(Vector2.ZERO, Vector2(0.0, -length), Color("#1c1c20"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
