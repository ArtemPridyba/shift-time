extends RefCounted
## Tests for InteractionSystem, Button, Lever, and their integration with
## TimeWorld via RoomTime-style player_action calls.
## Run by test_runner.gd. Every `test_*` method is executed.

const BACK := TimeWorld.BACKWARD
const FWD := TimeWorld.FORWARD

var failures: Array[String] = []


func _init(_tree: SceneTree) -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------------------
# InteractionSystem — pure logic, no nodes
# ---------------------------------------------------------------------------

func test_interaction_system_returns_nearest_in_range() -> void:
	var candidates := [
		{"id": "near", "position": Vector2(10, 0), "radius": 50.0},
		{"id": "far",  "position": Vector2(200, 0), "radius": 50.0},
	]
	var result := InteractionSystem.get_nearest(Vector2.ZERO, candidates)
	check(result == "near", "expected 'near', got '%s'" % result)


func test_interaction_system_ignores_out_of_range() -> void:
	var candidates := [
		{"id": "distant", "position": Vector2(100, 0), "radius": 30.0},
	]
	var result := InteractionSystem.get_nearest(Vector2.ZERO, candidates)
	check(result == "", "expected '', got '%s'" % result)


func test_interaction_system_on_boundary_counts_as_in_range() -> void:
	var candidates := [
		{"id": "edge", "position": Vector2(50, 0), "radius": 50.0},
	]
	var result := InteractionSystem.get_nearest(Vector2.ZERO, candidates)
	check(result == "edge", "distance == radius must be in range, got '%s'" % result)


func test_interaction_system_empty_candidates() -> void:
	var result := InteractionSystem.get_nearest(Vector2.ZERO, [])
	check(result == "", "empty list must return '', got '%s'" % result)


# ---------------------------------------------------------------------------
# Button state contract
# ---------------------------------------------------------------------------

func test_button_initial_state() -> void:
	var b := PushButton.new()
	var state: Dictionary = b.capture_state()
	check(state.has("pressed"), "button state must have 'pressed'")
	check(state["pressed"] == false, "button must start unpressed")
	b.free()


func test_button_restore_state_round_trips() -> void:
	var b := PushButton.new()
	b.restore_state({"pressed": true})
	var state: Dictionary = b.capture_state()
	check(state["pressed"] == true, "restore then capture must round-trip pressed=true")
	b.restore_state({"pressed": false})
	check(b.capture_state()["pressed"] == false, "restore then capture must round-trip pressed=false")
	b.free()


func test_button_blocks_player_always_false() -> void:
	var b := PushButton.new()
	check(not b.blocks_player_at({"pressed": false}, Rect2(0, 0, 44, 92)),
		"button must never block the player")
	b.free()


func test_button_one_way_already_pressed_no_change() -> void:
	var b := PushButton.new()
	b.pressed = true
	var changes: Array = b.get_interaction_change([])
	check(changes.is_empty(), "pressing an already-pressed button must return no changes")
	b.free()


func test_button_press_produces_self_change_without_target() -> void:
	var b := PushButton.new()
	b.object_id = "btn1"
	b.target_id = ""
	var changes: Array = b.get_interaction_change([])
	check(changes.size() == 1, "without target, one change expected; got %d" % changes.size())
	check(changes[0]["id"] == "btn1", "change id must be btn1")
	check(changes[0]["state"]["pressed"] == true, "change must set pressed=true")
	b.free()


# ---------------------------------------------------------------------------
# Lever state contract
# ---------------------------------------------------------------------------

func test_lever_initial_state() -> void:
	var lv := Lever.new()
	var state: Dictionary = lv.capture_state()
	check(state.has("on"), "lever state must have 'on'")
	check(state["on"] == false, "lever must start off")
	lv.free()


func test_lever_restore_state_round_trips() -> void:
	var lv := Lever.new()
	lv.restore_state({"on": true})
	var state_on: Dictionary = lv.capture_state()
	check(state_on["on"] == true, "round-trip on=true")
	lv.restore_state({"on": false})
	var state_off: Dictionary = lv.capture_state()
	check(state_off["on"] == false, "round-trip on=false")
	lv.free()


func test_lever_toggle_produces_on_change() -> void:
	var lv := Lever.new()
	lv.object_id = "lv1"
	lv.target_id = ""
	var changes: Array = lv.get_interaction_change([])
	check(changes.size() == 1, "without target one change, got %d" % changes.size())
	check(changes[0]["state"]["on"] == true, "first press must set on=true")
	lv.free()


