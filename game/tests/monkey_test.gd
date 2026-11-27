extends SceneTree
## The monkey: plays every level with random keys from a fixed seed and looks
## for what a person mashing keys could break. Not part of the usual run: it is
## long. Keys: walking, jump, E, F, Shift (long and short holds, fast
## flicking), R and Esc.
##
##   godot --headless --fixed-fps 60 --path game --script res://tests/monkey_test.gd -- level=level_03 seed=2 minutes=3
##
## Arguments after `--`, all optional: `level=` an id of levels.json or `all`
## (the default), `seed=` one number or a list `1,2,3` (default 1), `minutes=`
## minutes of game time per level and seed (default 2), `wait_seconds=` how
## long the world may wait for the player (default 10), `slow_ms=` a tick
## slower than this in wall time is reported (default 100).
##
## Every tick it checks: script errors; NaN or infinity in the states of
## recorded objects and in the heroine; a recorded value that jumps more than
## `max_state_step` of `data/time.json` per frame moved (live, and between
## neighbour frames of the history); the heroine out of the room or inside a
## wall; the world waiting (WAITED) longer than `wait_seconds`; the history
## holding more frames than its capacity, its numbers out of order, the cursor
## outside it; a slow tick. Exit code 1 when something is found.

const LEVEL_PREFIX := "level_"
## Ticks after a load or a reset whose wall time and jumps are not judged.
const SETTLE_TICKS := 3
## The heroine is checked against walls with her shape this much smaller.
const WALL_INSET_PX := 6.0
## She must be in a wall this many ticks in a row to be reported.
const WALL_TICKS := 6
## How far outside the room's blocks she may be before it is reported.
const ROOM_MARGIN_PX := 64.0
## Cells below the room a fall goes before the respawn (FALL_MARGIN_CELLS of
## `levels/test_room.gd`), plus one for the last tick.
const FALL_CELLS := 5
## A step of the heroine longer than this is a respawn, not a move.
const TELEPORT_PX := 160.0
## The whole history is checked for jumps this often, in ticks.
const FULL_SCAN_TICKS := 600
## How many examples of one problem are printed.
const EXAMPLES := 3
## Keys of states that count ticks, name a step or hold a goal, not what the
## player sees: they may start again from 0 (`quakes.since` when the next
## quake begins, `sprinkler.run` when the next rain begins) or flip at once
## (`shutter.target`; `closed` is the shutter).
const COUNTER_KEYS: Array[String] = ["since", "index", "target", "run"]
## Keys on a finer scale than the usual 0…1000, by how much: the water level
## runs 0…10000 (Water.LEVEL_MAX).
const FINE_KEYS := {"level": 10.0}
const ALL_ACTIONS: Array[String] = ["move_left", "move_right", "jump", "interact", "use_item", "rewind", "reset_level"]

var _errors := ScriptErrors.new()
var _rng := RandomNumberGenerator.new()
var _max_step := 40.0
var _wait_ticks := 600
var _slow_usec := 100000
## kind -> {"count": n, "examples": [...]} for the run in progress.
var _found := {}
var _total_found := 0
var _verbose := false
## History problems already reported in this run, by their text.
var _seen_history := {}


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _run() -> void:
	var args := _args()
	var time_data := Content.time()
	var per_second := int(time_data.get("physics_ticks_per_second", 60))
	_max_step = float(time_data["max_state_step"])
	_wait_ticks = int(float(args.get("wait_seconds", "10")) * per_second)
	_slow_usec = int(float(args.get("slow_ms", "100")) * 1000.0)
	_verbose = args.has("verbose")
	var ticks := int(float(args.get("minutes", "2")) * 60.0 * per_second)
	var seeds := PackedInt64Array()
	for part in str(args.get("seed", "1")).split(",", false):
		seeds.append(int(part))
	var wanted := str(args.get("level", "all"))
	var levels: Array[String] = []
	for entry: Variant in Content.levels():
		var id := str((entry as Dictionary).get("id", ""))
		if id.begins_with(LEVEL_PREFIX) and (wanted == "all" or wanted == id):
			levels.append(id)
	if levels.is_empty():
		print("FAIL no level matches '%s'" % wanted)
		quit(1)
		return
	for id in levels:
		for seed_value in seeds:
			await _play(id, seed_value, ticks)
	print("Monkey: %d problems" % _total_found)
	quit(1 if _total_found > 0 else 0)


## `key=value` arguments after `--`.
func _args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args


# --- one run ----------------------------------------------------------------

