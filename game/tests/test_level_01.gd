extends RefCounted
## Tests of what level 01 needs (task 2.5): a door that closes once, per-level
## object settings in levels.json, the room after its prelude and the exit.

const DOOR_PATH := "res://objects/door.tscn"
const LEVEL_PATH := "res://levels/level_01.tscn"
const ONCE := {"cycle": "once", "hold_open_seconds": 1, "close_seconds": 5}

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_door_closes_once_and_stays_closed() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.apply_settings(ONCE)
	var ticks := int(Content.time()["physics_ticks_per_second"])
	check(door.open == Door.OPEN_MAX, "a door that runs once starts fully open, is %d" % door.open)
	for i in ticks - 1:
		door.simulate_tick(i)
	check(door.open == Door.OPEN_MAX, "the door stays open for hold_open_seconds, is %d" % door.open)
	var last := door.open
	var worst := 0
	for i in 5 * ticks + 1:
		door.simulate_tick(i)
		check(door.open <= last, "the door must only close, went from %d to %d" % [last, door.open])
		worst = maxi(worst, last - door.open)
		last = door.open
	check(door.open == 0, "the door is closed after close_seconds, is %d" % door.open)
	check(worst <= int(Content.time()["max_state_step"]), "the door jumps %d per tick" % worst)
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
	check(door.open == 0, "a door that runs once must never open again, is %d" % door.open)
	door.free()


func test_door_without_settings_still_loops() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	var opened := false
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
		opened = opened or door.open == Door.OPEN_MAX
	check(opened and not door.once, "a plain door keeps its cycle")
	door.free()


func test_level_object_settings_are_checked() -> void:
	var entry := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "objects": {"door": ONCE}}
	check(Content.validate_levels([entry], 20.0).is_empty(), "good object settings must pass: %s" % [Content.validate_levels([entry], 20.0)])
	for bad: Variant in [[], {"door": 3}, {"door": {"cycle": "twice"}}, {"door": {"close_seconds": 0}}, {"door": {"close_seconds": "fast"}}]:
		var broken := entry.duplicate(true)
		broken["objects"] = bad
		check(not Content.validate_levels([broken], 20.0).is_empty(), "object settings %s must be reported" % [bad])
	var objects: Dictionary = Content.objects().duplicate(true)
	objects.erase("exit_zone")
	check(not Content.validate_objects(objects, Content.time()).is_empty(), "objects.json without exit_zone must be reported")


func test_level_01_starts_with_the_door_half_closed_and_closing() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	check(door.open > 350 and door.open < 650, "after the prelude the door is about half closed, is %d" % door.open)
	var gap := door.travel * door.open / Door.OPEN_MAX
	check(gap < player.body_rect().size.y + 16.0, "the doorway (%.0f px) must already be too low to promise a run through" % gap)
	var before := door.open
	await _ticks(30)
	check(door.open < before, "the door keeps closing in front of the player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed 4.5 s after the start, is %d" % door.open)
	check(not bool(room.get("is_completed")), "standing still never completes the level")
	await _free(room)


func test_level_01_shift_opens_the_door_and_holds_it_open() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed before Shift")
	var start := player.global_position
	Input.action_press("rewind")
	var last := door.open
	for i in 9 * 60:
		await _ticks(1)
		check(door.open >= last, "under Shift the door must only open, went from %d to %d" % [last, door.open])
		last = door.open
	check(door.open == Door.OPEN_MAX, "at the start of the history the door is fully open, is %d" % door.open)
	await _ticks(120)
	check(door.open == Door.OPEN_MAX, "the door stays open while Shift is held")
	check(player.global_position.distance_to(start) < 1.0, "Shift must not move the player")
	Input.action_release("rewind")
	await _ticks(8 * 60)
	check(door.open == 0, "released Shift replays the closing (rule A), door is %d" % door.open)
	await _free(room)


func test_level_01_fits_one_screen() -> void:
	var room := await _load()
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := blocks.get_used_rect().size * blocks.tile_set.tile_size
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	check(size.x == width, "the room is %d px wide, the screen %d" % [size.x, width])
	check(size.y >= height and size.y < height + blocks.tile_set.tile_size.y, "the room is %d px tall, the screen %d" % [size.y, height])
	await _free(room)


func test_finish_level_needs_a_running_level() -> void:
	var loader := _tree.root.get_node_or_null("LevelLoader")
	check(loader != null, "LevelLoader autoload is missing")
	if loader != null:
		check(str(loader.get("current_id")).is_empty() and not bool(loader.call("finish_level")), "finish_level without a running level changes nothing")


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame
	_reset_time()


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame


func _reset_time() -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
