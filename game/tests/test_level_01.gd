extends RefCounted
## Tests of what level 01 needs (task 2.5): a door that closes once, per-level
## object settings in levels.json, the room after its prelude and the exit.

const DOOR_PATH := "res://objects/door.tscn"
const PLATFORM_PATH := "res://objects/platform.tscn"
const LEVEL_PATH := "res://levels/level_01.tscn"
## How far right of the top of the flight the stair tests start: clear of the
## shutter beside it (half her 44 px hitbox and a little).
const STAIRS_TOP_FROM_EDGE := 28.0
const ONCE := {"cycle": "once", "hold_open_seconds": 1, "close_seconds": 5}

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_door_closes_once_and_stays_closed() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.apply_settings(ONCE)
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	check(door.open == Door.OPEN_MAX, "a door that runs once starts fully open, is %d" % door.open)
	for i in ticks - 1:
		door.simulate_tick(i)
	check(door.open == Door.OPEN_MAX, "the door stays open for hold_open_seconds, is %d" % door.open)
	var last := door.open
	var worst := 0
	for i in 5 * ticks + 1:
		door.simulate_tick(i)
		check(door.open <= last, "the door must only close, went from %d to %d" % [last, door.open])
		worst = maxi(worst, last - door.open)
		last = door.open
	check(door.open == 0, "the door is closed after close_seconds, is %d" % door.open)
	check(worst <= int(Content.time()["max_state_step"]), "the door jumps %d per tick" % worst)
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
	check(door.open == 0, "a door that runs once must never open again, is %d" % door.open)
	door.free()


func test_door_without_settings_still_loops() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	var opened := false
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
		opened = opened or door.open == Door.OPEN_MAX
	check(opened and not door.once, "a plain door keeps its cycle")
	door.free()


func test_platform_rides_once_and_stays() -> void:
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	platform.travel = Vector2(192, 0)
	platform.apply_settings({"cycle": "once", "speed": 96, "delay_seconds": 2})
	check(platform.once, "a platform with cycle 'once' must report it")
	var base := platform.position_at(0)
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	for i in 2 * ticks - 1:
		platform.simulate_tick(i)
	check(platform.position == base, "the platform waits at its start for delay_seconds, is at %s" % [platform.position])
	var last := platform.position
	var worst := 0.0
	for i in 2 * ticks + 1:
		platform.simulate_tick(i)
		worst = maxf(worst, platform.position.distance_to(last))
		check(platform.position.x >= last.x, "a platform that runs once must only ride forward")
		last = platform.position
	check(is_equal_approx(platform.position.x, base.x + 192.0), "the platform arrives at the end of its path, is at %s" % [platform.position])
	check(worst <= 96.0 / ticks + 0.01, "the platform moves %.2f px per tick, more than its speed" % worst)
	for i in platform.cycle_ticks() * 2:
		platform.simulate_tick(i)
	check(is_equal_approx(platform.position.x, base.x + 192.0), "a platform that runs once never comes back by itself")
	check(platform.position_at(platform.once_last_phase() - 1).x < base.x + 192.0, "the last tick before the arrival is still on the way")
	platform.free()


func test_platform_without_settings_still_loops() -> void:
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	platform.travel = Vector2(96, 0)
	var base := platform.position_at(0)
	var went_far := false
	for i in platform.cycle_ticks() + 1:
		platform.simulate_tick(i)
		went_far = went_far or is_equal_approx(platform.position.x, base.x + 96.0)
	check(went_far and not platform.once, "a plain platform keeps its round trip")
	check(platform.position.is_equal_approx(platform.position_at(1)), "after a whole cycle the platform is at the start again")
	platform.free()


func test_level_object_settings_are_checked() -> void:
	var entry := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "objects": {"door": ONCE}}
	check(Content.validate_levels([entry], 20.0).is_empty(), "good object settings must pass: %s" % [Content.validate_levels([entry], 20.0)])
	for bad: Variant in [[], {"door": 3}, {"door": {"cycle": "twice"}}, {"door": {"close_seconds": 0}}, {"door": {"close_seconds": "fast"}}, {"platform_1": {"speed": 0}}, {"platform_1": {"speed": "fast"}}, {"platform_2": {"delay_seconds": -1}}]:
		var broken := entry.duplicate(true)
		broken["objects"] = bad
		check(not Content.validate_levels([broken], 20.0).is_empty(), "object settings %s must be reported" % [bad])
	var objects: Dictionary = Content.objects().duplicate(true)
	objects.erase("exit_zone")
	check(not Content.validate_objects(objects, Content.time()).is_empty(), "objects.json without exit_zone must be reported")


func test_level_01_starts_with_the_door_half_closed_and_closing() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	check(door.open > 350 and door.open < 650, "after the prelude the door is about half closed, is %d" % door.open)
	var gap := door.travel * door.open / Door.OPEN_MAX
	check(gap < player.body_rect().size.y + 16.0, "the doorway (%.0f px) must already be too low to promise a run through" % gap)
	var before := door.open
	await _ticks(30)
	check(door.open < before, "the door keeps closing in front of the player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed 4.5 s after the start, is %d" % door.open)
	check(not bool(room.get("is_completed")), "standing still never completes the level")
	await _free(room)


func test_level_01_shift_opens_the_door_and_holds_it_open() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed before Shift")
	var start := player.global_position
	Input.action_press("rewind")
	var last := door.open
	for i in 9 * 60:
		await _ticks(1)
		check(door.open >= last, "under Shift the door must only open, went from %d to %d" % [last, door.open])
		last = door.open
	check(door.open == Door.OPEN_MAX, "at the start of the history the door is fully open, is %d" % door.open)
	await _ticks(120)
	check(door.open == Door.OPEN_MAX, "the door stays open while Shift is held")
	check(player.global_position.distance_to(start) < 1.0, "Shift must not move the player")
	Input.action_release("rewind")
	await _ticks(8 * 60)
	check(door.open == 0, "released Shift replays the closing (rule A), door is %d" % door.open)
	await _free(room)


func test_level_01_platform_1_has_left_and_platform_2_has_started_to_sink() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var first: MovingPlatform = room.get_node("Platform1")
	var second: MovingPlatform = room.get_node("Platform2")
	# The state comes from the phase: the body's own position lags a physics step.
	var start := first.position_at(0)
	var gap := first.position_at(first.phase).x - start.x
	check(gap > 100.0 and gap < first.travel.x, "after the prelude platform 1 is on its way, %.0f px from its start" % gap)
	var sunk := second.position_at(second.phase).y - second.position_at(0).y
	check(sunk > 0.0 and sunk < 3.0 * 64.0, "after the prelude platform 2 has started to sink but is still above platform 1's level, %.0f px down" % sunk)
	var jump_reach := float(Content.player()["walk_speed"]) * 2.0 * float(Content.player()["jump_velocity"]) / float(Content.player()["gravity"])
	check(player.global_position.x < start.x - 96.0, "the hero starts left of the pit, on the ground platform 1 has left")
	check(first.travel.x + 192.0 > jump_reach, "the pit is wider than a jump (%.0f px), so the platform is needed" % jump_reach)
	await _free(room)


## Platform 2 comes down to the level of platform 1's end at the very tick
## platform 1 arrives there, right beside it, and stops there (Artem's design,
## 24.11.2026): the only way onto it is from platform 1; from the floor of the
## pit it hangs too high to jump onto.
func test_level_01_platform_2_is_level_with_platform_1_when_it_arrives() -> void:
	var room := await _load()
	var first: MovingPlatform = room.get_node("Platform1")
	var second: MovingPlatform = room.get_node("Platform2")
	var arrival := first.once_last_phase()
	var first_end := first.position_at(arrival)
	var second_then := second.position_at(arrival)
	check(absf(second_then.y - first_end.y) < 1.0, "platform 2 is at y %.1f when platform 1 arrives at y %.1f" % [second_then.y, first_end.y])
	var width := float(((first.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.x)
	var between := (second_then.x - width / 2.0) - (first_end.x + width / 2.0)
	check(absf(between) < 1.0, "platform 2 stands %.1f px from the end of platform 1, it must be beside it" % between)
	var bottom := second.position_at(second.once_last_phase())
	check(absf(bottom.y - first_end.y) < 1.0, "platform 2 stops at platform 1's level, ends at y %.0f" % bottom.y)
	var params := Content.player()
	var jump_height := pow(float(params["jump_velocity"]), 2.0) / (2.0 * float(params["gravity"]))
	var pit_floor := 15.0 * 64.0
	var board := float(((second.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.y)
	var reach := pit_floor - (bottom.y - board / 2.0)
	check(reach > jump_height + 32.0, "from the pit floor platform 2 is out of reach: its top is %.0f px up, a jump %.0f px" % [reach, jump_height])
	# Down beside platform 1 it is two cells under the ledge (D138): only
	# rewinding lifts her up, a jump does not.
	var ledge_top := 8.0 * 64.0
	var climb := (bottom.y - board / 2.0) - ledge_top
	check(climb > jump_height + 16.0, "from platform 2 down below the ledge is out of a jump: %.0f px up, a jump %.0f px" % [climb, jump_height])
	check(second.position_at(arrival - 120).y < first_end.y - 64.0, "platform 2 is clearly above platform 1's level two seconds before")
	check(second.once and first.once, "both platforms of level 01 ride once")
	await _free(room)


## The level is wider than the screen and the camera may follow the hero over all
## of it (task 3.2, 16.11.2026).
func test_level_01_is_wider_than_one_screen_and_the_camera_follows() -> void:
	var room := await _load()
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := blocks.get_used_rect().size * blocks.tile_set.tile_size
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	# D112 (22.11.2026): the room was 1.5 screens wide while the world was
	# twice the heroine's size; sized to her it is a little over one screen.
	check(size.x > width and size.x <= 3 * width, "the room is %d px wide, the screen %d: it should be more than one screen, at most 3" % [size.x, width])
	check(size.y >= height and size.y < height + blocks.tile_set.tile_size.y, "the room is %d px tall, the screen %d" % [size.y, height])
	var camera: Camera2D = room.get_node("Player/Camera2D")
	check(camera.limit_right == size.x and camera.limit_left == 0, "the camera limits are %d..%d, the room is %d wide" % [camera.limit_left, camera.limit_right, size.x])
	await _free(room)


## The hero comes in from the doorway by himself: fades in, walks right, ignores
## the keys, then the level is his (task 3.2, 16.11.2026).
func test_level_01_hero_walks_in_and_then_is_free() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	var entrance := room.get_node("Entrance") as Node2D
	var frame := Rect2(entrance.position, entrance.get("size"))
	check(frame.has_point(spawn.global_position - Vector2(0, 10)), "the hero appears inside the entrance doorway")
	var entry := Content.level_for_scene(LEVEL_PATH)
	var expected := int(round(float(entry["intro_seconds"]) * float(Content.time()["physics_ticks_per_second"])))
	check(player.intro_ticks_left() > 0 and player.intro_ticks_left() <= expected, "the walk-in is running at the start, %d ticks left" % player.intro_ticks_left())
	check(player.modulate.a < 1.0, "the hero fades in")
	Input.action_press("move_left")
	await _ticks(20)
	check(player.global_position.x > spawn.global_position.x + 40.0, "during the walk-in the hero walks right whatever the keys say, x %.0f" % player.global_position.x)
	await _ticks(expected)
	Input.action_release("move_left")
	check(player.intro_ticks_left() == 0 and is_equal_approx(player.modulate.a, 1.0), "after the walk-in the hero is fully there and free")
	var after := player.global_position.x
	Input.action_press("move_left")
	await _ticks(20)
	Input.action_release("move_left")
	check(player.global_position.x < after - 40.0, "after the walk-in the keys steer the hero again")
	await _free(room)


## Stairs lead into the pit (D120): a slope no steeper than 40 degrees that she
## walks down and up step by step, without a jump and without leaving it.
func test_level_01_stairs_are_walked_down_and_up_without_a_jump() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var stairs := room.get_node_or_null("Stairs") as Stairs
	check(stairs != null, "level 01 has stairs into the pit")
	if stairs == null:
		await _free(room)
		return
	var flight := stairs.rect_px()
	check(rad_to_deg(atan(flight.size.y / flight.size.x)) <= 40.0, "the stairs are no steeper than 40 degrees")
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 5)
	# The shutter stands right at the top of the flight (D138): she starts on
	# the top tread beside it and climbs back up to it.
	var top_x := flight.position.x + STAIRS_TOP_FROM_EDGE
	player.global_position = Vector2(top_x, stairs.surface_y(top_x))
	player.velocity = Vector2.ZERO
	await _ticks(5)
	var trips := [["move_right", flight.end.x + 48.0], ["move_left", top_x + 8.0]]
	for trip: Array in trips:
		var action: String = trip[0]
		var goal: float = trip[1]
		var off_floor := 0
		var worst := 0.0
		var ticks := 0
		Input.action_press(action)
		while ticks < 4 * 60 and (player.global_position.x < goal if action == "move_right" else player.global_position.x > goal):
			await _ticks(1)
			ticks += 1
			if not player.is_on_floor():
				off_floor += 1
			var x := player.global_position.x
			if x > flight.position.x + 22.0 and x < flight.end.x - 22.0:
				worst = maxf(worst, absf(player.global_position.y - stairs.surface_y(x)))
		Input.action_release(action)
		check(ticks < 4 * 60, "%s: she gets across the stairs in time, at x %.0f" % [action, player.global_position.x])
		check(off_floor <= 2, "%s: she keeps to the stairs, %d ticks off the floor" % [action, off_floor])
		check(worst < 16.0, "%s: her feet stay on the slope, %.1f px at most" % [action, worst])
	check(player.is_on_floor() and absf(player.global_position.y - stairs.surface_y(player.global_position.x)) < 16.0, "back up, she stands on the top of the flight, at %s, the slope at %.1f" % [player.global_position, stairs.surface_y(player.global_position.x)])
	await _free(room)


## On a moving platform she stands (D120): the gait reads her own speed, not
## the platform's, so the ride does not make her run. Platform 1 has nearly
## arrived after the walk-in, so Shift rides it back.
func test_level_01_hero_stands_still_on_a_moving_platform() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var first: MovingPlatform = room.get_node("Platform1")
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 5)
	var top := first.rect_at(first.position_at(first.phase))
	player.global_position = Vector2(top.get_center().x, top.position.y)
	player.velocity = Vector2.ZERO
	await _ticks(10)
	var rig := player.rig()
	var start_x := player.global_position.x
	var walked := rig.distance()
	var running := 0
	Input.action_press("rewind")
	for i in 60:
		await _ticks(1)
		if rig.pose() != "idle":
			running += 1
	Input.action_release("rewind")
	var ridden := player.global_position.x - start_x
	check(player.is_on_floor() and absf(ridden) > 40.0, "she rides platform 1, %.0f px in a second" % ridden)
	check(running == 0, "riding without a key she stands, %d ticks not idle" % running)
	check(is_equal_approx(rig.distance(), walked), "riding does not advance her walk, %.1f px" % (rig.distance() - walked))
	await _free(room)


## On the stairs her feet stand on the treads (D120): no boot goes into a
## tread, one always stands on its tread, each step lands in the middle of a
## tread, and standing still both boots stand on their treads.
func test_level_01_hero_feet_stand_on_the_treads() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var stairs: Stairs = room.get_node("Stairs")
	var rig := player.rig()
	var flight := stairs.rect_px()
	var tread := stairs.tread_px()
	var legs: Array = HeroineData.load_data()["stairs"]["legs"]
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 5)
	# The shutter stands right at the top of the flight (D138): she starts on
	# the top tread beside it and climbs back up to it.
	var top_x := flight.position.x + STAIRS_TOP_FROM_EDGE
	player.global_position = Vector2(top_x, stairs.surface_y(top_x))
	player.velocity = Vector2.ZERO
	await _ticks(5)
	for action: String in ["move_right", "move_left"]:
		var goal := flight.end.x + 48.0 if action == "move_right" else top_x + 8.0
		var deepest := 0.0
		var hanging := 0.0
		var landings := 0
		var off_middle := 0
		var ticks := 0
		Input.action_press(action)
		while ticks < 4 * 60 and (player.global_position.x < goal if action == "move_right" else player.global_position.x > goal):
			await _ticks(1)
			ticks += 1
			var x := player.global_position.x
			if not player.is_on_floor() or x < flight.position.x + tread or x > flight.end.x - tread:
				continue
			var feet := _boots_on_treads(rig, stairs)
			deepest = maxf(deepest, maxf(feet["shin_near"]["sink"], feet["shin_far"]["sink"]))
			hanging = maxf(hanging, minf(feet["shin_near"]["gap"], feet["shin_far"]["gap"]))
			var phase := rig.run_phase()
			for i in 2:
				# Just after the landing of leg i: its foot is down.
				var since := wrapf(phase - 0.5 * float(i), -0.5, 0.5)
				if since < 0.0 or since > 0.035:
					continue
				var boot: Dictionary = feet[String(legs[i][1])]
				var from: float = boot["from"]
				var to: float = boot["to"]
				var column := floorf((from - flight.position.x) / tread)
				if column < 1.0 or column > float(stairs.step_count()) - 2.0:
					continue
				landings += 1
				var left := flight.position.x + column * tread
				if to > left + tread or from < left + 2.0 or to > left + tread - 2.0:
					off_middle += 1
		Input.action_release(action)
		check(ticks < 4 * 60, "%s: she gets across the stairs in time" % action)
		check(deepest <= 2.0, "%s: no boot goes into a tread, %.1f px at most" % [action, deepest])
		check(hanging <= 2.0, "%s: a boot always stands on its tread, the lower one hangs %.1f px at most" % [action, hanging])
		check(landings >= 3, "%s: she lands on the treads step by step, %d landings seen" % [action, landings])
		check(off_middle == 0, "%s: every step lands within a tread, %d of %d on an edge" % [action, off_middle, landings])
	# Standing in the middle of the flight, both boots stand on their treads.
	for offset in [0.0, tread * 0.3, tread * 0.6]:
		player.global_position = Vector2(flight.get_center().x + offset, flight.position.y)
		player.velocity = Vector2.ZERO
		await _ticks(30)
		var feet := _boots_on_treads(rig, stairs)
		for boot: String in feet:
			check(feet[boot]["sink"] <= 2.0 and feet[boot]["gap"] <= 2.0, "standing at +%.0f px, %s stands on its tread: %.1f px above, %.1f px into it" % [offset, boot, feet[boot]["gap"], feet[boot]["sink"]])
	await _free(room)


## The chain platform rides over the stairs (Artem 24.11): standing on it she
## stands on its board, the doll does not walk the treads under it; on the
## flight itself it does.
func test_level_01_hero_on_the_platform_over_the_stairs_is_not_on_the_stairs() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var stairs: Stairs = room.get_node("Stairs")
	var platform: Node2D = room.get_node("Platform1")
	var flight := Rect2(stairs.rect_px().position + stairs.global_position, stairs.rect_px().size)
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 5)
	player.global_position = Vector2(flight.get_center().x, flight.position.y)
	player.velocity = Vector2.ZERO
	await _ticks(30)
	check(not player._footing().is_empty(), "on the flight the doll stands on the treads")
	# The prelude has carried it past the flight: rewind it back over it.
	Input.action_press("rewind")
	var ticks := 0
	while ticks < 300 and platform.global_position.x > flight.position.x + 120.0:
		await _ticks(1)
		ticks += 1
	Input.action_release("rewind")
	player.global_position = platform.global_position + Vector2(0.0, -40.0)
	player.velocity = Vector2.ZERO
	await _ticks(20)
	check(platform.global_position.x > flight.position.x and platform.global_position.x < flight.end.x, "the platform is over the flight: %s in %s" % [platform.global_position, flight])
	check(player.is_on_floor() and player.global_position.y < platform.global_position.y, "she stands on the platform")
	check(player._footing().is_empty(), "on the platform the doll does not stand on the treads")
	await _free(room)


## Each boot against the treads under it: gap (its lowest point above the
## highest tread under it), sink (its deepest point into a tread), the room x
## of its sole from and to.
func _boots_on_treads(rig: HeroineRig, stairs: Stairs) -> Dictionary:
	var boots := {}
	var points: Dictionary = rig.sole_points()
	for boot: String in points:
		var lowest := -INF
		var top := INF
		var sink := -INF
		var from := INF
		var to := -INF
		for point: Vector2 in points[boot]:
			var at := rig.to_global(point)
			var tread_top := stairs.tread_y(at.x - stairs.global_position.x) + stairs.global_position.y
			lowest = maxf(lowest, at.y)
			top = minf(top, tread_top)
			sink = maxf(sink, at.y - tread_top)
			from = minf(from, at.x)
			to = maxf(to, at.x)
		boots[boot] = {"gap": top - lowest, "sink": sink, "from": from, "to": to}
	return boots


func test_level_01_reset_brings_the_hero_in_again() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 30)
	check(player.intro_ticks_left() == 0, "the first walk-in is over")
	room.call("restart")
	check(player.global_position.is_equal_approx(spawn.global_position) and player.intro_ticks_left() > 0, "a reset puts the hero back in the doorway and the walk-in starts again")
	await _free(room)


func test_intro_seconds_is_checked_in_levels_data() -> void:
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "intro_seconds": 1.5}
	check(Content.validate_levels([good], 20.0).is_empty(), "a valid intro_seconds must pass: %s" % [Content.validate_levels([good], 20.0)])
	for bad: Variant in [-1, "long", 11]:
		var entry := good.duplicate()
		entry["intro_seconds"] = bad
		check(not Content.validate_levels([entry], 20.0).is_empty(), "intro_seconds %s must be refused" % [bad])


