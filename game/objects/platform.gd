class_name MovingPlatform
extends AnimatableBody2D
## A recorded platform that rides from where it is placed to `start + travel`
## and back, with a pause at each end. Speed and pause come from
## `data/objects.json`. With `sync_to_physics` the player rides it both ways.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")

@export var object_id := "platform"
@export var travel := Vector2(480, 0)

## Tick on the path: there, pause, back, pause.
var phase := 0
var time_direction := 1
## The bottom of the player's body this deep inside the platform is riding it,
## not being crushed.
var carry_margin := 8.0

var _start := Vector2.ZERO
var _has_base := false
## Pixels per tick along the path.
var _step := 2.0
var _pause_ticks := 1


func _init() -> void:
	sync_to_physics = true
	var data := Content.objects()
	configure(data.get("platform", {}), Content.time())
	carry_margin = float(data.get("carry_margin_px", 8))


func configure(platform_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	_step = maxf(float(platform_data.get("speed", 120)), 1.0) / ticks
	_pause_ticks = maxi(int(round(float(platform_data.get("pause_seconds", 4)) * ticks)), 1)


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


func position_at(cycle_phase: int) -> Vector2:
	var moving := move_ticks()
	var p := cycle_phase
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
