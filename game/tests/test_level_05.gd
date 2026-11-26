extends RefCounted
## Tests of level 05 «Crane» (card docs/levels/05.md, D144): the collapse in
## three quakes (`CollapsePlan`, `Collapse`). Act 1: the platforms fall one by
## one, each followed by its lamp, the third breaks and crumbles into the pit;
## under Shift it comes back and lifts her to the crane. Act 2: her step onto
## the crane sets it riding down its rail. Act 3: the ceiling comes down in
## chunks, two lamps among them, while the world runs slow; she climbs them to
## the exit. The solutions in tests/solutions/level_05*.json
## play the level.

const LEVEL_PATH := "res://levels/level_05.tscn"
const CELL := 64.0
## Pieces of the level: platforms 0..2 (act 1, the third breaks), then the
## pieces of act 3 (D149, D162): the first chunk by the rail, the hanging
## wall, the low chunk under it, the tumbling chunk, two steps, the heavy
## slab and the platform it hangs against over pulleys.
const BROKEN := 2
const FIRST_CHUNK := 3
const FIRST := 3
const WALL := 4
const LOW := 5
const TUMBLER := 6
const STEP_B := 7
const STEP_C := 8
const SLAB := 9
const LIFT := 10
const ROUTE: Array[int] = [FIRST, LOW, STEP_B, STEP_C]
## The heroine's height (D112).
const HEIGHT := 92.0
## The heroine's jump (D112): about her height up, about 2.3 cells across;
## with a margin for a human hand.
const JUMP_UP := 1.4 * CELL
const JUMP_ACROSS := 2.0 * CELL
## Beyond her reach for sure: more than her best jump, with a margin.
const OUT_UP := 1.8 * CELL
const OUT_ACROSS := 2.6 * CELL
## Physics ticks per real second: every window to act is at least 3 s.
const TICKS_PER_SECOND := 60

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_collapse_plan_act_1_falls_one_by_one_each_platform_then_its_lamp() -> void:
	var plan := _level_plan()
	var starts: Array[int] = []
	for k in FIRST_CHUNK:
		var p := plan.pieces[k]
		check(int(p["act"]) == 1, "piece %d falls in act 1" % k)
		var start := plan.quake_tick + int(p["at"])
		starts.append(start)
		check(plan.drop(k, start - 1, -1) == 0.0, "platform %d hangs before its turn" % k)
		check(plan.drop(k, start + int(p["fall"]), -1) == 1.0, "platform %d lies after its fall" % k)
	for k in range(1, starts.size()):
		check(starts[k] > starts[k - 1], "platform %d falls after platform %d" % [k, k - 1])
	var act_1 := plan.lamps.filter(func(l: Dictionary) -> bool: return int(l["act"]) == 1)
	check(act_1.size() == starts.size(), "each platform has its lamp")
	for k in mini(act_1.size(), starts.size()):
		var lamp := plan.quake_tick + int(act_1[k]["at"])
		check(lamp > starts[k], "lamp %d falls after its platform" % k)
		check(k + 1 >= starts.size() or lamp < starts[k + 1], "lamp %d falls before the next platform" % k)
		var dark := plan.lamp_fall(int(act_1[k]["lamp"]), plan.clock_end, -1)
		check(float(dark["light"]) == 0.0 and float(dark["shatter"]) == 1.0, "lamp %d lies dark and broken" % k)
	check(plan.broken(BROKEN, plan.clock_end, -1) == 1.0, "the third platform breaks on its stub")
	check(plan.broken(0, plan.clock_end, -1) == 0.0 and plan.broken(1, plan.clock_end, -1) == 0.0,
		"the first two land whole")
	var landed := starts[BROKEN] + int(plan.pieces[BROKEN]["fall"])
	check(plan.crumble(BROKEN, landed + 1, -1) == 0.0, "the third lies a moment on its stub")
	check(plan.crumble(BROKEN, plan.clock_end, -1) == 1.0, "then crumbles into the pit")
	check(plan.crumble(0, plan.clock_end, -1) == 0.0 and plan.crumble(1, plan.clock_end, -1) == 0.0,
		"the first two stay on their stubs")
	check(plan.shake(plan.quake_tick, -1) == 1.0 and plan.shake(plan.quake_tick - 1, -1) == 0.0,
		"the hall shakes from the first quake on")


