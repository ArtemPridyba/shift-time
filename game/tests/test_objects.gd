extends RefCounted
## Tests of the door and the moving platform: the temporal object contract,
## their cycles from data, the reverse path without jumps (the done criterion
## of task 1.4), the crush rule, and both in the test room: Shift rewinds them,
## the player rides the platform both ways, the world waits instead of crushing.
## Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room.tscn"
const DOOR_PATH := "res://objects/door.tscn"
const PLATFORM_PATH := "res://objects/platform.tscn"
## The methods every temporal object has (docs/architecture.md, section 4.1).
const CONTRACT: Array[String] = [
	"capture_state", "restore_state", "simulate_tick", "on_time_direction_changed", "blocks_player_at",
]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- objects alone ----------------------------------------------------------

func test_door_follows_its_cycle_from_data() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	var data: Dictionary = Content.objects()["door"]
	var ticks := float(Content.time()["physics_ticks_per_second"])
	var opening := int(round(float(data["open_seconds"]) * ticks))
	var hold := int(round(float(data["hold_open_seconds"]) * ticks))
	check(door.open_at(0) == 0, "the cycle starts closed")
	check(door.open_at(opening) == Door.OPEN_MAX, "the door is fully open after open_seconds")
	check(door.open_at(opening + hold - 1) == Door.OPEN_MAX, "the door stays open for hold_open_seconds")
	check(door.open_at(door.cycle_ticks() - 1) == 0, "the cycle ends closed")
	var state := {"open": 500, "locked": false, "phase": 90}
	door.restore_state(state)
	check(door.capture_state() == state, "capture must return what restore set")
	check(is_equal_approx(door.position.y, -door.travel / 2.0), "half open must lift the door by half its travel")
	door.locked = true
	door.simulate_tick(0)
	check(door.open == 500, "a locked door stands still")
	door.free()


func test_door_and_platform_rewind_without_jumps() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	var objects := [door, platform]
	var world := TimeWorld.from_config(Content.time())
	var limit := float(Content.time()["max_state_step"])
	var forward := []
	for i in world.timeline.capacity() + 300:
		world.tick(TimeWorld.FORWARD, objects)
		forward.append(_look(door, platform))
	var backward := []
	for i in world.timeline.capacity() + 50:
		world.tick(TimeWorld.BACKWARD, objects)
		backward.append(_look(door, platform))
	var opened: int = forward.reduce(func(m: int, s: Array) -> int: return maxi(m, s[0]), 0)
	check(opened == Door.OPEN_MAX, "the door must open fully during the run")
	var far: float = forward.reduce(func(m: float, s: Array) -> float: return maxf(m, s[1].x), 0.0)
	check(is_equal_approx(far, platform.travel.x), "the platform must reach the end of its path")
	check(_max_step(forward) <= limit, "forward step %.1f is above max_state_step" % _max_step(forward))
	check(_max_step([forward[-1]] + backward) <= limit, "reverse step %.1f is above max_state_step" % _max_step([forward[-1]] + backward))
	var kept := world.timeline.capacity()
	var replayed := forward.slice(forward.size() - kept, forward.size() - 1)
	replayed.reverse()
	check(backward.slice(0, kept - 1) == replayed, "rewind must pass the recorded path in reverse")
	check(backward[-1] == backward[kept - 1], "at the oldest kept frame the world must stand still")
	for i in kept - 1:
		world.tick(TimeWorld.FORWARD, objects)
	check(_look(door, platform) == forward[-1], "releasing Shift must replay back to the same present")
	door.free()
	platform.free()


## The physics server writes a synced body's transform back a step late. The
## recorded state must come from the phase, or an interference captured between
## ticks writes a stale position and the replay jumps.
func test_platform_state_comes_from_its_phase_not_the_body() -> void:
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	for i in 6:
		platform.simulate_tick(i + 1)
	var expected := platform.position_at(platform.phase)
	platform.position = expected - Vector2(2, 0)
	var state := platform.capture_state()
	check(state["position"] == expected, "the platform must record the position of its phase, not the body's lagging one")
	platform.free()


func test_crush_rule_of_door_and_platform() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.position = Vector2(500, 500)
	var under_door := Rect2(478, 504, 44, 92)
	check(door.blocks_player_at({"open": 0, "locked": false, "phase": 0}, under_door), "a closed door over the player crushes")
	check(not door.blocks_player_at({"open": Door.OPEN_MAX, "locked": false, "phase": 0}, under_door), "an open door above the player does not")
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	# The platform's top is at y = -16; the rider's feet sink just under carry_margin.
	var riding := Rect2(-22, -16.0 - 92.0 + platform.carry_margin - 1.0, 44, 92)
	check(not platform.blocks_player_at({"phase": 0, "position": Vector2.ZERO}, riding), "a rider sunk less than carry_margin is riding")
	var beside := Rect2(80, -46, 44, 92)
	check(platform.blocks_player_at({"phase": 0, "position": Vector2.ZERO}, beside), "a platform into the player's side crushes")
	check(not platform.blocks_player_at({"phase": 0, "position": Vector2.ZERO}, Rect2()), "no player, nothing to crush")
	door.free()
	platform.free()


