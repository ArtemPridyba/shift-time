extends RefCounted
## Tests of level 02 «Поток», rebuilt 24.11.2026 after Artem's sketch (D150,
## card docs/levels/02.md): the height and the look of level 01; button 1 runs
## pool 1 into pool 2 through a sluice; the float of pool 1 carries the heroine
## up to the wall under Shift and the float of pool 2 up to the right floor on
## the replay (rule «А»); button 2 starts the tunnel's drain, its pump fails and
## floods the tunnel again, and only then the near gate opens, so the tunnel is
## crossed only with Shift. The solutions (with Shift, without it, swimming the
## flooded tunnel, running in during the drain) are in `tests/solutions/` and
## run by test_solutions.gd.

const LEVEL_PATH := "res://levels/level_02.tscn"
const LEVEL_01_PATH := "res://levels/level_01.tscn"
const BUTTONS_ROOM := "res://tests/rooms/test_room_buttons.tscn"
const CELL := 64
## Rows from the card: pool 1's full line and the start floor, pool 1's floor
## (= pool 2's full line = the right floor = the tunnel's brim), pool 2's floor,
## the tunnel's floor.
const LINE_ROW := 9
const LOW_ROW := 12
const POOL_2_FLOOR_ROW := 15
const TUNNEL_FLOOR_ROW := 14
## The heroine's head is under water while the water stands this high over her feet.
const HEAD_UNDER_PX := 78.0

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- the core, with the real button and door -------------------------------

## The core has to keep the press in the history: a button pressed at the head,
## rewound to the very first frame and released, presses itself and opens the
## door at the same frames as the first time, without the hero.
func test_core_replays_a_press_after_a_rewind_to_the_first_frame() -> void:
	var room := await _load(BUTTONS_ROOM)
	var at: Vector2 = room.get_node("PushButton").global_position + Vector2(0, 12)
	await _press_rewind_replay(room, "PushButton", "Door", at, at)
	await _free(room)


func _press_rewind_replay(room: Node, button_name: String, door_name: String, hero_at: Vector2, then_at: Vector2) -> void:
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node(door_name)
	var button: PushButton = room.get_node(button_name)
	var player: Player = room.get_node("Player")
	await _ticks(30)
	check(not button.pressed and door.open == 0, "the button starts up and the door shut")
	player.respawn(hero_at)
	time.player_interact(player.global_position)
	var press_cursor := time.cursor()
	var first := {}
	for i in 120:
		await _ticks(1)
		first[time.cursor()] = [button.pressed, door.open]
	check(button.pressed and door.open > 0, "the press must power the door")
	var head := time.cursor()
	player.respawn(then_at)
	await _rewind_to_start(time)
	check(time.cursor() == 0, "the rewind must reach the first frame, cursor %d" % time.cursor())
	check(not button.pressed and door.open == 0, "at the first frame the button is up and the door shut")
	Input.action_release("rewind")
	var replayed := 0
	var wrong := 0
	for i in head + 10:
		await _ticks(1)
		var cursor := time.cursor()
		if first.has(cursor):
			replayed += 1
			if [button.pressed, door.open] != first[cursor]:
				wrong += 1
	check(replayed > 100, "the replay must pass the recorded frames, saw %d" % replayed)
	check(wrong == 0, "%d replayed frames differ from the first run (press at frame %d)" % [wrong, press_cursor])
	check(button.pressed and door.open > 0, "after the replay the button is down and the door is open")


# --- the room ----------------------------------------------------------------

## As high as level 01, longer than one screen; the camera follows.
func test_level_02_is_as_high_as_level_01_and_wider_than_a_screen() -> void:
	var room := await _load(LEVEL_PATH)
	var size := _room_size(room)
	var first := await _load(LEVEL_01_PATH)
	var first_size := _room_size(first)
	await _free(first)
	check(size.y == first_size.y, "level 02 is %d px high, level 01 %d" % [size.y, first_size.y])
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	check(size.x > width and size.x <= 3 * width, "the room is %d px wide, the screen %d" % [size.x, width])
	var camera: Camera2D = room.get_node("Player/Camera2D")
	check(absi(camera.limit_right - size.x) <= 1 and absi(camera.limit_left) <= 1, "the camera limits are %d..%d, the room is %d wide" % [camera.limit_left, camera.limit_right, size.x])
	check(room.get_node_or_null("WorldBack") != null and room.get_node_or_null("WorldLight") != null, "the room wears the Night shop kit like level 01")
	await _free(room)


