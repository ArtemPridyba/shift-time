extends RefCounted
## Tests of level 05 «Crane» (card docs/levels/05.md, D176, D215), one screen:
## the crane rides down past the exit door, shut by a slab on two chains; a
## little further the explosion tears the slab's left chain, but the crane is
## below the door by then. Chunks of the ceiling fall behind it. Under Shift a
## fallen chunk rises again; a jump from it into the crane under Shift makes
## the crane hers (the pedal), Shift carries it to the door, letting go puts
## it on its brake and the explosion opens the door. Also the rules of
## `CollapsePlan` and `Collapse` the level uses (some, like act 1, only on
## data of their own). The solutions in tests/solutions/level_05*.json play
## the level and its wrong tries.

const LEVEL_PATH := "res://levels/level_05.tscn"
const CELL := 64.0
## The chunks of the ceiling: the top one she drops from into the crane, the
## step to it (both fall into the pit) and the lift from the floor.
const BOARD := 0
const STEP := 1
const LIFT := 2
const CHUNKS: Array[int] = [BOARD, STEP, LIFT]
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
	# Act 1 is not in the level any more (D215); its rules stay for later
	# levels. One tick per second, so the seconds are ticks.
	var plan := CollapsePlan.from_data({"quake_seconds": 2, "pieces": [
		{"act": 1, "second": 1, "fall_seconds": 2}, {"act": 1, "second": 5, "fall_seconds": 2},
		{"act": 1, "second": 9, "fall_seconds": 2, "breaks": true, "crumble_seconds": 3}],
		"lamps": [{"lamp": 0, "act": 1, "second": 3, "to_row": 10}, {"lamp": 1, "act": 1, "second": 7, "to_row": 10}]},
		1.0, {"shatter_seconds": 1}, {"shake_seconds": 1})
	var starts: Array[int] = []
	for k in 3:
		var start := plan.quake_tick + int(plan.pieces[k]["at"])
		starts.append(start)
		check(plan.drop(k, start - 1, -1) == 0.0, "platform %d hangs before its turn" % k)
		check(plan.drop(k, start + int(plan.pieces[k]["fall"]), -1) == 1.0, "platform %d lies after its fall" % k)
		check(k == 0 or starts[k] > starts[k - 1], "platform %d falls after the one before" % k)
	for k in 2:
		var lamp := plan.quake_tick + int(plan.lamps[k]["at"])
		check(lamp > starts[k] and lamp < starts[k + 1], "lamp %d falls between its platform and the next" % k)
		var dark := plan.lamp_fall(k, plan.clock_end, -1)
		check(float(dark["light"]) == 0.0 and float(dark["shatter"]) == 1.0, "lamp %d lies dark and broken" % k)
	check(plan.broken(2, plan.clock_end, -1) == 1.0 and plan.broken(0, plan.clock_end, -1) == 0.0,
		"only the third platform breaks")
	var landed := starts[2] + int(plan.pieces[2]["fall"])
	check(plan.crumble(2, landed + 1, -1) == 0.0 and plan.crumble(2, plan.clock_end, -1) == 1.0,
		"it lies a moment, then crumbles")
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
	(broken["pieces"][0] as Dictionary)["spin"] = "fast"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a spin that is not a number is reported")
	broken = good.duplicate(true)
	(broken["pieces"][0] as Dictionary)["kind"] = "roll"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "an unknown kind of fall is reported")
	broken = good.duplicate(true)
	(broken["pieces"][0] as Dictionary)["kind"] = "follow"
	(broken["pieces"][0] as Dictionary)["follow"] = 0
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a piece hung against itself is reported")
	broken = good.duplicate(true)
	(broken["slow"] as Dictionary)["tempo"] = 0
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a tempo of 0 is reported")
	broken = good.duplicate(true)
	(broken["crane"] as Dictionary)["lamps"] = [lamps.size()]
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a lamp the world does not have is reported")
	broken = good.duplicate(true)
	(broken["gate"] as Dictionary)["swing_seconds"] = 0
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a gate that swings in no time is reported")
	broken = good.duplicate(true)
	(broken["crane"] as Dictionary)["falls"] = "never"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a crane 'falls' that is no yes or no is reported")
	broken = good.duplicate(true)
	broken["gate"] = "open"
	check(not CollapsePlan.problems(broken, "x", lamps.size()).is_empty(), "a gate that is no object is reported")
	check(not CollapsePlan.problems(null, "x", 1).is_empty(), "no collapse object is reported")


func test_world_darkness_and_lamp_radius_are_checked() -> void:
	var good := {"darkness": "#17171e", "lamps": [{"x": 1, "drop": 1, "radius_px": 400}]}
	check(WorldData.validate_layout(good, "x").is_empty(), "a darker room and a lamp's own radius are fine")
	check(not WorldData.validate_layout({"darkness": "dark"}, "x").is_empty(), "a darkness that is no colour is reported")
	check(not WorldData.validate_layout({"lamps": [{"x": 1, "drop": 1, "radius_px": 0}]}, "x").is_empty(),
		"a lamp radius of 0 is reported")


