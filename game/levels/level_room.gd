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
	_begin_intro()
	var player := get_node_or_null("Player") as Player
	if player != null:
		player.show_overview(float(Content.camera().get("overview_start_seconds", 0.0)))
	var exit := get_node_or_null("Exit") as ExitZone
	if exit != null:
		exit.reached.connect(_on_exit_reached)
	_add_world_timer()


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


## The `WORLD 00:14.2` timer on every level (Д4), unless `world_timer.show`
## of `data/time_hud.json` is false.
func _add_world_timer() -> void:
	var data: Dictionary = Content.time_hud().get("world_timer", {})
	var room_time := get_node_or_null("RoomTime") as RoomTime
	if room_time == null or not bool(data.get("show", true)):
		return
	var timer := WorldTimer.new()
	timer.name = "WorldTimer"
	timer.watch(room_time)
	add_child(timer)


## In a level a fall into a pit open to the bottom is death (level 09, D135):
## the room starts again, as after drowning or burning.
func _on_fell() -> void:
	restart()


## The reset key, drowning and burning bring the hero in again.
func restart() -> void:
	super.restart()
	_begin_intro()


## The hero comes in by himself for `intro_seconds` of this level's entry in
## `data/levels.json` (0 or missing: he is simply there): fades in at the
## entrance and walks right while the keys are ignored. Used at the start and
## after every reset.
func _begin_intro() -> void:
	var player := get_node_or_null("Player") as Player
	if player == null:
		return
	var entry := Content.level_for_scene(scene_file_path)
	var seconds := float(entry.get("intro_seconds", 0.0))
	if seconds > 0.0:
		var per_second := float(Content.time().get("physics_ticks_per_second", 60))
		player.begin_intro(int(round(seconds * per_second)))
