extends RefCounted
## Tests of water (task 2.3): the level as a recorded state driven by its
## source, the float that follows the level, the player in water (sinking,
## lifted by rising water, breath and drowning) and the water test room.
## Run by test_runner.gd.

const WATER_PATH := "res://objects/water.tscn"
const FLOAT_PATH := "res://objects/water_float.tscn"
const LEVER_PATH := "res://objects/lever.tscn"
const ROOM_PATH := "res://levels/test_room_water.tscn"
const FWD := TimeWorld.FORWARD
const BACK := TimeWorld.BACKWARD
const DT := 1.0 / 60.0

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- the tank and its float ------------------------------------------------

func test_level_falls_forward_and_rises_under_shift_without_jumps() -> void:
	var water := _tank(Water.LEVEL_MAX, true, -1)
	var world := TimeWorld.from_config(Content.time())
	var objects: Array = [water]
	world.tick(FWD, objects)
	var forward: Array[int] = [water.level]
	var float_ok := true
	for i in 300:
		world.tick(FWD, objects)
		forward.append(water.level)
		float_ok = float_ok and _float_on_surface(water)
	check(forward[-1] < forward[0], "an open drain must lower the level")
	check(_steps_within(forward, -water.step(), 0), "draining, every tick must fall by at most one step, never rise")
	var backward: Array[int] = [water.level]
	for i in 340:
		world.tick(BACK, objects)
		backward.append(water.level)
		float_ok = float_ok and _float_on_surface(water)
	check(_steps_within(backward, 0, water.step()), "under Shift every tick must rise by at most one step, never fall")
	check(backward.slice(0, 301) == _reversed(forward), "under Shift the level must pass back through the recorded levels")
	check(water.level == Water.LEVEL_MAX, "rewound to frame 0 the tank must be full again")
	check(backward.slice(301).all(func(l: int) -> bool: return l == Water.LEVEL_MAX), "pinned at frame 0 the water must stand still")
	check(float_ok, "the float must stay on the surface on every tick, both ways")
	for i in 100:
		world.tick(FWD, objects)
	check(water.level == forward[100], "releasing Shift must replay the recorded drain (rule A)")
	water.free()


func test_closed_source_keeps_the_level() -> void:
	var water := _tank(6000, false, -1)
	var world := TimeWorld.from_config(Content.time())
	for i in 120:
		world.tick(FWD, [water])
	check(water.level == 6000 and water.flow == 0, "with the source closed the water must stand")
	water.free()


func test_flow_stops_when_the_tank_is_full_or_empty() -> void:
	var filling := _tank(Water.LEVEL_MAX - 1, true, 1)
	var draining := _tank(1, true, -1)
	for i in 5:
		filling.simulate_tick(i)
		draining.simulate_tick(i)
	check(filling.level == Water.LEVEL_MAX and filling.flow == 0, "a full tank must stop filling")
	check(draining.level == 0 and draining.flow == 0, "an empty tank must stop draining")
	check(draining.float_local_position(draining.floats()[0], 0).y == -draining.floats()[0].body_size().y / 2.0, "the float must rest on the bottom of an empty tank")
	filling.free()
	draining.free()


func test_closing_the_valve_in_the_past_keeps_the_water() -> void:
	var water := _tank(Water.LEVEL_MAX, true, -1)
	water.object_id = "water"
	var lever: Lever = (load(LEVER_PATH) as PackedScene).instantiate()
	lever.object_id = "valve"
	lever.on = true
	lever.target_ids = PackedStringArray(["water"])
	var objects: Array = [lever, water]
	var world := TimeWorld.from_config(Content.time())
	for i in 200:
		world.tick(FWD, objects)
	var head := world.timeline.head()
	for i in 100:
		world.tick(BACK, objects)
	var kept := water.level
	for change: Dictionary in lever.get_interaction_change(objects):
		world.player_action(objects, str(change["id"]), change["state"])
	check(world.timeline.head() < head, "closing the valve in the past must cut the recorded future")
	for i in 100:
		world.tick(FWD, objects)
	check(water.level == kept and not water.powered, "after the valve is closed in the past the water must stay where it was")
	lever.free()
	water.free()


func test_a_float_under_a_ceiling_waits_instead_of_crushing() -> void:
	var water := _tank(5000, false, -1)
	water.position = Vector2(1000, 800)
	var top := water.float_rect_at(water.floats()[0], 5000).position.y
	var x := water.float_rect_at(water.floats()[0], 5000).get_center().x
	var standing := Rect2(Vector2(x - 22, top - 92), Vector2(44, 92))
	var higher := water.capture_state()
	higher["level"] = 5000 + water.step() * 4
	check(not water.blocks_player_at(higher, standing), "a float rising under the feet carries the player")
	var squeezed := water.capture_state()
	squeezed["level"] = 5000 + water.step() * 60
	check(water.blocks_player_at(squeezed, standing), "a float rising through the player must count as crushing")
	water.free()


