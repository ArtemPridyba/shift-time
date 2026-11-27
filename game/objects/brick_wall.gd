class_name BrickWall
extends Node2D
## The bricked-up doorway before the exit of level 04 (card docs/levels/04.md,
## session 2): a recorded object across the rails. A minecart whose front meets
## it bounces back, unless it carries at least `minecart.break_load` pigs of
## iron: then it breaks through (`meet_cart`), the bricks fly out ahead of it
## in a cloud of dust and the cart jolts. The break is a change of the room
## (`apply_change`): left of the head of history it is interference and cuts a
## branch.
##
## Under Shift after the break the bricks fly back into the wall. The cart
## already past its face never meets it again: only a front that crosses the
## face counts, so the wall rebuilding behind the cart never crushes it.
##
## State recorded: { "broken": int } — 0 whole; from 1 the bricks fly, up to
## 1000 when they lie still.
##
## Numbers: `brick_wall` in data/objects.json. Temporal object contract:
## docs/architecture.md, section 4.1.

const BROKEN_MAX := 1000
const BRICK_COLOR := Color("#8a3b2a")
const MORTAR_COLOR := Color("#3a2a24")
const DUST_COLOR := Color("#b9a48c")

@export var object_id := "wall"
## The wall's size in pixels; the node's position is its bottom middle, on
## the rails.
@export var size := Vector2(32.0, 256.0)

var broken := 0

var _params := {}
var _step := 40


func _init() -> void:
	_params = Content.objects().get("brick_wall", {})
	var ticks := Content.world_ticks_per_second(Content.time())
	_step = maxi(int(ceil(float(BROKEN_MAX) / maxf(_number("burst_seconds") * ticks, 1.0))), 1)


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("rail_barrier")


func capture_state() -> Dictionary:
	return {"broken": broken}


func restore_state(state: Dictionary) -> void:
	broken = int(state["broken"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if broken > 0 and broken < BROKEN_MAX:
		broken = mini(broken + _step, BROKEN_MAX)
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func is_whole() -> bool:
	return broken == 0


## The wall in the parent's coordinates.
func rect() -> Rect2:
	return Rect2(position - Vector2(size.x / 2.0, size.y), size)


## A minecart's front swept `sweep` this tick (parent's coordinates). A whole
## wall stops it ("bounce") or, `heavy` with its load, breaks ("break");
## a broken one lets it pass (""). The room is an argument, never kept.
func meet_cart(room: Object, sweep: Rect2, heavy: bool) -> String:
	if broken > 0 or not rect().intersects(sweep):
		return ""
	if not heavy:
		return "bounce"
	room.call("apply_change", object_id, {"broken": 1})
	broken = maxi(broken, 1)
	queue_redraw()
	return "break"


func _draw() -> void:
	var w := size.x
	var h := size.y
	var brick := _number("brick_px")
	var rows := maxi(int(h / (brick * 0.5)), 1)
	var row_h := h / float(rows)
	var u := float(broken) / float(BROKEN_MAX)
	var fly := _number("fly_px")
	for r in rows:
		for c in 2:
			var cell := Rect2(Vector2(-w / 2.0 + c * w / 2.0, -h + r * row_h), Vector2(w / 2.0, row_h))
			if broken > 0:
				# Each brick flies out ahead (left) and falls, by its own seed.
				var seed := float((r * 7 + c * 13) % 11) / 10.0
				var out := Vector2(-fly * (0.4 + 0.6 * seed), 0.0) * u
				out.y += fly * 0.8 * u * u * (0.3 + seed)
				cell.position += out
				cell.position.y = minf(cell.position.y, -row_h)
			draw_rect(cell.grow(-1.0), BRICK_COLOR)
			draw_rect(cell, MORTAR_COLOR, false, 2.0)
	if broken > 0 and broken < BROKEN_MAX:
		# Dust, thinning out as the bricks settle.
		var alpha := 0.6 * (1.0 - u)
		for i in 6:
			var at := Vector2(-w / 2.0 - fly * 0.5 * u * (0.3 + 0.12 * i), -h * (0.15 + 0.13 * i))
			draw_circle(at, 18.0 + 30.0 * u, DUST_COLOR * Color(1, 1, 1, alpha))


func _number(key: String) -> float:
	var value: Variant = _params.get(key, 0.0)
	return float(value) if value is float or value is int else 0.0