func test_lever_toggle_twice_returns_off() -> void:
	var lv := Lever.new()
	lv.object_id = "lv1"
	lv.target_id = ""
	# First press: should return on=true (but we don't apply it here; we simulate).
	var c1: Array = lv.get_interaction_change([])
	# Apply the state to the lever.
	lv.restore_state(c1[0]["state"])
	var c2: Array = lv.get_interaction_change([])
	check(c2[0]["state"]["on"] == false, "second press must set on=false")
	lv.free()


# ---------------------------------------------------------------------------
# Integration with TimeWorld via fake objects (no scene tree)
# ---------------------------------------------------------------------------

## A minimal fake door with powered support, matching the Door contract.
class FakeDoor extends RefCounted:
	var object_id := "door1"
	var open := 0
	var locked := false
	var phase := 0
	var powered := false
	var linked_id := "btn1"  # non-empty so powered is included in state.

	func capture_state() -> Dictionary:
		return {"open": open, "locked": locked, "phase": phase, "powered": powered}

	func restore_state(state: Dictionary) -> void:
		open = int(state["open"])
		locked = bool(state["locked"])
		phase = int(state["phase"])
		powered = bool(state.get("powered", false))

	func simulate_tick(_tick: int) -> void:
		if locked:
			return
		var step := 34  # ~1000/30 ticks to open
		if powered:
			open = mini(open + step, 1000)
		else:
			open = maxi(open - step, 0)

	func on_time_direction_changed(_d: int) -> void:
		pass

	func blocks_player_at(_s: Dictionary, _r: Rect2) -> bool:
		return false


## A minimal fake button (only capture/restore, no scene).
class FakeButton extends RefCounted:
	var object_id := "btn1"
	var pressed := false
	var target_id := "door1"

	func capture_state() -> Dictionary:
		return {"pressed": pressed}

	func restore_state(state: Dictionary) -> void:
		pressed = bool(state["pressed"])

	func simulate_tick(_tick: int) -> void:
		pass

	func on_time_direction_changed(_d: int) -> void:
		pass

	func blocks_player_at(_s: Dictionary, _r: Rect2) -> bool:
		return false


func _world() -> TimeWorld:
	return TimeWorld.new(Timeline.new(1200))


func _objects(door: FakeDoor, btn: FakeButton) -> Array:
	return [door, btn]


## Presses the button: applies self-change + powered change to the door,
## as RoomTime.player_interact would do.
func _press_button(world: TimeWorld, door: FakeDoor, btn: FakeButton) -> void:
	# Self change: button pressed.
	var btn_state := btn.capture_state()
	btn_state["pressed"] = true
	world.player_action(_objects(door, btn), btn.object_id, btn_state)
	# Door change: set powered=true.
	var door_state := door.capture_state()
	door_state["powered"] = true
	world.player_action(_objects(door, btn), door.object_id, door_state)


func test_button_press_while_rewinding_records_state_and_cuts_future() -> void:
	var door := FakeDoor.new()
	var btn := FakeButton.new()
	var world := _world()
	var objects := _objects(door, btn)
	world.start(objects)

	# Simulate forward 30 ticks to have some history.
	for i in 30:
		world.tick(FWD, objects, Rect2())
	check(world.timeline.head() == 30, "timeline must have 30 forward ticks")

	# Rewind 15 ticks.
	for i in 15:
		world.tick(BACK, objects, Rect2())
	check(world.timeline.cursor() == 15, "cursor must be at tick 15 after rewind")

	# Press button while cursor is left of the head.
	_press_button(world, door, btn)

	check(world.timeline.at_head(), "branching must cut future so cursor is at head")
	check(world.timeline.head() == 15, "timeline head must be 15 after branch")
	check(btn.pressed, "button must be pressed after interaction")
	check(door.powered, "door must be powered after interaction")

	# Simulate forward again: future is re-built from the new state (door opens).
	var old_open := door.open
	for i in 10:
		world.tick(FWD, objects, Rect2())
	check(door.open > old_open, "door must open after powered is set and world runs forward")


func test_button_press_state_in_frame_has_both_button_and_door() -> void:
	var door := FakeDoor.new()
	var btn := FakeButton.new()
	var world := _world()
	var objects := _objects(door, btn)
	world.start(objects)

	# Build 20 ticks of history.
	for i in 20:
		world.tick(FWD, objects, Rect2())

	# Rewind 10 ticks.
	for i in 10:
		world.tick(BACK, objects, Rect2())

	# Apply both changes.
	_press_button(world, door, btn)

	# Advance one tick: the new frame should contain pressed=true and powered=true.
	world.tick(FWD, objects, Rect2())
	var btn_state: Dictionary = btn.capture_state()
	var door_state: Dictionary = door.capture_state()
	check(btn_state["pressed"] == true, "frame after interaction must have btn.pressed=true")
	check(door_state["powered"] == true, "frame after interaction must have door.powered=true")