# --- the player in water ---------------------------------------------------

func test_water_contact_finds_depth_and_head() -> void:
	var body := Rect2(0, 0, 44, 92)
	var tank := Rect2(-100, 0, 400, 300)
	var waist := PlayerMotion.water_contact(body, tank, 50.0, 0.0, 28.0)
	check(is_equal_approx(float(waist["depth"]), 42.0) and not waist["head_under"], "water at the waist: in it, head above")
	var over := PlayerMotion.water_contact(body, tank, 10.0, 0.0, 28.0)
	check(over["head_under"], "water above the middle of the head: head under")
	var dry := PlayerMotion.water_contact(body, tank, 100.0, 0.0, 28.0)
	check(float(dry["depth"]) == 0.0, "the surface below the feet: out of the water")
	var aside := PlayerMotion.water_contact(Rect2(320, 0, 44, 92), tank, 10.0, 0.0, 28.0)
	check(float(aside["depth"]) == 0.0 and not aside["head_under"], "beside the tank: out of the water")


func test_player_sinks_slowly_in_still_water() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var water := {"depth": 60.0, "rise": 0.0}
	var v := Vector2(0, float(params["max_fall_speed"]))
	for i in 90:
		v = motion.step(v, 0.0, false, false, DT, water)
	check(is_equal_approx(v.y, float(params["water_max_sink_speed"])), "in still water the player must sink at water_max_sink_speed, got %.1f" % v.y)


func test_rising_water_lifts_the_player() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var deep := motion.step(Vector2.ZERO, 0.0, false, true, DT, {"depth": 80.0, "rise": 90.0})
	check(deep.y < 0.0, "rising water must lift a player standing on the bottom")
	check(is_equal_approx(deep.y, -float(params["water_float_up_speed"])), "the lift up to the surface is capped by water_float_up_speed")
	var riding := motion.step(Vector2.ZERO, 0.0, false, false, DT, {"depth": 1.5, "rise": 90.0})
	check(is_equal_approx(riding.y, -90.0), "on the surface the player rises with the water, got %.1f" % riding.y)


func test_player_walks_slower_and_jumps_lower_from_the_bottom() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	for i in 60:
		v = motion.step(v, 1.0, false, true, DT, {"depth": 50.0, "rise": 0.0})
	check(is_equal_approx(v.x, float(params["walk_speed"]) * float(params["water_walk_factor"])), "in water the player walks at water_walk_factor")
	var jump := motion.step(Vector2.ZERO, 0.0, true, true, DT, {"depth": 120.0, "rise": 0.0})
	check(is_equal_approx(jump.y, -float(params["water_jump_velocity"])), "from the bottom the player jumps with water_jump_velocity")
	motion.reset()
	var off_surface := motion.step(Vector2.ZERO, 0.0, true, false, DT, {"depth": 1.0, "rise": 60.0})
	check(is_equal_approx(off_surface.y, -float(params["jump_velocity"])), "from the surface of rising water the player jumps out with a full jump")


func test_breath_runs_out_under_water_and_fills_above() -> void:
	var params := Content.player()
	var breath := Breath.new(params)
	var ticks := 0
	var outs := 0
	while ticks < 2000 and not breath.is_out():
		ticks += 1
		if breath.step(true, DT):
			outs += 1
	var expected := int(round(float(params["breath_seconds"]) * 60.0))
	check(absi(ticks - expected) <= 1, "the air must last breath_seconds under water: %d ticks, expected %d" % [ticks, expected])
	check(outs == 1 and not breath.step(true, DT), "running out must be reported once")
	for i in int(ceil(float(params["breath_refill_seconds"]) * 60.0)) + 1:
		breath.step(false, DT)
	check(is_equal_approx(breath.fraction(), 1.0), "above water the breath must fill up in breath_refill_seconds")
	breath.step(true, DT * 30)
	breath.step(false, DT)
	check(breath.fraction() < 1.0 and breath.fraction() > 0.9, "a breath taken fills a little, it does not jump to full")


func test_water_data_is_checked() -> void:
	var time_data := Content.time()
	var objects := Content.objects()
	check(Content.validate_objects(objects, time_data).is_empty(), "the water data must pass")
	var missing := objects.duplicate(true)
	missing.erase("water")
	check(not Content.validate_objects(missing, time_data).is_empty(), "a missing water section must be reported")
	var quick := objects.duplicate(true)
	quick["water"]["full_seconds"] = 1
	check(not Content.validate_objects(quick, time_data).is_empty(), "water faster than max_state_step must be reported")
	var player := Content.player()
	check(Content.validate_player(player).is_empty(), "the player data must pass")
	var short := player.duplicate(true)
	short["breath_seconds"] = 2
	check(not Content.validate_player(short).is_empty(), "a breath shorter than a window to act must be reported")
	var fast := player.duplicate(true)
	fast["water_walk_factor"] = 1.5
	check(not Content.validate_player(fast).is_empty(), "walking faster in water must be reported")


