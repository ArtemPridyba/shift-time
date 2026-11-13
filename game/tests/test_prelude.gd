extends RefCounted
## Tests of the level prelude (task 2.6): its length and scripted events come
## from `levels.json`, an event fires on its tick and rewinds like any frame,
## the same room records the same prelude every time and after a reset, and
## broken event data is reported. Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room_water.tscn"
const BACK := TimeWorld.BACKWARD

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## A lever-like interaction point: pressing flips `on` and powers its target.
class Switch extends RefCounted:
	var object_id := "switch"
	var target := "motor"
	var on := false

	func capture_state() -> Dictionary:
		return {"on": on}

	func restore_state(state: Dictionary) -> void:
		on = bool(state["on"])

	func simulate_tick(_tick: int) -> void:
		pass

	func on_time_direction_changed(_direction: int) -> void:
		pass

	func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
		return false

	func get_interaction_change(_objects: Array) -> Array:
		return [{"id": object_id, "state": {"on": not on}}, {"id": target, "state": {"powered": not on}}]


## Counts up while powered; `mark` is set only by a scripted state event.
class Motor extends RefCounted:
	var object_id := "motor"
	var powered := false
	var turns := 0
	var mark := 0

	func capture_state() -> Dictionary:
		return {"powered": powered, "turns": turns, "mark": mark}

	func restore_state(state: Dictionary) -> void:
		powered = bool(state["powered"])
		turns = int(state["turns"])
		mark = int(state["mark"])

	func simulate_tick(_tick: int) -> void:
		if powered:
			turns += 1

	func on_time_direction_changed(_direction: int) -> void:
		pass

	func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
		return false


# --- the rule, no nodes -----------------------------------------------------

func test_prelude_events_fire_on_their_tick_and_rewind() -> void:
	var switch := Switch.new()
	var motor := Motor.new()
	var objects := [switch, motor]
	var world := TimeWorld.from_config(Content.time())
	world.start(objects)
	var events := TimeWorld.prelude_events_from_data([
		{"second": 0.5, "press": "switch"},
		{"second": 1.0, "id": "motor", "state": {"mark": 7.0}},
	], 60.0)
	check(events.size() == 2 and int(events[0]["tick"]) == 30, "a second must turn into its tick")
	world.run_prelude(objects, 90, events)
	check(world.timeline.head() == 90, "a 90-tick prelude after the start frame must end at frame 90")
	check(switch.on and motor.powered and motor.mark == 7, "both events must have happened by the end")
	check(motor.turns == 60, "the motor runs from the press on tick 30, got %d turns" % motor.turns)
	_rewind_to(world, objects, 60)
	check(motor.mark == 7, "frame 60 holds the state event")
	_rewind_to(world, objects, 59)
	check(motor.mark == 0 and switch.on, "frame 59 is before the state event and after the press")
	_rewind_to(world, objects, 30)
	check(switch.on and motor.powered, "frame 30 holds the press")
	_rewind_to(world, objects, 29)
	check(not switch.on and not motor.powered and motor.turns == 0, "frame 29 is before the press")
	for i in 61:
		world.tick(TimeWorld.FORWARD, objects)
	check(world.timeline.cursor() == 90 and motor.mark == 7 and motor.turns == 60,
		"releasing Shift replays the events from the record (rule «A»)")


func test_event_on_the_first_tick_changes_the_starting_frame() -> void:
	var switch := Switch.new()
	var motor := Motor.new()
	var objects := [switch, motor]
	var world := TimeWorld.from_config(Content.time())
	world.start(objects)
	world.run_prelude(objects, 10, TimeWorld.prelude_events_from_data([{"second": 0, "press": "switch"}], 60.0))
	_rewind_to(world, objects, 0)
	check(switch.on and motor.powered, "an event at second 0 is part of the starting frame")


# --- data -------------------------------------------------------------------

