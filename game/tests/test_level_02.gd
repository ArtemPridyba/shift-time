extends RefCounted
## Tests of level 02 «Поток», rebuilt 24.11.2026 after Artem's sketch (D150,
## card docs/levels/02.md): the height and the look of level 01; button 1 runs
## pool 1 into pool 2 through a sluice; the float of pool 1 carries the heroine
## up to the wall under Shift and the float of pool 2 up to the right floor on
## the replay (rule «А»); button 2 starts the tunnel's drain, its pump fails and
## floods the tunnel again, and only then the near gate opens, so the tunnel is
## crossed only with Shift. The solutions (with Shift, without it, swimming the
## flooded tunnel, running in during the drain) are in `tests/solutions/` and
## run by test_solutions.gd. Between the pools and the tunnel (D169, D171):
## the pipe from pool 2 has no valve, so the full pool gushes into the pit;
## the heroine takes the handwheel from the empty pool under Shift, carries it
## back to before the gush and puts it on, and the pressure opens the door at
## the bottom of the dry pit.

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
	check(blocks.get_cell_source_id(Vector2i(53, 11)) != -1 and blocks.get_cell_source_id(Vector2i(53, 12)) == -1, "over the tunnel's floor the rock comes down to the brim")
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
			check((room.get_node("Button2Fault") as FaultFx).active(), "when the pump fails the breakdown shows at the button")
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


# --- the pipe and its valve (D169, D171) ------------------------------------------

## The valve is missing from the start: the open pipe shakes while pool 2
## fills, then gushes into the pit; the door stays shut and the gauge low.
func test_level_02_the_open_pipe_floods_the_pit() -> void:
	var room := await _load(LEVEL_PATH)
	var pipe: BurstPipe = room.get_node("Pipe")
	var valve: PipePlug = room.get_node("Plug")
	var pit: Water = room.get_node("Pit")
	var door: Door = room.get_node("PitDoor")
	check(not valve.seated and pit.level == 0, "at the start the flange is open and the pit is dry")
	check(absf(valve.global_position.y - POOL_2_FLOOR_ROW * CELL) < 4.0 and valve.global_position.x > 16 * CELL \
		and valve.global_position.x < 22 * CELL, "the handwheel lies on the bottom of pool 2: %s" % valve.global_position)
	var shook := false
	await _press_button_1(room)
	for i in 500:
		await _ticks(1)
		shook = shook or pipe.shaking()
		if pit.level == Water.LEVEL_MAX:
			break
	check(shook, "while the pool fills, the open pipe shakes")
	check(pit.level == Water.LEVEL_MAX, "the water from the open flange floods the pit: %d" % pit.level)
	check(door.open == 0, "the door at the bottom of the flooded pit stays shut")
	check(pipe.pressure() < 0.5, "without the valve the gauge stays low: %.2f" % pipe.pressure())
	await _free(room)


## Taking the handwheel under Shift is no interference (D171): the world keeps
## the press of button 1, and on release pool 2 fills again with the wheel in
## her hands.
func test_level_02_taking_the_valve_under_shift_keeps_the_history() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var valve: PipePlug = room.get_node("Plug")
	var pool_2: Water = room.get_node("Pool2")
	var player: Player = room.get_node("Player")
	await _press_button_1(room)
	await _ticks(300)
	check(pool_2.level == Water.LEVEL_MAX, "pool 2 is full")
	Input.action_press("rewind")
	for i in 600:
		await _ticks(1)
		if time.cursor() == 0:
			break
	check(pool_2.level == 0, "Shift empties pool 2")
	player.respawn(Vector2(valve.global_position.x - 20.0, POOL_2_FLOOR_ROW * CELL))
	await _ticks(10)
	time.player_interact(player.global_position)
	check(valve.held, "E on the bottom of the empty pool picks the handwheel up")
	Input.action_release("rewind")
	await _ticks(330)
	check(pool_2.level == Water.LEVEL_MAX, "the press is still in the history: the pool fills again: %d" % pool_2.level)
	check(valve.held, "the handwheel stays in her hands")
	await _free(room)