# --- the look of water (task 2.3А) -----------------------------------------

func test_look_of_water_is_the_same_forward_and_back() -> void:
	var room := await _load_room()
	var water: Water = room.get_node("Water")
	var valve: Lever = room.get_node("Lever")
	var forward := {}
	var angles := {}
	var saw_drops := false
	var saw_jet := false
	var saw_streak := false
	for i in 240:
		await _tree.physics_frame
		var shot := water.look_snapshot()
		forward[int(shot["tick"])] = shot
		angles[int(shot["tick"])] = valve.wheel_angle()
		saw_drops = saw_drops or not (shot["drops"] as PackedVector2Array).is_empty()
		saw_jet = saw_jet or not (shot["jet"] as PackedVector3Array).is_empty()
		saw_streak = saw_streak or float((shot["streaks"] as Dictionary).get("platform:dip_platform", 0.0)) > 0.0
	check(water.look.mark_count() > 0, "the platform dipping into the well must leave marks")
	check(saw_drops and saw_streak, "the platform leaving the water must drip")
	check(saw_jet, "the draining well must show its jet")
	var first_angle: float = angles[angles.keys().min()]
	var last_angle: float = angles[angles.keys().max()]
	check(not is_equal_approx(first_angle, last_angle), "the valve wheel must turn while the water flows")
	Input.action_press("rewind")
	var compared := 0
	var same := true
	var same_wheel := true
	for i in 200:
		await _tree.physics_frame
		var shot := water.look_snapshot()
		var tick := int(shot["tick"])
		if forward.has(tick):
			compared += 1
			same = same and shot == forward[tick]
			same_wheel = same_wheel and is_equal_approx(valve.wheel_angle(), float(angles[tick]))
	check(compared > 150, "the rewind must pass the ticks seen going forward, compared %d" % compared)
	check(same, "the look at a world tick must be the same going forward and rewinding")
	check(same_wheel, "under Shift the valve wheel must turn back through the same angles")
	await _free_room(room)


func test_look_marks_come_only_from_recorded_ticks_and_a_branch_drops_them() -> void:
	var look := WaterLook.new(Content.objects()["water_look"], Content.time())
	var dry := {"key": "p", "rect": Rect2(-50, -300, 100, 20)}
	var wet := {"key": "p", "rect": Rect2(-50, -200, 100, 20)}
	look.observe(10, true, -250.0, 400.0, [dry])
	look.observe(11, true, -250.0, 400.0, [wet])
	check(look.mark_count() == 1, "entering the water at the head leaves one mark")
	look.observe(12, false, -250.0, 400.0, [dry])
	check(look.mark_count() == 1, "replay and rewind add no marks")
	look.observe(11, true, -250.0, 400.0, [wet])
	check(look.mark_count() == 0, "a tick recorded after a branch drops the marks of the cut future")


func test_look_waves_grow_from_nothing() -> void:
	var look := WaterLook.new(Content.objects()["water_look"], Content.time())
	look.observe(0, true, -250.0, 400.0, [{"key": "p", "rect": Rect2(-50, -300, 100, 20)}])
	var before := []
	for x in [-60.0, -20.0, 0.0, 20.0, 60.0]:
		before.append(look.surface_offset(x, 1.0, -1.0))
	look.observe(1, true, -250.0, 400.0, [{"key": "p", "rect": Rect2(-50, -240, 100, 20)}])
	var after := []
	for x in [-60.0, -20.0, 0.0, 20.0, 60.0]:
		after.append(look.surface_offset(x, 1.0, -1.0))
	check(before == after, "a wave must not pop in at the tick of its mark")
	var live := WaterLook.new(Content.objects()["water_look"], Content.time())
	live.observe_live(0, "hero", Rect2(-10, -300, 20, 40), -250.0, 400.0)
	live.observe_live(1, "hero", Rect2(-10, -260, 20, 40), -250.0, 400.0)
	check(live.surface_offset(40.0, 500.0, 20.0) != live.surface_offset(40.0, 500.0, -1.0), "the hero's wave follows the hero's clock")


func test_water_look_data_is_checked() -> void:
	var time_data := Content.time()
	var objects := Content.objects()
	var missing := objects.duplicate(true)
	missing.erase("water_look")
	check(not Content.validate_objects(missing, time_data).is_empty(), "a missing water_look section must be reported")
	var broken := objects.duplicate(true)
	broken["water_look"]["wave_seconds"] = 0
	check(not Content.validate_objects(broken, time_data).is_empty(), "a water_look number at 0 must be reported")