func test_finish_level_needs_a_running_level() -> void:
	var loader := _tree.root.get_node_or_null("LevelLoader")
	check(loader != null, "LevelLoader autoload is missing")
	if loader != null:
		check(str(loader.get("current_id")).is_empty() and not bool(loader.call("finish_level")), "finish_level without a running level changes nothing")


## D82 (20.11.2026): the door and the entrance doorway are about 120 px next
## to the 94 px heroine, the door's body as tall as its doorway.
func test_level_01_door_is_about_120_px_and_she_fits_under_it() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var shape := (door.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(shape.size.y >= 110.0 and shape.size.y <= 140.0, "the door is %.0f px tall, it should be about 120" % shape.size.y)
	check(is_equal_approx(door.travel, shape.size.y), "the door opens by its own height")
	var player_shape := (room.get_node("Player/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(shape.size.y > player_shape.size.y, "the hero fits under the door")
	var entrance := room.get_node("Entrance") as Node2D
	var size: Vector2 = entrance.get("size")
	check(size.y >= 110.0 and size.y <= 140.0, "the entrance is %.0f px tall" % size.y)
	await _free(room)


## D83 (20.11.2026): the level opens on the whole room, then the camera comes
## close behind the heroine; the overview key shows the room again.
func test_level_01_camera_shows_the_room_then_comes_close() -> void:
	PlayerCamera.forget_zoom()
	var room := await _load()
	var camera: PlayerCamera = room.get_node("Player/Camera2D")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := Vector2(blocks.get_used_rect().size * blocks.tile_set.tile_size)
	var screen := Vector2(int(ProjectSettings.get_setting("display/window/size/viewport_width")), int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	check(camera.overview_amount() == 1.0, "the level starts on the whole room")
	check(size.x * camera.zoom.x <= screen.x + 1.0 and size.y * camera.zoom.y <= screen.y + 1.0, "the whole room fits on the screen, zoom %.2f" % camera.zoom.x)
	var params := Content.camera()
	var per_second := float(Content.time()["physics_ticks_per_second"])
	await _ticks(int((float(params["overview_start_seconds"]) + float(params["overview_blend_seconds"])) * per_second) + 5)
	check(camera.overview_amount() == 0.0, "after the start the camera is close")
	check(is_equal_approx(camera.zoom.x, float(params["zoom"])), "close zoom is %.2f, data says %.2f" % [camera.zoom.x, float(params["zoom"])])
	Input.action_press("overview")
	await _ticks(int(float(params["overview_blend_seconds"]) * per_second) + 2)
	check(camera.overview_amount() == 1.0, "holding the overview key shows the whole room")
	Input.action_release("overview")
	await _free(room)


## In the close view her feet stand low on the screen, not in its middle,
## so the frame is not half floor (Д5.1, Boris 20.11).
func test_camera_puts_her_feet_low_on_the_screen() -> void:
	var data := Content.camera()
	var feet := float(data["feet_screen_y"])
	check(feet > 0.6, "her feet must stand below the middle of the screen, at %.2f" % feet)
	var zoom := float(data["zoom"])
	var up := CameraView.focus_height(1080.0, zoom, feet)
	var feet_on_screen := 540.0 + up * zoom
	check(absf(feet_on_screen - feet * 1080.0) < 0.5, "the camera looks %.1f px above her feet, so they stand at %.0f of 1080" % [up, feet_on_screen])
	var broken: Dictionary = data.duplicate(true)
	broken["feet_screen_y"] = 0.3
	check(not Content.validate_camera(broken).is_empty(), "feet above the middle of the screen must be reported")


## The overview is centred on the room along the side where the screen sees
## more than the room (D83).
func test_camera_overview_math() -> void:
	var room := Rect2(0, 0, 3072, 1088)
	var screen := Vector2(1920, 1080)
	var zoom := CameraView.overview_zoom(room, screen, 2.0)
	check(is_equal_approx(zoom, 0.625), "a wide room fits by its width, zoom %.3f" % zoom)
	var limits := CameraView.limits(room, screen, zoom)
	check(limits.position.x == 0 and limits.end.x == 3072, "the width stays the room's")
	check(limits.position.y < 0 and absi(limits.position.y + limits.end.y - 1088) <= 1, "the height grows evenly on both ends")
	check(CameraView.limits(room, screen, 2.0) == Rect2i(room), "close up the limits are the room")
	check(is_equal_approx(CameraView.overview_zoom(Rect2(0, 0, 800, 400), screen, 2.0), 2.0), "a small room is never shown closer than the close view")
	check(is_equal_approx(CameraView.blend_zoom(2.0, 0.5, 0.5), 1.0), "half way the zoom is even in scale")
	check(not Content.validate_camera({}).is_empty() and Content.validate_camera({}).size() == Content.CAMERA_KEYS.size(), "an empty camera.json must report every key")
	var broken := Content.camera().duplicate()
	broken["zoom"] = 0.5
	check(not Content.validate_camera(broken).is_empty(), "a close zoom below 1 must be reported")
	broken = Content.camera().duplicate()
	broken["zoom_max"] = float(broken["zoom"]) - 0.5
	check(not Content.validate_camera(broken).is_empty(), "a closest view nearer than the start zoom must be reported")
	broken = Content.camera().duplicate()
	broken["zoom_step"] = 1.0
	check(not Content.validate_camera(broken).is_empty(), "a wheel step that does not change the zoom must be reported")


## D95 (21.11.2026): a wheel step multiplies the zoom, which stays between the
## whole room and the closest view; the camera slides to it evenly.
func test_camera_wheel_zoom_math() -> void:
	check(is_equal_approx(CameraView.step_zoom(2.0, 1.0, 0.6, 3.0, 1.2), 2.4), "one step in multiplies by the step")
	check(is_equal_approx(CameraView.step_zoom(2.4, -1.0, 0.6, 3.0, 1.2), 2.0), "one step out undoes it")
	check(is_equal_approx(CameraView.step_zoom(2.9, 3.0, 0.6, 3.0, 1.2), 3.0), "never closer than the closest view")
	check(is_equal_approx(CameraView.step_zoom(0.7, -3.0, 0.6, 3.0, 1.2), 0.6), "never farther than the whole room")
	check(is_equal_approx(CameraView.step_zoom(2.0, -5.0, 4.0, 3.0, 1.2), 3.0), "a room smaller than the closest view keeps the closest view")
	var z := 1.0
	for i in 60:
		var next := CameraView.ease_zoom(z, 3.0, 10.0, 1.0 / 60.0)
		check(next >= z and next <= 3.0, "the zoom slides towards the chosen one without overshooting")
		z = next
	check(absf(z - 3.0) < 0.01, "after a second it is there, %.3f" % z)


## D95: the mouse wheel moves the close view between the whole room and
## zoom_max, and the next level starts at the chosen zoom.
func test_level_01_wheel_zooms_and_is_remembered() -> void:
	PlayerCamera.forget_zoom()
	var params := Content.camera()
	var per_second := float(Content.time()["physics_ticks_per_second"])
	var room := await _load()
	var camera: PlayerCamera = room.get_node("Player/Camera2D")
	check(is_equal_approx(camera.chosen_zoom(), float(params["zoom"])), "the level starts at the data zoom")
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	check(camera.overview_amount() == 1.0 and is_equal_approx(camera.chosen_zoom(), float(params["zoom"]) * float(params["zoom_step"])), "one wheel step up comes one step closer, %.2f" % camera.chosen_zoom())
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(camera.chosen_zoom(), float(params["zoom_max"])), "the wheel stops at zoom_max")
	await _ticks(int((float(params["overview_blend_seconds"]) + 1.0) * per_second))
	check(camera.overview_amount() == 0.0, "the wheel ends the start overview")
	check(absf(camera.zoom.x - float(params["zoom_max"])) < 0.01, "the camera has slid to the chosen zoom, %.2f" % camera.zoom.x)
	for i in 60:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(camera.chosen_zoom(), camera.far_zoom()) and camera.far_zoom() < 1.0, "the wheel stops at the whole room, %.2f" % camera.chosen_zoom())
	await _ticks(int(per_second))
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := Vector2(blocks.get_used_rect().size * blocks.tile_set.tile_size)
	check(size.x * camera.zoom.x <= 1921.0 and size.y * camera.zoom.y <= 1081.0, "zoomed all the way out the whole room is on the screen")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_EQUAL
	key.pressed = true
	_tree.root.push_input(key)
	var chosen := camera.chosen_zoom()
	check(chosen > camera.far_zoom(), "the = key comes closer too")
	await _free(room)
	room = await _load()
	camera = room.get_node("Player/Camera2D")
	check(is_equal_approx(camera.chosen_zoom(), chosen), "the next level starts at the chosen zoom, %.2f, not the data's" % camera.chosen_zoom())
	await _free(room)
	PlayerCamera.forget_zoom()


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	_tree.root.push_input(event)


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


func test_level_01_shutter_wheel_turns_with_the_recorded_door() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	check(door.housing_height > 0.0, "the shutter of level 01 hangs under a brick housing")
	check(door.z_index > 0, "the housing is drawn over the room's ground")
	var turns := ObjectLook.number(ObjectLook.of("shutter"), "wheel_turns", 0.0)
	await _ticks(1)
	var housing := door.position + door.housing_rect().position
	var last := door.wheel_angle()
	for i in 3 * 60:
		await _ticks(1)
		check(is_equal_approx(door.wheel_angle(), door.mech_fraction() * turns * TAU), "the wheel turns by the recorded open")
		check(door.wheel_angle() <= last + 0.0001, "the wheel turns back while the shutter closes")
		last = door.wheel_angle()
		check((door.position + door.housing_rect().position).distance_to(housing) < 0.01, "the housing stays where it is")
	Input.action_press("rewind")
	await _ticks(5 * 60)
	check(door.wheel_angle() > last, "under Shift the wheel turns the other way with the shutter")
	await _free(room)


func test_level_01_platforms_ride_on_their_tracks() -> void:
	var room := await _load()
	var one: MovingPlatform = room.get_node("Platform1")
	var two: MovingPlatform = room.get_node("Platform2")
	check(one.track == "chain" and two.track == "rack", "platform 1 rides a chain, platform 2 a toothed column")
	check(ObjectLook.picture("platform") != null, "the plank picture of the kit loads")
	await _ticks(2 * 60)
	var r := ObjectLook.number(ObjectLook.of("platform"), "gear_px", 0.0) / 2.0
	check(one.mech_travel() > 0.0 and is_equal_approx(one.gear_angle(), one.mech_travel() / r),
			"the drums turn by the recorded travel")
	await _free(room)


func test_level_01_exit_door_opens_on_the_ledge_and_then_lets_her_out() -> void:
	var room := await _load()
	var zone: ExitZone = room.get_node("Exit")
	var door: ExitDoor = room.get_node("Exit/ExitDoor")
	var player: Player = room.get_node("Player")
	# After her walk-in: from then on she stands where she is put.
	await _ticks(60)
	check(door.elapsed < 0.0, "the exit door is shut while she is far from it")
	player.global_position = zone.global_position + Vector2(0.0, zone.size.y / 2.0)
	await _ticks(3)
	check(door.elapsed >= 0.0, "the exit door starts to open when she stands on the ledge")
	check(not bool(room.get("is_completed")), "a shut door does not let her out")
	Input.action_press("rewind")
	await _ticks(int(ceil(door.open_seconds() * 60.0)) + 5)
	check(door.is_open(), "the exit door opens under Shift too: it is not a temporal object")
	check(door.wheel_turns_done() == ObjectLook.number(ObjectLook.of("exit_door"), "wheel_turns", 0.0),
			"the wheel made its turns")
	check(bool(room.get("is_completed")), "standing in the open doorway she is out")
	await _free(room)


func test_level_01_clock_and_beacon_run_by_world_time() -> void:
	var room := await _load()
	var time: RoomTime = room.get_node("RoomTime")
	var clock: WallClock = room.get_node("Clock")
	var beacon: Beacon = room.get_node("Exit/Beacon")
	var turn := ObjectLook.number(ObjectLook.of("clock"), "minute_turn_seconds", 0.0)
	check(is_equal_approx(clock.minute_angle(turn) - clock.minute_angle(0.0), TAU), "the minute hand turns once in minute_turn_seconds")
	await _ticks(2 * 60)
	var ahead := time.world_seconds()
	check(ahead > 1.0, "world time runs forward, is %.2f" % ahead)
	Input.action_press("rewind")
	await _ticks(60)
	check(time.world_seconds() < ahead, "under Shift world time and the clock's hands go back")
	await _ticks(20 * 60)
	var still := time.world_seconds()
	await _ticks(30)
	check(time.world_seconds() == still, "at frame 0 the clock and the beacon stand")
	check(beacon.facing(still) >= 0.0 and beacon.facing(still) <= 1.0, "the beacon's pulse is 0 to 1")
	await _free(room)


func test_kit_objects_data_is_checked() -> void:
	check(Content.validate_kit_objects(Content.look().get("kit_objects")).is_empty(), "kit_objects of look.json passes the check")
	var broken := (Content.look()["kit_objects"] as Dictionary).duplicate(true)
	broken["shutter"]["blade_region"] = [0, 0, 64]
	broken["clock"]["minute_turn_seconds"] = 0
	broken["beacon"]["color"] = "red-ish"
	broken["exit_door"].erase("wheel_turns")
	check(Content.validate_kit_objects(broken).size() == 4, "a broken region, a zero, a bad colour and a missing key are caught: %s" % [Content.validate_kit_objects(broken)])


func test_quake_plan_finds_quakes_and_repeats() -> void:
	var plan := QuakePlan.from_data({"list": [{"second": 6, "strength": 0.4}, {"second": 14, "strength": 1}],
		"repeat_every_seconds": 13, "repeat_strength": 0.3,
		"falls": [{"kind": "lamp", "lamp": 3, "quake": 2, "delay_seconds": 0.5, "to_row": 12}]}, 10.0)
	check(plan.index_at(59) == -1 and plan.index_at(60) == 0 and plan.index_at(139) == 0, "the first quake starts on its tick")
	check(plan.index_at(140) == 1 and plan.index_at(269) == 1 and plan.index_at(270) == 2, "after the last one listed they repeat")
	check(plan.start_tick(3) == 400 and is_equal_approx(plan.strength(3), 0.3), "a repeat starts 13 s after the one before, as weak as repeat_strength")
	var fall: Dictionary = plan.falls[0]
	check(int(fall["lamp"]) == 2 and int(fall["quake"]) == 1 and int(fall["delay"]) == 5, "falls count from 0, delays in ticks")
	check(plan.fall_elapsed(fall, 0, 30, 99) == -1 and plan.fall_elapsed(fall, 1, 3, 99) == -1, "nothing falls before its quake and its delay")
	check(plan.fall_elapsed(fall, 1, 12, 99) == 7 and plan.fall_elapsed(fall, 2, 0, 99) == 99, "it falls after the delay and lies after a later quake")


func test_quake_data_is_checked() -> void:
	check(Content.validate().is_empty(), "levels.json with quakes passes the check: %s" % [Content.validate()])
	var broken := {"list": [{"second": 14, "strength": 1}, {"second": 6, "strength": 2}], "repeat_every_seconds": -1,
		"falls": [{"kind": "lamp", "lamp": 9, "quake": 1, "to_row": 12}, {"kind": "rock", "quake": 3}]}
	var problems := QuakePlan.problems(broken, "level_x", 6)
	# Late second, strength 2, negative repeat, lamp 9, kind rock, quake 3, no to_row.
	check(problems.size() == 7, "seven problems are caught: %s" % [problems])


func test_level_01_quake_drops_the_lamp_and_shift_lifts_it_back_without_a_jump() -> void:
	var room := await _load()
	var time: RoomTime = room.get_node("RoomTime")
	var quakes: Quakes = room.get_node("Quakes")
	var light: WorldLight = room.get_node("WorldLight")
	var lamp := 2
	check(quakes.lamp_fall(lamp).get("drop") == 0.0, "at the start the third lamp hangs")
	var shook := false
	while time.world_seconds() < 6.4:
		await _ticks(1)
		shook = shook or quakes.shake_amount() > 0.0
	check(shook and quakes.lamp_fall(lamp)["drop"] == 0.0, "the weak quake at 6 s shakes the room but drops nothing")
	var lit := light.lights[lamp].energy
	var drops: Array[float] = []
	while time.world_seconds() < 16.5:
		await _ticks(1)
		drops.append(float(quakes.lamp_fall(lamp)["drop"]))
	check(quakes.lamp_fall(lamp)["drop"] == 1.0 and quakes.lamp_fall(lamp)["shatter"] == 1.0, "after 14 s the lamp lies broken on the floor")
	check(light.lights[lamp].energy < 0.001 and lit > 0.0, "and its island of light is gone")
	check(_largest_step(drops) < 0.2, "it falls without a jump, largest step %.2f" % _largest_step(drops))
	Input.action_press("rewind")
	var back: Array[float] = []
	while time.world_seconds() > 12.0:
		await _ticks(1)
		back.append(float(quakes.lamp_fall(lamp)["drop"]))
	check(back.size() > 20 and _largest_step(back) < 0.2, "under Shift it flies back up without a jump, largest step %.2f" % _largest_step(back))
	check(quakes.lamp_fall(lamp)["drop"] == 0.0 and light.lights[lamp].energy > 0.0, "before 14 s it hangs and shines again")
	Input.action_release("rewind")
	while time.world_seconds() < 16.5:
		await _ticks(1)
	check(quakes.lamp_fall(lamp)["drop"] == 1.0, "released, the recorded quake drops it again (rule A)")
	await _free(room)


func _largest_step(values: Array[float]) -> float:
	var largest := 0.0
	for i in range(1, values.size()):
		largest = maxf(largest, absf(values[i] - values[i - 1]))
	return largest


func test_level_01_world_timer_and_sparking_wire() -> void:
	check(WorldTimer.text_of(14.23) == "WORLD 00:14.2" and WorldTimer.text_of(75.0) == "WORLD 01:15.0", "the timer reads WORLD mm:ss.t")
	check(WorldTimer.text_of(-1.0) == "WORLD 00:00.0", "it never shows less than zero")
	var room := await _load()
	var time: RoomTime = room.get_node("RoomTime")
	var timer: WorldTimer = room.get_node("WorldTimer")
	await _ticks(90)
	check(timer.label.text == WorldTimer.text_of(time.world_seconds()), "the timer shows the room's world time: %s" % timer.label.text)
	var wire: SparkingWire = room.get_node("SparkingWire")
	check(wire.sparks != null and wire.sparks.preset == "sparks", "the torn wire sparks with the sparks preset")
	await _free(room)