## The handwheel in her hands stays with her while Shift takes the world to
## before the gush; put on there, it holds: a new branch with a dry pit and
## the door opened by the pressure.
func test_level_02_the_valve_carried_into_the_past_holds() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var pipe: BurstPipe = room.get_node("Pipe")
	var valve: PipePlug = room.get_node("Plug")
	var pit: Water = room.get_node("Pit")
	var door: Door = room.get_node("PitDoor")
	var player: Player = room.get_node("Player")
	await _take_valve_and_flood(room)
	player.respawn(_by_the_hole())
	await _ticks(40)
	Input.action_press("rewind")
	var stayed := true
	for i in 600:
		await _ticks(1)
		stayed = stayed and valve.held and valve.global_position.distance_to(player.global_position) < 80.0
		if not pipe.leaking() and pit.level == 0:
			break
	check(not pipe.leaking() and pit.level == 0, "Shift takes the world to before the gush")
	check(stayed, "the handwheel stays in her hands all the way back")
	time.player_interact(player.global_position)
	check(valve.seated and valve.firm and not valve.held, "E by the flange puts the valve on, firmly")
	Input.action_release("rewind")
	for i in 400:
		await _ticks(1)
	check(not pipe.leaking() and pit.level <= 300, "in the new branch the pipe holds and the pit stays dry: %d" % pit.level)
	check(pipe.pressure() > 0.95, "the gauge shows the full pool")
	check(door.open == Door.OPEN_MAX, "the pressure of the full pool opens the door: %d" % door.open)
	await _free(room)


## Artem's playtest (25.11): Shift held all the way to frame 0, before the
## press of button 1, and the valve put on there. That cuts nothing (D171):
## the world replays the press, pool 2 fills, the pipe holds, the door opens.
func test_level_02_the_valve_put_on_at_frame_0_keeps_the_press() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var pipe: BurstPipe = room.get_node("Pipe")
	var valve: PipePlug = room.get_node("Plug")
	var pool_2: Water = room.get_node("Pool2")
	var pit: Water = room.get_node("Pit")
	var door: Door = room.get_node("PitDoor")
	var player: Player = room.get_node("Player")
	await _take_valve_and_flood(room)
	player.respawn(_by_the_hole())
	await _ticks(40)
	Input.action_press("rewind")
	for i in 900:
		await _ticks(1)
		if time.cursor() == 0:
			break
	check(time.cursor() == 0 and pool_2.level == 0, "Shift reaches the first frame, before the press")
	time.player_interact(player.global_position)
	check(valve.seated and valve.firm, "E by the flange puts the valve on at frame 0")
	await _ticks(20)
	Input.action_release("rewind")
	var leaked := false
	for i in 500:
		await _ticks(1)
		leaked = leaked or pipe.leaking() or pit.level > 300
	check(pool_2.level == Water.LEVEL_MAX, "the press is replayed: pool 2 fills: %d" % pool_2.level)
	check(not leaked, "no water gushes into the pit")
	check(door.open == Door.OPEN_MAX, "the pressure opens the door: %d" % door.open)
	await _free(room)


## Put on after the gush, without Shift: the leak stops but the pit stays
## full and the door shut; E takes the valve off again to try once more.
func test_level_02_the_valve_put_on_late_leaves_the_pit_full() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var valve: PipePlug = room.get_node("Plug")
	var pit: Water = room.get_node("Pit")
	var door: Door = room.get_node("PitDoor")
	var player: Player = room.get_node("Player")
	await _take_valve_and_flood(room)
	player.respawn(_by_the_hole())
	await _ticks(5)
	time.player_interact(player.global_position)
	check(valve.seated and valve.firm, "the valve is on")
	await _ticks(5)
	var level := pit.level
	await _ticks(240)
	check(level > 3000 and pit.level == level and pit.flow == 0, "the leak stops, the water stays: %d -> %d" % [level, pit.level])
	check(door.open == 0, "the door at the bottom of the full pit stays shut")
	time.player_interact(player.global_position)
	check(valve.held and not valve.seated, "E takes the valve off again")
	await _free(room)