## The heights the solution stands on: the waters meet on one line, the
## floats start out of reach and only the full ones reach the next floor.
func test_level_02_geometry_follows_the_sketch() -> void:
	var room := await _load(LEVEL_PATH)
	var pool_1: Water = room.get_node("Pool1")
	var pool_2: Water = room.get_node("Pool2")
	var tunnel: Water = room.get_node("Tunnel")
	check(is_equal_approx(pool_1.position.y, LOW_ROW * CELL), "pool 1's floor is on row %d" % LOW_ROW)
	check(is_equal_approx(pool_1.position.y - pool_1.size.y, LINE_ROW * CELL), "full pool 1 stands on the start floor's row")
	check(is_equal_approx(pool_2.position.y - pool_2.size.y, LOW_ROW * CELL), "full pool 2 stands as high as pool 1's floor: one line for both")
	check(is_equal_approx(pool_2.position.y, POOL_2_FLOOR_ROW * CELL), "pool 2's floor is on row %d" % POOL_2_FLOOR_ROW)
	check(is_equal_approx(tunnel.position.y - tunnel.size.y, LOW_ROW * CELL), "the tunnel's water stands to the brim, the floor at the gates")
	check(tunnel.size.y > HEAD_UNDER_PX, "the full tunnel covers the heroine's head")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var float_1 := _float_rect(pool_1, Water.LEVEL_MAX)
	check(float_1.position.x - 5 * CELL > 3 * CELL, "the full float of pool 1 is out of a jump from the start floor")
	var float_1_low := _float_rect(pool_1, 0)
	check(float_1_low.position.y - LINE_ROW * CELL > 110.0, "from the low float of pool 1 the wall is above a jump")
	var float_2 := _float_rect(pool_2, 0)
	check(float_2.position.y - LOW_ROW * CELL > 110.0, "from the low float of pool 2 the right floor is above a jump")
	var float_2_high := _float_rect(pool_2, Water.LEVEL_MAX)
	check(absf(float_2_high.end.x - 26 * CELL) <= CELL and float_2_high.position.y <= LOW_ROW * CELL, "the full float of pool 2 reaches the right floor")
	# The rock over the tunnel's floor reaches down to the brim: no air pocket.
	check(blocks.get_cell_source_id(Vector2i(40, 11)) != -1 and blocks.get_cell_source_id(Vector2i(40, 12)) == -1, "over the tunnel's floor the rock comes down to the brim")
	await _free(room)


# --- pools ---------------------------------------------------------------------

## Button 1 opens the sluice: pool 1 runs into pool 2, the two levels add up to
## one tank at every tick; Shift brings both back and the button up.
func test_level_02_button_1_runs_pool_1_into_pool_2() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var pool_1: Water = room.get_node("Pool1")
	var pool_2: Water = room.get_node("Pool2")
	var sluice: Door = room.get_node("Sluice")
	var button: PushButton = room.get_node("Button1")
	await _ticks(60)
	check(pool_1.level == Water.LEVEL_MAX and pool_2.level == 0, "before the press pool 1 is full and pool 2 empty")
	check(sluice.open == 0, "before the press the sluice is shut")
	time.player_interact(button.global_position)
	var worst := 0
	for i in 240:
		await _ticks(1)
		worst = maxi(worst, absi(pool_1.level + pool_2.level - Water.LEVEL_MAX))
	check(button.pressed and sluice.open == Door.OPEN_MAX, "the press opens the sluice")
	check(pool_1.level == 0 and pool_2.level == Water.LEVEL_MAX, "pool 1 ran into pool 2: %d and %d" % [pool_1.level, pool_2.level])
	check(worst <= 2 * pool_1.step(), "what pool 1 loses pool 2 gains at every tick, worst %d" % worst)
	await _rewind_to_start(time)
	check(not button.pressed and pool_1.level == Water.LEVEL_MAX and pool_2.level == 0, "Shift brings the button up and the water back")
	await _free(room)