func test_lever_toggle_twice_powered_returns_false() -> void:
	var door := FakeDoor.new()
	var lv := Lever.new()
	lv.object_id = "lv1"
	lv.target_id = "door1"

	# First press: on=true, door powered=true.
	var c1: Array = lv.get_interaction_change([door])
	# c1 should have two entries.
	check(c1.size() == 2, "first press must produce 2 changes (lever + door); got %d" % c1.size())
	var door_change_1: Dictionary = {}
	for item: Variant in c1:
		var d := item as Dictionary
		if str(d.get("id", "")) == "door1":
			door_change_1 = d
	check(not door_change_1.is_empty(), "first press must include a change for door1")
	if not door_change_1.is_empty():
		check(bool((door_change_1.get("state", {}) as Dictionary).get("powered", false)) == true,
			"first press must set powered=true on door")

	# Apply the lever state.
	lv.restore_state({"on": true})

	# Second press: on=false, door powered=false.
	var c2: Array = lv.get_interaction_change([door])
	var door_change_2: Dictionary = {}
	for item: Variant in c2:
		var d := item as Dictionary
		if str(d.get("id", "")) == "door1":
			door_change_2 = d
	check(not door_change_2.is_empty(), "second press must include a change for door1")
	if not door_change_2.is_empty():
		check(bool((door_change_2.get("state", {}) as Dictionary).get("powered", false)) == false,
			"second press must set powered=false on door")
	lv.free()


# ---------------------------------------------------------------------------
# Content.validate_objects — new sections
# ---------------------------------------------------------------------------

func test_validate_objects_accepts_button_and_lever() -> void:
	var time_data := Content.time()
	var objects := Content.objects()
	var errors := Content.validate_objects(objects, time_data)
	check(errors.is_empty(), "shipped objects.json with button+lever must pass: %s" % str(errors))


func test_validate_objects_rejects_missing_button() -> void:
	var time_data := Content.time()
	var objects := Content.objects().duplicate(true)
	objects.erase("button")
	check(not Content.validate_objects(objects, time_data).is_empty(),
		"missing 'button' section must be reported")


func test_validate_objects_rejects_missing_lever() -> void:
	var time_data := Content.time()
	var objects := Content.objects().duplicate(true)
	objects.erase("lever")
	check(not Content.validate_objects(objects, time_data).is_empty(),
		"missing 'lever' section must be reported")


func test_validate_objects_rejects_zero_interact_radius() -> void:
	var time_data := Content.time()
	var objects := Content.objects().duplicate(true)
	objects["button"] = {"interact_radius_px": 0}
	check(not Content.validate_objects(objects, time_data).is_empty(),
		"interact_radius_px = 0 must be reported")


# ---------------------------------------------------------------------------
# Several targets: one control drives several objects (one valve, two tanks)
# ---------------------------------------------------------------------------

func test_lever_powers_every_target_and_the_old_single_target() -> void:
	var lever: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	var first: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	var second: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	first.object_id = "first"
	first.linked_id = "lever"
	second.object_id = "second"
	second.linked_id = "lever"
	lever.target_id = "first"
	lever.target_ids = PackedStringArray(["second", "first", "missing"])
	var changes := lever.get_interaction_change([lever, first, second])
	var ids: Array = changes.map(func(c: Dictionary) -> String: return str(c["id"]))
	check(ids == ["lever", "first", "second"], "the lever must change itself and each found target once, got %s" % [ids])
	for change: Dictionary in changes.slice(1):
		check(bool(change["state"]["powered"]), "every target must be powered by the lever turned on")
		check(change["state"].has("open"), "a target's change must keep the rest of its state")
	lever.free()
	first.free()
	second.free()


func test_button_powers_every_target() -> void:
	var button: PushButton = (load("res://objects/push_button.tscn") as PackedScene).instantiate()
	var first: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	var second: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	first.object_id = "first"
	first.linked_id = "button"
	second.object_id = "second"
	second.linked_id = "button"
	button.target_ids = PackedStringArray(["first", "second"])
	var changes := button.get_interaction_change([button, first, second])
	check(changes.size() == 3, "the button must change itself and both targets")
	check(changes.slice(1).all(func(c: Dictionary) -> bool: return bool(c["state"]["powered"])), "both targets must be powered")
	button.free()
	first.free()
	second.free()
