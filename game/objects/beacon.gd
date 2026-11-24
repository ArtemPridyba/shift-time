class_name Beacon
extends Node2D
## The red beacon over the way out (task Д4): a dome in a cage with a mirror
## turning inside. The mirror's angle comes from the world time of the room
## (`RoomTime.world_seconds`), so the glint runs across the dome and the light
## on the wall pulses by it, and under Shift the glint runs the other way; at
## frame 0 it stands. It keeps no history. Numbers: `kit_objects.beacon` of
## `data/look.json`.

var _look := {}
var _room_time: RoomTime
var _light: PointLight2D
var _seconds := -1.0


func _ready() -> void:
	_look = ObjectLook.of("beacon")
	_room_time = WallClock.find_room_time(self)
	_light = PointLight2D.new()
	_light.texture = KitTextures.soft_disc()
	_light.color = ObjectLook.color(_look, "color", Color("#ff3a24"))
	_light.texture_scale = ObjectLook.number(_look, "radius_px", 150.0) * 2.0 / float(KitTextures.DISC_SIZE)
	add_child(_light)
	_update(0.0)


func _process(_delta: float) -> void:
	var now := _room_time.world_seconds() if _room_time != null else 0.0
	if now != _seconds:
		_update(now)


## The mirror's angle at world second `seconds`: a turn in `turn_seconds`.
func mirror_angle(seconds: float) -> float:
	return seconds / maxf(ObjectLook.number(_look, "turn_seconds", 1.6), 0.001) * TAU


## How much of the mirror faces the room, 0 … 1: the light's pulse.
func facing(seconds: float) -> float:
	return 0.5 + 0.5 * cos(mirror_angle(seconds))


func _update(seconds: float) -> void:
	_seconds = seconds
	_light.energy = ObjectLook.number(_look, "energy", 0.8) * (0.35 + 0.65 * facing(seconds))
	queue_redraw()


func _draw() -> void:
	var px := ObjectLook.number(_look, "size_px", 22.0)
	var dome := ObjectLook.picture("beacon")
	var size := Vector2(px, px) if dome == null else ObjectLook.fit(dome, px)
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	if dome != null:
		draw_texture_rect(dome, r, false)
	else:
		draw_rect(r, Color("#8a1a12"))
	# The glint: where the mirror points across the dome, bright when it faces us.
	var s := maxf(_seconds, 0.0)
	var x := sin(mirror_angle(s)) * size.x * 0.32
	var glint := ObjectLook.color(_look, "color", Color("#ff3a24")).lightened(0.5)
	glint.a = 0.25 + 0.75 * facing(s)
	draw_circle(Vector2(x, -size.y * 0.55), size.x * 0.14, glint)
