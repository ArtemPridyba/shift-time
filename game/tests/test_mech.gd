extends RefCounted
## Tests of the mechanisms drawn by code (task Д2): their angles and link
## offsets are functions of the recorded travel of a door or a platform, and
## in the showcase the same frame of history shows the same gear angle and the
## same particles, forward and after Shift. Run by test_runner.gd.

const SHOWCASE_PATH := "res://tests/rooms/mech_test.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_gear_rolls_by_travel() -> void:
	check(is_equal_approx(MechDrive.rolling_angle(TAU * 36.0, 36.0), TAU), "a gear that rolled its rim once has turned once")
	check(MechDrive.rolling_angle(-36.0, 36.0) == -1.0, "travel back turns the gear back")
	check(MechDrive.rolling_angle(10.0, 0.0) == 0.0, "a gear without radius stands still")


func test_meshed_gear_turns_the_other_way() -> void:
	check(is_equal_approx(MechDrive.meshed_angle(1.0, 36.0, 20.0), -1.8), "a meshed gear turns the other way by the ratio of radii")


func test_links_wrap_by_one_pitch() -> void:
	check(is_equal_approx(MechDrive.link_offset(31.0, 15.0), 1.0), "the link offset wraps forward")
	check(is_equal_approx(MechDrive.link_offset(-1.0, 15.0), 14.0), "the link offset wraps backward")


func test_valve_wheel_turns_two_and_a_half_times() -> void:
	check(is_equal_approx(MechDrive.wheel_angle(1.0, 2.5), 5.0 * PI), "an open door has turned its wheel 2.5 times")
	check(MechDrive.wheel_angle(1.5, 2.5) == MechDrive.wheel_angle(1.0, 2.5), "the wheel stops at open")
	check(MechDrive.wheel_angle(0.0, 2.5) == 0.0, "a closed door's wheel is at its start")


func test_door_and_platform_report_their_travel() -> void:
	var door: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	door.travel = 192.0
	door.open = Door.OPEN_MAX / 2
	check(is_equal_approx(door.mech_travel(), 96.0), "a half-open door has moved half its travel")
	check(is_equal_approx(door.mech_fraction(), 0.5), "a half-open door is at 0.5")
	door.free()
	var platform: MovingPlatform = (load("res://objects/platform.tscn") as PackedScene).instantiate()
	platform.travel = Vector2(0, -256)
	platform.phase = platform.move_ticks()
	check(is_equal_approx(platform.mech_travel(), 256.0), "a platform at the end of its path has moved its whole travel")
	check(is_equal_approx(platform.mech_fraction(), 1.0), "a platform at the end of its path is at 1")
	platform.free()
	check(MechDrive.travel_of(null) == 0.0 and MechDrive.fraction_of(Node.new()) == 0.0,
		"without a driven object a mechanism stands still")


func test_chain_loop_is_closed_and_continuous() -> void:
	var chain := MechChain.new()
	chain.to = Vector2(0, 300)
	chain.drum_radius = 15.0
	var length := chain.loop_length()
	check(chain.point_at(0.0).distance_to(chain.point_at(length)) < 0.01, "the chain loop must close")
	var biggest := 0.0
	var s := 0.0
	while s < length:
		biggest = maxf(biggest, chain.point_at(s).distance_to(chain.point_at(s + 1.0)))
		s += 1.0
	check(biggest < 1.01, "one pixel along the chain moves a link at most one pixel, the biggest was %.3f" % biggest)
	check(is_equal_approx(fmod(length, chain.link_step()), 0.0) or is_equal_approx(fmod(length, chain.link_step()), chain.link_step()),
		"the links fill the loop exactly")
	chain.free()


func test_showcase_mechanisms_keep_no_history() -> void:
	var room := await _load_showcase()
	var room_time: RoomTime = room.get_node("RoomTime")
	var ids: Array[String] = []
	for node: Node in room_time.temporal_objects():
		ids.append(str(node.get("object_id")))
	ids.sort()
	check(ids == ["gate", "lift", "slider"], "only the gate, the lift and the slider are recorded, got %s" % [ids])
	for node in room.find_children("*", "Node2D", true, false):
		if node is MechPart:
			check(not node.is_in_group("temporal"), "mechanism %s must not be recorded" % node.name)
	await _free(room)


func test_showcase_same_frame_same_look_forward_and_back() -> void:
	var room := await _load_showcase()
	var room_time: RoomTime = room.get_node("RoomTime")
	var gear: MechGear = room.get_node("GateGear")
	var wheel: MechValveWheel = room.get_node("Slider/Handwheel")
	var chain: MechChain = room.get_node("LiftChain")
	var dust: TimeParticles = room.get_node("Dust")
	var sparks: TimeParticles = room.get_node("Sparks")
	# 2.5 s of the world clock (D96): the gate is opening then.
	await _ticks(int(round(2.5 * Content.world_ticks_per_second(Content.time()))))
	var mark := room_time.cursor()
	var look := _look(gear, wheel, chain, dust, sparks)
	await _ticks(20)
	gear.refresh()
	check(not is_equal_approx(gear.angle(), look["gear"]), "the gate gear must turn while the gate opens")
	var ahead := room_time.cursor()
	var look_ahead := _look(gear, wheel, chain, dust, sparks)
	Input.action_press("rewind")
	# The first half second of Shift goes back one frame a tick (D62).
	await _ticks(20)
	check(room_time.cursor() == mark, "20 ticks of Shift must bring the world back 20 frames, cursor %d, mark %d" % [room_time.cursor(), mark])
	check(_look(gear, wheel, chain, dust, sparks) == look, "back on the same frame, gears, wheel, chain and particles must look the same")
	Input.action_release("rewind")
	await _ticks(20)
	check(room_time.cursor() == ahead, "releasing Shift replays the recorded future")
	check(_look(gear, wheel, chain, dust, sparks) == look_ahead, "the replayed future must look as it was recorded")
	await _free(room)


func _look(gear: MechGear, wheel: MechValveWheel, chain: MechChain, dust: TimeParticles, sparks: TimeParticles) -> Dictionary:
	for part: MechPart in [gear, wheel, chain]:
		part.refresh()
	return {
		"gear": gear.angle(), "wheel": wheel.angle(), "chain": chain.links_offset(),
		"dust": dust.last_sample, "sparks": sparks.last_sample, "seconds": dust.world_seconds,
	}


func _load_showcase() -> Node:
	Input.action_release("rewind")
	var room: Node = (load(SHOWCASE_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
