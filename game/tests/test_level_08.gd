extends RefCounted
## Tests of level 08 «Crane» on one screen (card docs/levels/08.md, D210): the
## collapse of level 05 as a puzzle (`CollapsePlan`, `Collapse`). Act 1: the
## bridge's two slabs fall onto their stubs, the heavy slab sinks and pulls the
## yellow platform up flush with the exit tower. Act 2: her step onto the crane
## sets it riding down its rail; act 3: it falls at the end. Under Shift the
## crane flies back first, then the slab she stands on lifts her to the
## bridge; at the world's start she walks onto the platform, and the replayed
## fall of the heavy slab lifts her to the exit. The solutions in
## tests/solutions/level_08*.json play the level.

const LEVEL_PATH := "res://levels/level_08.tscn"
const CELL := 64.0
## Pieces of the level: the bridge's slabs, the heavy slab, the platform.
const SLAB_A := 0
const SLAB_B := 1
const HEAVY := 2
const LIFT := 3
## The heroine's height and jump (D112), with a margin for a human hand.
const HEIGHT := 92.0
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


func test_level_08_plan_the_bridge_falls_then_the_counterweight() -> void:
	var plan := _level_plan()
	check(plan.pieces.size() == 4, "two bridge slabs, a heavy slab and its platform, got %d" % plan.pieces.size())
	for k in plan.pieces.size():
		check(int(plan.pieces[k]["act"]) == 1, "piece %d falls in act 1, before her eyes" % k)
	var start := func(k: int) -> int: return plan.quake_tick + int(plan.pieces[k]["at"])
	check(start.call(SLAB_A) < start.call(SLAB_B) and start.call(SLAB_B) < start.call(HEAVY),
		"slab A, then slab B, then the heavy slab")
	check(str(plan.pieces[HEAVY]["kind"]) == "sink", "the heavy slab sinks evenly, so the platform rises evenly")
	check(int(plan.pieces[LIFT]["follow"]) == HEAVY, "the platform hangs against the heavy slab")
	var mid: int = int(start.call(HEAVY)) + int(plan.pieces[HEAVY]["fall"]) / 2
	check(plan.way(LIFT, mid, -1) == plan.way(HEAVY, mid, -1) and plan.way(LIFT, mid, -1) > 0.0,
		"the platform rises as the slab sinks")
	check(plan.drop(LIFT, plan.clock_end, -1) == 1.0, "once the slab is down the platform is up")
	check(plan.tempo == 1.0 and plan.slowness(plan.arrival() + 100) == 0.0, "no slow part in this room")
	check(plan.crane_lamps.size() == 1 and plan.crane_hits[0] > plan.ride_delay and plan.crane_hits[0] < plan.arrival(),
		"the lamp over the rail falls as the crane passes it")
	# History (D56): everything she rewinds must still be in the room's history
	# (data/time.json history_seconds) after the whole ride.
	var history := int(float(Content.time().get("history_seconds", 20)) * TICKS_PER_SECOND)
	check(plan.clock_end + plan.ride_end < history,
		"the fall of act 1 and the whole ride fit into the history: %d of %d ticks" % [plan.clock_end + plan.ride_end, history])


func test_level_08_her_window_to_step_off_the_crane_is_3_seconds() -> void:
	var plan := _level_plan()
	check(plan.crane_fall_at >= 3 * TICKS_PER_SECOND,
		"the crane waits at the end of its rail for %d ticks before it falls" % plan.crane_fall_at)


func test_level_08_act_1_falls_before_her_eyes() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	for k in collapse.pieces.size():
		check(collapse.piece_hangs(k), "piece %d hangs at the start" % k)
	await _ticks(collapse.plan.clock_end + 4)
	for k in [SLAB_A, SLAB_B]:
		check(collapse.piece_lies(k) and collapse.piece_holds(k), "bridge slab %d lies on its stub and holds her" % k)
	check(collapse.piece_lies(HEAVY), "the heavy slab is down")
	check(collapse.piece_rect(LIFT).position.y == collapse.rests[LIFT].position.y, "the platform is up by the tower")
	check(collapse.crane_waits(), "the crane waits for her by the ledge")
	check(collapse.clock == collapse.plan.clock_end, "act 1's clock stops once all is down, so the room may stand")
	await _free(room)