func test_collapse_plan_slow_clock_eases_down_holds_and_eases_back() -> void:
	# One tick per second, so the seconds are ticks.
	var plan := CollapsePlan.from_data({"slow": {"from_seconds": 10, "ease_seconds": 4, "hold_seconds": 20, "tempo": 0.25}},
		1.0, {}, {})
	check(is_equal_approx(plan.slow_ticks(10.0), 10.0), "before the slow part the world keeps time")
	var last := 0.0
	for r in 60:
		var now := plan.slow_ticks(float(r))
		check(now - last <= 1.0001 and now >= last, "the slow clock never jumps or runs back at %d" % r)
		last = now
	check(is_equal_approx(plan.slow_ticks(20.0) - plan.slow_ticks(19.0), 0.25), "it holds the slow tempo")
	check(is_equal_approx(plan.slow_ticks(50.0) - plan.slow_ticks(49.0), 1.0), "and keeps time again after it")
	var expected := 10.0 + 4.0 * (1.0 + 0.25) / 2.0 + 20.0 * 0.25 + 4.0 * (1.0 + 0.25) / 2.0 + 2.0
	check(is_equal_approx(plan.slow_ticks(40.0), expected), "the eases are even ramps, %.3f" % plan.slow_ticks(40.0))


func test_collapse_plan_crane_rides_strikes_lamps_in_order_then_act_3() -> void:
	var plan := CollapsePlan.from_data({"crane": {"delay_seconds": 2, "speed": 10, "lamps": [0, 1, 2], "lamp_lead_px": 5},
		"slow": {"from_seconds": 0, "ease_seconds": 1, "hold_seconds": 0, "tempo": 1}}, 1.0, {}, {})
	plan.aim(0.0, Vector2(100.0, 20.0), [30.0, 60.0, 500.0])
	check(plan.ride_ticks == 11, "it rides the length of its way at its speed, %d ticks" % plan.ride_ticks)
	var hits := plan.crane_hits
	check(hits[0] >= plan.ride_delay and hits[1] > hits[0], "the lamps over the rail fall in order as it passes")
	check(hits[2] == -1, "a lamp beyond the end of the rail never falls")
	check(plan.crane_pose(0, Vector2(100.0, 20.0), 0.0)["at"] == Vector2.ZERO, "it waits at the start")
	check((plan.crane_pose(plan.arrival(), Vector2(100.0, 20.0), 0.0)["at"] as Vector2).is_equal_approx(Vector2(100.0, 20.0)),
		"it stops at the end of the rail")
	check(plan.act3(plan.arrival() - 1) < 0.0 and plan.act3(plan.arrival()) == 0.0, "act 3 begins on its arrival")
	check(plan.shake(0, 0) == 1.0, "her step shakes the hall")
	check(plan.shake(0, plan.arrival()) == 1.0, "the arrival shakes it again")


## A plan whose act 3 begins halfway down a level rail (D176): one tick per
## second, so the seconds are ticks.
func _mid_ride_plan() -> CollapsePlan:
	var plan := CollapsePlan.from_data({"crane": {"delay_seconds": 2, "speed": 10, "blast_way": 0.5,
		"sag_seconds": 2, "sag_px": 10, "fall_second": 3, "fall_seconds": 2},
		"pieces": [{"act": 3, "second": 2, "fall_seconds": 5, "kind": "sink"}],
		"slow": {"from_seconds": 0, "ease_seconds": 1, "hold_seconds": 40, "tempo": 0.25}}, 1.0, {}, {})
	plan.aim(0.0, Vector2(100.0, 0.0), [])
	return plan


