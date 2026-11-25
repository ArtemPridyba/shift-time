extends RefCounted
## Tests of level 03 «Interference» (card docs/levels/03.md, D155). Part 1:
## fire runs along the six zones of a bridge; at the fifth a sensor opens the
## sprinklers, and the rain puts out the rest of the bridge and the torch in
## its holder. Under Shift at frame 0 the burning torch is taken and the alarm
## pulled; the torch thrust into the barricade burns the way open. Part 2:
## the rope burns with the barricade and the ramp falls across the gap; the
## reverse flamethrower sucks the fire of the oil in and lights the crates
## under Shift; walking through burning oil is death. Also the
## latch platform and the door that opens once (D103), and the sprinkler with
## its start and its pipe from the earlier level 03.

const PLATFORM_PATH := "res://objects/platform.tscn"
const DOOR_PATH := "res://objects/door.tscn"
const LEVEL_PATH := "res://levels/level_03.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_latch_holds_a_platform_only_at_its_start() -> void:
	var held: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	held.holdable = true
	held.travel = Vector2(-192, 0)
	held.apply_settings({"cycle": "once", "speed": 192, "delay_seconds": 0.5})
	var base := held.position_at(0)
	held.powered = true
	for i in 5 * 60:
		held.simulate_tick(i)
	check(held.position == base, "a latched platform stays at its start, is at %s" % [held.position])
	check(held.capture_state().get("powered", false) == true, "a holdable platform records its latch")
	held.powered = false
	for i in 5 * 60:
		held.simulate_tick(i)
	check(is_equal_approx(held.position.x, base.x - 192.0), "a released platform rides on, is at %s" % [held.position])
	held.free()

	var late: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	late.holdable = true
	late.travel = Vector2(-192, 0)
	late.apply_settings({"cycle": "once", "speed": 192, "delay_seconds": 0.5})
	for i in late.once_last_phase() - 5:
		late.simulate_tick(i)
	late.powered = true
	for i in 60:
		late.simulate_tick(i)
	check(is_equal_approx(late.position.x, late.position_at(0).x - 192.0), "the latch never holds or pulls back a platform that has left")
	late.free()

	var plain: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	check(not plain.capture_state().has("powered"), "a platform without a latch records no 'powered'")
	plain.free()


func test_door_opens_once_and_stays_open() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.apply_settings({"cycle": "opens_once", "delay_seconds": 1, "open_seconds": 1})
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	check(door.open == 0, "a door that opens once starts closed, is %d" % door.open)
	for i in ticks:
		door.simulate_tick(i)
	check(door.open == 0, "it waits closed for delay_seconds, is %d" % door.open)
	var last := door.open
	for i in ticks + 1:
		door.simulate_tick(i)
		check(door.open >= last, "a door that opens once only opens")
		check(door.open - last <= int(Content.time()["max_state_step"]), "the door jumps %d per tick" % (door.open - last))
		last = door.open
	check(door.open == Door.OPEN_MAX, "it is open after open_seconds, is %d" % door.open)
	var state := door.capture_state()
	for i in 10 * ticks:
		door.simulate_tick(i)
	check(door.capture_state() == state, "an open door that opened once never changes again")
	door.free()