func _play(id: String, seed_value: int, ticks: int) -> void:
	_rng.seed = seed_value
	_found.clear()
	_seen_history.clear()
	_errors.reset()
	var start_ms := Time.get_ticks_msec()
	var keys := MonkeyKeys.new(_rng)
	var room := await _load(id)
	var settle := SETTLE_TICKS
	var waited := 0
	var in_wall := 0
	var exits := 0
	var resets := 0
	var pauses := 0
	var paused_ticks := 0
	var previous := {}
	var previous_cursor := -1
	var previous_pos := Vector2.INF
	var deaths := [0]
	_connect_deaths(room, deaths)
	var deaths_seen := 0
	var last_usec := Time.get_ticks_usec()
	for tick in ticks:
		var pressed := keys.next()
		for action in ALL_ACTIONS:
			if action in pressed:
				Input.action_press(action)
			else:
				Input.action_release(action)
		if keys.take_esc():
			_press_pause()
			pauses += 1
		await physics_frame
		if _verbose and tick % 600 == 0:
			print("  tick %d, %.1f s, paused %s" % [tick, (Time.get_ticks_msec() - start_ms) / 1000.0, paused])
		var now_usec := Time.get_ticks_usec()
		var tick_usec := now_usec - last_usec
		last_usec = now_usec
		if _paused():
			paused_ticks += 1
			continue
		if bool(room.get("is_completed")):
			# The exit: start the level again instead of moving on.
			exits += 1
			room = await _reload(room, id)
			_connect_deaths(room, deaths)
			deaths_seen = int(deaths[0])
			settle = SETTLE_TICKS
			previous.clear()
			previous_pos = Vector2.INF
			last_usec = Time.get_ticks_usec()
			continue
		var clock := room.get_node_or_null("RoomTime") as RoomTime
		var player := room.get_node_or_null("Player") as Player
		if clock == null or player == null:
			_report("no RoomTime or Player", "%s tick %d" % [id, tick])
			break
		var reset: bool = "reset_level" in pressed or int(deaths[0]) != deaths_seen
		deaths_seen = int(deaths[0])
		var pos := player.global_position
		if previous_pos != Vector2.INF and pos.distance_to(previous_pos) > TELEPORT_PX:
			reset = true
		previous_pos = pos
		if reset:
			resets += 1
			settle = SETTLE_TICKS
		var where := "%s seed %d tick %d" % [id, seed_value, tick]
		if settle > 0:
			settle -= 1
		elif tick_usec > _slow_usec:
			_report("slow tick", "%s: %.0f ms" % [where, tick_usec / 1000.0])
		# The world waiting for the player.
		if clock.last_step == TimeWorld.Step.WAITED:
			waited += 1
			if waited == _wait_ticks + 1:
				_report("world waits too long", "%s: WAITED %d ticks in a row" % [where, waited])
		else:
			waited = 0
		# Recorded states: NaN and jumps.
		var frame := TemporalRecorder.new().capture(clock.temporal_objects())
		var cursor := clock.cursor()
		var moved := maxi(absi(cursor - previous_cursor), 1)
		for problem in nan_problems(frame):
			_report("NaN in a state", "%s: %s" % [where, problem])
		if not reset and settle == 0 and not previous.is_empty():
			for problem in jump_problems(previous, frame, _max_step * moved):
				_report("state jumps", "%s (%d frames moved): %s" % [where, moved, problem])
		previous = frame
		previous_cursor = cursor
		# The history.
		for problem in history_problems(clock.world.timeline, _max_step, tick % FULL_SCAN_TICKS == 0):
			if not _seen_history.has(problem):
				_seen_history[problem] = true
				_report("history", "%s: %s" % [where, problem])
		# The heroine.
		if not _is_finite(pos) or not _is_finite(player.velocity):
			_report("NaN in the heroine", "%s: position %s velocity %s" % [where, pos, player.velocity])
		var bounds := _room_rect(room)
		if bounds.has_area() and not _inside(bounds, pos):
			_report("heroine out of the room", "%s: at %s, room %s" % [where, pos, bounds])
		if not reset and _in_wall(player):
			in_wall += 1
			if in_wall == WALL_TICKS:
				_report("heroine in a wall", "%s: at %s, %s" % [where, pos, _wall_names(player)])
		else:
			in_wall = 0
		if _errors.count > 0:
			for message in _errors.messages:
				_report("script error", "%s: %s" % [where, message])
			_errors.reset()
	for action in ALL_ACTIONS:
		Input.action_release(action)
	if _paused():
		_resume()
	room.queue_free()
	await process_frame
	_reset_time()
	var problems := 0
	for kind: String in _found:
		problems += int(_found[kind]["count"])
	_total_found += problems
	print("%s %s seed %d: %d ticks, %.1f s, exits %d, resets %d, pauses %d (%d ticks), problems %d" % [
		"PASS" if problems == 0 else "FAIL", id, seed_value, ticks,
		(Time.get_ticks_msec() - start_ms) / 1000.0, exits, resets, pauses, paused_ticks, problems])
	for kind: String in _found:
		print("  - %s: %d" % [kind, _found[kind]["count"]])
		for example: String in _found[kind]["examples"]:
			print("      ", example)