func test_collapse_plan_act_3_can_begin_halfway_down_the_rail() -> void:
	var plan := _mid_ride_plan()
	var end := plan.ride_delay + plan.ride_ticks
	check(plan.act3_at > plan.ride_delay and plan.act3_at < end, "act 3 begins on the way, tick %d" % plan.act3_at)
	check(plan.crane_way(plan.act3_at) >= 0.5 and plan.crane_way(plan.act3_at - 1) < 0.5,
		"it begins where the crane is halfway down its rail")
	check(plan.act3(plan.act3_at - 1) < 0.0 and plan.act3(plan.act3_at) == 0.0, "act 3's clock starts there")
	check(plan.shake(0, plan.act3_at) == 1.0, "the third quake shakes the hall there")
	var a := plan.act3_at + 5
	var before := plan.crane_way(plan.act3_at - 1) - plan.crane_way(plan.act3_at - 2)
	check(plan.crane_way(a + 1) - plan.crane_way(a) < before * 0.5, "the crane rides on slower in the slow world")
	check(plan.arrival() > end, "so it reaches the end later, tick %d" % plan.arrival())
	var at_end := plan.crane_pose(plan.arrival(), Vector2(100.0, 0.0), 0.0)["at"] as Vector2
	check(is_equal_approx(at_end.x, 100.0) and at_end.y < 2.0, "it stops at the end of the rail, %s" % at_end)
	check((plan.crane_pose(plan.arrival() - 1, Vector2(100.0, 0.0), 0.0)["at"] as Vector2).y == 0.0,
		"it sags only once it is at the end")
	check(not plan.crane_down(plan.arrival()) and plan.crane_down(plan.ride_end), "and falls into the pit after that")
	var last := 0.0
	for r in plan.ride_end:
		var now := plan.crane_way(r)
		check(now >= last, "the crane never jumps back on its way at %d" % r)
		last = now


func test_collapse_plan_the_brake_holds_the_crane_where_it_was() -> void:
	var plan := _mid_ride_plan()
	var at := plan.act3_at + 4
	check(plan.can_brake(at), "the riding crane can be put on its brake")
	check(not plan.can_brake(plan.ride_delay - 1), "a waiting one cannot")
	var way := plan.crane_way(at)
	plan.brake = at
	check(not plan.can_brake(at + 1), "once on the brake it stays on it")
	check(plan.crane_way(plan.ride_end) == way, "on the brake it stays where it was")
	check(not plan.crane_down(plan.ride_end), "and never falls")
	check(plan.crane_way(at - 3) < way, "before the brake it rode as recorded")
	check(plan.act3(plan.ride_end) > plan.act3(at), "the world runs on around it")
	plan.brake = -1
	check(plan.crane_down(plan.ride_end), "without the brake it ends in the pit")
	check(not plan.can_brake(plan.ride_end), "and a falling crane cannot be held")


class FakeRoom:
	var changes: Array[Dictionary] = []

	func apply_change(_id: String, partial: Dictionary) -> bool:
		changes.append(partial)
		return true


## Her rect standing with her feet on `floor` (a rect), in its middle.
static func _standing_on(floor: Rect2) -> Rect2:
	return Rect2(Vector2(floor.get_center().x - 16.0, floor.position.y - HEIGHT), Vector2(32.0, HEIGHT))


func test_collapse_pedal_brakes_the_crane_she_jumped_into_from_a_piece_under_shift() -> void:
	var collapse := Collapse.new()
	collapse.plan = _mid_ride_plan()
	collapse.pieces = [Rect2(0, -200, 64, 16)]
	collapse.rests = [Rect2(0, 400, 64, 16)]
	collapse.crane_rect = Rect2(100, 0, 96, 16)
	collapse.crane_travel = Vector2(100.0, 0.0)
	_tree.root.add_child(collapse)
	var ride := collapse.plan.act3_at + 3
	collapse.restore_state({"clock": 0, "ride": ride, "calm": -1, "brake": -1})
	var room := FakeRoom.new()
	var crane := _standing_on(collapse.crane_load_rect())
	collapse.sense(room, -1, crane)
	collapse.sense(room, 1, crane)
	check(room.changes.is_empty() and not collapse.pedal_armed(), "standing on the crane all along does nothing")
	collapse.sense(room, -1, _standing_on(collapse.piece_rect(0)))
	collapse.sense(room, 1, crane)
	check(room.changes.is_empty(), "jumping into it in normal time does nothing")
	collapse.sense(room, -1, _standing_on(collapse.piece_rect(0)))
	collapse.sense(room, -1, crane)
	check(collapse.pedal_armed() and room.changes.is_empty(), "jumping into it under Shift makes the pedal hers")
	collapse.sense(room, -1, Rect2(crane.position - Vector2(0, 40), crane.size))
	collapse.sense(room, -1, crane)
	check(collapse.pedal_armed(), "a jump on its floor keeps it hers")
	collapse.sense(room, 1, crane)
	check(room.changes.size() == 1 and int(room.changes[0].get("brake", -2)) == ride,
		"letting go of Shift puts the crane on its brake there: %s" % [room.changes])
	collapse.free()


