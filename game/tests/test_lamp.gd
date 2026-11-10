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


func test_lamp_hangs_then_falls_dimming_and_shatters() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	var fall_ticks := int(round(float(Content.objects()["lamp"]["fall_seconds"]) * 60.0))
	var hang_y := lamp.position.y
	_run(world, objects, FWD, 30)
	check(lamp.lit and not lamp.broken and lamp.drop == 0 and lamp.light == Lamp.FULL, "the lamp must hang and shine at full light before its break")
	_run(world, objects, FWD, 30 + fall_ticks / 2)
	check(lamp.drop > 0 and lamp.light > 0 and lamp.light < Lamp.FULL, "mid-fall the lamp must be falling and dimmer, but still lit")
	check(lamp.position.y > hang_y, "mid-fall the lamp must be lower than where it hung")
	check(lamp.lit and not lamp.broken, "the lamp is not broken until it lands")
	_run(world, objects, FWD, fall_ticks)
	check(lamp.broken and not lamp.lit and lamp.light == 0 and lamp.drop == Lamp.FULL, "after landing the lamp must be broken, dark and at the bottom")
	check(lamp.light_source().is_empty(), "a broken lamp must give no light")
	_run(world, objects, FWD, 60)
	check(lamp.shatter == Lamp.FULL, "the shards must have settled")
	lamp.free()


func test_impact_flashes_the_floor_then_fades() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	var fall_ticks := int(round(float(Content.objects()["lamp"]["fall_seconds"]) * 60.0))
	var flash_ticks := int(round(float(Content.objects()["lamp"]["flash_seconds"]) * 60.0))
	_run(world, objects, FWD, 60 + fall_ticks - 1)
	check(lamp.flash == 0 and lamp.light > 0, "before the impact there must be no flash")
	_run(world, objects, FWD, 5)
	check(lamp.flash > 0 and lamp.light == 0, "at the impact the flash must light up while the lamp's own light is out")
	var source := lamp.light_source()
	check(not source.is_empty(), "the impact flash must give light")
	var floor_y := lamp.position.y + Lamp.FLOOR_OFFSET.y
	check(not source.is_empty() and is_equal_approx((source["position"] as Vector2).y, floor_y), "the flash must be on the floor where the lamp landed")
	_run(world, objects, FWD, flash_ticks + 5)
	check(lamp.flash == 0 and lamp.light_source().is_empty(), "the flash must be over and the room dark after it fades")
	_run(world, objects, BACK, 200)
	check(lamp.flash == 0 and lamp.light == Lamp.FULL, "under Shift the lamp must be back up with no flash")
	lamp.free()


func test_lamp_falls_smoothly_without_big_steps() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	var max_step := int(Content.time()["max_state_step"])
	var previous := lamp.capture_state()
	var dimmed := true
	var lowered := true
	for i in 260:
		world.tick(FWD, objects)
		var now := lamp.capture_state()
		for key in ["drop", "light", "shatter"]:
			check(absi(int(now[key]) - int(previous[key])) <= max_step, "%s jumped more than max_state_step on tick %d" % [key, i])
		dimmed = dimmed and int(now["light"]) <= int(previous["light"])
		lowered = lowered and int(now["drop"]) >= int(previous["drop"])
		previous = now
	check(dimmed, "the light must only get dimmer while the lamp falls")
	check(lowered, "the lamp must only go down while it falls")
	lamp.free()


func test_shift_flies_the_lamp_back_and_release_drops_it_again() -> void:
	var lamp := _lamp(1.0)
	var objects := [lamp]
	var world := TimeWorld.new(Timeline.new(600))
	var hang_y := lamp.position.y
	_run(world, objects, FWD, 220)
	check(lamp.broken and lamp.shatter > 0, "the lamp must be shattered at the head")
	_run(world, objects, BACK, 170)
	check(lamp.lit and not lamp.broken and lamp.drop == 0 and lamp.light == Lamp.FULL, "under Shift the lamp must be whole, hanging and shining")
	check(is_equal_approx(lamp.position.y, hang_y), "under Shift the lamp must be back where it hung")
	check(not lamp.light_source().is_empty(), "the reassembled lamp must give light")
	_run(world, objects, FWD, 5)
	check(lamp.lit and lamp.light == Lamp.FULL, "right after release the lamp must still shine")
	_run(world, objects, FWD, 200)
	check(lamp.broken and not lamp.lit, "the recorded fall must play again after Shift is released")
	lamp.free()


func test_lamp_state_is_simple_and_round_trips() -> void:
	var lamp := _lamp(1.0)
	var state := lamp.capture_state()
	for key in ["lit", "broken", "phase", "drop", "light", "shatter", "flash"]:
		check(state.has(key), "lamp state must have '%s'" % key)
	var recorder := TemporalRecorder.new()
	check(recorder.validate([lamp]).is_empty(), "the lamp must satisfy the temporal contract")
	for i in 100:
		lamp.simulate_tick(i)
	var later := lamp.capture_state()
	lamp.restore_state(state)
	check(lamp.capture_state() == state, "restoring a state must give the same state")
	lamp.restore_state(later)
	check(lamp.capture_state() == later, "restoring a later state must give the same state")
	lamp.free()