func test_collapse_plan_blast_flares_up_at_the_third_quake_and_dies() -> void:
	var plan := _mid_ride_plan()
	plan.blast_ticks = 20
	var a := plan.act3_at
	check(plan.blast_light(a - 1) == 0.0 and plan.blast_age(a - 1) < 0.0, "no explosion before the third quake")
	var peak := 0.0
	for r in range(a, plan.ride_end):
		peak = maxf(peak, plan.blast_light(r))
	check(peak > 0.95, "it flashes at full light, %.2f" % peak)
	check(plan.blast_light(a + 100000) == 0.0, "and dies out")


func test_collapse_plan_the_gate_swings_aside_after_the_third_quake() -> void:
	var plan := CollapsePlan.from_data({"crane": {"delay_seconds": 2, "speed": 10, "blast_way": 0.5},
		"gate": {"second": 2, "swing_seconds": 3}}, 1.0, {}, {})
	plan.aim(0.0, Vector2(100.0, 0.0), [])
	var tears := plan.act3_at + 2
	check(plan.gate_open(-1) == 0.0 and plan.gate_open(tears) == 0.0, "the slab hangs on both chains until its chain tears")
	check(plan.gate_open(tears + 1) > 0.0 and plan.gate_open(tears + 2) < 1.0, "then swings aside")
	check(plan.gate_open(tears + 3) == 1.0, "and stays aside")
	check(plan.gate_open(plan.ride_end) == 1.0, "for good")
	plan.brake = plan.ride_delay + 1
	check(plan.gate_open(tears + 3) == 1.0, "the crane's brake does not stop the world: the chain tears all the same")
	check(CollapsePlan.from_data({}, 1.0, {}, {}).gate_open(1000) == 0.0, "without a gate nothing swings")


func test_level_05_is_one_screen() -> void:
	var room := await _load()
	var used := (room.get_node("Blocks") as TileMapLayer).get_used_rect()
	check(used.size == Vector2i(30, 17), "the room is one screen, 30x17 cells: %s" % used.size)
	await _free(room)


func test_level_05_starts_from_the_effect() -> void:
	# The prelude (D215): the empty crane has ridden down by itself, the
	# explosion has opened the door, the chunks lie where they fell.
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	check(plan.ride_start >= 0, "the crane sets off by itself")
	check(collapse.ride >= plan.arrival() and collapse.is_open(), "when she comes in the crane is down and the door open, ride %d" % collapse.ride)
	for k in CHUNKS:
		check(collapse.piece_lies(k), "chunk %d lies where it fell" % k)
	check(not collapse.piece_holds(BOARD) and not collapse.piece_holds(STEP), "the two chunks in the pit are out of play")
	check(collapse.piece_holds(LIFT), "the one by the entrance lies on the floor")
	var spawn := (room.get_node("SpawnPoint") as Node2D).position
	check(spawn.x > collapse.rests[LIFT].end.x and spawn.x - collapse.rests[LIFT].end.x < 6.0 * CELL, "she comes in by it")
	await _free(room)


func test_level_05_the_door_is_out_of_reach_but_by_the_rail() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var exit := room.get_node("Exit") as ExitZone
	var zone := exit.rect()
	var spawn := (room.get_node("SpawnPoint") as Node2D).position
	check(spawn.y - zone.end.y > OUT_UP and absf(spawn.x - zone.get_center().x) > OUT_ACROSS, "the entrance is far from the door")
	for k in CHUNKS:
		var hang := collapse.pieces[k]
		check(hang.position.x - zone.end.x > OUT_ACROSS or zone.position.x - hang.end.x > OUT_ACROSS,
			"hanging chunk %d is far from the door" % k)
	# Somewhere on its way the crane's floor is the door's sill.
	var best := INF
	for i in 101:
		var load_rect := Rect2(collapse.crane_rect.position + collapse.crane_travel * (float(i) / 100.0), collapse.crane_rect.size)
		if load_rect.position.x < zone.end.x and load_rect.end.x > zone.position.x:
			best = minf(best, absf(load_rect.position.y - zone.end.y))
	check(best < 0.2 * CELL, "the crane passes the door with its floor at the sill, %.0f px" % best)
	await _free(room)


