extends SceneTree
## Time of a physics tick by level (task of 27.11.2026, D208). Plays each
## level's solution (`game/tests/solutions/level_NN.json`) headless and
## measures, every tick: the whole frame (all nodes, physics and idle) and
## the own share of RoomTime (recording, `world.tick`), RoomSound (sounds of the
## room), KeyHints (key hints, `_process`) and the Sound autoload (`_process`).
## A share is taken by two probe nodes put right before and right after the
## node in the tree with its priority, so the node itself is not changed.
##
##   godot --headless --fixed-fps 60 --path game --script $PWD/tools/profile_ticks.gd
##   godot --headless --path game --script $PWD/tools/profile_ticks.gd -- level_01 level_03
##   ... -- level_05 --children   # also every child of the level, the 8 dearest
##
## Without `--fixed-fps` the frames come at the speed of the wall clock (60 a
## second), so a run lasts as long as the solutions themselves. Prints one line
## per level: mean, 95th percentile and worst in microseconds.

const SOLUTIONS := "res://tests/solutions/"
const SETTLE_TICKS := 2


## Marks the start or the end of one part of the frame.
class Probe extends Node:
	var stats: Dictionary
	var key: String
	var is_end := false
	var idle := false
	var _start := 0

	func _physics_process(_delta: float) -> void:
		if not idle:
			_mark()

	func _process(_delta: float) -> void:
		if idle:
			_mark()

	func _mark() -> void:
		var now := Time.get_ticks_usec()
		if not is_end:
			stats["_start_" + key] = now
			return
		var start: int = stats.get("_start_" + key, -1)
		if start >= 0:
			(stats[key] as Array).append(now - start)
			stats["_start_" + key] = -1


var _stats := {}
var _last_frame := 0
var _children := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var levels: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg == "--children":
			_children = true
		else:
			levels.append(arg)
	if levels.is_empty():
		for entry: Variant in Content.levels():
			if entry is Dictionary:
				levels.append(str(entry.get("id", "")))
	var wall := Time.get_ticks_msec()
	print("PROFILE level ticks exit load_ms | part: mean p95 max (us)")
	for id: String in levels:
		await _play(id)
	print("PROFILE all levels in %.1f s of wall clock" % (float(Time.get_ticks_msec() - wall) / 1000.0))
	quit(0)


func _play(id: String) -> void:
	var path := SOLUTIONS + id + ".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		print("PROFILE %s: no solution %s" % [id, path])
		return
	var actions := _all_actions(data)
	for action: Variant in actions:
		Input.action_release(action)
	_reset_time()
	_stats = {}
	for key in ["frame", "room_time", "room_sound", "key_hints", "sound"]:
		_stats[key] = []
	var started := Time.get_ticks_usec()
	var room: Node = (load(_scene(id)) as PackedScene).instantiate()
	root.add_child(room)
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	for i in SETTLE_TICKS:
		await physics_frame
	_bracket(_find(room, "RoomTime"), "room_time", false)
	_bracket(room.get_node_or_null("RoomSound"), "room_sound", false)
	_bracket(_find(room, "KeyHints"), "key_hints", true)
	_bracket(root.get_node_or_null("Sound"), "sound", true)
	if _children:
		for child in room.get_children():
			if child.is_in_group("profile_probe") or child.name in ["RoomSound", "RoomTime"]:
				continue
			for idle in [false, true]:
				var key := "%s:%s" % [child.name, "idle" if idle else "physics"]
				_stats[key] = []
				_bracket(child, key, idle)
	var ticks := 0
	var reached := false
	_last_frame = 0
	for segment: Variant in data["segments"]:
		for action: Variant in actions:
			if action in segment["actions"]:
				Input.action_press(action)
			else:
				Input.action_release(action)
		for i in int(segment["ticks"]):
			await physics_frame
			_frame()
			ticks += 1
			if bool(room.get("is_completed")):
				reached = true
				break
		if reached:
			break
	for action: Variant in actions:
		Input.action_release(action)
	var line := "PROFILE %s %d %s %.0f" % [id, ticks, "yes" if reached else "NO", load_ms]
	for key in ["frame", "room_time", "room_sound", "key_hints", "sound"]:
		line += " | %s %s" % [key, _summary(_stats[key])]
	print(line)
	if _children:
		var rows := []
		for key: String in _stats:
			if ":" in key and not key.begins_with("_") and not (_stats[key] as Array).is_empty():
				rows.append([_mean(_stats[key]), key])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for row: Array in rows.slice(0, 8):
			print("PROFILE   %s %s" % [row[1], _summary(_stats[row[1]])])
	for probe in get_nodes_in_group("profile_probe"):
		probe.queue_free()
	room.queue_free()
	await process_frame
	_reset_time()


## Called once a tick, before the nodes of the tick run.
func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0:
		(_stats["frame"] as Array).append(now - _last_frame)
	_last_frame = now


func _bracket(node: Node, key: String, idle: bool) -> void:
	if node == null:
		return
	var parent := node.get_parent()
	var index := node.get_index()
	var begin := _probe(key, false, idle, node)
	var end := _probe(key, true, idle, node)
	parent.add_child(begin)
	parent.move_child(begin, index)
	parent.add_child(end)
	parent.move_child(end, index + 2)


func _probe(key: String, is_end: bool, idle: bool, target: Node) -> Probe:
	var probe := Probe.new()
	probe.name = "Profile_%s_%s" % [key, "end" if is_end else "begin"]
	probe.stats = _stats
	probe.key = key
	probe.is_end = is_end
	probe.idle = idle
	probe.process_priority = target.process_priority
	probe.process_physics_priority = target.process_physics_priority
	probe.process_mode = target.process_mode
	probe.add_to_group("profile_probe")
	return probe


static func _mean(values: Array) -> int:
	var total := 0
	for v: int in values:
		total += v
	return total / maxi(values.size(), 1)


static func _summary(values: Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for v: int in sorted:
		total += v
	return "%d %d %d" % [total / sorted.size(), sorted[int(sorted.size() * 0.95)], sorted[-1]]


static func _find(room: Node, node_name: String) -> Node:
	return room.find_child(node_name, true, false)


static func _scene(id: String) -> String:
	for entry: Variant in Content.levels():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return str(entry.get("scene", ""))
	return ""


static func _all_actions(data: Dictionary) -> Array:
	var all := []
	for segment: Variant in data["segments"]:
		for action: Variant in segment["actions"]:
			if not action in all:
				all.append(action)
	return all


func _reset_time() -> void:
	var manager := root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
