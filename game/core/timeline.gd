class_name Timeline
extends RefCounted
## The history of one room: a bounded ring of frames, a cursor and a head.
##
## A frame is a Dictionary `object_id -> state` (plain types only). Frames are
## numbered with growing integers. The head is the newest frame, the cursor is
## the frame the world shows now. At the head the world simulates and records;
## left of the head it only replays. When the ring is full, the oldest frame is
## dropped and the cursor never goes left of the oldest kept frame.
##
## A tick on which nothing in the room changed writes no frame (D56 «а»): the
## head stands and counts the still ticks (`hold()`). So the start of the
## history is never lost while the player thinks, and a rewind skips the still
## time at once. Every frame keeps its world tick: the number of ticks the
## world lived to it, still ones included. Decoration and the ticks stored in
## states run on that clock (`world_tick()`), so they keep moving while the
## room stands.
##
## Pure rules: no nodes, no UI, no references to the game or the level.

const MIN_CAPACITY := 2

var _capacity: int
var _slots: Array = []
var _ticks: Array = []   # the world tick of every slot
var _first := 0   # number of the oldest kept frame
var _head := -1   # number of the newest frame, -1 while the history is empty
var _cursor := -1
var _held := 0    # still ticks after the head frame; only at the head


func _init(capacity: int) -> void:
	_capacity = maxi(capacity, MIN_CAPACITY)
	_slots.resize(_capacity)
	_ticks.resize(_capacity)


## How many frames `time.json` asks the history to hold.
static func capacity_for(time_data: Dictionary) -> int:
	var seconds := float(time_data.get("history_seconds", 20))
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	var every := maxf(float(time_data.get("snapshot_every_ticks", 1)), 1.0)
	return maxi(int(round(seconds * ticks / every)), MIN_CAPACITY)


static func from_config(time_data: Dictionary) -> Timeline:
	return Timeline.new(capacity_for(time_data))


func capacity() -> int:
	return _capacity


## Number of frames kept now.
func size() -> int:
	return _head - _first + 1


func is_empty() -> bool:
	return _head < _first


## Number of the oldest kept frame.
func first() -> int:
	return _first


## Number of the newest frame; -1 while empty.
func head() -> int:
	return _head


## Number of the frame the world shows; -1 while empty.
func cursor() -> int:
	return _cursor


func at_head() -> bool:
	return _cursor == _head


## True when nothing is left to rewind: the cursor is on the oldest frame and
## no still ticks are held after it.
func at_start() -> bool:
	return is_empty() or (_cursor == _first and held() == 0)


## Writes a new frame after the head. Only allowed at the head: a change in the
## past goes through `branch()` first. Returns false and changes nothing when
## the cursor is left of the head. The frame's world tick is one after the
## present (the head frame plus its still ticks).
func record(frame: Dictionary) -> bool:
	if not at_head():
		return false
	var tick := 0 if is_empty() else world_tick() + 1
	_append(frame, tick)
	return true


## True when `frame` is the same as the head frame: the room did not change.
func same_as_head(frame: Dictionary) -> bool:
	return not is_empty() and _slots[_head % _capacity] == frame


## One still tick at the head: no frame is written, the head frame stands for
## one more tick of world time. Returns false away from the head or while empty.
func hold() -> bool:
	if is_empty() or not at_head():
		return false
	_held += 1
	return true


## Still ticks the head frame stands for after its own tick; 0 left of the head.
func held() -> int:
	return _held if at_head() else 0


## The world tick the room shows now: the tick of the frame at the cursor, plus
## the still ticks at the head. -1 while empty.
func world_tick() -> int:
	if is_empty():
		return -1
	return int(_ticks[_cursor % _capacity]) + held()


## The world tick of kept frame `number`; -1 outside the kept frames.
func tick_of(number: int) -> int:
	if number < _first or number > _head:
		return -1
	return int(_ticks[number % _capacity])


func _append(frame: Dictionary, tick: int) -> void:
	_head += 1
	_slots[_head % _capacity] = frame.duplicate(true)
	_ticks[_head % _capacity] = tick
	_cursor = _head
	_held = 0
	if size() > _capacity:
		_first += 1


## The frame at the cursor (a copy), or an empty Dictionary while empty.
func current() -> Dictionary:
	if is_empty():
		return {}
	return (_slots[_cursor % _capacity] as Dictionary).duplicate(true)