func test_collapse_data_is_checked() -> void:
	var entry := Content.level_for_scene(LEVEL_PATH)
	var lamps: Array = (entry["world"] as Dictionary)["lamps"]
	var good: Dictionary = entry["collapse"]
	check(CollapsePlan.problems(good, "x", lamps.size()).is_empty(), "the level's collapse data has no problems: %s"
		% CollapsePlan.problems(good, "x", lamps.size()))
	var broken := good.duplicate(true)
	broken["pieces"] = []
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a collapse without pieces is reported")
	broken = good.duplicate(true)
	(broken["pieces"][0] as Dictionary)["act"] = 2
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a piece of act 2 is reported")
	broken = good.duplicate(true)
	(broken["pieces"][4] as Dictionary)["spin"] = "fast"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a spin that is not a number is reported")
	broken = good.duplicate(true)
	(broken["pieces"][4] as Dictionary)["kind"] = "roll"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "an unknown kind of fall is reported")
	broken = good.duplicate(true)
	(broken["pieces"][LIFT] as Dictionary)["follow"] = LIFT
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a platform hung against itself is reported")
	broken = good.duplicate(true)
	(broken["pieces"][LIFT] as Dictionary).erase("follow")
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a platform hung against nothing is reported")
	broken = good.duplicate(true)
	(broken["slow"] as Dictionary)["tempo"] = 0
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a tempo of 0 is reported")
	broken = good.duplicate(true)
	(broken["crane"] as Dictionary)["lamps"] = [lamps.size()]
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a lamp the world does not have is reported")
	check(not CollapsePlan.problems(null, "x", 1).is_empty(), "no collapse object is reported")


func test_world_darkness_and_lamp_radius_are_checked() -> void:
	var good := {"darkness": "#17171e", "lamps": [{"x": 1, "drop": 1, "radius_px": 400}]}
	check(WorldData.validate_layout(good, "x").is_empty(), "a darker room and a lamp's own radius are fine")
	check(not WorldData.validate_layout({"darkness": "dark"}, "x").is_empty(), "a darkness that is no colour is reported")
	check(not WorldData.validate_layout({"lamps": [{"x": 1, "drop": 1, "radius_px": 0}]}, "x").is_empty(),
		"a lamp radius of 0 is reported")


func test_level_05_act_1_falls_before_her_eyes() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	for k in FIRST_CHUNK:
		check(collapse.piece_hangs(k), "platform %d hangs at the start" % k)
	await _ticks(collapse.plan.clock_end + 4)
	for k in FIRST_CHUNK:
		check(collapse.piece_lies(k), "platform %d has fallen onto its stub" % k)
	check(collapse.piece_holds(0) and collapse.piece_holds(1), "the first two hold her")
	check(not collapse.piece_holds(BROKEN), "the third has crumbled and holds nobody")
	for k in range(FIRST_CHUNK, collapse.pieces.size()):
		check(collapse.piece_hangs(k), "chunk %d still hangs in the ceiling" % k)
	check(collapse.crane_waits(), "the crane waits for her by the ledge")
	for one in collapse.plan.lamps:
		if int(one["act"]) == 1:
			check(float(collapse.lamp_fall(int(one["lamp"]))["light"]) == 0.0, "lamp %d of act 1 is out" % int(one["lamp"]))
	check(collapse.lamp_fall(0).is_empty() and collapse.lamp_fall(4).is_empty(), "the lamps over the start and the ledge stay")
	check(collapse.clock == collapse.plan.clock_end, "act 1's clock stops once all is down, so the room may stand")
	await _free(room)


func test_level_05_under_shift_the_broken_platform_lifts_her_to_the_ledge() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	# She is on it while it lies broken, before it crumbles.
	for i in collapse.plan.clock_end:
		await _tree.physics_frame
		if collapse.piece_lies(BROKEN):
			break
	var rest := collapse.rests[BROKEN]
	player.respawn(Vector2(rest.get_center().x, rest.position.y))
	await _ticks(20)
	Input.action_press("rewind")
	for i in 240:
		await _tree.physics_frame
		if collapse.piece_hangs(BROKEN):
			break
	await _ticks(10)
	Input.action_release("rewind")
	var hang := collapse.pieces[BROKEN]
	check(collapse.piece_hangs(BROKEN), "under Shift the broken platform mends and goes back up")
	check(absf(player.global_position.y - hang.position.y) < 8.0,
		"it carried her up level with the ledge, feet at %.0f, top %.0f" % [player.global_position.y, hang.position.y])
	await _free(room)