func test_sprinkler_rains_only_at_full_flow_and_is_no_tank() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.size = Vector2(256, 200)
	check(sprinkler.water_global_rect() == Rect2(), "a shut sprinkler wets nothing")
	sprinkler.powered = true
	var last := sprinkler.flow
	var ticks := 0
	while not sprinkler.is_raining() and ticks < 10 * 60:
		sprinkler.simulate_tick(ticks)
		check(sprinkler.flow - last <= int(Content.time()["max_state_step"]), "the flow jumps %d per tick" % (sprinkler.flow - last))
		check(sprinkler.is_raining() or sprinkler.water_global_rect() == Rect2(), "the rain wets only at full flow")
		last = sprinkler.flow
		ticks += 1
	var spin_up := float(Content.objects()["sprinkler"]["spin_up_seconds"]) * 60.0
	check(absf(ticks - spin_up) <= 1.0, "the rain is full after spin_up_seconds, took %d ticks" % ticks)
	check(sprinkler.water_global_rect().size == sprinkler.size, "full rain wets its whole rect")
	check(not (sprinkler as Object) is Water, "a sprinkler is not a tank: the hero never wades in it")
	sprinkler.powered = false
	for i in 10 * 60:
		sprinkler.simulate_tick(i)
	check(sprinkler.flow == 0 and sprinkler.water_global_rect() == Rect2(), "a shut sprinkler runs dry")
	sprinkler.free()


func test_sprinkler_with_a_start_holds_its_rain_until_then() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.apply_settings({"start_seconds": 1.0})
	sprinkler.powered = true
	for tick in range(1, 60):
		sprinkler.simulate_tick(tick)
	check(sprinkler.flow == 0, "a powered sprinkler stays dry before its start")
	for tick in range(60, 120):
		sprinkler.simulate_tick(tick)
	check(sprinkler.is_raining(), "after its start it rains on its own")
	sprinkler.powered = false
	for tick in range(120, 180):
		sprinkler.simulate_tick(tick)
	check(sprinkler.flow == 0, "unpowered, it shuts")
	sprinkler.free()


func test_wood_catches_from_the_zone_before_it_in_a_chain() -> void:
	var wood: Dictionary = Content.objects()["wood"]
	var first := WoodBurn.new(wood, Content.time())
	var second := WoodBurn.new(wood, Content.time())
	var spread := int(round(float(wood["spread_seconds"]) * 60.0))
	check(first.spread_ticks == spread, "spread_seconds comes from objects.json")
	check(not second.catches_from(first, false), "a whole zone before it lights nothing")
	first.ignite()
	var caught := -1
	for i in spread + 5:
		first.tick(false)
		if caught < 0 and second.catches_from(first, false):
			caught = i + 1
	check(caught == spread, "the next zone catches after spread_seconds, caught on tick %d" % caught)
	check(not second.catches_from(first, true), "a wet zone never catches")
	second.ignite()
	check(not second.catches_from(first, false), "a burning zone does not catch again")
	first.phase = WoodBurn.Phase.BURNT
	var third := WoodBurn.new(wood, Content.time())
	check(not third.catches_from(first, false), "a burnt zone has fallen and lights nothing")


func test_sprinkler_sensor_opens_it_when_its_zone_burns() -> void:
	var holder := Node2D.new()
	var zone: WoodZone = (load("res://objects/wood_zone.tscn") as PackedScene).instantiate()
	zone.object_id = "watched"
	var sprinkler := Sprinkler.new()
	sprinkler.sensor_id = "watched"
	holder.add_child(zone)
	holder.add_child(sprinkler)
	_tree.root.add_child(holder)
	sprinkler.simulate_tick(1)
	check(not sprinkler.powered, "the sensor waits while its zone is whole")
	zone.burn.ignite()
	sprinkler.simulate_tick(2)
	check(sprinkler.powered, "fire under the sensor opens the sprinkler")
	zone.burn.douse()
	sprinkler.simulate_tick(3)
	check(sprinkler.powered, "once open it stays open")
	holder.queue_free()
	await _tree.process_frame


