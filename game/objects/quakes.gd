class_name Quakes
extends Node2D
## The quakes of a level (task Д4, D127): at moments of world time from the
## level's `quakes` in `data/levels.json` the camera shakes, dust falls from the
## ceiling, the hanging lamps swing, and at the strong one a lamp and a lump of
## plaster fall to the floor. The lamp is drawn by `WorldLight`, which asks
## `lamp_fall` here; the dust and the lump are drawn here.
##
## A recorded object: its state is the quake that started last and the ticks
## since its start, held at the end of the quake's window. So between quakes the
## state stands and the room may stand still (D56), and through a quake frames
## are written: under Shift the lamp flies back up, the lump back into the wall
## and the dust up to the ceiling without a jump, and after Shift is released
## the recorded quake plays again (rule «A»). Nothing here can be touched by
## the player. State: { "index": int (-1 before the first), "since": int }.
##
## Temporal object contract: docs/architecture.md, section 4.1.

@export var object_id := "quakes"

var index := -1
var since := 0
## Set by tests or by the level entry (`_plan()` reads it once).
var plan: QuakePlan
var _look := {}
var _ticks_per_second := 48.0
## Ticks: the window a quake's state runs for, the shake, the dust, a fall.
var _window := 1
var _shake_ticks := 1
var _dust_ticks := 1
var _fall_ticks := 1
var _shatter_ticks := 1
var _ceiling_y := 0.0
var _room_width := 0.0


func _init() -> void:
	_look = ObjectLook.of("quake")
	_ticks_per_second = Content.world_ticks_per_second(Content.time())
	_shake_ticks = _ticks("shake_seconds", 1.4)
	_dust_ticks = _ticks("dust_seconds", 2.0)
	_fall_ticks = _ticks("fall_seconds", 0.8)
	_shatter_ticks = _ticks("shatter_seconds", 0.6)


func _ready() -> void:
	add_to_group("temporal")
	_plan()


## The plan of this level, read once from the entry of the parent's scene.
func _plan() -> QuakePlan:
	if plan != null:
		return plan
	var room := get_parent()
	var entry := Content.level_for_scene(room.scene_file_path if room != null else "")
	plan = QuakePlan.from_data(entry.get("quakes"), _ticks_per_second)
	var layout := WorldData.layout(entry)
	_ceiling_y = WorldData.ceiling(layout) * WorldData.CELL
	_room_width = 32.0 * WorldData.CELL
	var back: Variant = layout.get("back", [])
	for piece: Variant in (back if back is Array else []):
		var r: Variant = piece.get("rect") if piece is Dictionary else null
		if r is Array and r.size() == 4:
			_room_width = maxf(_room_width, (float(r[0]) + float(r[2])) * WorldData.CELL)
	var longest := maxi(_shake_ticks, _dust_ticks)
	for fall: Dictionary in plan.falls:
		longest = maxi(longest, int(fall["delay"]) + _fall_ticks + _shatter_ticks)
	_window = longest + 1
	return plan


func capture_state() -> Dictionary:
	return {"index": index, "since": since}


func restore_state(state: Dictionary) -> void:
	index = int(state["index"])
	since = int(state["since"])
	queue_redraw()


## Everything follows the world tick: the state is the quake that started last
## and the ticks since, held once its window is over.
func simulate_tick(tick: int) -> void:
	var p := _plan()
	index = p.index_at(tick)
	since = 0 if index < 0 else mini(tick - p.start_tick(index), _window)
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## How hard the room shakes now: 0 to 1. Up at once, then dying away.
func shake_amount() -> float:
	if index < 0 or since >= _shake_ticks:
		return 0.0
	var x := float(since) / float(_shake_ticks)
	var rise := clampf(float(since + 1) / 3.0, 0.0, 1.0)
	return _plan().strength(index) * rise * (1.0 - x) * (1.0 - x)


## The camera's offset now, in pixels: a fixed pattern of two sines.
func shake_offset() -> Vector2:
	var amount := shake_amount()
	if amount <= 0.0:
		return Vector2.ZERO
	var t := float(since) / _ticks_per_second * TAU * ObjectLook.number(_look, "shake_hz", 9.0)
	var px := ObjectLook.number(_look, "shake_px", 7.0) * amount
	return Vector2(sin(t) * px, sin(t * 1.37 + 1.1) * px * 0.6)