func test_broken_prelude_events_are_reported() -> void:
	var history := float(Content.time()["history_seconds"])
	var level := {"id": "a", "scene": ROOM_PATH, "prelude_seconds": 2, "title": "A"}
	var good := level.duplicate(true)
	good["prelude_events"] = [{"second": 1, "press": "valve"}, {"second": 2, "id": "water", "state": {"level": 0}}]
	check(Content.validate_levels([good], history).is_empty(), "good prelude events must pass: %s" % [Content.validate_levels([good], history)])
	var cases := {
		"not a list": {"prelude_events": {"second": 1}},
		"after the prelude": {"prelude_events": [{"second": 3, "press": "valve"}]},
		"before the prelude": {"prelude_events": [{"second": -1, "press": "valve"}]},
		"no second": {"prelude_events": [{"press": "valve"}]},
		"both forms": {"prelude_events": [{"second": 1, "press": "valve", "id": "water", "state": {"level": 0}}]},
		"neither form": {"prelude_events": [{"second": 1}]},
		"empty state": {"prelude_events": [{"second": 1, "id": "water", "state": {}}]},
		"state without id": {"prelude_events": [{"second": 1, "state": {"level": 0}}]},
	}
	for name: String in cases:
		var broken := level.duplicate(true)
		broken.merge(cases[name], true)
		check(not Content.validate_levels([broken], history).is_empty(), "prelude events '%s' must be reported" % name)


func test_every_prelude_event_names_an_object_of_its_room() -> void:
	for entry: Variant in Content.levels():
		var events: Array = (entry as Dictionary).get("prelude_events", [])
		if events.is_empty():
			continue
		var room: Node = (load(str(entry["scene"])) as PackedScene).instantiate()
		_tree.root.add_child(room)
		await _tree.physics_frame
		var time: RoomTime = room.get_node("RoomTime")
		var ids := {}
		for object in time.temporal_objects():
			ids[str(object.get("object_id"))] = object
		for event: Variant in events:
			var data := event as Dictionary
			var id := str(data.get("press", data.get("id", "")))
			check(ids.has(id), "%s: prelude event names '%s', which is not in the room" % [entry["id"], id])
			if data.has("press") and ids.has(id):
				check((ids[id] as Object).has_method("get_interaction_change"), "%s: '%s' cannot be pressed" % [entry["id"], id])
		room.queue_free()
		await _tree.process_frame


# --- in the water test room -------------------------------------------------

func test_room_takes_its_prelude_from_levels_json() -> void:
	var room := _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var water: Water = room.get_node("Water")
	var lever: Lever = room.get_node("Lever")
	var entry := Content.level_for_scene(ROOM_PATH)
	check(is_equal_approx(time.prelude_seconds, float(entry["prelude_seconds"])), "the prelude length must come from levels.json")
	check(lever.on and water.powered and water.level < Water.LEVEL_MAX, "after the prelude the valve is open and the well drains")
	var objects := time.temporal_objects()
	var at_event := int(round(float(entry["prelude_events"][0]["second"]) * 60.0))
	var history := _frames(time.world)
	check(history.size() >= at_event + 2, "the prelude must be recorded")
	var before: Dictionary = history[at_event - 1]
	var after: Dictionary = history[at_event]
	check(not bool(before["valve"]["on"]) and not bool(before["water"]["powered"]), "before the event the valve is shut")
	check(bool(after["valve"]["on"]) and bool(after["water"]["powered"]), "the scripted press opens the valve and the water on its tick")
	check(int(history[0]["water"]["level"]) == Water.LEVEL_MAX, "the prelude starts with a full well")
	check(objects.size() > 0, "the room has recorded objects")
	await _free_room(room)


func test_the_same_room_records_the_same_prelude_every_time() -> void:
	var first := _load_room()
	var a := _frames((first.get_node("RoomTime") as RoomTime).world)
	await _free_room(first)
	var second := _load_room()
	var time: RoomTime = second.get_node("RoomTime")
	var b := _frames(time.world)
	check(a.size() > 1 and a == b, "two loads of one room must record the same prelude frame by frame")
	# Change the past, then reset: the prelude comes back the same.
	for i in 120:
		time.world.tick(BACK, time.temporal_objects())
	var shut: Dictionary = (second.get_node("Lever") as Lever).capture_state()
	shut["on"] = false
	time.player_action("valve", shut)
	time.reset()
	check(_frames(time.world) == a, "after a reset the room has the same prelude again")
	await _free_room(second)


# --- helpers ----------------------------------------------------------------

func _rewind_to(world: TimeWorld, objects: Array, frame: int) -> void:
	while world.timeline.cursor() > frame:
		world.tick(BACK, objects)


func _frames(world: TimeWorld) -> Array:
	var cursor := world.timeline.cursor()
	var frames := []
	while world.timeline.step_back():
		pass
	frames.append(world.timeline.current().duplicate(true))
	while world.timeline.step_forward():
		frames.append(world.timeline.current().duplicate(true))
	while world.timeline.cursor() > cursor:
		world.timeline.step_back()
	return frames


func _load_room() -> Node:
	Input.action_release("rewind")
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	return room


func _free_room(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame
