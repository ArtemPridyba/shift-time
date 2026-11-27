extends Node
## Autoload. Plays recorded level solutions in the real game, to check a build
## in the browser (task И1, 27.11.2026, D203). Without a request it does
## nothing at all. A request names levels:
##
##   browser:  index.html?solution=level_01   (or ?solution=chapter, or
##             ?solution=level_01,level_03)
##   editor:   Project → Run → Main Run Args: `-- --solution chapter`
##   desktop:  godot --path game -- --solution chapter
##
## It opens the first level, holds the actions of its solution
## (`tests/solutions/level_NN.json`) tick by tick of the physics, so it plays
## the same at any frame rate (only slower when the frames are few), and when
## the level is passed LevelLoader fades into the next one as for a player.
## A solution that ends without the exit opens the next requested level. Every
## result is printed (`SOLUTION level_01: exit at tick 1062`) and, in the
## browser, kept in `window.solutionReplay` as JSON; the progress save is
## left untouched. Under a tool or test main loop (`--script`) the arguments
## are not read: tools/shots.gd has its own `--solution`.

signal level_played(id: String, reached: bool, tick: int)
signal finished(results: Array)

const ARGUMENT := "--solution"
const URL_PARAMETER := "solution"
const LOG_PREFIX := "SOLUTION"

## [{"level": id, "reached": bool, "tick": int}, ...] of the levels played.
var results: Array = []

var _queue: Array[String] = []
var _script: SolutionScript
var _room: Node
## The scene that is leaving (a passed level, or the one before a load): it is
## skipped until the next scene takes its place.
var _left: Node
var _tick := 0
var _held: Array = []


func _ready() -> void:
	# Before the level and the player in every physics tick, as the headless
	# test presses its keys before the tick.
	process_physics_priority = -1000
	set_physics_process(false)
	if get_tree().get_script() != null:
		return
	var request := _request()
	if not request.is_empty():
		start.call_deferred(request)


## True while a replay runs.
func is_running() -> bool:
	return is_physics_processing()


## Starts playing the levels the request names (`chapter`, `level_01`, or ids
## separated by commas). False when it names no level with a solution.
func start(request: String) -> bool:
	stop()
	results.clear()
	var loader := _loader()
	if loader == null:
		return false
	for id in SolutionScript.levels_for(request, loader.call("order")):
		if SolutionScript.for_level(id) != null:
			_queue.append(id)
		else:
			_report(id, false, 0, "has no solution file")
	if _queue.is_empty():
		_log("nothing to play for '%s'" % request)
		_publish()
		return false
	_log("plays %s" % ", ".join(_queue))
	loader.set("save_path", "")
	set_physics_process(true)
	_open_next()
	return true


## Ends the replay and lets every key go.
func stop() -> void:
	_release()
	_queue.clear()
	_script = null
	_room = null
	_left = null
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var loader := _loader()
	var scene := get_tree().current_scene
	if loader == null or scene == null or _queue.is_empty():
		return
	var id := _queue[0]
	if scene == _left:
		return
	if scene != _room:
		# A new scene: the level asked for, or one that LevelLoader faded into
		# on its own (the next in the list), which is not the one asked for.
		if str(loader.get("current_id")) != id or not "is_completed" in scene:
			if not bool(loader.call("is_passing")) and str(loader.get("current_id")) != id:
				loader.call("load_level", id)
			return
		_room = scene
		_script = SolutionScript.for_level(id)
		_tick = 0
	if bool(_room.get("is_completed")):
		_done(id, true)
		return
	if _tick >= _script.end_tick():
		_done(id, false)
		return
	_hold(_script.actions_at(_tick))
	_tick += 1


func _done(id: String, reached: bool) -> void:
	_release()
	_report(id, reached, _tick, "")
	_queue.pop_front()
	_script = null
	_left = _room
	_room = null
	if _queue.is_empty():
		_log("done: %d of %d levels reached the exit" % [
			results.filter(func(r: Dictionary) -> bool: return r["reached"]).size(), results.size()])
		set_physics_process(false)
		_publish()
		finished.emit(results)
		return
	# A passed level fades into the next one by itself; otherwise open it.
	if not reached:
		_open_next()


func _open_next() -> void:
	_room = null
	_left = get_tree().current_scene
	var loader := _loader()
	if loader != null and not _queue.is_empty():
		loader.call("load_level", _queue[0])


func _hold(actions: Array) -> void:
	for action: Variant in _held:
		if not action in actions:
			Input.action_release(action)
	for action: Variant in actions:
		if InputMap.has_action(action) and not Input.is_action_pressed(action):
			Input.action_press(action)
	_held = actions.duplicate()


func _release() -> void:
	for action: Variant in _held:
		Input.action_release(action)
	_held = []


func _report(id: String, reached: bool, tick: int, why: String) -> void:
	results.append({"level": id, "reached": reached, "tick": tick})
	if why.is_empty():
		why = ("exit at tick %d" if reached else "no exit after %d ticks") % tick
	_log("%s: %s" % [id, why])
	level_played.emit(id, reached, tick)
	_publish()


func _publish() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.solutionReplay = %s;" % JSON.stringify(
			{"running": not _queue.is_empty(), "results": results}), true)


func _log(line: String) -> void:
	print("%s %s" % [LOG_PREFIX, line])


func _loader() -> Node:
	return get_node_or_null("/root/LevelLoader")


## The request: `?solution=` of the page in the browser, `--solution NAME`
## after `--` elsewhere.
func _request() -> String:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('%s') || ''" % URL_PARAMETER, true)
		return str(value) if value != null else ""
	var args := OS.get_cmdline_user_args()
	var i := args.find(ARGUMENT)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	for arg in args:
		if arg.begins_with(ARGUMENT + "="):
			return arg.trim_prefix(ARGUMENT + "=")
	return ""