func test_level_03_prelude_leaves_the_picture_of_the_card() -> void:
	var room := await _load()
	var zones := _zones(room)
	check(zones[2].burn.is_burning() and zones[3].burn.is_burning(), "the hero comes in while the bridge burns")
	await _ticks(10)
	check((room.get_node("Sprinkler") as Sprinkler).powered, "the fire reaches the sensor as the hero comes in")
	await _ticks(90)
	for i in 2:
		check(zones[i].burn.phase == WoodBurn.Phase.BURNT, "zone %d has burnt and fallen" % (i + 1))
	for i in range(2, 6):
		check(zones[i].burn.phase == WoodBurn.Phase.WHOLE, "zone %d is whole and wet" % (i + 1))
	for i in range(2, 5):
		check(zones[i].doused >= 0, "the rain put zone %d out" % (i + 1))
	var sprinkler: Sprinkler = room.get_node("Sprinkler")
	check(sprinkler.is_raining(), "the sensor set the rain going")
	check(not (room.get_node("Alarm") as FireAlarm).pulled, "nobody pulled the handle: the sensor did it")
	var torch: Torch = room.get_node("Torch")
	check(torch.mounted and not torch.lit, "the rain put the torch out in its holder")
	var barricade: WoodZone = room.get_node("Barricade")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE and barricade.doused < 0, "the barricade never caught")
	await _free(room)


func test_level_03_frame_zero_has_the_first_zone_burning_and_the_torch_lit() -> void:
	var room := await _load()
	var zones := _zones(room)
	var torch: Torch = room.get_node("Torch")
	Input.action_press("rewind")
	await _ticks(8 * 60)
	check(int(room.get_node("RoomTime").call("cursor")) == 0, "Shift brings the world to the start of the history")
	check(zones[0].burn.is_burning(), "at frame 0 the first zone burns")
	for i in range(1, 6):
		check(zones[i].burn.phase == WoodBurn.Phase.WHOLE and not zones[i].burn.is_burning(), "at frame 0 zone %d is whole" % (i + 1))
	check(torch.lit and torch.mounted, "at frame 0 the torch burns in its holder")
	check(not (room.get_node("Sprinkler") as Sprinkler).powered, "at frame 0 the alarm is quiet")
	Input.action_release("rewind")
	await _ticks(7 * 60)
	check(zones[1].burn.phase == WoodBurn.Phase.BURNT and zones[2].burn.phase == WoodBurn.Phase.WHOLE, "released Shift replays: the same two zones fall (rule A)")
	check(not torch.lit, "released Shift replays: the rain puts the torch out again")
	await _free(room)


func test_level_03_history_never_has_the_torch_in_hands_or_the_way_open() -> void:
	var room := await _load()
	var torch: Torch = room.get_node("Torch")
	var barricade: WoodZone = room.get_node("Barricade")
	var bad := 0
	for i in 8 * 60:
		await _ticks(1)
		if torch.held or barricade.burn.phase != WoodBurn.Phase.WHOLE or barricade.burn.is_burning():
			bad += 1
	Input.action_press("rewind")
	for i in 10 * 60:
		await _ticks(1)
		if torch.held or barricade.burn.phase != WoodBurn.Phase.WHOLE or barricade.burn.is_burning():
			bad += 1
	check(bad == 0, "the torch in the hands or the barricade alight on %d ticks of the recorded history" % bad)
	await _free(room)


func test_level_03_alarm_now_changes_nothing() -> void:
	var room := await _load()
	var zones := _zones(room)
	await _ticks(2 * 60)
	await _stand_by(room, "Alarm")
	await _press("interact")
	check((room.get_node("Alarm") as FireAlarm).pulled, "the hero by the handle pulls it")
	await _ticks(60)
	check(zones[0].burn.phase == WoodBurn.Phase.BURNT and zones[1].burn.phase == WoodBurn.Phase.BURNT, "rain on fallen zones brings nothing back")
	await _free(room)


func test_level_03_torch_taken_now_is_only_a_stick() -> void:
	var room := await _load()
	var torch: Torch = room.get_node("Torch")
	var barricade: WoodZone = room.get_node("Barricade")
	await _ticks(2 * 60)
	await _stand_by(room, "Torch")
	await _press("interact")
	check(torch.held and not torch.lit, "the torch taken now is out")
	await _by_barricade(room)
	await _press("interact")
	check(not torch.held and torch.host == "", "E by the barricade only drops a torch that is out")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE and not barricade.burn.is_burning(), "a torch that is out lights nothing")
	await _free(room)