# --- tunnel --------------------------------------------------------------------

## Button 2: the tunnel drains and the far gate opens; the pump fails before
## the tunnel is dry, the button sparks, the tunnel fills to the brim and only
## then the near gate opens. While the water is low enough to breathe on the
## tunnel floor the near gate is shut and the far one open: the heroine gets
## that air only from inside, with Shift.
func test_level_02_the_tunnel_floods_again_and_only_then_opens() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var tunnel: Water = room.get_node("Tunnel")
	var gate_in: Door = room.get_node("GateIn")
	var gate_out: Door = room.get_node("GateOut")
	var button: PushButton = room.get_node("Button2")
	var sparks: ButtonSparks = room.get_node("Button2/Sparks")
	await _ticks(30)
	# The far gate is the lever's (D161): switched on here as the jet would.
	var lever: Lever = room.get_node("LeverJet")
	for change: Dictionary in lever.get_interaction_change(time.temporal_objects()):
		time.player_action(str(change["id"]), change["state"])
	await _ticks(120)
	check(gate_out.open == Door.OPEN_MAX, "the lever opens the far gate")
	check(sparks.is_lit(), "the button sparks before the press, as a hint")
	time.player_interact(button.global_position)
	await _ticks(5)
	check(not sparks.is_lit(), "pressed, the button is quiet")
	var breath_level := int(Water.LEVEL_MAX * HEAD_UNDER_PX / tunnel.size.y)
	var lowest := Water.LEVEL_MAX
	var turned_at := -1
	var flooded_at := -1
	var opened_in_at := -1
	var low_ticks := 0
	var bad_gates := 0
	for i in 1200:
		await _ticks(1)
		lowest = mini(lowest, tunnel.level)
		if tunnel.turned() and turned_at < 0:
			turned_at = i
			check(sparks.is_lit(), "when the pump fails the button sparks again")
		if turned_at >= 0 and tunnel.level == Water.LEVEL_MAX and flooded_at < 0:
			flooded_at = i
		if gate_in.open > 0 and opened_in_at < 0:
			opened_in_at = i
		if tunnel.level < breath_level:
			low_ticks += 1
			if gate_in.open > 0 or gate_out.open < Door.OPEN_MAX:
				bad_gates += 1
	check(turned_at > 0, "the pump fails")
	check(lowest > 0 and lowest < breath_level, "the tunnel runs low but never dry: lowest %d" % lowest)
	check(flooded_at > turned_at, "after the failure the tunnel fills to the brim")
	check(opened_in_at >= flooded_at - 30, "the near gate opens only with the tunnel flooded: opens at %d, full at %d" % [opened_in_at, flooded_at])
	check(gate_in.open == Door.OPEN_MAX and gate_out.open == Door.OPEN_MAX, "at the end both gates stand open")
	check(low_ticks >= 3 * 60, "the air on the tunnel floor lasts %d ticks: at least 3 s to see it" % low_ticks)
	check(bad_gates == 0, "%d low-water ticks with the near gate open or the far one shut" % bad_gates)
	check(tunnel.capture_state().has("run"), "the pump's run is recorded, so Shift plays the failure back")
	await _free(room)