## One field of one object in kept frame `number`, read without copying the
## frame (the sound reads many frames a tick, D183); null where the frame, the
## object or the field is missing. Do not change what it returns.
func peek(number: int, object_id: String, field: String) -> Variant:
	if number < _first or number > _head:
		return null
	var state: Variant = (_slots[number % _capacity] as Dictionary).get(object_id)
	return (state as Dictionary).get(field) if state is Dictionary else null


## A copy of kept frame `number`, or an empty Dictionary outside the kept frames.
func frame_at(number: int) -> Dictionary:
	if number < _first or number > _head:
		return {}
	return (_slots[number % _capacity] as Dictionary).duplicate(true)


## One frame back. Returns false at the start of the history: the cursor stays
## on the oldest frame and nothing breaks.
## The still ticks at the head go back first, all in one step: they held no
## change, so the frame stays and only the world tick moves back to it (D56).
func step_back() -> bool:
	if at_start():
		return false
	if held() > 0:
		_held = 0
		return true
	_cursor -= 1
	return true


## One frame forward. Returns false at the head.
func step_forward() -> bool:
	if at_head():
		return false
	_cursor += 1
	return true


## Cuts everything right of the cursor: the cursor becomes the head, and the
## old future is never replayed. Recording continues from here.
func branch() -> void:
	if is_empty():
		return
	for number in range(_cursor + 1, _head + 1):
		_slots[number % _capacity] = null
	if _cursor != _head:
		_held = 0
	_head = _cursor


## Writes `frame` over the frame at the cursor. Only allowed at the head (after
## `branch()` the cursor is the head): an interference rewrites the present of
## the new branch. Returns false and changes nothing elsewhere or while empty.
## When the head stands for still ticks, its frame is also the past of those
## ticks: then `frame` is written after it, on the tick of the present.
func replace_current(frame: Dictionary) -> bool:
	if is_empty() or not at_head():
		return false
	if _held > 0:
		_append(frame, world_tick())
		return true
	_slots[_cursor % _capacity] = frame.duplicate(true)
	return true


## Writes `state` as the state of `object_id` in every kept frame, past and
## future. Used when the live player takes or puts down an item nothing else
## depends on (the valve of level 02, D175): the room's history stays, only
## the item's own frames change, so it never jumps under Shift or on a replay.
func rewrite_all(object_id: String, state: Dictionary) -> void:
	if is_empty():
		return
	for number in range(_first, _head + 1):
		var frame: Dictionary = _slots[number % _capacity]
		frame[object_id] = state.duplicate(true)


## Writes `state` as the state of `object_id` in kept frame `number` only.
## Used when what depends on an item is re-derived along the recorded future
## without cutting the room's history (the pit and the door under the valve of
## level 02, D175). Returns false outside the kept frames.
func write_at(number: int, object_id: String, state: Dictionary) -> bool:
	if number < _first or number > _head:
		return false
	(_slots[number % _capacity] as Dictionary)[object_id] = state.duplicate(true)
	return true


## Writes `state` as the state of `object_id` in every kept frame left of the
## cursor. Used when the live player lets an item go: the item has no past of
## its own before that moment (docs/architecture.md, section 2.5).
func rewrite_past(object_id: String, state: Dictionary) -> void:
	if is_empty():
		return
	for number in range(_first, _cursor):
		var frame: Dictionary = _slots[number % _capacity]
		frame[object_id] = state.duplicate(true)


## Writes `state` as the state of `object_id` only in the kept frames left of
## the cursor where its recorded state has `flag` set: a torch put back on its
## stand takes back the frames it spent in the hands, and its own past on the
## stand before them stays as it was (level 03, D177).
func rewrite_past_where(object_id: String, state: Dictionary, flag: String) -> void:
	if is_empty():
		return
	for number in range(_first, _cursor):
		var frame: Dictionary = _slots[number % _capacity]
		var old: Variant = frame.get(object_id)
		if old is Dictionary and bool((old as Dictionary).get(flag, false)):
			frame[object_id] = state.duplicate(true)


## Forgets everything.
func clear() -> void:
	_slots.fill(null)
	_ticks.fill(null)
	_first = 0
	_held = 0
	_head = -1
	_cursor = -1