## How far lamp number `lamp` (0-based) swings now, in radians.
func swing(lamp: int) -> float:
	var amount := shake_amount()
	if amount <= 0.0:
		return 0.0
	var t := float(since) / _ticks_per_second * TAU * 1.3 + float(lamp) * 0.9
	return deg_to_rad(ObjectLook.number(_look, "swing_degrees", 7.0)) * amount * sin(t)


## A falling lamp (0-based `lamp`): {"drop": 0..1 of the way down, "light":
## 0..1, "shatter": 0..1, "to_row": float}; an empty Dictionary for a lamp that
## does not fall.
func lamp_fall(lamp: int) -> Dictionary:
	for fall: Dictionary in _plan().falls:
		if str(fall["kind"]) == "lamp" and int(fall["lamp"]) == lamp:
			var parts := _fall_parts(fall)
			parts["to_row"] = float(fall["to_row"])
			return parts
	return {}


## Whether something falls or shakes now: for the look to redraw.
func is_active() -> bool:
	return index >= 0 and since < _window


func _fall_parts(fall: Dictionary) -> Dictionary:
	var elapsed := _plan().fall_elapsed(fall, index, since, _window)
	if elapsed < 0:
		return {"drop": 0.0, "light": 1.0, "shatter": 0.0}
	var x := clampf(float(elapsed) / float(_fall_ticks), 0.0, 1.0)
	var shatter := clampf(float(elapsed - _fall_ticks) / float(_shatter_ticks), 0.0, 1.0)
	# Falls with growing speed; the light dies on the way down.
	return {"drop": x * x, "light": 1.0 - x, "shatter": shatter}


func _ticks(key: String, fallback: float) -> int:
	return maxi(int(round(ObjectLook.number(_look, key, fallback) * _ticks_per_second)), 1)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera != null:
		camera.offset = shake_offset()


func _draw() -> void:
	if index < 0:
		return
	_draw_dust()
	for fall: Dictionary in _plan().falls:
		if str(fall["kind"]) == "lump":
			_draw_lump(fall)


## Specks of dust and plaster that fall from the ceiling across the room: a
## fixed pattern, so under Shift they rise back to it.
func _draw_dust() -> void:
	if since >= _dust_ticks:
		return
	var count := int(ObjectLook.number(_look, "dust_count", 36.0) * _plan().strength(index))
	var t := float(since) / _ticks_per_second
	var life := float(since) / float(_dust_ticks)
	var color := ObjectLook.color(_look, "dust_color", Color("#b9ad98"))
	for k in count:
		var u := fposmod(float(k) * 0.618034 + float(index) * 0.29, 1.0)
		var start := float(k % 5) * 0.08
		var age := t - start
		if age <= 0.0:
			continue
		var x := u * _room_width + sin(age * 3.0 + float(k)) * 6.0
		var y := _ceiling_y + 4.0 + 160.0 * age * age + 20.0 * age
		var size := 1.5 + float(k % 3)
		color.a = 0.75 * (1.0 - life)
		draw_rect(Rect2(x, y, size, size), color)


## A lump of plaster: it breaks out of the wall, falls with growing speed and
## lies on the floor; the kit picture `lump`.
func _draw_lump(fall: Dictionary) -> void:
	var elapsed := _plan().fall_elapsed(fall, index, since, _window)
	if elapsed < 0:
		return
	var from: Vector2 = fall["at"] * WorldData.CELL
	var px := ObjectLook.number(_look, "lump_px", 30.0)
	var picture := ObjectLook.picture("lump")
	var size := ObjectLook.fit(picture, px) if picture != null else Vector2(px, px * 0.66)
	var floor_y := float(fall["to_row"]) * WorldData.CELL - size.y / 2.0
	var x := clampf(float(elapsed) / float(_fall_ticks), 0.0, 1.0)
	var at := Vector2(from.x + 18.0 * x, lerpf(from.y, floor_y, x * x))
	var turn := 2.2 * x
	if picture != null:
		ObjectLook.draw_turned(self, picture, at, size, turn)
	else:
		draw_set_transform(at, turn)
		draw_rect(Rect2(-size / 2.0, size), Color("#9d917e"))
		draw_set_transform(Vector2.ZERO)
