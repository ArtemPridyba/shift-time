class_name PlayerCamera
extends Camera2D
## The camera on the heroine (D83, 20.11.2026): close (`zoom` of
## `data/camera.json`) and a little ahead of her in the direction she faces;
## at the start of a level and while the `overview` key (Tab) is held it pulls
## back to show the whole room. Presentation only: it changes nothing in the
## world and nothing is recorded.


var _params := {}
var _room := Rect2()
## 0: the close view, 1: the whole room.
var _view := 0.0
var _start_left := 0.0
var _lead := 0.0


func _ready() -> void:
	_params = Content.camera()
	position_smoothing_speed = _number("follow_speed", 8.0)
	_apply()


## The room the camera keeps to, in room pixels.
func set_room(rect: Rect2) -> void:
	_room = rect
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


func close_zoom() -> float:
	return _number("zoom", 2.0)


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
	var facing := 1.0
	if player != null and player.has_method("facing"):
		facing = float(player.call("facing"))
	var target := facing * _number("lead_px", 140.0)
	_lead = lerpf(_lead, target, 1.0 - exp(-_number("lead_speed", 2.5) * delta))
	_apply()


func _apply() -> void:
	var screen := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var close := close_zoom()
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


func _number(key: String, fallback: float) -> float:
	var value: Variant = _params.get(key, fallback)
	return float(value) if value is float or value is int else fallback