## No way round the valve: Shift alone, all the way back to the first frame,
## never opens the door (it needs the pressure of the full pool).
func test_level_02_shift_alone_never_opens_the_pit_door() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("PitDoor")
	await _press_button_1(room)
	var opened := false
	for i in 400:
		await _ticks(1)
		opened = opened or door.open > 0
	Input.action_press("rewind")
	for i in 600:
		await _ticks(1)
		opened = opened or door.open > 0
		if time.cursor() == 0:
			break
	Input.action_release("rewind")
	check(time.cursor() == 0, "Shift reaches the first frame")
	check(not opened, "the door never opened, forward or back")
	await _free(room)


## E away from the flange puts the handwheel down where she stands; under
## Shift and on the replay it stays there, never jumping back to an old place.
func test_level_02_a_dropped_valve_stays_where_it_was_let_go() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var valve: PipePlug = room.get_node("Plug")
	var player: Player = room.get_node("Player")
	await _take_valve_and_flood(room)
	player.respawn(Vector2(27.5 * CELL, LOW_ROW * CELL))
	await _ticks(20)
	Input.action_press("rewind")
	await _ticks(60)
	time.player_interact(player.global_position)
	check(not valve.held, "E away from the flange puts the valve down, under Shift too")
	await _ticks(30)
	var at := valve.global_position
	check(absf(at.x - player.global_position.x) < 64.0, "it lies by her feet")
	await _ticks(60)
	check(valve.global_position.distance_to(at) < 2.0, "under Shift it stays there: %s -> %s" % [at, valve.global_position])
	Input.action_release("rewind")
	await _ticks(120)
	check(valve.global_position.distance_to(at) < 2.0, "on the replay it stays there: %s -> %s" % [at, valve.global_position])
	await _free(room)


func test_pipe_numbers_are_checked_in_data() -> void:
	var data: Dictionary = Content.objects().duplicate(true)
	for key: String in ["interact_radius_px", "insert_radius_px", "gravity", "max_fall_speed", "friction_px", "follow_px"]:
		var bad := data.duplicate(true)
		(bad["pipe_plug"] as Dictionary)[key] = 0
		check(not Content.validate_objects(bad, Content.time()).is_empty(), "pipe_plug.%s = 0 must be refused" % key)
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "objects": {"pipe": {"leak_level": 9000, "door_level": 9800}}}
	check(Content.validate_levels([good], 20.0).is_empty(), "valid pipe levels pass")
	for bad_level: Variant in [-1, 10001, "high"]:
		var entry := good.duplicate(true)
		entry["objects"] = {"pipe": {"leak_level": bad_level}}
		check(not Content.validate_levels([entry], 20.0).is_empty(), "leak_level %s must be refused" % [bad_level])


func _press_button_1(room: Node) -> void:
	var time: RoomTime = room.get_node("RoomTime")
	await _ticks(40)
	time.player_interact(room.get_node("Button1").global_position)


## The heroine takes the handwheel from the empty pool at the start (at the
## head: no Shift needed in a test), presses button 1 and waits for the gush.
func _take_valve_and_flood(room: Node) -> void:
	var time: RoomTime = room.get_node("RoomTime")
	var valve: PipePlug = room.get_node("Plug")
	var pit: Water = room.get_node("Pit")
	var player: Player = room.get_node("Player")
	await _ticks(20)
	player.respawn(Vector2(valve.global_position.x - 20.0, POOL_2_FLOOR_ROW * CELL))
	await _ticks(10)
	time.player_interact(player.global_position)
	check(valve.held, "E picks the handwheel up")
	await _press_button_1(room)
	for i in 500:
		await _ticks(1)
		if pit.level > 4000:
			break
	await _ticks(60)


