extends RefCounted
## Tests of water and the valve (task 2.3): the level falls in normal time and
## rises back under Shift without jumps, it stands at its limits and with a
## closed source, the valve's wheel turns back under Shift, closing the valve
## in the past cuts the old future, and the hero in water: walks slower, cannot
## jump, sinks to the bottom, and rising water carries the hero out of the well.
## Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room_water.tscn"
const WATER_PATH := "res://objects/water.tscn"
const VALVE_PATH := "res://objects/valve.tscn"
const DT := 1.0 / 60.0
## The test room's well: its walls and the ground on both sides (px).
const WELL_LEFT := 768.0
const WELL_RIGHT := 1152.0
const WELL_BOTTOM := 1024.0
const GROUND := 640.0

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- objects alone ----------------------------------------------------------

func test_water_drains_and_rises_back_without_jumps() -> void:
	var water: Water = (load(WATER_PATH) as PackedScene).instantiate()
	water.source_open = true
	var world := TimeWorld.from_config(Content.time())
	var limit := float(Content.time()["max_state_step"])
	world.start([water])
	var forward: Array[int] = []
	for i in 300:
		world.tick(TimeWorld.FORWARD, [water])
		forward.append(water.level)
	check(forward[-1] < 1000 and water.flow == -1, "an open source must drain the water in normal time")
	var backward: Array[int] = []
	for i in 320:
		world.tick(TimeWorld.BACKWARD, [water])
		backward.append(water.level)
	check(_monotonic(forward, -1), "the level must only fall in normal time")
	check(_monotonic(backward, 1), "the level must only rise under Shift")
	check(_max_step([1000] + forward) <= limit and _max_step(backward) <= limit, "the level must change without jumps")
	check(backward[-1] == 1000, "at the start of the history the tank is full again, got %d" % backward[-1])
	water.free()


func test_water_stands_at_its_limits_and_without_source() -> void:
	var still: Water = (load(WATER_PATH) as PackedScene).instantiate()
	still.level = 700
	var world := TimeWorld.from_config(Content.time())
	for i in 120:
		world.tick(TimeWorld.FORWARD, [still])
	check(still.level == 700 and still.flow == 0, "a closed source must keep the level")
	var pool: Water = (load(WATER_PATH) as PackedScene).instantiate()
	pool.fills = true
	pool.source_open = true
	pool.level = 0
	pool.max_level = 600
	world = TimeWorld.from_config(Content.time())
	for i in 600:
		world.tick(TimeWorld.FORWARD, [pool])
	check(pool.level == 600 and pool.flow == 0, "a filling tank must stop at max_level, got %d" % pool.level)
	still.free()
	pool.free()


func test_valve_wheel_turns_while_open_and_back_under_shift() -> void:
	var valve: Valve = (load(VALVE_PATH) as PackedScene).instantiate()
	valve.open = true
	var world := TimeWorld.from_config(Content.time())
	for i in 90:
		world.tick(TimeWorld.FORWARD, [valve])
	var turned := valve.angle
	check(turned > 0, "an open valve's wheel must turn")
	world.tick(TimeWorld.BACKWARD, [valve])
	check(valve.angle < turned, "under Shift the wheel must turn back")
	world.tick(TimeWorld.FORWARD, [valve])
	check(valve.angle == turned, "releasing Shift must replay the recorded wheel")
	valve.free()
	var shut: Valve = (load(VALVE_PATH) as PackedScene).instantiate()
	world = TimeWorld.from_config(Content.time())
	for i in 30:
		world.tick(TimeWorld.FORWARD, [shut])
	check(shut.angle == 0, "a closed valve's wheel must stand")
	shut.free()


func test_broken_water_data_is_reported() -> void:
	var objects := Content.objects().duplicate(true)
	objects["water"]["drain_seconds"] = 1
	check(not Content.validate_objects(objects, Content.time()).is_empty(), "a well that drains in 1 s must be reported")
	var player := Content.player().duplicate(true)
	player["water_walk_factor"] = 1.5
	check(not Content.validate_player(player).is_empty(), "water that speeds the hero up must be reported")


# --- the hero's rules in water (no nodes) -----------------------------------

func test_hero_walks_slower_and_cannot_jump_in_water() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	for i in 60:
		v = motion.step(v, 1.0, false, true, DT, 50.0, 0.0)
	var slow := float(params["walk_speed"]) * float(params["water_walk_factor"])
	check(is_equal_approx(v.x, slow), "under water the hero walks at %.0f px/s, got %.0f" % [slow, v.x])
	v = motion.step(v, 0.0, true, true, DT, 50.0, 0.0)
	check(v.y >= 0.0, "the hero must not jump out of the water")


