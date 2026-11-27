extends RefCounted
## The checks of the monkey (`tests/monkey_test.gd`, D201) on small made-up
## cases, and the rules it found broken. The monkey itself is long and runs
## apart; these run with every test.

const Monkey := preload("res://tests/monkey_test.gd")
const LEVEL_PATH := "res://levels/level_01.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_nan_in_a_state_is_found() -> void:
	check(Monkey.nan_problems({"door": {"open": 10, "phase": 0.5}}).is_empty(), "plain numbers are fine")
	check(not Monkey.nan_problems({"door": {"open": NAN}}).is_empty(), "NaN must be found")
	check(not Monkey.nan_problems({"crate": {"position": Vector2(INF, 0)}}).is_empty(), "an infinite vector must be found")


func test_jumps_are_found_but_counters_may_restart() -> void:
	var limit := float(Content.time()["max_state_step"])
	check(Monkey.jump_problems({"door": {"open": 0}}, {"door": {"open": int(limit)}}, limit).is_empty(), "a step of max_state_step is fine")
	check(not Monkey.jump_problems({"door": {"open": 0}}, {"door": {"open": int(limit) + 1}}, limit).is_empty(), "a bigger step must be found")
	check(not Monkey.jump_problems({"crate": {"position": Vector2.ZERO}}, {"crate": {"position": Vector2(0, 300)}}, limit).is_empty(),
		"a teleport of a body must be found")
	check(Monkey.jump_problems({"quakes": {"since": 107}}, {"quakes": {"since": 0}}, limit).is_empty(), "a tick counter may start again")
	check(Monkey.jump_problems({"sprinkler": {"run": 240}}, {"sprinkler": {"run": 0}}, limit).is_empty(), "the rain's tick counter may start again")
	check(Monkey.jump_problems({"shutter": {"target": 0}}, {"shutter": {"target": 1000}}, limit).is_empty(), "a goal may flip")
	check(Monkey.jump_problems({"pool": {"level": 0}}, {"pool": {"level": int(limit) * 10}}, limit).is_empty(),
		"the water level is ten times finer")
	check(Monkey.jump_problems({"door": {"open": 0}}, {"lamp": {"drop": 900}}, limit).is_empty(), "a new object is no jump")


func test_history_problems_are_found() -> void:
	var timeline := Timeline.new(8)
	for i in 12:
		timeline.record({"door": {"open": i * 10}})
	check(Monkey.history_problems(timeline, 40.0, true).is_empty(), "a smooth full history is fine: %s" % [Monkey.history_problems(timeline, 40.0, true)])
	check(timeline.first() > 0, "the test history must have overflowed")
	var torn := Timeline.new(8)
	torn.record({"door": {"open": 0}})
	torn.record({"door": {"open": 500}})
	check(not Monkey.history_problems(torn, 40.0).is_empty(), "a jump between neighbour frames must be found")


func test_wall_check_finds_the_heroine_inside_blocks() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	for i in 3:
		await _tree.physics_frame
	var player := room.get_node("Player") as Player
	check(not Monkey._in_wall(player), "at the spawn the heroine is not in a wall")
	var blocks := room.get_node("Blocks") as TileMapLayer
	var cell := Vector2(blocks.tile_set.tile_size)
	var used := blocks.get_used_rect()
	# The bottom row of the room is solid ground.
	var inside := blocks.global_position + (Vector2(used.position.x + used.size.x / 2, used.end.y - 1) + Vector2(0.5, 0.0)) * cell
	player.global_position = inside
	await _tree.physics_frame
	check(Monkey._in_wall(player), "deep in the ground the heroine must be found in a wall")
	room.queue_free()
	await _tree.process_frame


func test_level_spin_up_obeys_max_state_step() -> void:
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 0, "title": "x",
		"objects": {"sprinkler": {"spin_up_seconds": 0.6}}}
	check(Content.validate_levels([good], 20.0).is_empty(), "a slow spin-up passes: %s" % [Content.validate_levels([good], 20.0)])
	var fast := good.duplicate(true)
	fast["objects"]["sprinkler"]["spin_up_seconds"] = 0.3
	check(not Content.validate_levels([fast], 20.0).is_empty(), "a spin-up that jumps more than max_state_step must be reported")