# --- the water test room ---------------------------------------------------

func test_shift_lifts_the_player_in_the_well_to_the_rim() -> void:
	var room := await _load_room()
	var water: Water = room.get_node("Water")
	var player: Player = room.get_node("Player")
	var time: RoomTime = room.get_node("RoomTime")
	check(water.level < Water.LEVEL_MAX and water.powered, "after the prelude the well must be draining")
	var spawn_y := player.global_position.y
	check(spawn_y < water.surface_global_y(), "the spawn ledge must be dry after the prelude")
	player.respawn(Vector2(640, water.global_position.y))
	await _ticks(5)
	check(player.is_head_under_water(), "at the bottom of the well the head is under water")
	Input.action_press("rewind")
	var lowest := player.global_position.y
	var pinned := false
	for i in 900:
		await _tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		if time.last_step == TimeWorld.Step.PINNED:
			pinned = true
			break
	check(pinned, "Shift must rewind the well to frame 0")
	check(water.level == Water.LEVEL_MAX, "at frame 0 the well is full")
	check(lowest <= water.surface_global_y() + 2.0, "the rising water must lift the player to the rim, feet at %.0f, surface %.0f" % [lowest, water.surface_global_y()])
	check(not player.is_head_under_water() and player.breath_fraction() > 0.5, "lifted on the surface the player breathes")
	await _free_room(room)


func test_player_drowns_when_stuck_under_water_and_the_room_restarts() -> void:
	var room := await _load_room()
	var water: Water = room.get_node("Water")
	var lever: Lever = room.get_node("Lever")
	var player: Player = room.get_node("Player")
	var time: RoomTime = room.get_node("RoomTime")
	var vignette: BreathVignette = player.get_node("BreathVignette")
	var spawn := player.global_position
	var after_prelude := water.level
	var drowned := [0]
	var at_reset := {}
	# The room restarts on the same signal and is connected first.
	player.drowned.connect(func() -> void:
		drowned[0] += 1
		at_reset.merge({"level": water.level, "powered": water.powered, "on": lever.on, "position": player.global_position, "breath": player.breath_fraction()}))
	check(vignette.strength() == 0.0, "with full lungs the screen is not darkened")
	time.player_interact(lever.global_position)
	await _ticks(2)
	check(not water.powered, "the lever must close the valve")
	player.respawn(Vector2(640, water.global_position.y))
	await _ticks(120)
	check(player.is_head_under_water() and player.breath_fraction() < 1.0, "under water the breath must run down")
	check(vignette.strength() > 0.0, "running out of air must darken the screen edges")
	var radius := vignette.clear_radius()
	await _ticks(60)
	check(vignette.clear_radius() < radius, "the darkness must close in toward the centre as the air runs out")
	check((player.get_node("Bubbles") as CPUParticles2D).emitting, "under water the player lets out bubbles")
	await _ticks(int(float(Content.player()["breath_seconds"]) * 60.0))
	check(drowned[0] == 1, "out of air the player must drown once, got %d" % drowned[0])
	check(at_reset.get("position", Vector2.INF).distance_to(spawn) < 4.0, "after drowning the player is back at the spawn")
	check(at_reset.get("level") == after_prelude and at_reset.get("powered") == true and at_reset.get("on") == true, "after drowning the room is as it was loaded, prelude included: %s" % [at_reset])
	check(at_reset.get("breath") == 1.0, "after drowning the breath is full again")
	await _free_room(room)


# --- helpers ----------------------------------------------------------------

func _tank(level: int, powered: bool, flow: int) -> Water:
	var water: Water = (load(WATER_PATH) as PackedScene).instantiate()
	water.size = Vector2(512, 400)
	water.level = level
	water.powered = powered
	water.open_flow = flow
	var float_body: WaterFloat = (load(FLOAT_PATH) as PackedScene).instantiate()
	float_body.position = Vector2(40, 0)
	water.add_child(float_body)
	return water


## The float's bottom sits `float_draft_px` under the surface, or on the bottom.
func _float_on_surface(water: Water) -> bool:
	var float_body := water.floats()[0]
	var draft := float(Content.objects()["water"]["float_draft_px"])
	var bottom := float_body.position.y + float_body.body_size().y / 2.0
	return is_equal_approx(bottom, minf(water.surface_local_y(water.level) + draft, 0.0))


func _steps_within(values: Array[int], low: int, high: int) -> bool:
	for i in range(1, values.size()):
		var d := values[i] - values[i - 1]
		if d < low or d > high:
			return false
	return true


func _reversed(values: Array[int]) -> Array[int]:
	var result := values.duplicate()
	result.reverse()
	return result


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
