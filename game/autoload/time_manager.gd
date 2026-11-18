extends Node
## Holds the direction of world time: +1 normally, -1 while `rewind` is held.
## It records nothing and moves nothing. Temporal objects listen to
## `direction_changed`; the player does not, because the player's own time
## always runs forward.
##
## No `class_name`: a class with the autoload's name would hide the singleton.

## Emitted once per change of direction, never on a tick that changes nothing.
signal direction_changed(direction: int)

const FORWARD := 1
const BACKWARD := -1
const ACTION := "rewind"

## +1 while time runs forward, -1 while the world is rewound.
var direction: int:
	get:
		return _direction

## Frames of history the world goes back on this tick: 0 in forward time,
## 1 at the start of a hold and up to `rewind_speed_max` of `data/time.json`
## once Shift has been held long enough (D62).
var rewind_frames: int:
	get:
		return _rewind_frames

## How fast the world rewinds now, 1.0 in forward time: the wrist device runs
## its light faster with it.
var rewind_speed: float:
	get:
		return _rewind.speed

var _direction := FORWARD
var _rewind := RewindSpeed.from_config(Content.time())
var _rewind_frames := 0
## Set by `reset()` while Shift is still held: rewinding stays off until the
## key is released and pressed again.
var _needs_release := false


func _init() -> void:
	# Run before the objects that read the direction, so that a change shows up
	# in the same physics tick.
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	# Polled on the physics tick, not read from key events: tests press actions
	# with `Input.action_press`, which sends no events, and a tick-aligned
	# direction is the same in the game and in a recorded solution.
	var pressed := Input.is_action_pressed(ACTION)
	if not pressed:
		_needs_release = false
	_set_direction(BACKWARD if pressed and not _needs_release else FORWARD)
	_rewind_frames = _rewind.frames_for(_direction)


func is_rewinding() -> bool:
	return _direction == BACKWARD


## Back to forward time, for a level reset. A held Shift does not bring
## rewinding back until it is released.
func reset() -> void:
	_needs_release = Input.is_action_pressed(ACTION)
	_rewind.reset()
	_rewind_frames = 0
	_set_direction(FORWARD)


func _set_direction(new_direction: int) -> void:
	if new_direction == _direction:
		return
	_direction = new_direction
	direction_changed.emit(_direction)
