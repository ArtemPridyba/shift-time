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
## `"start": "open"` or `"closed"` (the default), and may give it a latch:
## `"delay_seconds"` (world seconds) before it starts to close once its target
## turned to closed (shutter Z of level 04). A latched shutter records two
## more numbers: `aim`, the target it has taken up, and `hold`, world ticks
## left before it moves.
##
## A shutter closing onto a minecart (level 04) waits above the cart and its
## rider, as it waits for the heroine; it never cuts through them. A shutter
## in the group `rail_barrier` stops a cart whose front meets its blade
## (`meet_cart`).
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
## True when it stands over rails and stops a minecart (shutter Z, level 04).
@export var bars_carts := false

var closed := CLOSED_MAX
var target := CLOSED_MAX

var aim := CLOSED_MAX
var hold := 0

var carry_margin := 8.0
var _step := 40
## World ticks of the latch before it closes; 0 means no latch.
var _delay_ticks := 0
var _ticks_per_second := 48.0
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
	_ticks_per_second = ticks
	var seconds := float(shutter_data.get("move_seconds", 0.6))
	_step = maxi(int(ceil(float(CLOSED_MAX) / maxf(seconds * ticks, 1.0))), 1)


func apply_settings(settings: Dictionary) -> void:
	var start := CLOSED_MAX
	if str(settings.get("start", START_CLOSED)) == START_OPEN:
		start = 0
	closed = start
	target = start
	aim = start
	hold = 0
	var delay: Variant = settings.get("delay_seconds", 0.0)
	if delay is float or delay is int:
		_delay_ticks = maxi(int(round(float(delay) * _ticks_per_second)), 0)
	_apply()


func _ready() -> void:
	add_to_group("temporal")
	if bars_carts:
		add_to_group("rail_barrier")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	_base()
	_apply()


func capture_state() -> Dictionary:
	if _delay_ticks > 0:
		return {"closed": closed, "target": target, "aim": aim, "hold": hold}
	return {"closed": closed, "target": target}


func restore_state(state: Dictionary) -> void:
	closed = int(state["closed"])
	target = int(state["target"])
	aim = int(state.get("aim", target))
	hold = int(state.get("hold", 0))
	_apply()


func simulate_tick(_tick: int) -> void:
	if aim != target:
		# A new target: the latch holds a closing for its delay, never an opening.
		aim = target
		hold = _delay_ticks if target > closed else 0
	if hold > 0:
		hold -= 1
		_apply()
		return
	if closed < aim:
		var next := mini(closed + _step, aim)
		if not _onto_cart(rect_at(next)):
			closed = next
	elif closed > aim:
		closed = maxi(closed - _step, aim)
	_apply()


## True when `rect` would come down on a minecart of this room or its rider.
func _onto_cart(rect: Rect2) -> bool:
	if not is_inside_tree():
		return false
	var room := get_parent()
	for cart in get_tree().get_nodes_in_group("minecart"):
		if room != null and cart.get_parent() == room and cart.has_method("outline_rect"):
			if rect.intersects(cart.call("outline_rect")):
				return true
	return false


## A minecart's front swept `sweep` this tick (parent's coordinates):
## "bounce" if it meets the blade, "" if it goes on (group `rail_barrier`).
func meet_cart(_room: Object, sweep: Rect2, _heavy: bool) -> String:
	return "bounce" if rect_at(closed).intersects(sweep) else ""


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