func test_light_is_brightest_at_the_lamp_and_fades_to_the_edge() -> void:
	var source := {"position": Vector2(100, 100), "radius": 100.0, "intensity": 1.0}
	var near := LightField.source_brightness(Vector2(105, 100), source)
	var middle := LightField.source_brightness(Vector2(150, 100), source)
	var edge := LightField.source_brightness(Vector2(195, 100), source)
	check(LightField.source_brightness(Vector2(100, 100), source) == 1.0, "the light must be full at the lamp")
	check(near > middle and middle > edge, "the light must weaken the farther from the lamp")
	check(LightField.source_brightness(Vector2(400, 100), source) == 0.0, "beyond the radius there is no light")
	var dim := {"position": Vector2(100, 100), "radius": 100.0, "intensity": 0.5}
	check(LightField.source_brightness(Vector2(120, 100), dim) < LightField.source_brightness(Vector2(120, 100), source), "a dimmer lamp must light less")
	check(LightField.is_lit(Vector2(120, 100), [source]), "a point near the lamp must be lit")
	check(not LightField.is_lit(Vector2(199, 100), [source]), "the very edge is too dark for items to glow")
	check(not LightField.is_lit(Vector2(100, 100), []), "without sources everything is dark")


func test_special_items_glow_only_in_the_light() -> void:
	var room := await _load_room()
	var near: GlowItem = room.get_node("GlowNear")
	var far: GlowItem = room.get_node("GlowFar")
	await _ticks(5)
	check(near.is_glowing(), "an item in the lamp's light must glow")
	check(not far.is_glowing(), "an item in the dark must not glow")
	var lamp: Lamp = room.get_node("Lamp")
	await _ticks(_dark_ticks())
	check(lamp.broken, "the lamp must have broken by now")
	check(not near.is_glowing(), "after the lamp breaks nothing may glow")
	await _free_room(room)


func test_darkness_mask_follows_the_lamp_and_shift() -> void:
	var room := await _load_room()
	var darkness: Darkness = room.get_node("Darkness")
	var lamp: Lamp = room.get_node("Lamp")
	await _ticks(5)
	check(darkness.light_sources().size() == 1, "a lit lamp must open one hole in the darkness")
	await _ticks(_dark_ticks())
	check(darkness.light_sources().is_empty(), "with the lamp broken the room must be fully dark")
	Input.action_press("rewind")
	await _ticks(90)
	check(lamp.lit and darkness.light_sources().size() == 1, "while Shift is held the reassembled lamp must light the room")
	Input.action_release("rewind")
	await _ticks(_dark_ticks())
	check(lamp.broken, "after Shift is released the lamp must break again")
	await _free_room(room)


func test_data_check_reports_bad_lamp_and_darkness_numbers() -> void:
	var time_data := Content.time()
	check(Content.validate_objects(Content.objects(), time_data).is_empty(), "the shipped objects.json must pass")
	var short_lamp: Dictionary = Content.objects().duplicate(true)
	short_lamp["lamp"]["break_seconds"] = 1
	check(not Content.validate_objects(short_lamp, time_data).is_empty(), "a lamp that breaks within 3 s must be reported")
	var no_flash: Dictionary = Content.objects().duplicate(true)
	no_flash["lamp"]["flash_seconds"] = 0
	check(not Content.validate_objects(no_flash, time_data).is_empty(), "a lamp with no flash time must be reported")
	var quick_fall: Dictionary = Content.objects().duplicate(true)
	quick_fall["lamp"]["fall_seconds"] = 0.1
	check(not Content.validate_objects(quick_fall, time_data).is_empty(), "a lamp falling faster than max_state_step must be reported")
	var no_lamp: Dictionary = Content.objects().duplicate(true)
	no_lamp.erase("lamp")
	check(not Content.validate_objects(no_lamp, time_data).is_empty(), "a missing lamp must be reported")
	var bright: Dictionary = Content.objects().duplicate(true)
	bright["darkness"]["ambient"] = 2
	check(not Content.validate_objects(bright, time_data).is_empty(), "an ambient light above 1 must be reported")
	var no_dark: Dictionary = Content.objects().duplicate(true)
	no_dark.erase("darkness")
	check(not Content.validate_objects(no_dark, time_data).is_empty(), "a missing darkness section must be reported")


## Ticks until the lamp of the dark room has fallen and broken, with a margin.
func _dark_ticks() -> int:
	var lamp: Dictionary = Content.objects()["lamp"]
	return int((float(lamp["break_seconds"]) + float(lamp["fall_seconds"])) * 60.0) + 30


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