func _report(kind: String, example: String) -> void:
	if not _found.has(kind):
		_found[kind] = {"count": 0, "examples": []}
	_found[kind]["count"] += 1
	if (_found[kind]["examples"] as Array).size() < EXAMPLES:
		(_found[kind]["examples"] as Array).append(example)


func _load(id: String) -> Node:
	_reset_time()
	var scene := ""
	for entry: Variant in Content.levels():
		if str((entry as Dictionary).get("id", "")) == id:
			scene = str(entry.get("scene", ""))
	var room: Node = (load(scene) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	var loader := root.get_node_or_null("LevelLoader")
	if loader != null:
		loader.set("current_id", id)
	for i in 2:
		await physics_frame
	return room


func _reload(room: Node, id: String) -> Node:
	room.queue_free()
	await process_frame
	return await _load(id)


func _connect_deaths(room: Node, deaths: Array) -> void:
	var player := room.get_node_or_null("Player") as Player
	if player == null:
		return
	var count := func() -> void: deaths[0] += 1
	player.drowned.connect(count)
	player.burned.connect(count)


func _press_pause() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = "pause"
	release.pressed = false
	Input.parse_input_event(release)


func _paused() -> bool:
	return paused


func _resume() -> void:
	var loader := root.get_node_or_null("LevelLoader")
	if loader != null:
		loader.call("resume")


func _reset_time() -> void:
	var manager := root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")


## The room's blocks in world coordinates; empty without blocks.
static func _room_rect(room: Node) -> Rect2:
	var blocks := room.get_node_or_null("Blocks") as TileMapLayer
	if blocks == null or blocks.tile_set == null:
		return Rect2()
	var cell := Vector2(blocks.tile_set.tile_size)
	var used := blocks.get_used_rect()
	return Rect2(blocks.global_position + Vector2(used.position) * cell, Vector2(used.size) * cell)


## Inside the room's blocks, with a margin; below them only as far as a fall
## goes before the room brings her back (`test_room.gd`, FALL_MARGIN_CELLS).
static func _inside(bounds: Rect2, pos: Vector2) -> bool:
	var fall := float(FALL_CELLS) * 64.0
	var room := bounds.grow(ROOM_MARGIN_PX)
	room.size.y += fall
	return room.has_point(pos)


## True when the heroine's shape, made smaller by WALL_INSET_PX, overlaps a
## solid body.
static func _in_wall(player: Player) -> bool:
	return not _wall_hits(player).is_empty()


static func _wall_names(player: Player) -> String:
	var names := PackedStringArray()
	for hit: Dictionary in _wall_hits(player):
		var collider: Object = hit.get("collider")
		names.append(str((collider as Node).name) if collider is Node else str(collider))
	return ", ".join(names)


static func _wall_hits(player: Player) -> Array:
	var shape_node: CollisionShape2D = null
	for child in player.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			shape_node = child
			break
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return []
	var small := RectangleShape2D.new()
	small.size = ((shape_node.shape as RectangleShape2D).size - Vector2.ONE * WALL_INSET_PX * 2.0).max(Vector2.ONE)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = small
	query.transform = shape_node.global_transform
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query, 4)


# --- checks on states, usable by the rule tests -----------------------------