func test_level_05_the_door_opens_only_after_the_crane_has_passed_it() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	var zone := (room.get_node("Exit") as ExitZone).rect()
	check((room.get_node("Exit") as ExitZone).get("_door") == collapse, "the slab locks the exit")
	var first_open := -1
	for r in plan.ride_end:
		if plan.gate_open(r) >= 1.0:
			first_open = r
			break
	check(first_open > plan.act3_at, "the slab swings aside after the explosion, ride tick %d" % first_open)
	collapse.restore_state({"clock": plan.clock_end, "ride": first_open - 1, "calm": -1, "brake": -1})
	check(not collapse.is_open(), "the door is shut a tick before")
	var load_rect := collapse.crane_load_rect()
	# By then the crane is below and past the door: no jump from it gets there.
	check(load_rect.position.y - zone.end.y > OUT_UP or load_rect.position.x - zone.end.x > OUT_ACROSS,
		"when the door opens the crane is out of reach of it: crane %s, door %s" % [load_rect, zone])
	collapse.restore_state({"clock": plan.clock_end, "ride": first_open, "calm": -1, "brake": -1})
	check(collapse.is_open(), "then it is open")
	await _free(room)


func test_level_05_the_top_chunk_hangs_out_of_reach_of_the_crane_and_falls_behind_it() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	for k in CHUNKS:
		var hang := collapse.pieces[k]
		var falls := plan.act3_at + int(plan.pieces[k]["at"])
		var passes_under := false
		for r in range(plan.ride_delay, plan.arrival() + 1):
			var crane := plan.crane_pose(r, collapse.crane_travel, 0.0)
			var load_rect := Rect2(collapse.crane_rect.position + (crane["at"] as Vector2), collapse.crane_rect.size)
			var gap := maxf(hang.position.x - load_rect.end.x, load_rect.position.x - hang.end.x)
			if gap < JUMP_ACROSS:
				check(load_rect.position.y - hang.position.y > OUT_UP,
					"hanging chunk %d is out of reach from the crane (ride %d)" % [k, r])
			if gap < 0.0:
				check(load_rect.position.y - hang.end.y > HEIGHT + 8.0,
					"she has room to ride under hanging chunk %d (ride %d)" % [k, r])
				passes_under = passes_under or r < falls
		check(passes_under == (k == BOARD), "only the top chunk still hangs when the crane passes under it (chunk %d)" % k)
	await _free(room)


func test_level_05_the_chunks_are_a_stair_from_the_floor_to_the_top_one() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var plan := collapse.plan
	var order: Array[int] = [LIFT, STEP, BOARD]
	for i in range(1, order.size()):
		var from := collapse.pieces[order[i - 1]]
		var to := collapse.pieces[order[i]]
		check(from.position.x - to.end.x <= JUMP_ACROSS and from.position.y - to.position.y < JUMP_UP,
			"from hanging chunk %d she jumps onto %d" % [order[i - 1], order[i]])
	# The lift lies before the crane comes over it, and rises after it has
	# gone: it never takes her to the crane itself.
	var hang := collapse.pieces[LIFT]
	var rest := collapse.rests[LIFT]
	for r in range(plan.act3_at, plan.arrival() + 1):
		var crane := plan.crane_pose(r, collapse.crane_travel, 0.0)
		var load_rect := Rect2(collapse.crane_rect.position + (crane["at"] as Vector2), collapse.crane_rect.size)
		var lift_top := lerpf(hang.position.y, rest.position.y, plan.way(LIFT, plan.clock_end, r))
		if hang.position.x - load_rect.end.x < OUT_ACROSS:
			check(lift_top - load_rect.position.y > OUT_UP,
				"when the crane comes near the lift, the lift is far below it (ride %d)" % r)
	# The top chunk is far from the door: the only way out is the crane.
	var zone := (room.get_node("Exit") as ExitZone).rect()
	check(collapse.pieces[BOARD].position.x - zone.end.x > OUT_ACROSS, "the top chunk is far from the door")
	await _free(room)


func test_level_05_from_the_floor_the_crane_is_out_of_reach() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var end := Rect2(collapse.crane_rect.position + collapse.crane_travel, collapse.crane_rect.size)
	var floor_y := (room.get_node("SpawnPoint") as Node2D).position.y
	check(floor_y - end.position.y > OUT_UP, "from the floor the crane at the end of its rail is out of reach")
	check(collapse.rests[LIFT].position.y - end.position.y > OUT_UP, "from the fallen chunk too")
	check(end.position.x - collapse.rests[LIFT].end.x > 0.5 * CELL, "and she can jump onto the chunk clear of the crane over her head")
	await _free(room)


func test_level_05_the_crane_stays_by_the_floor() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	collapse.restore_state({"clock": collapse.plan.clock_end, "ride": collapse.plan.ride_end, "calm": -1, "brake": -1})
	check(not collapse.plan.crane_down(collapse.ride), "the crane never falls: she can always try again")
	check(collapse.plan.can_brake(collapse.ride), "and at the end of its rail it can still be put on its brake")
	check(collapse.plan.ride_end < 60 * TICKS_PER_SECOND, "its counter stops once all is down, ride %d" % collapse.plan.ride_end)
	check(collapse.plan.slowness(collapse.plan.act3_at + 60) == 0.0, "the world keeps its tempo")
	await _free(room)


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
