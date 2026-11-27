class_name TimeWorld
extends RefCounted
## The rules of world time for one room (docs/architecture.md, section 2).
##
## Every physics tick `tick()` moves the cursor of the room's `Timeline`:
## - rewinding and the cursor above the start: `frames` frames back (one, or
##   more once a long hold has sped up, `RewindSpeed`), objects restore the last;
## - rewinding at the start: the world stands still (pinned at frame 0);
## - forward left of the head: one frame forward, the recorded future replays (rule «A»);
## - forward at the head: objects simulate one tick and a new frame is recorded;
##   when nothing changed, no frame is written and the head stands (STILL, D56).
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

enum Step { STARTED, RECORDED, STILL, REWOUND, REPLAYED, PINNED, WAITED }

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


## The present state of `objects`, as a frame of the history.
func recorder_capture(objects: Array) -> Dictionary:
	return _recorder.capture(objects)


## One physics tick. `direction` is +1 or -1 (TimeManager). `player_rect` is
## the player's body in world pixels; an empty rect means there is no player
## (prelude, tests), and nothing can be crushed. `frames` is how many frames a
## rewinding tick goes back; each of them is checked for crushing, and the
## rewind stops before the first that would crush the player.
func tick(direction: int, objects: Array, player_rect: Rect2 = Rect2(), frames: int = 1) -> Step:
	if timeline.is_empty():
		start(objects)
		return Step.STARTED
	if direction < 0:
		return _rewind(objects, player_rect, maxi(frames, 1))
	if not timeline.at_head():
		timeline.step_forward()
		return _show_or_wait(objects, player_rect, Step.REPLAYED, timeline.step_back)
	var before := _recorder.capture(objects)
	var tick_number := timeline.world_tick() + 1
	for object in objects:
		if object is Object and object.has_method("simulate_tick"):
			object.call("simulate_tick", tick_number)
	var after := _recorder.capture(objects)
	if crushes(after, objects, player_rect):
		_recorder.restore(before, objects)
		return Step.WAITED
	if timeline.same_as_head(after):
		timeline.hold()
		return Step.STILL
	timeline.record(after)
	return Step.RECORDED


## True when this tick ran at the head: recorded, or still with nothing to record.
static func at_head_step(step: Step) -> bool:
	return step == Step.RECORDED or step == Step.STILL


## Runs the room without the player for `ticks` ticks, recording every frame
## (the prelude, section 2.2). `events` are the scripted events of the level
## (`prelude_events_from_data`): an event on tick k changes the frame recorded
## k ticks after the prelude starts (0 is the starting frame). The prelude
## runs at the head, so an event is ordinary recording, never a branch.
## Events of one tick apply in their order in the data.
func run_prelude(objects: Array, ticks: int, events: Array = []) -> void:
	_apply_events(objects, events, 0)
	for i in maxi(ticks, 0):
		tick(FORWARD, objects)
		_apply_events(objects, events, i + 1)


## The scripted events of a level's entry in `levels.json`, with their second
## turned into a tick: {"tick": k, "press": id} presses an interaction point as
## the player would (a lever with all its targets), {"tick": k, "id": id,
## "state": {...}} sets fields of an object's state (a manipulator, a reverse
## item baked into the prelude).
static func prelude_events_from_data(events: Variant, ticks_per_second: float) -> Array:
	var result := []
	if not events is Array:
		return result
	for event: Variant in events:
		if not event is Dictionary:
			continue
		var data := event as Dictionary
		var out := {"tick": int(round(float(data.get("second", 0.0)) * ticks_per_second))}
		if data.has("press"):
			out["press"] = str(data["press"])
		else:
			out["id"] = str(data.get("id", ""))
			out["state"] = (data.get("state", {}) as Dictionary).duplicate(true)
		result.append(out)
	return result


func _apply_events(objects: Array, events: Array, at_tick: int) -> void:
	var changed := false
	for event: Variant in events:
		var data := event as Dictionary
		if int(data.get("tick", -1)) != at_tick:
			continue
		var changes: Array = []
		if data.has("press"):
			var source := _object(objects, str(data["press"]))
			if source != null and source.has_method("get_interaction_change"):
				changes = source.call("get_interaction_change", objects)
		else:
			changes = [{"id": str(data.get("id", "")), "state": data.get("state", {})}]
		for change: Variant in changes:
			var target := _object(objects, str((change as Dictionary).get("id", "")))
			if target == null:
				continue
			var state: Dictionary = (target.call("capture_state") as Dictionary).duplicate(true)
			state.merge(((change as Dictionary).get("state", {}) as Dictionary).duplicate(true), true)
			target.call("restore_state", state)
			changed = true
	if not changed:
		return
	if timeline.is_empty():
		timeline.record(_recorder.capture(objects))
	else:
		timeline.replace_current(_recorder.capture(objects))


func _object(objects: Array, object_id: String) -> Object:
	for object in objects:
		if object is Object and str((object as Object).get("object_id")) == object_id:
			return object
	return null


## The player changed a recorded object (button, lever, valve).
func player_action(objects: Array, object_id: String, new_state: Dictionary) -> bool:
	return _interfere(objects, object_id, new_state)


## A live source (a reverse item) changed a recorded object. Once per contact
## is the source's job.
func live_action(objects: Array, object_id: String, new_state: Dictionary) -> bool:
	return _interfere(objects, object_id, new_state)


## The live player let an item go (task 2.7): the item had been in the
## player's hands, so its frames before the cursor hold nothing it could
## rewind along. They all get its present state: under Shift the item stays
## where it was let go, as the world does at frame 0, and never jumps.
func rewrite_past(objects: Array, object_id: String) -> bool:
	var target := _object(objects, object_id)
	if target == null or timeline.is_empty():
		return false
	timeline.rewrite_past(object_id, (target.call("capture_state") as Dictionary).duplicate(true))
	return true


## The live player took or put down an item without changing the room's
## history (D175): every kept frame gets the item's present state; nothing is
## cut. Returns false when there is no such object.
func rewrite_all(objects: Array, object_id: String) -> bool:
	var target := _object(objects, object_id)
	if target == null:
		return false
	if timeline.is_empty():
		start(objects)
	timeline.rewrite_all(object_id, (target.call("capture_state") as Dictionary).duplicate(true))
	return true


## Like `rewrite_past`, but only the frames where the object's state had
## `flag` set (`Timeline.rewrite_past_where`).
func rewrite_past_where(objects: Array, object_id: String, flag: String) -> bool:
	var target := _object(objects, object_id)
	if target == null or timeline.is_empty():
		return false
	timeline.rewrite_past_where(object_id, (target.call("capture_state") as Dictionary).duplicate(true), flag)
	return true


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


func _rewind(objects: Array, player_rect: Rect2, frames: int) -> Step:
	var moved := 0
	for i in frames:
		if timeline.at_start():
			break
		var back := timeline.cursor() if timeline.held() > 0 else timeline.cursor() - 1
		if crushes(timeline.frame_at(back), objects, player_rect):
			if moved == 0:
				return Step.WAITED
			break
		timeline.step_back()
		moved += 1
	if moved == 0:
		return Step.PINNED
	_recorder.restore(timeline.current(), objects)
	return Step.REWOUND


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
