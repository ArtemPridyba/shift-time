class_name TimeWorld
extends RefCounted
## The rules of world time for one room (docs/architecture.md, section 2).
##
## Every physics tick `tick()` moves the cursor of the room's `Timeline`:
## - rewinding and the cursor above the start: one frame back, objects restore it;
## - rewinding at the start: the world stands still (pinned at frame 0);
## - forward left of the head: one frame forward, the recorded future replays (rule «A»);
## - forward at the head: objects simulate one tick and a new frame is recorded.
## Before a frame is shown, solid objects are asked whether it would crush the
## player; if so the world waits on this tick (section 2.3).
## An interference (`player_action`, `live_action`) left of the head cuts the
## future (`Timeline.branch()`) and writes the new state at the cursor.
##
## The objects come as an argument on every call: the world keeps no reference
## to them, to the level or to the game.

## The directions, the same numbers as TimeManager; `core/` does not refer to it.
const FORWARD := 1
const BACKWARD := -1

enum Step { STARTED, RECORDED, REWOUND, REPLAYED, PINNED, WAITED }

var timeline: Timeline
var _recorder := TemporalRecorder.new()


func _init(history: Timeline) -> void:
	timeline = history


static func from_config(time_data: Dictionary) -> TimeWorld:
	return TimeWorld.new(Timeline.from_config(time_data))


## Records the present of the objects as the first frame. `tick()` calls it by
## itself while the history is empty.
func start(objects: Array) -> void:
	timeline.clear()
	timeline.record(_recorder.capture(objects))


## One physics tick. `direction` is +1 or -1 (TimeManager). `player_rect` is
## the player's body in world pixels; an empty rect means there is no player
## (prelude, tests), and nothing can be crushed.
func tick(direction: int, objects: Array, player_rect: Rect2 = Rect2()) -> Step:
	if timeline.is_empty():
		start(objects)
		return Step.STARTED
	if direction < 0:
		if not timeline.step_back():
			return Step.PINNED
		return _show_or_wait(objects, player_rect, Step.REWOUND, timeline.step_forward)
	if not timeline.at_head():
		timeline.step_forward()
		return _show_or_wait(objects, player_rect, Step.REPLAYED, timeline.step_back)
	var before := _recorder.capture(objects)
	var tick_number := timeline.head() + 1
	for object in objects:
		if object is Object and object.has_method("simulate_tick"):
			object.call("simulate_tick", tick_number)
	var after := _recorder.capture(objects)
	if crushes(after, objects, player_rect):
		_recorder.restore(before, objects)
		return Step.WAITED
	timeline.record(after)
	return Step.RECORDED


## Runs the room without the player for `ticks` ticks, recording every frame
## (the prelude, section 2.2).
func run_prelude(objects: Array, ticks: int) -> void:
	for i in maxi(ticks, 0):
		tick(FORWARD, objects)


## The player changed a recorded object (button, lever, valve).
func player_action(objects: Array, object_id: String, new_state: Dictionary) -> bool:
	return _interfere(objects, object_id, new_state)


## A live source (a reverse item) changed a recorded object. Once per contact
## is the source's job.
func live_action(objects: Array, object_id: String, new_state: Dictionary) -> bool:
	return _interfere(objects, object_id, new_state)


## True when a solid object, put into its state from `frame`, would overlap the
## player in a way it is not allowed to (`blocks_player_at`).
func crushes(frame: Dictionary, objects: Array, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	for object in objects:
		if not object is Object or not object.has_method("blocks_player_at"):
			continue
		var id := str(object.get("object_id"))
		if frame.has(id) and object.call("blocks_player_at", frame[id], player_rect):
			return true
	return false


func _show_or_wait(objects: Array, player_rect: Rect2, done: Step, undo: Callable) -> Step:
	var frame := timeline.current()
	if crushes(frame, objects, player_rect):
		undo.call()
		return Step.WAITED
	_recorder.restore(frame, objects)
	return done


func _interfere(objects: Array, object_id: String, new_state: Dictionary) -> bool:
	if timeline.is_empty():
		start(objects)
	for object in objects:
		if object is Object and str(object.get("object_id")) == object_id:
			object.call("restore_state", new_state.duplicate(true))
			timeline.branch()
			timeline.replace_current(_recorder.capture(objects))
			return true
	return false