## A tank whose pump fails turns its flow after `turn_after_seconds`; the turn
## is in the recorded state, so a restored frame turns at the same tick again.
func test_water_with_a_failing_pump_turns_and_restores() -> void:
	var tank: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	tank.apply_settings({"full_seconds": 4, "turn_after_seconds": 1})
	tank.level = Water.LEVEL_MAX
	tank.open_flow = -1
	tank.powered = true
	var ticks := tank.turn_after_ticks
	check(ticks > 0, "turn_after_seconds becomes ticks")
	for i in ticks:
		tank.simulate_tick(i)
	check(not tank.turned() and tank.flow == -1, "before the turn the tank drains")
	var at_turn := tank.capture_state()
	var low := tank.level
	tank.simulate_tick(ticks)
	tank.simulate_tick(ticks + 1)
	check(tank.turned() and tank.level > low and tank.flow == 1, "after the turn the tank fills")
	var after := tank.capture_state()
	tank.restore_state(at_turn)
	check(not tank.turned() and tank.level == low, "a restored frame is from before the turn")
	tank.simulate_tick(ticks)
	tank.simulate_tick(ticks + 1)
	check(tank.capture_state() == after, "and turns at the same tick again")
	var plain: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	check(not plain.capture_state().has("run") and not plain.turned(), "a tank without the setting keeps its old state")
	tank.free()
	plain.free()


# --- the jet (D161) -------------------------------------------------------------

## Button 1, the drain, then Shift with the heroine up on the start floor: the
## jet flies out of the sluice across the empty pool and hits the lever behind
## the bars; the lever stays on after the replay and opens the far gate, and
## both lamps turn green.
func test_level_02_the_jet_hits_the_lever_when_nothing_is_in_its_way() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var jet: ReverseJet = room.get_node("Jet")
	var lever: Lever = room.get_node("LeverJet")
	var gate_out: Door = room.get_node("GateOut")
	var lamp: LeverLamp = room.get_node("GateLamp")
	await _ticks(40)
	time.player_interact(room.get_node("Button1").global_position)
	var forward_jet := false
	for i in 200:
		await _ticks(1)
		forward_jet = forward_jet or jet.reach > 0.0
	check(not forward_jet, "forward the pool drains quietly: no jet")
	check(not lamp.is_on(), "the lamps are red before the hit")
	Input.action_press("rewind")
	var reached := false
	for i in 90:
		await _ticks(1)
		reached = reached or (jet.reach >= jet.length_px and not jet.blocked)
	Input.action_release("rewind")
	check(reached, "under Shift the jet flies the whole way to the bars")
	await _ticks(240)
	check(lever.on, "the jet switched the lever on, and it stays on forward")
	check(gate_out.open == Door.OPEN_MAX, "the lever opened the far gate: %d" % gate_out.open)
	check(lamp.is_on(), "the lamp over the gate is green")
	await _free(room)


## On the float, the heroine stands in the jet's way: it splashes on her and
## pushes her a little, and the lever stays off.
func test_level_02_the_heroine_on_the_float_blocks_the_jet() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var jet: ReverseJet = room.get_node("Jet")
	var lever: Lever = room.get_node("LeverJet")
	var player: Player = room.get_node("Player")
	var pool_1: Water = room.get_node("Pool1")
	await _ticks(40)
	time.player_interact(room.get_node("Button1").global_position)
	await _ticks(200)
	var float_top := _float_rect(pool_1, pool_1.level)
	player.respawn(Vector2(float_top.get_center().x + 16.0, float_top.position.y))
	await _ticks(20)
	var x_before := player.global_position.x
	Input.action_press("rewind")
	var was_blocked := false
	for i in 90:
		await _ticks(1)
		was_blocked = was_blocked or jet.blocked
	Input.action_release("rewind")
	check(was_blocked, "the jet stops on the heroine")
	check(not lever.on, "with the heroine in the way the lever stays off")
	check(player.global_position.x < x_before - 4.0, "the jet pushes her a little: %.1f -> %.1f" % [x_before, player.global_position.x])
	check(player.global_position.x > float_top.position.x, "but not off the float")
	await _free(room)