func test_level_03_torch_and_alarm_in_the_past_burn_the_way_open() -> void:
	var room := await _load()
	var zones := _zones(room)
	var torch: Torch = room.get_node("Torch")
	var barricade: WoodZone = room.get_node("Barricade")
	await _stand_by(room, "Torch")
	Input.action_press("rewind")
	await _ticks(8 * 60)
	await _press("interact")
	check(torch.held and torch.lit, "under Shift at frame 0 the hero takes the burning torch")
	await _stand_by(room, "Alarm")
	await _press("interact")
	check((room.get_node("Sprinkler") as Sprinkler).powered, "the alarm pulled at frame 0 opens the sprinklers in the new branch")
	check(torch.held, "the second change on the same frame keeps the torch in the hands")
	Input.action_release("rewind")
	await _ticks(3 * 60)
	for i in 6:
		check(zones[i].burn.phase == WoodBurn.Phase.WHOLE and not zones[i].burn.is_burning(), "zone %d stands wet" % (i + 1))
	check(zones[0].doused >= 0, "the rain put the first zone out")
	check(torch.held and torch.lit, "in the hands the torch burns on under the rain")
	await _by_barricade(room)
	await _press("interact")
	check(barricade.burn.is_burning(), "the torch thrust into the barricade sets it burning")
	check(not torch.held and torch.host == "barricade", "the torch stays in the fire")
	var candidate := torch.interaction_candidate()
	check(float(candidate["radius"]) < 0.0, "a torch in the fire can never be taken again")
	var burn_ticks := int(round(float(Content.level_for_scene(LEVEL_PATH)["objects"]["barricade"]["burn_seconds"]) * 60.0))
	check(barricade.burn.burn_ticks == burn_ticks, "the barricade takes its burn time from the level")
	# Step back out of the flames: 3 s in them is death.
	Input.action_press("move_left")
	await _ticks(20)
	Input.action_release("move_left")
	await _ticks(burn_ticks - 10)
	check(barricade.burn.phase == WoodBurn.Phase.BURNT, "the barricade burns through: the way is open")
	check(torch.is_spent(), "the torch burns up with it")
	var at := torch.position
	Input.action_press("rewind")
	for i in 90:
		await _ticks(1)
		check(not torch.held and torch.position == at, "under Shift the torch stays in the barricade, never jumps to the hands")
	await _free(room)


func test_level_03_torch_lights_nothing_under_shift() -> void:
	var room := await _load()
	var torch: Torch = room.get_node("Torch")
	var barricade: WoodZone = room.get_node("Barricade")
	await _stand_by(room, "Torch")
	Input.action_press("rewind")
	await _ticks(8 * 60)
	await _press("interact")
	Input.action_release("rewind")
	await _ticks(30)
	await _by_barricade(room)
	Input.action_press("rewind")
	await _ticks(10)
	check(torch.held and torch.lit, "the torch still burns in the hands")
	check(torch.wood_in_reach() == null, "under Shift the torch offers no wood to light")
	await _press("interact")
	check(not torch.held and torch.host == "", "under Shift E only drops the torch")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE and not barricade.burn.is_burning(), "under Shift the torch lights nothing")
	await _free(room)


