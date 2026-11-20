class_name CameraView
extends RefCounted
## The two views of the camera (D83, 20.11.2026): close behind the heroine and
## the whole room fitted into the screen. Plain math so the tests can check it.


## The zoom that shows the whole `room` on a `screen`, never closer than `close`.
static func overview_zoom(room: Rect2, screen: Vector2, close: float) -> float:
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return close
	return minf(close, minf(screen.x / room.size.x, screen.y / room.size.y))


## A zoom between `close` and `far` for `amount` 0..1, eased at both ends and
## even in scale, so the room grows and shrinks at a steady pace.
static func blend_zoom(close: float, far: float, amount: float) -> float:
	var s := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	return exp(lerpf(log(close), log(far), s))


## Camera limits for `zoom`: the room itself, or, along a side where the screen
## sees more than the room, the room grown evenly on both ends, so the room
## stays in the middle of the screen instead of sticking to one edge.
static func limits(room: Rect2, screen: Vector2, zoom: float) -> Rect2i:
	var seen := screen / maxf(zoom, 0.0001)
	var grow := (seen - room.size).max(Vector2.ZERO) / 2.0
	var left := floori(room.position.x - grow.x)
	var top := floori(room.position.y - grow.y)
	var right := ceili(room.end.x + grow.x)
	var bottom := ceili(room.end.y + grow.y)
	return Rect2i(left, top, right - left, bottom - top)