## The jet runs only under Shift, while the world moves back through a drain
## and the surface is below the mouth.
func test_reverse_jet_runs_only_back_through_a_drain() -> void:
	check(ReverseJet.runs(-1, true, -1, 700.0, 672.0), "Shift, moving, a drain played back, the surface below: runs")
	check(not ReverseJet.runs(1, true, -1, 700.0, 672.0), "forward: no jet")
	check(not ReverseJet.runs(-1, false, -1, 700.0, 672.0), "the world standing at its start: no jet")
	check(not ReverseJet.runs(-1, true, 1, 700.0, 672.0), "a fill played back is a drain, not a jet")
	check(not ReverseJet.runs(-1, true, -1, 600.0, 672.0), "the mouth under water: no jet")


## The lever stands behind the bars, out of the heroine's reach from the start
## floor and from the floor of pool 1.
func test_level_02_the_lever_is_out_of_reach() -> void:
	var room := await _load(LEVEL_PATH)
	var lever: Lever = room.get_node("LeverJet")
	var radius := float(lever.interaction_candidate()["radius"])
	var half := 22.0
	var nearest_pool := Vector2(5 * CELL + half, LOW_ROW * CELL)
	var nearest_floor := Vector2(lever.global_position.x, LINE_ROW * CELL)
	check(lever.global_position.distance_to(nearest_pool) > radius, "from pool 1's floor the lever is out of reach")
	check(lever.global_position.distance_to(nearest_floor) > radius, "from the start floor the lever is out of reach")
	var blocks: TileMapLayer = room.get_node("Blocks")
	check(blocks.get_cell_source_id(Vector2i(4, 11)) != -1, "the niche is solid behind the bars: she cannot walk in")
	await _free(room)


func test_reverse_jet_numbers_are_checked_in_objects_data() -> void:
	var data: Dictionary = Content.objects().duplicate(true)
	check(Content.validate_objects(data, Content.time()).is_empty(), "objects.json passes")
	for key: String in ["speed_px", "push_px_per_second", "thickness_px"]:
		var bad := data.duplicate(true)
		(bad["reverse_jet"] as Dictionary)[key] = 0
		check(not Content.validate_objects(bad, Content.time()).is_empty(), "reverse_jet.%s = 0 must be refused" % key)


# --- objects -------------------------------------------------------------------

func test_a_water_gate_follows_the_level_of_its_tank() -> void:
	var room := Node2D.new()
	_tree.root.add_child(room)
	var tank := Water.new()
	tank.object_id = "well"
	tank.size = Vector2(256, 768)
	tank.position = Vector2(0, 768)
	room.add_child(tank)
	var gate: WaterGate = (load("res://objects/water_gate.tscn") as PackedScene).instantiate()
	gate.apply_settings({"open_level": 500, "open_seconds": 1})
	gate.position = Vector2(400, 700)
	room.add_child(gate)
	tank.level = 501
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == 0 and not gate.powered, "one unit over the level the gate stays shut, open %d" % gate.open)
	tank.level = 500
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == Door.OPEN_MAX, "at the level the gate opens fully, open %d" % gate.open)
	tank.level = 4000
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == 0, "with the tank high again the gate closes, open %d" % gate.open)
	var state := gate.capture_state()
	check(state.has("powered") and int(state["open"]) == 0, "the gate's state is recorded like a door's")
	room.queue_free()
	await _tree.process_frame


## The near gate of level 02's tunnel the other way round: shut while the tank
## is full before its pump failed, open once it is full again after.
func test_a_water_gate_can_open_after_the_flood() -> void:
	var room := Node2D.new()
	_tree.root.add_child(room)
	var tank: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	tank.object_id = "tunnel"
	tank.apply_settings({"full_seconds": 2, "turn_after_seconds": 1})
	tank.level = Water.LEVEL_MAX
	tank.open_flow = -1
	room.add_child(tank)
	var gate: WaterGate = (load("res://objects/water_gate.tscn") as PackedScene).instantiate()
	gate.watch_id = "tunnel"
	gate.opens_after_flood = true
	gate.apply_settings({"open_level": 9500, "open_seconds": 1})
	room.add_child(gate)
	for i in 60:
		gate.simulate_tick(i)
	check(gate.open == 0, "full before the failure, the gate stays shut")
	tank.powered = true
	var opened_low := false
	for i in 400:
		tank.simulate_tick(i)
		gate.simulate_tick(i)
		if gate.open > 0 and tank.level < 9500:
			opened_low = true
	check(not opened_low, "the gate never opens with the tank low")
	check(tank.turned() and tank.level == Water.LEVEL_MAX and gate.open == Door.OPEN_MAX, "flooded again, the gate opens")
	room.queue_free()
	await _tree.process_frame