func test_level_05_the_crane_goes_only_when_she_stands_on_it_in_normal_time() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var room_time := room.get_node("RoomTime")
	var top := collapse.crane_load_rect()
	var on := Rect2(Vector2(top.get_center().x - 22.0, top.position.y - 92.0), Vector2(44.0, 92.0))
	var toe := Rect2(Vector2(top.position.x - 30.0, top.position.y - 92.0), Vector2(44.0, 92.0))
	collapse.sense(room_time, -1, on)
	check(collapse.ride < 0, "standing on it with Shift held sets nothing going")
	collapse.sense(room_time, 1, toe)
	check(collapse.ride < 0, "a toe from the ledge sets nothing going")
	collapse.sense(room_time, 1, on)
	check(collapse.ride == 0, "her step in normal time sets it going")
	check(collapse.shake_amount() == 1.0, "and shakes the hall")
	await _ticks(collapse.plan.ride_delay + 30)
	var moved := collapse.crane_load_rect().position - top.position
	check(moved.x > 0.0 and moved.y > 0.0, "after a moment it rides right and down its rail, moved %s" % moved)
	await _free(room)


func test_level_05_act_3_goes_down_under_a_wall_then_up_to_the_counterweight() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	var ledge := _exit_floor(room)
	var start := plan.arrival() + plan.slow_from + plan.slow_ease
	var onto_first := 0
	var ok := {"wall": true, "down": true, "under": true, "steps": true, "ledge_out": true, "onto_lift": true}
	# The first ten seconds of the slow part, before her step onto the ledge.
	for r in range(start, start + 10 * TICKS_PER_SECOND):
		collapse.restore_state({"clock": plan.clock_end, "ride": r})
		var crane := collapse.crane_load_rect()
		var first := collapse.piece_rect(FIRST)
		if crane.position.y - first.position.y <= JUMP_UP and first.position.x - crane.end.x <= JUMP_ACROSS:
			onto_first += 1
		var wall := collapse.piece_rect(WALL)
		var low := collapse.piece_rect(LOW)
		# The wall stands in her way past the first chunk's end, too high to
		# jump over; she drops past its edge.
		if wall.end.y <= first.position.y - HEIGHT - JUMP_UP or first.position.y - wall.position.y <= OUT_UP:
			ok["wall"] = false
		if wall.position.x - first.end.x < 0.9 * CELL:
			ok["down"] = false
		# Below, the low chunk reaches under the wall with room for her.
		if low.position.y - first.position.y < CELL or low.position.y - wall.end.y < HEIGHT + 8.0 \
				or low.position.x > wall.position.x or low.end.x < wall.end.x:
			ok["under"] = false
		for i in [[LOW, STEP_B], [STEP_B, STEP_C]]:
			var a := collapse.piece_rect(i[0])
			var b := collapse.piece_rect(i[1])
			if a.position.y - b.position.y > JUMP_UP or b.position.y >= a.position.y or b.position.x - a.end.x > JUMP_ACROSS:
				ok["steps"] = false
		var c := collapse.piece_rect(STEP_C)
		if c.position.y - ledge.y <= OUT_UP:
			ok["ledge_out"] = false
		var lift := collapse.piece_rect(LIFT)
		if collapse.piece_hangs(LIFT) and (c.position.y - lift.position.y > JUMP_UP or lift.position.x - c.end.x > 0.5 * CELL):
			ok["onto_lift"] = false
	check(onto_first >= 3 * TICKS_PER_SECOND, "she can jump from the crane onto the first chunk for 3 s at least, %d ticks" % onto_first)
	check(ok["wall"], "the wall hangs in her way past the first chunk, too high to jump over")
	check(ok["down"], "between the first chunk and the wall there is room to drop down")
	check(ok["under"], "the low chunk lies well below the first and reaches under the wall with room for her")
	check(ok["steps"], "from the low chunk two chunks are a step up each")
	check(ok["ledge_out"], "the last of them stays below the exit ledge, out of her reach")
	check(ok["onto_lift"], "while the platform still hangs low she steps onto it from the last chunk")
	var sizes := {}
	for k in ROUTE:
		sizes[collapse.pieces[k].size] = true
	check(sizes.size() == ROUTE.size(), "each chunk of her way is its own size")
	collapse.restore_state({"clock": plan.clock_end, "ride": start})
	check(collapse.slowness() == 1.0, "the world is at its slowest then")
	check(plan.heroine_tempo < 1.0 and plan.heroine_tempo > plan.tempo, "she slows down too, less than the world")
	check(is_equal_approx(Engine.time_scale, plan.heroine_tempo), "her clock runs at her slow tempo, %.2f" % Engine.time_scale)
	check(collapse.piece_holds(FIRST), "a falling chunk holds her")
	var act_3 := plan.lamps.filter(func(l: Dictionary) -> bool: return int(l["act"]) == 3)
	check(act_3.size() == 2, "two lamps fall among the chunks")
	var world_lamps: Array = (Content.level_for_scene(LEVEL_PATH)["world"] as Dictionary)["lamps"]
	for one: Dictionary in act_3:
		var fall := collapse.lamp_fall(int(one["lamp"]))
		check(float(fall["light"]) == 1.0 and float(fall["drop"]) > 0.0 and float(fall["drop"]) < 1.0,
			"lamp %d is on its way down among the chunks, still shining" % int(one["lamp"]))
		var x := float((world_lamps[int(one["lamp"])] as Dictionary)["x"]) * CELL
		var clear := true
		for k in ROUTE + [WALL, LIFT]:
			clear = clear and (x < collapse.pieces[k].position.x - 8.0 or x > collapse.pieces[k].end.x + 8.0)
		check(clear, "lamp %d falls through a gap, past every chunk of her way" % int(one["lamp"]))
	collapse.restore_state({"clock": plan.clock_end, "ride": plan.ride_end})
	for k in collapse.lost:
		check(not collapse.piece_holds(k), "at the bottom of the pit chunk %d holds nobody" % k)
	for one: Dictionary in act_3:
		check(float(collapse.lamp_fall(int(one["lamp"]))["light"]) == 0.0, "lamp %d is broken at the bottom" % int(one["lamp"]))
	check(collapse.crane_load_rect().position.y > ledge.y + 8.0 * CELL, "the crane has fallen into the pit")
	check(Engine.time_scale == 1.0, "after the slow part her clock is back to normal")
	collapse.restore_state({"clock": plan.clock_end, "ride": start})
	await _free(room)
	check(Engine.time_scale == 1.0, "leaving the level puts her clock back to normal")


