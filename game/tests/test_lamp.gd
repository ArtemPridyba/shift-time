extends RefCounted
## Tests of the lamp and the dark room (task 2.8): the lamp shines until its
## recorded break, Shift reassembles it, releasing Shift plays the break again
## (rule «A»), only lit places glow, the darkness mask follows the lamp, and
## the data check catches broken lamp and darkness numbers. Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room_dark.tscn"
const BACK := TimeWorld.BACKWARD
const FWD := TimeWorld.FORWARD

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _lamp(seconds: float) -> Lamp:
	var lamp := Lamp.new()
	lamp.break_seconds = seconds
	lamp.configure(Content.objects().get("lamp", {}), Content.time())
	return lamp


func _run(world: TimeWorld, objects: Array, direction: int, ticks: int) -> void:
	for i in ticks:
		world.tick(direction, objects)


func test_lamp_shines_until_its_break_and_then_goes_dark() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	_run(world, objects, FWD, 30)
	check(lamp.lit and not lamp.broken, "the lamp must shine before its break")
	_run(world, objects, FWD, 60)
	check(lamp.broken and not lamp.lit, "the lamp must be broken and dark after its break")
	check(lamp.light_source().is_empty(), "a broken lamp must give no light")
	lamp.free()


func test_shift_reassembles_the_lamp_and_release_breaks_it_again() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	_run(world, objects, FWD, 90)
	check(lamp.broken, "the lamp must be broken at the head")
	_run(world, objects, BACK, 60)
	check(lamp.lit and not lamp.broken, "under Shift the lamp must be whole and shine")
	check(not lamp.light_source().is_empty(), "the reassembled lamp must give light")
	var kept := lamp.lit
	_run(world, objects, FWD, 5)
	check(lamp.lit == kept and lamp.lit, "right after release the lamp must still shine")
	_run(world, objects, FWD, 60)
	check(lamp.broken and not lamp.lit, "the recorded break must play again after Shift is released")
	lamp.free()


func test_lamp_state_is_simple_and_round_trips() -> void:
	var lamp := _lamp(1.0)
	var state := lamp.capture_state()
	check(state.keys().size() == 3 and state.has("lit") and state.has("broken") and state.has("phase"), "lamp state must be lit, broken, phase")
	var recorder := TemporalRecorder.new()
	check(recorder.validate([lamp]).is_empty(), "the lamp must satisfy the temporal contract")
	lamp.simulate_tick(0)
	lamp.restore_state(state)
	check(lamp.capture_state() == state, "restoring a state must give the same state")
	lamp.free()


func test_light_field_reaches_only_inside_the_circle() -> void:
	var sources := [{"position": Vector2(100, 100), "radius": 50.0}]
	check(LightField.is_lit(Vector2(120, 100), sources), "a point inside the circle must be lit")
	check(not LightField.is_lit(Vector2(300, 100), sources), "a point outside the circle must be dark")
	check(not LightField.is_lit(Vector2(100, 100), []), "without sources everything is dark")


func test_special_items_glow_only_in_the_light() -> void:
	var room := await _load_room()
	var near: GlowItem = room.get_node("GlowNear")
	var far: GlowItem = room.get_node("GlowFar")
	await _ticks(5)
	check(near.is_glowing(), "an item in the lamp's light must glow")
	check(not far.is_glowing(), "an item in the dark must not glow")
	var lamp: Lamp = room.get_node("Lamp")
	await _ticks(int(Content.objects()["lamp"]["break_seconds"] * 60) + 30)
	check(lamp.broken, "the lamp must have broken by now")
	check(not near.is_glowing(), "after the lamp breaks nothing may glow")
	await _free_room(room)


func test_darkness_mask_follows_the_lamp_and_shift() -> void:
	var room := await _load_room()
	var darkness: Darkness = room.get_node("Darkness")
	var lamp: Lamp = room.get_node("Lamp")
	await _ticks(5)
	check(darkness.light_sources().size() == 1, "a lit lamp must open one hole in the darkness")
	await _ticks(int(Content.objects()["lamp"]["break_seconds"] * 60) + 30)
	check(darkness.light_sources().is_empty(), "with the lamp broken the room must be fully dark")
	Input.action_press("rewind")
	await _ticks(90)
	check(lamp.lit and darkness.light_sources().size() == 1, "while Shift is held the reassembled lamp must light the room")
	Input.action_release("rewind")
	await _ticks(int(Content.objects()["lamp"]["break_seconds"] * 60) + 30)
	check(lamp.broken, "after Shift is released the lamp must break again")
	await _free_room(room)


func test_data_check_reports_bad_lamp_and_darkness_numbers() -> void:
	var time_data := Content.time()
	check(Content.validate_objects(Content.objects(), time_data).is_empty(), "the shipped objects.json must pass")
	var short_lamp: Dictionary = Content.objects().duplicate(true)
	short_lamp["lamp"]["break_seconds"] = 1
	check(not Content.validate_objects(short_lamp, time_data).is_empty(), "a lamp that breaks within 3 s must be reported")
	var no_lamp: Dictionary = Content.objects().duplicate(true)
	no_lamp.erase("lamp")
	check(not Content.validate_objects(no_lamp, time_data).is_empty(), "a missing lamp must be reported")
	var bright: Dictionary = Content.objects().duplicate(true)
	bright["darkness"]["ambient"] = 2
	check(not Content.validate_objects(bright, time_data).is_empty(), "an ambient light above 1 must be reported")
	var no_dark: Dictionary = Content.objects().duplicate(true)
	no_dark.erase("darkness")
	check(not Content.validate_objects(no_dark, time_data).is_empty(), "a missing darkness section must be reported")


func _load_room() -> Node:
	Input.action_release("rewind")
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free_room(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
