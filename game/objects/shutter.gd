class_name Shutter
extends AnimatableBody2D
## A recorded shutter driven by time plates (level 04, D118): it moves toward
## its `target`, closed or open, and stays there. Standing, it is a wall that
## rises into the ceiling to open; lying, it is a hatch over a pit that slides
## into the floor to open. Place it closed in the scene; `travel` is where it
## goes when fully open, relative to closed.
##
## A plate stepped on in normal time sets the target to closed; stepped on
## with Shift held, to open (`TimePlate`). The shutter keeps no other rule.
##
## State recorded: { "closed": int 0…1000, "target": int 0 or 1000 }.
## A level picks the start in `objects` of its entry in `data/levels.json`:
## `"start": "open"` or `"closed"` (the default).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const CLOSED_MAX := 1000
const START_OPEN := "open"
const START_CLOSED := "closed"
const BODY_COLOR := Color("#6b717a")
const EDGE_COLOR := Color("#3c4148")
const STRIPE_COLOR := Color("#d9b400")

@export var object_id := "shutter"
## Where the shutter goes when fully open, from its closed place, in pixels.
@export var travel := Vector2(0.0, -128.0)
@export var size := Vector2(32.0, 128.0)
## The letter shared with its plate, drawn on both (blockout look).
@export var label := ""

var closed := CLOSED_MAX
var target := CLOSED_MAX

var carry_margin := 8.0
var _step := 40
var _closed_position := Vector2.ZERO
var _has_base := false


func _init() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	# The stowed shutter hides inside the ceiling or the floor blocks.
	z_index = -1
	var data := Content.objects()
	carry_margin = float(data.get("carry_margin_px", 8))
	configure(data.get("shutter", {}), Content.time())


## Seconds of a full move into a step per world tick (D96).
func configure(shutter_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := Content.world_ticks_per_second(time_data)
	var seconds := float(shutter_data.get("move_seconds", 0.6))
	_step = maxi(int(ceil(float(CLOSED_MAX) / maxf(seconds * ticks, 1.0))), 1)


func apply_settings(settings: Dictionary) -> void:
	var start := CLOSED_MAX
	if str(settings.get("start", START_CLOSED)) == START_OPEN:
		start = 0
	closed = start
	target = start
	_apply()


func _ready() -> void:
	add_to_group("temporal")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	_base()
	_apply()


func capture_state() -> Dictionary:
	return {"closed": closed, "target": target}


func restore_state(state: Dictionary) -> void:
	closed = int(state["closed"])
	target = int(state["target"])
	_apply()


func simulate_tick(_tick: int) -> void:
	if closed < target:
		closed = mini(closed + _step, target)
	elif closed > target:
		closed = maxi(closed - _step, target)
	_apply()


func on_time_direction_changed(_direction: int) -> void:
	pass


## True when the shutter in `state` would overlap the player above the feet:
## standing on a hatch is riding, a wall coming down on her head waits.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, carry_margin))
	return rect_at(int(state["closed"])).intersects(body)


func is_open() -> bool:
	return closed == 0


## The body in the parent's coordinates when it is `amount` closed.
func rect_at(amount: int) -> Rect2:
	var offset := travel * float(CLOSED_MAX - amount) / float(CLOSED_MAX)
	return Rect2(_base() + offset - size / 2.0, size)


## How far the shutter has moved from closed, 0…1, for mechanisms on it.
func mech_fraction() -> float:
	return float(CLOSED_MAX - closed) / float(CLOSED_MAX)


func _apply() -> void:
	position = _base() + travel * mech_fraction()
	queue_redraw()


func _base() -> Vector2:
	if not _has_base:
		_closed_position = position
		_has_base = true
	return _closed_position


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect, EDGE_COLOR, false, 3.0)
	# Hazard stripes on the leading edge: the edge that meets the floor or the
	# far side of the pit, so the closing reads by shape.
	var stripe := Rect2(rect.position, Vector2(rect.size.x, 10.0)) if travel.y < 0.0 else Rect2(rect.position, Vector2(10.0, rect.size.y))
	if travel.y < 0.0:
		stripe.position.y = rect.end.y - 10.0
	draw_rect(stripe, STRIPE_COLOR)
	if label != "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-8.0, 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, 16.0, 22, Color.WHITE)