func test_level_05_a_tumbling_chunk_crosses_her_jump_and_shift_sends_it_back() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	var start := plan.arrival() + plan.slow_from + plan.slow_ease
	check(str(plan.pieces[TUMBLER]["kind"]) == "tumble", "the small chunk tumbles")
	var blocked := 0
	var above_before := false
	var turned := false
	var solid := true
	var drift := false
	for r in range(plan.arrival(), start + 15 * TICKS_PER_SECOND):
		collapse.restore_state({"clock": plan.clock_end, "ride": r})
		var a := collapse.piece_rect(LOW)
		var b := collapse.piece_rect(STEP_B)
		# Where her body flies on the jump from the low chunk up to the next.
		var top := minf(a.position.y, b.position.y) - JUMP_UP - 1.2 * CELL
		var jump := Rect2(a.end.x, top, b.position.x - a.end.x, a.position.y - top)
		var t := collapse.piece_rect(TUMBLER)
		if t.intersects(jump):
			if r >= start:
				blocked += 1
				turned = turned or absf(plan.turn(TUMBLER, plan.clock_end, r)) > 0.5
				solid = solid and collapse.piece_holds(TUMBLER)
				drift = drift or not is_equal_approx(t.position.x, collapse.pieces[TUMBLER].position.x)
		elif blocked == 0 and t.end.y <= jump.position.y and not collapse.piece_hangs(TUMBLER):
			above_before = true
	check(blocked >= 3 * TICKS_PER_SECOND, "it tumbles across her jump up from the low chunk for 3 s at least, %d ticks" % blocked)
	check(above_before, "before that it falls above the jump, so Shift sends it back out of her way")
	check(turned and drift, "it turns over and drifts sideways on its way")
	check(solid, "it is solid (D149, variant а), though only above her feet")
	await _free(room)


func test_level_05_a_tumbling_chunk_in_the_gap_knocks_her_out_of_the_jump() -> void:
	# From the edge of the low chunk she jumps for the next twice: once while
	# the tumbling chunk crosses the gap, once while it is still above.
	var landed_blocked := await _jump_up_from_low_chunk(5 * TICKS_PER_SECOND)
	var landed_clear := await _jump_up_from_low_chunk(TICKS_PER_SECOND / 2)
	check(not landed_blocked, "with the chunk in the gap she hits it and falls short")
	check(landed_clear, "with the chunk above the gap she lands on the next step")