func test_button_sparks_are_decoration_that_reverses() -> void:
	var ticks := 60.0
	for i in ButtonSparks.COUNT:
		check(ButtonSparks.spark_at(i, 100, ticks) == ButtonSparks.spark_at(i, 100, ticks), "a spark depends on the tick alone")
	var moved := ButtonSparks.spark_at(0, 100, ticks) != ButtonSparks.spark_at(0, 110, ticks)
	check(moved, "the sparks move with the world tick")
	var period := int(round(ButtonSparks.PERIOD_SECONDS * ticks))
	check(ButtonSparks.spark_at(1, 40, ticks).is_equal_approx(ButtonSparks.spark_at(1, 40 + period, ticks)), "a spark repeats after one period")
	var highest := 0.0
	for tick in period:
		highest = minf(highest, ButtonSparks.spark_at(2, tick, ticks).y)
	check(highest < -20.0 and highest > -ButtonSparks.HEIGHT_PX - 1.0, "a spark jumps up, never above its height: %.1f" % highest)


# --- data ----------------------------------------------------------------------

func test_water_settings_of_a_level_are_checked_in_levels_data() -> void:
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x",
		"objects": {"well": {"full_seconds": 9, "outlet_inset_px": 352, "lifts_player": false, "turn_after_seconds": 7}, "gate": {"open_level": 500, "open_seconds": 2}}}
	check(Content.validate_levels([good], 20.0).is_empty(), "valid water settings must pass: %s" % [Content.validate_levels([good], 20.0)])
	for bad: Variant in [{"full_seconds": 0}, {"full_seconds": "fast"}, {"outlet_inset_px": -3}, {"outlet_inset_px": "left"}, {"lifts_player": "no"}, {"lifts_player": 0}, {"open_level": -1}, {"open_level": "low"}, {"open_level": 10001}, {"turn_after_seconds": 0}, {"turn_after_seconds": "soon"}]:
		var entry := good.duplicate(true)
		entry["objects"] = {"well": bad}
		check(not Content.validate_levels([entry], 20.0).is_empty(), "water settings %s must be refused" % [bad])
	var entry := Content.level_for_scene(LEVEL_PATH)
	check(float(entry["prelude_seconds"]) < float(Content.time()["history_seconds"]), "the prelude leaves room in the history for the hero's own time")


func test_water_applies_its_own_full_seconds() -> void:
	var fast: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	var slow: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	fast.apply_settings({"full_seconds": 4})
	slow.apply_settings({"full_seconds": 12, "outlet_inset_px": 200})
	check(fast.step() > slow.step() * 2, "a tank with fewer full_seconds runs faster: steps %d and %d" % [fast.step(), slow.step()])
	check(slow.look.outlet_inset_px == 200.0, "outlet_inset_px reaches the look")
	fast.free()
	slow.free()


# --- helpers ---------------------------------------------------------------

func _room_size(room: Node) -> Vector2i:
	var blocks: TileMapLayer = room.get_node("Blocks")
	return blocks.get_used_rect().size * blocks.tile_set.tile_size


func _float_rect(water: Water, level: int) -> Rect2:
	var float_body: WaterFloat = water.get_node("Float")
	return water.float_rect_at(float_body, level)


func _rewind_to_start(time: RoomTime) -> void:
	Input.action_press("rewind")
	var guard := 0
	while time.cursor() > 0 and guard < 2000:
		await _tree.physics_frame
		guard += 1
	await _ticks(5)


func _load(path: String) -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(path) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
	Input.action_release("move_right")
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
