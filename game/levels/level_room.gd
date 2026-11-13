extends "res://levels/test_room.gd"
## A level: a room with a way out. When the player reaches the node `Exit`
## (an `ExitZone`), the level is completed and, after `exit_zone.delay_seconds`
## of `data/objects.json`, LevelLoader moves on.

signal completed

## True from the tick the player reached the exit.
var is_completed := false

var _exit_ticks_left := 0


func _ready() -> void:
	super._ready()
	var exit := get_node_or_null("Exit") as ExitZone
	if exit != null:
		exit.reached.connect(_on_exit_reached)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_completed or _exit_ticks_left <= 0:
		return
	_exit_ticks_left -= 1
	if _exit_ticks_left == 0:
		var loader := get_node_or_null("/root/LevelLoader")
		if loader != null:
			loader.call("finish_level")


func _on_exit_reached() -> void:
	if is_completed:
		return
	is_completed = true
	var seconds := float((Content.objects().get("exit_zone", {}) as Dictionary).get("delay_seconds", 0.6))
	var per_second := float(Content.time().get("physics_ticks_per_second", 60))
	_exit_ticks_left = maxi(int(round(seconds * per_second)), 1)
	completed.emit()
