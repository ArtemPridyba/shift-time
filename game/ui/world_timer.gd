class_name WorldTimer
extends CanvasLayer
## The world-time timer at the top left of the screen (task Д4): `WORLD 00:14.2`,
## the world seconds of the room (`RoomTime.world_seconds`, D96), the same time
## the clock on the column shows. Under Shift it counts back, at frame 0 it
## stands. Presentation only: it reads the room's time and keeps none. Every
## level gets one (`LevelRoom`); numbers and colours: `world_timer` of
## `data/time_hud.json`. Not the time colour: that belongs to the heroine (D60).

const LAYER := 50

var label: Label
var _room_time: RoomTime
var _shown := -1.0


## `00:14.2` for 14.23 seconds; minutes past 99 stay at 99:59.9.
static func text_of(seconds: float) -> String:
	var tenths := clampi(int(floor(maxf(seconds, 0.0) * 10.0)), 0, 99 * 600 + 599)
	return "WORLD %02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


func _init() -> void:
	layer = LAYER
	var data: Dictionary = Content.time_hud().get("world_timer", {})
	label = Label.new()
	label.name = "Text"
	label.position = Vector2(float(data.get("x_px", 22)), float(data.get("y_px", 16)))
	var settings := LabelSettings.new()
	settings.font_size = int(data.get("font_px", 20))
	settings.font_color = Color.from_string(str(data.get("color", "#d8d0c0")), Color.WHITE)
	settings.outline_size = int(data.get("outline_px", 4))
	settings.outline_color = Color.from_string(str(data.get("outline", "#0b0a09")), Color.BLACK)
	label.label_settings = settings
	label.modulate.a = float(data.get("alpha", 0.85))
	label.text = text_of(0.0)
	add_child(label)


## Watches `room_time` (the room's RoomTime).
func watch(room_time: RoomTime) -> void:
	_room_time = room_time


func _process(_delta: float) -> void:
	if _room_time == null or not is_instance_valid(_room_time):
		return
	var now := _room_time.world_seconds()
	if now != _shown:
		_shown = now
		label.text = text_of(now)
