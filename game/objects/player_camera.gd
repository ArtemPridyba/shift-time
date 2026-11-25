class_name PlayerCamera
extends Camera2D
## The camera on the heroine (D83, 20.11.2026): close and a little ahead of
## her in the direction she faces; at the start of a level and while the
## `overview` key (Tab) is held it pulls back to show the whole room. The
## player sets how close with the mouse wheel or the = and - keys (D95,
## 21.11.2026): from the whole room on the screen to `zoom_max` of
## `data/camera.json`; a level starts at `zoom`, and the choice is kept for the
## next levels while the game is open. While she rides the minecart of level
## 04 (D168) it pulls back by `ride_zoom` and looks `ride_lead_px` ahead along
## the ride, so the next switch shows early. Presentation only: it changes nothing in
## the world and nothing is recorded.


## The zoom the player chose, kept between levels while the game runs; 0 until
## the first wheel step.
static var _remembered := 0.0

var _params := {}
var _room := Rect2()
## 0: the close view, 1: the whole room.
var _view := 0.0
var _start_left := 0.0
var _lead := 0.0
## The zoom of the close view the player chose, and the one shown now on the way to it.
var _chosen := 0.0
var _shown := 0.0


## Forgets the chosen zoom, so the next level starts at `zoom` again (tests).
static func forget_zoom() -> void:
	_remembered = 0.0


func _ready() -> void:
	_params = Content.camera()
	position_smoothing_speed = _number("follow_speed", 8.0)
	_chosen = _remembered if _remembered > 0.0 else _number("zoom", 2.0)
	_chosen = _clamped(_chosen)
	_shown = _chosen
	_apply()


## The room the camera keeps to, in room pixels.
func set_room(rect: Rect2) -> void:
	_room = rect
	_chosen = _clamped(_chosen)
	_shown = _clamped(_shown)
	_apply()


## Shows the whole room for `seconds`, then slides to the close view; a move
## key after her walk-in ends it sooner.
func show_overview(seconds: float) -> void:
	_start_left = seconds
	_view = 1.0 if seconds > 0.0 else _view
	_apply()
	reset_smoothing()


## 0 while close, 1 while the whole room is shown, between while sliding.
func overview_amount() -> float:
	return _view


## The zoom of the close view shown now.
func close_zoom() -> float:
	return _shown


## The zoom of the close view the player chose; the camera slides to it.
func chosen_zoom() -> float:
	return _chosen


## The farthest the player may zoom out: the whole room on the screen.
func far_zoom() -> float:
	return CameraView.overview_zoom(_room, _screen(), _number("zoom_max", 3.0))


## Moves the chosen zoom by `notches` wheel steps (above 0: closer) and
## remembers it for the next levels. The start overview gives way at once.
func zoom_by(notches: float) -> void:
	_chosen = CameraView.step_zoom(_chosen, notches, far_zoom(), _number("zoom_max", 3.0), _number("zoom_step", 1.15))
	_remembered = _chosen
	_start_left = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var notches := 0.0
	if event is InputEventMagnifyGesture:
		var factor := (event as InputEventMagnifyGesture).factor
		if factor > 0.0:
			notches = log(factor) / log(_number("zoom_step", 1.15))
	elif event.is_action_pressed("zoom_in", true):
		notches = _wheel_steps(event)
	elif event.is_action_pressed("zoom_out", true):
		notches = -_wheel_steps(event)
	if notches != 0.0:
		zoom_by(notches)
		get_viewport().set_input_as_handled()


## One step per wheel click; a smooth wheel or a trackpad in the browser
## reports a fraction of a click in `factor`.
func _wheel_steps(event: InputEvent) -> float:
	if event is InputEventMouseButton and (event as InputEventMouseButton).factor > 0.0:
		return minf((event as InputEventMouseButton).factor, 1.0)
	return 1.0


func _physics_process(delta: float) -> void:
	var player := get_parent()
	if _start_left > 0.0:
		_start_left -= delta
		# While she walks in by herself the keys do nothing, so they don't cut it short.
		var walking_in := player != null and player.has_method("intro_ticks_left") and int(player.call("intro_ticks_left")) > 0
		if not walking_in and (Input.get_axis("move_left", "move_right") != 0.0 or Input.is_action_pressed("jump")):
			_start_left = 0.0
	var want := 1.0 if _start_left > 0.0 or Input.is_action_pressed("overview") else 0.0
	_view = move_toward(_view, want, delta / _number("overview_blend_seconds", 0.7))
	var ride: Dictionary = player.call("ride_view") if player != null and player.has_method("ride_view") else {}
	var want_zoom := _chosen * (_number("ride_zoom", 1.0) if not ride.is_empty() else 1.0)
	_shown = CameraView.ease_zoom(_shown, _clamped(want_zoom), _number("zoom_speed", 10.0), delta)
	var facing := 1.0
	if player != null and player.has_method("facing"):
		facing = float(player.call("facing"))
	var target := facing * _number("lead_px", 140.0)
	if not ride.is_empty():
		var motion: Vector2 = ride.get("direction", Vector2.ZERO)
		target = signf(motion.x) * _number("ride_lead_px", 360.0) if absf(motion.x) > 0.3 else _lead
	_lead = lerpf(_lead, target, 1.0 - exp(-_number("lead_speed", 2.5) * delta))
	_apply()


func _apply() -> void:
	var screen := _screen()
	var close := _shown
	var far := CameraView.overview_zoom(_room, screen, close)
	var amount := smoothstep(0.0, 1.0, _view)
	var z := CameraView.blend_zoom(close, far, _view)
	zoom = Vector2(z, z)
	# Her feet stand low on the screen, not in the middle of it (Д5.1).
	var near_focus := Vector2(_lead, -CameraView.focus_height(screen.y, close, _number("feet_screen_y", 0.72)))
	if _room.size != Vector2.ZERO and get_parent() is Node2D:
		var parent := get_parent() as Node2D
		var room_centre := _room.get_center() - parent.global_position
		position = near_focus.lerp(room_centre, amount)
		var limit := CameraView.limits(_room, screen, z)
		limit_left = limit.position.x
		limit_top = limit.position.y
		limit_right = limit.end.x
		limit_bottom = limit.end.y
	else:
		position = near_focus


func _screen() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)


## The zoom kept between the whole room and the closest view.
func _clamped(value: float) -> float:
	var near := _number("zoom_max", 3.0)
	if _room.size == Vector2.ZERO:
		return clampf(value, 0.01, near)
	return clampf(value, minf(far_zoom(), near), near)


func _number(key: String, fallback: float) -> float:
	var value: Variant = _params.get(key, fallback)
	return float(value) if value is float or value is int else fallback
