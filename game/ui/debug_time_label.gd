extends CanvasLayer
## Temporary on-screen text for the direction of time, so a person can see
## `TimeManager` work before the real indicator exists. The wrist device and
## its indicator (task 1.5, `time_hud.*`) replace it: delete this file and its
## node in `levels/test_room.tscn` then.
##
## The arrows carry the direction as well as the words: not color alone.

const TEXT_FORWARD := "TIME  >>  FORWARD"
const TEXT_BACKWARD := "TIME  <<  REWIND"

var _label := Label.new()


func _ready() -> void:
	layer = 100
	_label.position = Vector2(32, 24)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	add_child(_label)
	var manager := get_node_or_null("/root/TimeManager")
	if manager == null:
		_label.text = "TIME  ??  NO MANAGER"
		return
	manager.direction_changed.connect(_on_direction_changed)
	_on_direction_changed(manager.direction)


func _on_direction_changed(direction: int) -> void:
	_label.text = TEXT_BACKWARD if direction < 0 else TEXT_FORWARD
