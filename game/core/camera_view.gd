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


## Where the close view looks on her, from her feet up, so that her feet
## stand at `feet_screen_y` of the screen's height (0.5 the middle) at `zoom`
## (Д5.1: not half a screen of floor under her).
static func focus_height(screen_height: float, zoom: float, feet_screen_y: float) -> float:
	return (feet_screen_y - 0.5) * screen_height / maxf(zoom, 0.0001)


## The zoom after `notches` steps of the wheel (D95, 21.11.2026): each step
## multiplies the zoom by `step` (above 1: closer, below 0 notches: farther),
## so a step feels the same close up and far away. It stays between `far`
## (the whole room) and `near` (the closest view).
static func step_zoom(zoom: float, notches: float, far: float, near: float, step: float) -> float:
	var low := minf(far, near)
	return clampf(zoom * pow(step, notches), low, near)


## One frame of the camera sliding from the zoom it shows to the chosen one,
## even in scale, `speed` per second (exponential, never overshoots).
static func ease_zoom(shown: float, target: float, speed: float, delta: float) -> float:
	if shown <= 0.0 or target <= 0.0:
		return target
	var t := 1.0 - exp(-speed * delta)
	return exp(lerpf(log(shown), log(target), t))
