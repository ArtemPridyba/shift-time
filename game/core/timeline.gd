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
## Pure rules: no nodes, no UI, no references to the game or the level.

const MIN_CAPACITY := 2

var _capacity: int
var _slots: Array = []
var _first := 0   # number of the oldest kept frame
var _head := -1   # number of the newest frame, -1 while the history is empty
var _cursor := -1


func _init(capacity: int) -> void:
	_capacity = maxi(capacity, MIN_CAPACITY)
	_slots.resize(_capacity)


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


func at_start() -> bool:
	return is_empty() or _cursor == _first


## Writes a new frame after the head. Only allowed at the head: a change in the
## past goes through `branch()` first. Returns false and changes nothing when
## the cursor is left of the head.
func record(frame: Dictionary) -> bool:
	if not at_head():
		return false
	_head += 1
	_slots[_head % _capacity] = frame.duplicate(true)
	_cursor = _head
	if size() > _capacity:
		_first += 1
	return true


## The frame at the cursor (a copy), or an empty Dictionary while empty.
func current() -> Dictionary:
	if is_empty():
		return {}
	return (_slots[_cursor % _capacity] as Dictionary).duplicate(true)


## One frame back. Returns false at the start of the history: the cursor stays
## on the oldest frame and nothing breaks.
func step_back() -> bool:
	if at_start():
		return false
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
	_head = _cursor


## Writes `frame` over the frame at the cursor. Only allowed at the head (after
## `branch()` the cursor is the head): an interference rewrites the present of
## the new branch. Returns false and changes nothing elsewhere or while empty.
func replace_current(frame: Dictionary) -> bool:
	if is_empty() or not at_head():
		return false
	_slots[_cursor % _capacity] = frame.duplicate(true)
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


## Forgets everything.
func clear() -> void:
	_slots.fill(null)
	_first = 0
	_head = -1
	_cursor = -1