func test_level_03_geometry() -> void:
	var room := await _load()
	var zones := _zones(room)
	var barricade: WoodZone = room.get_node("Barricade")
	var sprinkler: Sprinkler = room.get_node("Sprinkler")
	var torch: Torch = room.get_node("Torch")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := blocks.tile_set.tile_size.x
	for i in range(1, 6):
		check(zones[i].spread_from == zones[i - 1].object_id, "zone %d catches from the one before it" % (i + 1))
		check(is_equal_approx(zones[i].global_rect().position.x, zones[i - 1].global_rect().end.x), "the zones of the bridge touch")
	check(sprinkler.sensor_id == zones[4].object_id, "the sensor watches the fifth zone")
	var left := int(zones[0].global_rect().position.x / cell)
	var right := int(zones[5].global_rect().end.x / cell)
	var top := int(zones[0].global_rect().position.y / cell)
	check(blocks.get_cell_source_id(Vector2i(left - 1, top)) != -1 and blocks.get_cell_source_id(Vector2i(left - 1, top - 1)) == -1, "the entrance floor is level with the bridge")
	for x in range(left, right):
		for y in range(top, blocks.get_used_rect().end.y):
			check(blocks.get_cell_source_id(Vector2i(x, y)) == -1, "the pit under the bridge is open to the bottom, block at %d,%d" % [x, y])
	var player := Content.player()
	var reach := 2.0 * float(player["jump_velocity"]) / float(player["gravity"]) * float(player["walk_speed"])
	check(2 * zones[0].size.x > reach + cell, "two fallen zones (%d px) must be wider than a jump (%.0f px)" % [2 * zones[0].size.x, reach])
	sprinkler.flow = Sprinkler.FLOW_MAX
	var rain := sprinkler.water_global_rect()
	for zone in zones:
		check(rain.intersects(zone.global_rect()), "the rain reaches %s" % zone.object_id)
	check(rain.intersects(torch.flame_rect()), "the rain reaches the torch in its holder")
	check(not rain.intersects(barricade.global_rect()), "the rain never reaches the barricade")
	await _free(room)


## The six zones of the bridge, left to right.
func _zones(room: Node) -> Array[WoodZone]:
	var zones: Array[WoodZone] = []
	for i in 6:
		zones.append(room.get_node("Bridge%d" % (i + 1)) as WoodZone)
	return zones


## Puts the hero on the ledge just left of the barricade, facing it.
func _by_barricade(room: Node) -> void:
	var player: Player = room.get_node("Player")
	var barricade: WoodZone = room.get_node("Barricade")
	var rect := barricade.global_rect()
	player.respawn(Vector2(rect.position.x - 30.0, rect.end.y))
	Input.action_press("move_right")
	await _ticks(2)
	Input.action_release("move_right")
	# The torch in the hands catches up with them at `follow_px` a tick.
	await _ticks(90)


func test_water_pipe_follows_its_sprinkler() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.name = "Source"
	var pipe := WaterPipe.new()
	pipe.source_path = NodePath("../Source")
	pipe.points = PackedVector2Array([Vector2.ZERO, Vector2(400, 0), Vector2(400, 200)])
	var holder := Node2D.new()
	holder.add_child(sprinkler)
	holder.add_child(pipe)
	_tree.root.add_child(holder)
	check(pipe.fill == 0.0 and pipe.run == 0.0, "a pipe to a shut sprinkler is empty")
	sprinkler.powered = true
	pipe.refresh()
	check(pipe.fill == 1.0 and pipe.run == 0.0, "an open line before its rain starts is full and still")
	sprinkler.flow = Sprinkler.FLOW_MAX
	pipe.refresh()
	check(pipe.run == 1.0, "water runs in the pipe while it rains")
	sprinkler.powered = false
	sprinkler.flow = Sprinkler.FLOW_MAX / 2
	pipe.refresh()
	check(is_equal_approx(pipe.fill, 0.5) and is_equal_approx(pipe.run, 0.5), "a closed line drains with its flow")
	pipe.on_world_tick(30, true)
	var at_30 := pipe.dash_offset()
	pipe.on_world_tick(31, true)
	var at_31 := pipe.dash_offset()
	pipe.on_world_tick(30, false)
	check(at_31 != at_30, "the dashes move with world time")
	check(pipe.dash_offset() == at_30, "the dashes stand where they were at the same world frame, so they run back under Shift")
	var look := Content.look_pipe()
	pipe.kind = WaterPipe.Kind.MAIN
	check(pipe.width() == float(look["main_width_px"]), "the main takes its width from look.json")
	pipe.kind = WaterPipe.Kind.FEED
	check(pipe.width() < float(look["main_width_px"]), "the feed pipe is thinner than the main")
	holder.queue_free()
	await _tree.process_frame