func test_hero_sinks_and_rising_water_lifts_to_its_surface() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	for i in 120:
		v = motion.step(v, 0.0, false, false, DT, 100.0, 0.0)
	check(is_equal_approx(v.y, float(params["water_sink_speed"])), "in standing water the hero sinks at water_sink_speed")
	v = motion.step(Vector2.ZERO, 0.0, false, true, DT, 200.0, 48.0)
	check(is_equal_approx(v.y, -float(params["water_lift_speed"])), "rising water must lift the hero from the bottom")
	v = motion.step(Vector2.ZERO, 0.0, false, false, DT, 0.0, 48.0)
	check(is_equal_approx(v.y, -48.0), "at the surface the hero rides up with it, got %.1f" % v.y)


# --- in the test room -------------------------------------------------------

func test_water_room_keeps_the_contract() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var water: Water = room.get_node("Water")
	var valve: Valve = room.get_node("Valve")
	var objects := time.temporal_objects()
	check(objects.has(water) and objects.has(valve), "the water room must record its water and valve")
	for problem in TemporalRecorder.new().validate(objects):
		check(false, problem)
	check(valve.target_id == water.object_id and valve.open == water.source_open,
		"the valve and the water must start the same: open valve, open source")
	await _free_room(room)


func test_shift_raises_the_water_and_turns_the_wheel_back() -> void:
	var room := await _load_room()
	var water: Water = room.get_node("Water")
	var valve: Valve = room.get_node("Valve")
	await _ticks(120)
	var level := water.level
	var angle := valve.angle
	check(level < 1000 and angle > 0, "after 2 s the water must be draining and the wheel turning")
	Input.action_press("rewind")
	await _ticks(2)
	var rising := true
	var last := water.level
	for i in 40:
		await _ticks(1)
		rising = rising and water.level >= last
		last = water.level
	check(rising and water.level > level, "the water must rise back under Shift")
	check(valve.angle < angle, "the wheel must turn back under Shift")
	await _free_room(room)


func test_closing_the_valve_in_the_past_cuts_the_old_future() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var water: Water = room.get_node("Water")
	var valve: Valve = room.get_node("Valve")
	var player: Player = room.get_node("Player")
	player.respawn(valve.global_position + Vector2(0, 40))
	await _ticks(180)
	Input.action_press("rewind")
	await _ticks(60)
	time.player_interact(player.global_position)
	check(not valve.open and not water.source_open, "the valve must close the source under Shift")
	Input.action_release("rewind")
	var kept := water.level
	await _ticks(60)
	check(water.level == kept and water.flow == 0, "after the valve is closed in the past the water must stand, not replay the drain")
	check(time.last_step == TimeWorld.Step.RECORDED, "the room must record the new branch")
	await _free_room(room)


func test_hero_sinks_in_the_well_and_rising_water_carries_the_hero_out() -> void:
	var room := await _load_room()
	var player: Player = room.get_node("Player")
	var water: Water = room.get_node("Water")
	player.respawn(Vector2((WELL_LEFT + WELL_RIGHT) / 2.0, WELL_BOTTOM - 120.0))
	await _ticks(90)
	check(player.is_on_floor() and absf(player.position.y - WELL_BOTTOM) < 2.0, "the hero must sink to the bottom of the well, at y %.0f" % player.position.y)
	Input.action_press("move_right")
	await _ticks(20)
	var slow := float(Content.player()["walk_speed"]) * float(Content.player()["water_walk_factor"])
	check(player.velocity.x <= slow + 1.0, "under water the hero walks slower, %.0f px/s" % player.velocity.x)
	await _ticks(130)
	check(player.position.x < WELL_RIGHT and player.position.y > GROUND + 100.0, "without Shift the hero cannot leave the well")
	Input.action_press("rewind")
	var above := 0.0
	for i in 300:
		await _ticks(1)
		above = maxf(above, water.surface_y() - player.position.y)
	Input.action_release("move_right")
	check(above < 4.0, "the water lifts the hero to its surface, not above it (%.1f px)" % above)
	check(player.position.x > WELL_RIGHT and absf(player.position.y - GROUND) < 2.0,
		"Shift and right must carry the hero out onto the right ground, at %s" % player.position)
	await _free_room(room)


# --- helpers ----------------------------------------------------------------

func _monotonic(values: Array[int], sign: int) -> bool:
	for i in range(1, values.size()):
		if (values[i] - values[i - 1]) * sign < 0:
			return false
	return true


func _max_step(values: Array) -> float:
	var most := 0.0
	for i in range(1, values.size()):
		most = maxf(most, absf(float(values[i]) - float(values[i - 1])))
	return most


func _load_room() -> Node:
	Input.action_release("rewind")
	Input.action_release("move_right")
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free_room(room: Node) -> void:
	Input.action_release("rewind")
	Input.action_release("move_right")
	room.queue_free()
	await _tree.process_frame


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
