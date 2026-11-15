class_name MovingPlatform
extends AnimatableBody2D
## A recorded platform that rides from where it is placed to `start + travel`
## and back, with a pause at each end. Speed and pause come from
## `data/objects.json`. With `sync_to_physics` the player rides it both ways.
##
## A level may change a platform through `objects` of its entry in
## `data/levels.json` (`apply_settings`): other `speed` and `pause_seconds`, and
## `"cycle": "once"` for a platform that waits `delay_seconds` at its start,
## rides to `start + travel` one time and then stays there (level 01).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")
const CYCLE_LOOP := "loop"
const CYCLE_ONCE := "once"

@export var object_id := "platform"
@export var travel := Vector2(480, 0)

## Tick on the path: there, pause, back, pause. In `once` mode: wait, ride, stay.
var phase := 0
var time_direction := 1
## True for a platform that rides one way one time (`"cycle": "once"`).
var once := false
## The bottom of the player's body this deep inside the platform is riding it,
## not being crushed.
var carry_margin := 8.0

var _start := Vector2.ZERO
var _has_base := false
## Pixels per tick along the path.
var _step := 2.0
var _pause_ticks := 1
## Ticks a `once` platform waits at its start before it rides.
var _delay_ticks := 0


func _init() -> void:
	sync_to_physics = true
	var data := Content.objects()
	configure(data.get("platform", {}), Content.time())
	carry_margin = float(data.get("carry_margin_px", 8))


func configure(platform_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	_step = maxf(float(platform_data.get("speed", 120)), 1.0) / ticks
	_pause_ticks = maxi(int(round(float(platform_data.get("pause_seconds", 4)) * ticks)), 1)
	_delay_ticks = maxi(int(round(float(platform_data.get("delay_seconds", 0)) * ticks)), 0)


## Settings of this platform from the level's entry in `data/levels.json`: any
## of `speed`, `pause_seconds`, `delay_seconds`, and `cycle` ("loop" or "once").
func apply_settings(settings: Dictionary) -> void:
	var platform_data: Dictionary = (Content.objects().get("platform", {}) as Dictionary).duplicate()
	platform_data.merge(settings, true)
	configure(platform_data, Content.time())
	once = str(settings.get("cycle", CYCLE_LOOP)) == CYCLE_ONCE


func _ready() -> void:
	_base()


## The position comes from the phase, not from the node: with `sync_to_physics`
## the physics server writes the body's transform back a step late, and an
## interference captured outside the tick would record a stale position.
func capture_state() -> Dictionary:
	return {"phase": phase, "position": position_at(phase)}


func restore_state(state: Dictionary) -> void:
	phase = int(state["phase"])
	position = state["position"]


func simulate_tick(_tick: int) -> void:
	if once:
		phase = mini(phase + 1, once_last_phase())
	else:
		phase = (phase + 1) % cycle_ticks()
	position = position_at(phase)


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## True when the platform in `state` would overlap the player's body above the
## feet: standing on it is riding, anything deeper is crushing.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, carry_margin))
	return rect_at(state["position"]).intersects(body)


func cycle_ticks() -> int:
	return 2 * (move_ticks() + _pause_ticks)


## Ticks for one way along the path (`travel` is set by the scene after _init).
func move_ticks() -> int:
	return maxi(int(ceil(travel.length() / _step)), 1)


## The tick on which a `once` platform has arrived and stays for good.
func once_last_phase() -> int:
	return _delay_ticks + move_ticks()


func position_at(cycle_phase: int) -> Vector2:
	var moving := move_ticks()
	var p := cycle_phase
	if once:
		if p < _delay_ticks:
			return _base()
		p -= _delay_ticks
		if p >= moving:
			return _base() + travel
		return _base() + travel * (float(p) / moving)
	if p < moving:
		return _base() + travel * (float(p) / moving)
	p -= moving
	if p < _pause_ticks:
		return _base() + travel
	p -= _pause_ticks
	if p < moving:
		return _base() + travel * (float(moving - p) / moving)
	return _base()


func rect_at(at: Vector2) -> Rect2:
	var size := _size()
	return Rect2(at - size / 2.0, size)


func _base() -> Vector2:
	if not _has_base:
		# Ride from where the platform is placed in the scene.
		_start = position
		_has_base = true
	return _start


func _size() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size
	return Vector2(192, 32)


func _draw() -> void:
	var size := _size()
	draw_rect(Rect2(-size / 2.0, size), BODY_COLOR)
	draw_rect(Rect2(Vector2(-size.x / 2.0 + 8.0, -size.y / 2.0), Vector2(size.x - 16.0, 6.0)), ACCENT_COLOR)