func test_pipe_look_data_is_checked() -> void:
	var data := Content.look().duplicate(true)
	check(Content.validate_look(data).is_empty(), "look.json passes the data check")
	data["pipe"].erase("dash_speed_px")
	check(not Content.validate_look(data).is_empty(), "a missing pipe number must be reported")
	data = Content.look().duplicate(true)
	data["pipe"]["water"] = "blue-ish"
	check(not Content.validate_look(data).is_empty(), "a broken pipe colour must be reported")
	data = Content.look().duplicate(true)
	data["pipe"]["wall_px"] = 8
	check(not Content.validate_look(data).is_empty(), "walls thicker than the feed pipe must be reported")


## Puts the hero on the floor next to a node (the alarm, the torch).
func _stand_by(room: Node, node_name: String) -> void:
	var player: Player = room.get_node("Player")
	var target: Node2D = room.get_node(node_name)
	var at := target.global_position
	if target is Torch:
		at.y += (target as Torch).floor_offset_px
	player.respawn(at - Vector2(20.0, 0.0))
	await _ticks(10)


func _press(action: String) -> void:
	Input.action_press(action)
	await _ticks(6)
	Input.action_release(action)


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	# Two ticks, as the solution player settles: the bodies' positions come
	# back from the physics server a tick late.
	await _ticks(2)
	return room


func _free(room: Node) -> void:
	for action in ["rewind", "move_right", "move_left", "interact", "use_item"]:
		Input.action_release(action)
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


func test_oil_burns_on_under_rain_and_only_the_jet_puts_it_out() -> void:
	var oil := WoodBurn.new(Content.objects()["wood"], Content.time())
	oil.oil = true
	oil.ignite()
	for i in oil.burn_ticks * 2:
		check(oil.tick(i % 2 == 0) == WoodBurn.Event.NONE, "oil neither burns out nor goes out under water")
	check(oil.is_burning(), "oil burns on and on, rain or not")
	check(not oil.is_solid(), "oil on the floor is never solid")
	check(oil.douse(), "the jet in normal time puts the oil out")
	check(not oil.is_solid(), "put-out oil is not solid either")


func test_oil_slows_the_walk_like_water() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	var slow := Vector2.ZERO
	for i in 120:
		v = motion.step(v, 1.0, false, true, 1.0 / 60.0)
		slow = motion.step(slow, 1.0, false, true, 1.0 / 60.0, {"slow": true})
	check(is_equal_approx(v.x, float(params["walk_speed"])), "on land she walks at walk_speed")
	check(is_equal_approx(slow.x, float(params["walk_speed"]) * float(params["water_walk_factor"])), "in oil she walks as in water")
	check(slow.y == 0.0, "oil holds no one up and drags no one down on the floor")


func test_level_03_burning_oil_is_too_long_to_wade() -> void:
	var room := await _load()
	var oil: WoodZone = room.get_node("Oil")
	var params := Content.player()
	var slow := float(params["walk_speed"]) * float(params["water_walk_factor"])
	var width: float = room.get_node("Player").get("_size").x
	var in_fire := (oil.size.x + 2.0 * float(Content.objects()["wood"]["flame_side_px"]) + width) / slow
	check(oil.oil and oil.burn.is_burning(), "the oil burns from the start")
	check(in_fire > float(params["fire_seconds"]) + 0.5, "wading the oil takes %.1f s in fire, it must kill (%s s)" % [in_fire, params["fire_seconds"]])
	check(oil.get_node("CollisionShape2D").disabled, "the oil is not solid")
	await _free(room)