## Where she stands to reach the hole: the edge of the floor over the pit.
func _by_the_hole() -> Vector2:
	return Vector2(31.55 * CELL, LOW_ROW * CELL)


# --- the breakdown of the pump (25.11 notes) ------------------------------------

## Button 2 starts the pump in the room over the tunnel: its fan turns; when
## the pump fails, real sparks (the preset of the torn wire) and smoke come
## out at the button, the panel and the motor, the lamps over them stutter and
## the fan stops; under Shift all of it goes back before the failure.
func test_level_02_the_pump_breaks_down_with_sparks_smoke_and_lamps() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var tunnel: Water = room.get_node("Tunnel")
	var pumps: PumpRoom = room.get_node("PumpRoom")
	var button_fault: FaultFx = room.get_node("Button2Fault")
	var panel_fault: FaultFx = room.get_node("PanelFault")
	var motor_fault: FaultFx = room.get_node("MotorFault")
	check(button_fault.spark_particles.preset == "sparks" and button_fault.smoke_particles.preset == "smoke", "the button's breakdown uses the sparks and smoke presets")
	check(panel_fault.spark_particles != null and motor_fault.smoke_particles != null, "the panel sparks, the motor smokes")
	await _ticks(20)
	check(not button_fault.spark_particles.visible and not motor_fault.smoke_particles.visible, "before the press nothing sparks or smokes")
	time.player_interact(room.get_node("Button2").global_position)
	await _ticks(60)
	check(pumps.running() and pumps.fan_angle() > 0.0, "the pump runs, its fan turns")
	check(button_fault.lamp_factor(5) == 1.0, "the lamp burns steadily while the pump runs")
	for i in 600:
		await _ticks(1)
		if tunnel.fault_seconds() > 1.0:
			break
	check(tunnel.turned() and not pumps.running() and pumps.failed(), "the pump has failed")
	var angle := pumps.fan_angle()
	await _ticks(30)
	check(is_equal_approx(pumps.fan_angle(), angle), "the fan stands after the failure")
	check(button_fault.spark_particles.visible and button_fault.spark_particles.alive_count() > 0 \
		or button_fault.smoke_particles.alive_count() > 0, "sparks or smoke come out at the button")
	check(motor_fault.smoke_particles.visible and motor_fault.smoke_particles.alive_count() > 0, "the motor smokes")
	var dark := 0
	for k in 40:
		if FaultFx.blink(float(k) / 20.0, ObjectLook.of("fault"), 5) < 1.0:
			dark += 1
	check(dark > 5 and dark < 35, "the lamp stutters: dark in %d of 40 steps" % dark)
	check(button_fault.lamp_factor(0) == 1.0, "lamps away from the breakdown keep burning")
	Input.action_press("rewind")
	for i in 600:
		await _ticks(1)
		if not tunnel.turned():
			break
	Input.action_release("rewind")
	check(not tunnel.turned() and not motor_fault.smoke_particles.visible and button_fault.lamp_factor(5) == 1.0, "under Shift the breakdown goes back")
	await _free(room)


## Smoke of a breakdown starts empty: at the first moment there is none, a
## second later some, and the same second always looks the same.
func test_smoke_of_a_breakdown_starts_empty() -> void:
	var field := ParticleField.from_preset(Content.look_particles()["smoke"], 5)
	field.starts_empty = true
	check(field.sample(0.0).size() <= ParticleField.STRIDE, "no smoke at the moment of the failure")
	check(field.sample(1.0).size() > 4 * ParticleField.STRIDE, "a second later it smokes")
	check(field.sample(1.0) == field.sample(1.0), "smoke is a function of the seconds")
	field.starts_empty = false
	check(field.sample(0.0).size() > 4 * ParticleField.STRIDE, "a stream that has always run is full at 0")


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
