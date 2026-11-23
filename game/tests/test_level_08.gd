extends RefCounted
## Tests of level 08 «Plates» (task 3.8, card docs/levels/08.md, D118): a time
## plate takes the direction of time. A step in normal time closes its
## shutters; a step with Shift held sends the closing into the past, so they
## open once time runs forward. Only the step counts, never standing on it.
## The solutions in tests/solutions/level_08*.json play the level.

const LEVEL_PATH := "res://levels/level_08.tscn"


class FakeRoom:
	extends RefCounted
	var calls: Array = []

	func apply_change(id: String, state: Dictionary) -> bool:
		calls.append({"id": id, "state": state})
		return true


var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_shutter_moves_to_its_target_without_jumps() -> void:
	var shutter := Shutter.new()
	shutter.apply_settings({"start": "open"})
	check(shutter.is_open(), "a shutter set to start open is open")
	check(shutter.capture_state() == {"closed": 0, "target": 0}, "an open shutter records closed 0 and target 0")
	shutter.target = Shutter.CLOSED_MAX
	var max_step := int(Content.time()["max_state_step"])
	var last := shutter.closed
	for i in 5 * 60:
		shutter.simulate_tick(i)
		check(absi(shutter.closed - last) <= max_step, "a shutter moves at most max_state_step per tick")
		last = shutter.closed
	check(shutter.closed == Shutter.CLOSED_MAX, "a shutter reaches its target, is at %d" % shutter.closed)
	shutter.simulate_tick(0)
	check(shutter.closed == Shutter.CLOSED_MAX, "a shutter at its target stays")
	shutter.apply_settings({})
	check(shutter.closed == Shutter.CLOSED_MAX and shutter.target == Shutter.CLOSED_MAX, "a shutter starts closed by default")
	shutter.free()


func test_shutter_waits_rather_than_crushes() -> void:
	var shutter := Shutter.new()
	shutter.size = Vector2(32, 128)
	shutter.travel = Vector2(0, -128)
	shutter.position = Vector2(100, 64)
	shutter.apply_settings({"start": "open"})
	var under := Rect2(Vector2(84, 36), Vector2(44, 92))
	check(shutter.blocks_player_at({"closed": Shutter.CLOSED_MAX, "target": Shutter.CLOSED_MAX}, under),
		"a closed wall overlaps the heroine standing in its doorway")
	check(not shutter.blocks_player_at({"closed": 0, "target": 0}, under), "an open wall does not")
	shutter.free()


func test_plate_takes_the_direction_of_time() -> void:
	var plate := TimePlate.new()
	plate.object_id = "plate_x"
	plate.target_ids = PackedStringArray(["wall", "hatch"])
	var forward := plate.step_changes(1)
	check(forward.size() == 3, "a step changes the plate and each of its shutters")
	check(forward[0] == {"id": "plate_x", "state": {"mark": TimePlate.MARK_CLOSE}}, "a step in normal time shows the flag down")
	check(forward[1] == {"id": "wall", "state": {"target": Shutter.CLOSED_MAX}}, "a step in normal time closes the shutter")
	var back := plate.step_changes(-1)
	check(back[0] == {"id": "plate_x", "state": {"mark": TimePlate.MARK_OPEN}}, "a step under Shift shows the flag up")
	check(back[2] == {"id": "hatch", "state": {"target": 0}}, "a step under Shift opens the shutter")
	plate.free()


func test_plate_counts_only_the_step() -> void:
	var plate := TimePlate.new()
	plate.object_id = "plate_x"
	plate.target_ids = PackedStringArray(["wall"])
	plate.width = 192.0
	plate.position = Vector2(200, 448)
	var room := FakeRoom.new()
	var on := Rect2(Vector2(180, 448 - 92), Vector2(44, 92))
	var off := Rect2(Vector2(400, 448 - 92), Vector2(44, 92))
	var above := Rect2(Vector2(180, 300 - 92), Vector2(44, 92))
	check(plate.touches(on) and not plate.touches(off) and not plate.touches(above), "the plate feels feet on it, not beside or above it")
	plate.sense(room, 1, on)
	check(room.calls.size() == 2, "stepping on in normal time changes the plate and its shutter")
	plate.sense(room, -1, on)
	plate.sense(room, -1, on)
	check(room.calls.size() == 2, "standing on the plate and pressing Shift does nothing")
	plate.sense(room, -1, off)
	plate.sense(room, -1, on)
	check(room.calls.size() == 4 and room.calls[3]["state"] == {"target": 0}, "a new step under Shift opens the shutter")
	plate.forget_step()
	plate.sense(room, 1, on)
	check(room.calls.size() == 6, "after a reset the plate feels the next step")
	plate.free()


func test_data_check_knows_shutter_starts() -> void:
	check(Content._object_settings_problems({"wall": {"start": "open"}}, "x").is_empty(), "'start': 'open' is valid level data")
	check(not Content._object_settings_problems({"wall": {"start": "half"}}, "x").is_empty(), "an unknown shutter start is broken level data")


func test_level_starts_with_b_closed_and_the_rest_open() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var shutters := {}
	for node in room.find_children("*", "Shutter", true, false):
		shutters[(node as Shutter).object_id] = node
	check(shutters.size() == 4, "level 08 has four shutters, has %d" % shutters.size())
	for id in ["shutter_a", "hatch_c", "wall_c"]:
		check(shutters.has(id) and (shutters[id] as Shutter).is_open(), "%s starts open" % id)
	check(shutters.has("shutter_b") and (shutters["shutter_b"] as Shutter).closed == Shutter.CLOSED_MAX, "shutter_b starts closed")
	var plates := room.find_children("*", "TimePlate", true, false)
	check(plates.size() == 3, "level 08 has three plates, has %d" % plates.size())
	for plate: Node in plates:
		for id in (plate as TimePlate).target_ids:
			check(shutters.has(id), "%s drives %s, which is in the level" % [(plate as TimePlate).object_id, id])
	room.queue_free()
	await _tree.process_frame