## Values of a frame (`object_id -> state`) that are NaN or infinite.
static func nan_problems(frame: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for object_id: Variant in frame:
		var state: Variant = frame[object_id]
		if not state is Dictionary:
			continue
		for key: Variant in state:
			if not _is_finite(state[key]):
				problems.append("%s.%s = %s" % [object_id, key, state[key]])
	return problems


## Numbers and vectors that changed by more than `limit` between two frames.
static func jump_problems(before: Dictionary, after: Dictionary, limit: float) -> PackedStringArray:
	var problems := PackedStringArray()
	for object_id: Variant in after:
		if not before.has(object_id) or not after[object_id] is Dictionary or not before[object_id] is Dictionary:
			continue
		var old: Dictionary = before[object_id]
		var new: Dictionary = after[object_id]
		for key: Variant in new:
			if not old.has(key) or str(key) in COUNTER_KEYS:
				continue
			var step := _distance(old[key], new[key]) / float(FINE_KEYS.get(str(key), 1.0))
			if step > limit:
				problems.append("%s.%s %s -> %s (step %.1f, limit %.1f)" % [object_id, key, old[key], new[key], step, limit])
	return problems


## What is wrong with a history: more frames than it holds, its numbers out
## of order, the cursor outside it, a jump between neighbour frames at its
## edges (both ends, or `full` for every frame).
static func history_problems(timeline: Timeline, limit: float, full := false) -> PackedStringArray:
	var problems := PackedStringArray()
	if timeline.is_empty():
		return problems
	if timeline.size() > timeline.capacity():
		problems.append("%d frames kept, capacity %d" % [timeline.size(), timeline.capacity()])
	if timeline.head() - timeline.first() + 1 != timeline.size():
		problems.append("first %d, head %d, but %d frames" % [timeline.first(), timeline.head(), timeline.size()])
	if timeline.cursor() < timeline.first() or timeline.cursor() > timeline.head():
		problems.append("cursor %d outside %d..%d" % [timeline.cursor(), timeline.first(), timeline.head()])
	var numbers: Array[int] = []
	if full:
		for n in range(timeline.first(), timeline.head()):
			numbers.append(n)
	else:
		for n in [timeline.first(), timeline.first() + 1, timeline.head() - 2, timeline.head() - 1]:
			if n >= timeline.first() and n < timeline.head() and not n in numbers:
				numbers.append(n)
	for n in numbers:
		if timeline.tick_of(n + 1) <= timeline.tick_of(n):
			problems.append("world tick of frame %d (%d) not after frame %d (%d)" % [n + 1, timeline.tick_of(n + 1), n, timeline.tick_of(n)])
		for problem in jump_problems(timeline.frame_at(n), timeline.frame_at(n + 1), limit):
			problems.append("frames %d -> %d: %s" % [n, n + 1, problem])
	return problems


static func _distance(a: Variant, b: Variant) -> float:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(b) - float(a))
	if a is Vector2 and b is Vector2:
		return (a as Vector2).distance_to(b)
	return 0.0


static func _is_finite(value: Variant) -> bool:
	if value is float:
		return is_finite(value)
	if value is Vector2:
		return (value as Vector2).is_finite()
	return true


## The keys a monkey holds, one tick at a time. Every channel keeps its key
## for a random while: walking, jumps, E, F held, Shift in long and short
## holds and in bursts of fast flicking, R and Esc now and then.
class MonkeyKeys:
	extends RefCounted

	var _rng: RandomNumberGenerator
	var _move := ""
	var _move_left := 0
	var _jump_left := 0
	var _f_left := 0
	var _f_held := false
	var _shift_left := 0
	var _shift_held := false
	var _flicker_left := 0
	var _e_cooldown := 0
	var _esc := false
	var _pause_left := 0

	func _init(rng: RandomNumberGenerator) -> void:
		_rng = rng

	## The actions held on this tick.
	func next() -> Array[String]:
		var held: Array[String] = []
		# Walking: left, right or standing, for 0.2–3 s.
		_move_left -= 1
		if _move_left <= 0:
			var pick := _rng.randi_range(0, 4)
			_move = "" if pick == 0 else ("move_left" if pick <= 2 else "move_right")
			_move_left = _rng.randi_range(12, 180)
		if not _move.is_empty():
			held.append(_move)
		# Jump: a tap or a long press.
		_jump_left -= 1
		if _jump_left <= 0 and _rng.randf() < 0.03:
			_jump_left = _rng.randi_range(1, 20)
		if _jump_left > 0:
			held.append("jump")
		# E: a press of a tick or two.
		_e_cooldown -= 1
		if _e_cooldown <= 0 and _rng.randf() < 0.02:
			_e_cooldown = _rng.randi_range(2, 40)
			held.append("interact")
		elif _e_cooldown > 0 and _e_cooldown % 37 == 1:
			held.append("interact")
		# F: held for a while.
		_f_left -= 1
		if _f_left <= 0:
			_f_held = _rng.randf() < 0.25
			_f_left = _rng.randi_range(10, 200)
		if _f_held:
			held.append("use_item")
		# Shift: long holds, short taps and bursts of flicking.
		if _flicker_left > 0:
			_flicker_left -= 1
			_shift_held = _rng.randf() < 0.5
		else:
			_shift_left -= 1
			if _shift_left <= 0:
				var kind := _rng.randf()
				if kind < 0.1:
					_flicker_left = _rng.randi_range(20, 120)
				elif kind < 0.45:
					_shift_held = true
					_shift_left = _rng.randi_range(120, 900)
				elif kind < 0.7:
					_shift_held = true
					_shift_left = _rng.randi_range(2, 30)
				else:
					_shift_held = false
					_shift_left = _rng.randi_range(20, 400)
		if _shift_held:
			held.append("rewind")
		# R: seldom. Esc: seldom, and pressed again to leave the pause.
		if _rng.randf() < 0.0008:
			held.append("reset_level")
		if _pause_left > 0:
			_pause_left -= 1
			if _pause_left == 0:
				_esc = true
		elif _rng.randf() < 0.0006:
			_esc = true
			_pause_left = _rng.randi_range(5, 60)
		return held

	## True once when Esc is pressed on this tick.
	func take_esc() -> bool:
		var was := _esc
		_esc = false
		return was