## Puts the collapse `after` ticks into the slowest part of act 3 and her on
## the right edge of the low chunk, jumps right and tells whether she landed
## on the next step.
func _jump_up_from_low_chunk(after: int) -> bool:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	var plan := collapse.plan
	var ride := plan.arrival() + plan.slow_from + plan.slow_ease + after
	collapse.restore_state({"clock": plan.clock_end, "ride": ride})
	var step := collapse.piece_rect(LOW)
	player.respawn(Vector2(step.end.x - 28.0, step.position.y))
	await _ticks(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _ticks(32)
	Input.action_release("jump")
	await _ticks(40)
	Input.action_release("move_right")
	await _ticks(8)
	var next := collapse.piece_rect(STEP_B)
	var feet := player.global_position
	var landed := player.is_on_floor() and feet.x > next.position.x - 22.0 and absf(feet.y - next.position.y) < 8.0
	await _free(room)
	return landed


func test_level_05_the_falling_slab_pulls_the_platform_up_to_the_exit() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	var ledge := _exit_floor(room)
	check(int(plan.pieces[LIFT]["follow"]) == SLAB, "the platform hangs against the heavy slab over pulleys")
	var start := plan.arrival() + plan.slow_from + plan.slow_ease
	collapse.restore_state({"clock": plan.clock_end, "ride": start})
	var low := collapse.piece_rect(LIFT)
	check(collapse.piece_hangs(LIFT) and collapse.piece_hangs(SLAB), "when the world slows down the slab still hangs and the platform is low")
	var risen_at := -1
	var follows := true
	var before := collapse.piece_rect(LIFT).position.y
	for r in range(start, start + 10 * TICKS_PER_SECOND):
		collapse.restore_state({"clock": plan.clock_end, "ride": r})
		var y := collapse.piece_rect(LIFT).position.y
		follows = follows and y <= before + 0.01
		before = y
		if risen_at < 0 and collapse.piece_lies(LIFT):
			risen_at = r
	check(risen_at > start, "in the slow part the slab falls and pulls the platform all the way up, %d ticks in" % (risen_at - start))
	check(follows, "the platform only ever rises as the slab falls")
	var high := collapse.piece_rect(LIFT)
	check(is_equal_approx(high.position.y, ledge.y) and high.end.x <= ledge.x and ledge.x - high.end.x < 0.3 * CELL,
		"up there it is flush with the exit ledge, right by it")
	var c := collapse.piece_rect(STEP_C)
	check(c.position.y - high.position.y > OUT_UP, "then it is out of her reach from the last chunk")
	check(high.position.y - low.position.y < -3.0 * CELL, "it rose more than three cells")
	check(collapse.piece_holds(LIFT) and collapse.piece_holds(SLAB), "the platform and the slab hold her, even down")
	check(collapse.slowness() == 1.0, "and the world is still slow")
	await _free(room)


func test_level_05_her_step_onto_the_exit_ledge_ends_the_slow_part() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	var plan := collapse.plan
	var ledge := _exit_floor(room)
	# Before the slow part a step onto the ledge changes nothing.
	collapse.restore_state({"clock": plan.clock_end, "ride": plan.arrival()})
	check(not plan.can_calm(plan.arrival()), "before the world slows down there is nothing to end")
	var start := plan.arrival() + plan.slow_from + plan.slow_ease
	collapse.restore_state({"clock": plan.clock_end, "ride": start + 3 * TICKS_PER_SECOND})
	check(collapse.slow_now(), "three seconds into the slow part the world is slow")
	player.respawn(Vector2(ledge.x + 2.0 * CELL, ledge.y))
	await _ticks(10)
	check(collapse.calm >= 0, "her step onto the exit ledge is recorded, at ride %d" % collapse.calm)
	await _ticks(plan.slow_ease + 10)
	check(not collapse.slow_now(), "and the world runs at its own tempo again")
	check(Engine.time_scale == 1.0, "so does she")
	await _free(room)


func test_collapse_plan_blast_flares_up_at_the_third_quake_and_dies() -> void:
	var plan := _level_plan()
	plan.aim(0.0, Vector2(100.0, 0.0), [])
	var a := plan.arrival()
	check(plan.blast_light(a - 1) == 0.0 and plan.blast_age(a - 1) < 0.0, "no explosion before the third quake")
	var peak := 0.0
	var last := 0
	for r in range(a, plan.ride_end):
		peak = maxf(peak, plan.blast_light(r))
		if plan.blast_age(r) >= 0.0:
			last = r
	check(peak > 0.95, "it flashes at full light, %.2f" % peak)
	check(plan.blast_light(plan.ride_end) == 0.0, "and dies out")
	check(plan.act3(last) > plan.act3(a + plan.slow_from), "it is still burning when the world slows down")
	check(plan.heroine_scale(a - 1) == 1.0 and plan.heroine_scale(plan.ride_end) == 1.0, "she moves at her own pace before and after")


func test_level_05_a_fall_into_the_pit_starts_the_room_again() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	await _ticks(3 * 60)
	check(collapse.clock > 120, "the collapse has gone on")
	player.respawn(Vector2(30.0 * CELL, 15.0 * CELL))
	await _ticks(90)
	check(player.global_position.x < 5.0 * CELL, "after the fall she is back at the start, x %.0f" % player.global_position.x)
	check(collapse.clock < 120, "and the room starts again from its beginning, clock %d" % collapse.clock)
	await _free(room)


func test_level_05_layout() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var blocks := room.get_node("Blocks") as TileMapLayer
	var used := blocks.get_used_rect()
	var solid := func(x: float, y: float) -> bool:
		return blocks.get_cell_source_id(Vector2i(int(floor(x / CELL)), int(floor(y / CELL)))) != -1
	var spawn := (room.get_node("SpawnPoint") as Node2D).position
	for k in FIRST_CHUNK:
		var rest := collapse.rests[k]
		check(solid.call(rest.get_center().x, rest.end.y + 1.0), "platform %d lies on its stub" % k)
		check(spawn.y - collapse.pieces[k].end.y > JUMP_UP, "hanging platform %d is out of reach from the floor" % k)
	for k in range(1, FIRST_CHUNK):
		check(collapse.rests[k].position.x - collapse.rests[k - 1].end.x <= JUMP_ACROSS,
			"from fallen platform %d she jumps onto %d" % [k - 1, k])
	# The broken platform hangs level with the ledge, which starts where it ends.
	var hang := collapse.pieces[BROKEN]
	check(solid.call(hang.end.x + 4.0, hang.position.y + 4.0), "the ledge starts where the third platform ends")
	check(not solid.call(hang.end.x + 4.0, hang.position.y - 4.0), "level with it")
	check(collapse.rests[BROKEN].position.y - hang.position.y > JUMP_UP, "the ledge is out of reach from the wreck")
	# The crane waits flush with the ledge's end.
	var crane := collapse.crane_rect
	check(solid.call(crane.position.x - 4.0, crane.position.y + 4.0) and not solid.call(crane.position.x - 4.0, crane.position.y - 4.0),
		"the crane waits level with the ledge, by its end")
	# The chunks are lost below the room; the exit ledge is out of reach without them.
	for k in collapse.lost:
		check(collapse.rests[k].position.y >= float(used.end.y) * CELL, "lost chunk %d falls out of sight" % k)
	var ledge := _exit_floor(room)
	var end := collapse.crane_rect.end + collapse.crane_travel
	check(ledge.x - end.x > 2.0 * JUMP_ACROSS, "from the end of the rail the exit ledge is out of reach")
	await _free(room)


## The left end of the exit ledge's floor (its x, its top y).
func _exit_floor(room: Node) -> Vector2:
	var exit := room.find_children("*", "ExitZone", true, false)[0] as ExitZone
	var blocks := room.get_node("Blocks") as TileMapLayer
	var floor_y := exit.position.y + exit.size.y / 2.0
	var x := int(floor(exit.position.x / CELL))
	while blocks.get_cell_source_id(Vector2i(x - 1, int(floor_y / CELL))) != -1:
		x -= 1
	return Vector2(float(x) * CELL, floor_y)


func _level_plan() -> CollapsePlan:
	var entry := Content.level_for_scene(LEVEL_PATH)
	return CollapsePlan.from_data(entry.get("collapse"), Content.world_ticks_per_second(Content.time()),
		ObjectLook.of("quake"), ObjectLook.of("collapse"))


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