func test_door_rising_under_the_player_is_riding_not_crushing() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.position = Vector2(500, 500)
	# The hero stands on the door's top at every tick of the opening; the next
	# frame lifts the top by about a pixel, which is riding like on a platform.
	var ticks: int = door.cycle_ticks()
	var worst := 0
	for tick in ticks:
		var before := door.open_at(tick)
		var after := door.open_at(tick + 1)
		if after <= before:
			continue
		var top := door.rect_at(before).position.y
		var standing := Rect2(door.position.x - 22.0, top - 92.0, 44.0, 92.0)
		if door.blocks_player_at({"open": after, "locked": false, "phase": 0}, standing):
			worst += 1
	check(worst == 0, "a door rising under the hero's feet must not count as crushing (%d ticks did)" % worst)
	# A door that comes down on the head is still a crush.
	var head := Rect2(door.position.x - 22.0, door.rect_at(Door.OPEN_MAX).end.y - 6.0, 44.0, 92.0)
	check(door.blocks_player_at({"open": Door.OPEN_MAX, "locked": false, "phase": 0}, head), "a door resting on the hero's head still crushes")
	door.free()


# --- in the test room -------------------------------------------------------

func test_room_objects_keep_the_contract() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var objects := time.temporal_objects()
	check(objects.size() >= 2, "the test room must have a door and a platform, found %d temporal objects" % objects.size())
	for problem in TemporalRecorder.new().validate(objects):
		check(false, problem)
	for object in objects:
		for method in CONTRACT:
			check(object.has_method(method), "%s has no %s()" % [object.name, method])
		check(object is AnimatableBody2D and object.sync_to_physics, "%s must be an AnimatableBody2D with sync_to_physics" % object.name)
	await _free_room(room)


func test_shift_rewinds_door_and_platform_in_room() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var platform: MovingPlatform = room.get_node("Platform")
	var player: Player = room.get_node("Player")
	await _ticks(120)
	var door_open := door.open
	var platform_x := platform.position.x
	check(door_open > 0 and platform_x > 800.0, "after 2 s the door must be opening and the platform riding")
	var player_at := player.position
	Input.action_press("rewind")
	await _ticks(2)
	var last := door.open
	var falling := true
	for i in 60:
		await _ticks(1)
		falling = falling and door.open <= last
		last = door.open
	check(time.last_step == TimeWorld.Step.REWOUND, "holding Shift must rewind the room")
	check(falling and door.open < door_open, "the door must close back under Shift")
	check(platform.position.x < platform_x, "the platform must ride back under Shift")
	check(player.position.distance_to(player_at) < 1.0, "Shift must not move the player standing aside")
	await _ticks(120)
	check(time.last_step == TimeWorld.Step.PINNED and door.open == 0, "at the start of the history the world stands still")
	Input.action_release("rewind")
	await _ticks(5)
	check(time.last_step == TimeWorld.Step.REPLAYED, "releasing Shift must replay the recorded future")
	await _free_room(room)


func test_player_rides_the_platform_both_ways() -> void:
	var room := await _load_room()
	var platform: MovingPlatform = room.get_node("Platform")
	var player: Player = room.get_node("Player")
	player.respawn(platform.position + Vector2(0, -16))
	await _ticks(60)
	var offset := player.position.x - platform.position.x
	check(platform.position.x > 900.0, "the platform must ride right")
	check(absf(offset) < 4.0, "the player must ride along forward, %.1f px off" % offset)
	var x := player.position.x
	Input.action_press("rewind")
	await _ticks(40)
	Input.action_release("rewind")
	offset = player.position.x - platform.position.x
	check(player.position.x < x - 50.0, "the player must ride back with the rewound platform")
	check(absf(offset) < 4.0, "the player must stay on the platform in rewind, %.1f px off" % offset)
	await _free_room(room)


func test_world_waits_instead_of_crushing_in_room() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	var data: Dictionary = Content.objects()["door"]
	var ticks := float(Content.time()["physics_ticks_per_second"])
	await _ticks(int((float(data["open_seconds"]) + 1.0) * ticks))
	player.respawn(Vector2(door.position.x, 960))
	await _ticks(int((float(data["hold_open_seconds"]) + float(data["close_seconds"])) * ticks))
	check(time.last_step == TimeWorld.Step.WAITED, "the closing door must make the world wait over the player")
	check(door.open > 0 and not door.rect_at(door.open).intersects(player.body_rect()), "the door must stop above the player")
	check(player.position.y > 950.0, "the player must not be pushed into the floor")
	player.respawn(Vector2(160, 960))
	await _ticks(3)
	check(time.last_step == TimeWorld.Step.RECORDED, "once the player steps away the world goes on")
	await _free_room(room)


func test_world_keeps_going_while_the_hero_rides_the_rising_door_in_room() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var platform: MovingPlatform = room.get_node("Platform")
	var player: Player = room.get_node("Player")
	var top := door.rect_at(0).position.y
	player.respawn(Vector2(door.position.x, top))
	var start_y := player.position.y
	var platform_x := platform.position.x
	var waited := 0
	for i in 90:
		await _ticks(1)
		if time.last_step == TimeWorld.Step.WAITED:
			waited += 1
	check(waited == 0, "the world must not wait while the hero rides the rising door (%d waits)" % waited)
	check(door.open > 0, "the door must keep opening under the hero")
	check(player.position.y < start_y - 10.0, "the hero must be carried up by the door: %.1f px" % (start_y - player.position.y))
	check(platform.position.x != platform_x, "the platform must keep moving while the hero rides the door")
	await _free_room(room)


# --- helpers ----------------------------------------------------------------

func _look(door: Door, platform: MovingPlatform) -> Array:
	return [door.open, platform.position]


## The biggest change between neighbouring looks: door in thousandths, platform in pixels.
func _max_step(looks: Array) -> float:
	var biggest := 0.0
	for i in range(1, looks.size()):
		biggest = maxf(biggest, absf(float(looks[i][0] - looks[i - 1][0])))
		biggest = maxf(biggest, (looks[i][1] as Vector2).distance_to(looks[i - 1][1]))
	return biggest


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