func test_level_08_layout() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var blocks := room.get_node("Blocks") as TileMapLayer
	var used := blocks.get_used_rect()
	var solid := func(x: float, y: float) -> bool:
		return blocks.get_cell_source_id(Vector2i(int(floor(x / CELL)), int(floor(y / CELL)))) != -1
	check(used.size == Vector2i(30, 17), "one screen of 30x17 cells, got %s" % used.size)
	var spawn := (room.get_node("SpawnPoint") as Node2D).position
	var ledge_end := 7.0 * CELL
	check(solid.call(ledge_end - 4.0, spawn.y + 4.0) and not solid.call(ledge_end + 4.0, spawn.y + 4.0),
		"the entrance ledge ends at column 7")
	var crane := collapse.crane_rect
	check(solid.call(crane.position.x - 4.0, crane.position.y + 4.0) and not solid.call(crane.position.x - 4.0, crane.position.y - 4.0),
		"the crane waits level with the ledge, by its end")
	for k in [SLAB_A, SLAB_B]:
		var hang := collapse.pieces[k]
		var rest := collapse.rests[k]
		check(solid.call(rest.get_center().x, rest.end.y + 1.0), "slab %d lies on its stub" % k)
		check(spawn.y - hang.end.y > OUT_UP or hang.position.x - crane.end.x > OUT_ACROSS,
			"hanging slab %d is out of reach from the ledge and the waiting crane" % k)
		check(rest.position.x - crane.end.x > OUT_ACROSS, "fallen slab %d is out of reach from the waiting crane" % k)
	# From the end of the rail she steps down onto slab A, and the crane falls
	# past it.
	var end := Rect2(crane.position + collapse.crane_travel, crane.size)
	var a := collapse.rests[SLAB_A]
	check(a.position.x - end.end.x > 0.0 and a.position.x - end.end.x < JUMP_ACROSS / 2.0 and a.position.y > end.position.y,
		"from the end of the rail slab A is a step down: crane ends at %.0f, slab at %.0f" % [end.end.x, a.position.x])
	check(collapse.rests[SLAB_B].position.x - a.end.x < JUMP_ACROSS / 2.0, "slab B lies next to slab A")
	# The mended bridge runs level onto the platform, which rises flush with
	# the tower; from the bridge the tower is out of reach.
	var lift_low := collapse.pieces[LIFT]
	var lift_up := collapse.rests[LIFT]
	for k in [SLAB_A, SLAB_B]:
		check(collapse.pieces[k].position.y == lift_low.position.y, "slab %d hangs level with the low platform" % k)
	check(lift_low.position.x - collapse.pieces[SLAB_B].end.x < 8.0 and collapse.pieces[SLAB_B].position.x - collapse.pieces[SLAB_A].end.x < 8.0,
		"the bridge has no gaps")
	check(solid.call(lift_up.end.x + 4.0, lift_up.position.y + 4.0) and not solid.call(lift_up.end.x + 4.0, lift_up.position.y - 4.0),
		"the risen platform is flush with the top of the tower")
	check(lift_low.position.y - lift_up.position.y > OUT_UP, "from the low platform the tower's top is out of reach")
	check(a.position.y - lift_up.position.y > OUT_UP, "from the fallen bridge the risen platform is out of reach")
	# The heavy slab sinks as far as the platform rises, and never over her
	# head while she walks the bridge at the start.
	var heavy_way := collapse.rests[HEAVY].position.y - collapse.pieces[HEAVY].position.y
	check(is_equal_approx(heavy_way, lift_low.position.y - lift_up.position.y), "one chain: the slab sinks as far as the platform rises")
	check(lift_low.position.y - HEIGHT - collapse.pieces[HEAVY].end.y > 0.5 * CELL, "the hanging slab is well over her head on the bridge")
	await _free(room)


func test_level_08_under_shift_the_crane_flies_back_first_then_her_slab_lifts_her() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	await _ticks(collapse.plan.clock_end + 2)
	var load_rect := collapse.crane_load_rect()
	player.respawn(Vector2(load_rect.get_center().x, load_rect.position.y))
	for i in collapse.plan.arrival() + 30:
		await _tree.physics_frame
		if collapse.crane_arrived():
			break
	check(collapse.crane_arrived(), "her step set the crane riding to the end of its rail")
	var a := collapse.rests[SLAB_A]
	player.respawn(Vector2(a.get_center().x, a.position.y))
	await _ticks(10)
	Input.action_press("rewind")
	var back := -1
	var rose := -1
	for i in 900:
		await _tree.physics_frame
		if back < 0 and collapse.ride < 0:
			back = i
		if rose < 0 and not collapse.piece_lies(SLAB_A):
			rose = i
		if collapse.clock == 0:
			break
	check(back >= 0 and rose > back, "the crane is back before her slab rises: back %d, rose %d" % [back, rose])
	await _ticks(60)
	var hang := collapse.pieces[SLAB_A]
	check(collapse.piece_hangs(SLAB_A) and collapse.piece_hangs(SLAB_B), "the bridge hangs whole at the world's start")
	check(absf(player.global_position.y - hang.position.y) < 8.0,
		"slab A carried her up to the bridge, feet at %.0f, top %.0f" % [player.global_position.y, hang.position.y])
	Input.action_release("rewind")
	await _free(room)


func test_level_08_from_the_worlds_start_the_replayed_fall_lifts_her_to_the_exit() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	await _ticks(collapse.plan.clock_end + 2)
	Input.action_press("rewind")
	for i in 600:
		await _tree.physics_frame
		if collapse.clock == 0:
			break
	var low := collapse.pieces[LIFT]
	player.respawn(Vector2(low.get_center().x, low.position.y))
	await _ticks(3 * TICKS_PER_SECOND)
	check(collapse.clock == 0 and collapse.piece_rect(LIFT).position.y == low.position.y,
		"held at the world's start the platform waits low by the bridge")
	Input.action_release("rewind")
	await _ticks(collapse.plan.clock_end + 10)
	var up := collapse.rests[LIFT]
	check(absf(player.global_position.y - up.position.y) < 8.0,
		"the replayed fall of the slab lifted her to the tower's top, feet at %.0f, top %.0f" % [player.global_position.y, up.position.y])
	await _free(room)


func _level_plan() -> CollapsePlan:
	var entry := Content.level_for_scene(LEVEL_PATH)
	var plan := CollapsePlan.from_data(entry.get("collapse"), Content.world_ticks_per_second(Content.time()),
		ObjectLook.of("quake"), ObjectLook.of("collapse"))
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	var collapse := room.get_node("Collapse") as Collapse
	plan.aim(collapse.crane_rect.get_center().x, collapse.crane_travel, _lamp_x(entry))
	room.free()
	return plan


static func _lamp_x(entry: Dictionary) -> Array:
	var layout := WorldData.layout(entry)
	var ceiling := WorldData.ceiling(layout)
	var xs: Array = []
	for lamp: Variant in layout.get("lamps", []):
		xs.append(WorldData.lamp_at(lamp, ceiling).x)
	return xs


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