func test_level_03_ramp_falls_when_the_rope_burns_and_rises_under_shift() -> void:
	var room := await _load()
	var ramp: Ramp = room.get_node("Ramp")
	var barricade: WoodZone = room.get_node("Barricade")
	check(not ramp.rope_gone() and ramp.fall == 0, "the rope holds the ramp upright")
	check(absf(ramp.tip().x - ramp.position.x) < 2.0 and ramp.tip().y < ramp.position.y - 200.0, "upright, the ramp stands over its hinge")
	for i in 100:
		ramp.simulate_tick(i)
	check(ramp.fall == 0, "while the barricade stands, the ramp stands")
	barricade.restore_state({"phase": WoodBurn.Phase.BURNT, "burn": barricade.burn.burn_ticks, "doused": -1, "burnt": 1})
	var tips: Array[Vector2] = []
	var max_step := float(Content.time()["max_state_step"])
	for i in 200:
		var before := ramp.tip()
		ramp.simulate_tick(i)
		check(before.distance_to(ramp.tip()) <= max_step, "the tip moves at most max_state_step a tick")
		tips.append(ramp.tip())
	check(ramp.is_lying(), "the ramp has fallen")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := float(blocks.tile_set.tile_size.x)
	var corner := Vector2(34, 10) * cell
	check(ramp.tip().distance_to(corner) < 8.0, "lying, the tip rests on the corner of the ledge, at %s" % ramp.tip())
	check(blocks.get_cell_source_id(Vector2i(ramp.position / cell)) != -1, "the hinge is on the lower floor")
	var lying := ramp.capture_state()
	ramp.restore_state({"fall": 0})
	check(absf(ramp.tip().x - ramp.position.x) < 2.0, "restoring frame 0 stands the ramp up again")
	ramp.restore_state(lying)
	check(ramp.tip().distance_to(corner) < 8.0, "and the lying frame lays it down")
	await _free(room)


func test_level_03_part_2_geometry() -> void:
	var room := await _load()
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := float(blocks.tile_set.tile_size.x)
	var oil: WoodZone = room.get_node("Oil")
	var crates: WoodZone = room.get_node("Crates")
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	var exit: Node2D = room.get_node("ExitZone") if room.has_node("ExitZone") else null
	for node in room.get_children():
		if node is ExitZone:
			exit = node
	var player := Content.player()
	var jump := 2.0 * float(player["jump_velocity"]) / float(player["gravity"]) * float(player["walk_speed"])
	var gap := 0
	for x in range(34, 38):
		var open := true
		for y in range(10, blocks.get_used_rect().end.y):
			open = open and blocks.get_cell_source_id(Vector2i(x, y)) == -1
		gap += 1 if open else 0
	check(gap == 4 and gap * cell > jump + cell * 0.5, "the gap behind the ledge is 4 open cells, wider than a jump (%.0f px)" % jump)
	check(is_equal_approx(oil.global_rect().end.y, 12 * cell), "the oil lies on the lower floor")
	check(roundi(oil.size.x / cell) == 10, "the oil is 10 cells")
	check(thrower.global_position.x < oil.global_rect().position.x, "the flamethrower lies before the oil")
	# The pile closes the way under the wall: solid cells over it, the floor below.
	var pile := crates.global_rect()
	for x in range(int(pile.position.x / cell), int(pile.end.x / cell)):
		check(blocks.get_cell_source_id(Vector2i(x, int(pile.position.y / cell) - 1)) != -1, "the wall stands over the crates in column %d" % x)
	check(is_equal_approx(pile.end.y, 12 * cell), "the crates stand on the floor")
	var side := float(Content.objects()["wood"]["flame_side_px"])
	var width: float = room.get_node("Player").get("_size").x
	check(pile.position.x - side - (oil.global_rect().end.x + side) > width + 16.0, "between the oil's fire and the crates' fire she has room to stand")
	check(exit != null and exit.global_position.x > pile.end.x, "the exit is behind the crates")
	await _free(room)
