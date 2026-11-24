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
## A `holdable` platform can be held at its start by a latch (a `Lever` whose
## target is this platform; level 03): while `powered`, a `once` platform that
## has not left its start yet stays there. The latch only holds, it never moves
## the platform: once the platform has left its start, `powered` does nothing.
##
## Dressed from the Night shop kit (task Д4): the plank is the `platform`
## picture (its ends kept, its middle stretched to the width). `track` adds the
## fixed way it rides: "rack" — a toothed column along a vertical path,
## "chain" — a chain between two drums along a horizontal one; a gear on the
## platform and the drums turn by the recorded travel, the chain's links run
## with it, so under Shift they go back exactly. Numbers:
## `kit_objects.platform` of `data/look.json`.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")
const CYCLE_LOOP := "loop"
const CYCLE_ONCE := "once"

@export var object_id := "platform"
@export var travel := Vector2(480, 0)
## True for a platform a latch can hold at its start (see above).
@export var holdable := false
## The platform's width in pixels; 0 keeps the width of its scene (a bridge
## of level 03 is wider).
@export var width := 0.0
## The fixed way the platform rides, drawn behind it: "", "rack" or "chain".
@export var track := ""

## Tick on the path: there, pause, back, pause. In `once` mode: wait, ride, stay.
var phase := 0
var time_direction := 1
## True for a platform that rides one way one time (`"cycle": "once"`).
var once := false
## Set by the latch of a `holdable` platform.
var powered := false
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
	var ticks := Content.world_ticks_per_second(time_data)
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
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if width > 0.0 and shape != null and shape.shape is RectangleShape2D:
		var own := (shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		own.size.x = width
		shape.shape = own
	_base()


## The position comes from the phase, not from the node: with `sync_to_physics`
## the physics server writes the body's transform back a step late, and an
## interference captured outside the tick would record a stale position.
func capture_state() -> Dictionary:
	var state := {"phase": phase, "position": position_at(phase)}
	if holdable:
		state["powered"] = powered
	return state


func restore_state(state: Dictionary) -> void:
	phase = int(state["phase"])
	position = state["position"]
	queue_redraw()
	if holdable:
		powered = bool(state.get("powered", false))


func simulate_tick(_tick: int) -> void:
	if is_held():
		return
	if once:
		phase = mini(phase + 1, once_last_phase())
	else:
		phase = (phase + 1) % cycle_ticks()
	position = position_at(phase)
	queue_redraw()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## True while a latch holds this platform at its start.
func is_held() -> bool:
	return holdable and powered and once and phase <= _delay_ticks


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


## How far the platform is from its start along its path, in pixels, and the
## same as 0…1: mechanisms on it (task Д2) turn by the recorded phase.
func mech_travel() -> float:
	return (position_at(phase) - _base()).length()


func mech_fraction() -> float:
	var full := travel.length()
	return mech_travel() / full if full > 0.0 else 0.0


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
	var plank := ObjectLook.picture("platform")
	if plank != null:
		_draw_kit(plank, size)
		return
	draw_rect(Rect2(-size / 2.0, size), BODY_COLOR)
	draw_rect(Rect2(Vector2(-size.x / 2.0 + 8.0, -size.y / 2.0), Vector2(size.x - 16.0, 6.0)), ACCENT_COLOR)


## The gear on the platform rolls along its track: the travel over its radius.
func gear_angle() -> float:
	var r := ObjectLook.number(ObjectLook.of("platform"), "gear_px", 22.0) / 2.0
	return mech_travel() / maxf(r, 1.0)


func _draw_kit(plank: Texture2D, size: Vector2) -> void:
	var look := ObjectLook.of("platform")
	var top := -size.y / 2.0
	var shift := _base() - position
	var gear := ObjectLook.picture("shutter_gear_small")
	var gear_px := ObjectLook.number(look, "gear_px", 22.0)
	var tint := ObjectLook.color(look, "track_tint", Color.WHITE)
	if track == "rack":
		var rack := ObjectLook.picture("platform_rack")
		var w := ObjectLook.number(look, "rack_px", 18.0)
		var y0 := shift.y + minf(0.0, travel.y) - ObjectLook.number(look, "track_above_px", 64.0)
		var y1 := shift.y + maxf(0.0, travel.y) + ObjectLook.number(look, "track_below_px", 64.0)
		if rack != null:
			ObjectLook.draw_region_down(self, rack, Rect2(Vector2.ZERO, rack.get_size()),
					Rect2(shift.x - w / 2.0, y0, w, y1 - y0), tint)
	elif track == "chain":
		var chain := ObjectLook.picture("platform_chain")
		var h := ObjectLook.number(look, "chain_px", 10.0)
		var x0 := shift.x + minf(0.0, travel.x)
		var x1 := shift.x + maxf(0.0, travel.x)
		var y := top + ObjectLook.number(look, "chain_below_px", 12.0)
		if chain != null:
			ObjectLook.draw_region_across(self, chain, Rect2(Vector2.ZERO, chain.get_size()),
					Rect2(x0, y - h / 2.0, x1 - x0, h), tint, -mech_travel() * signf(travel.x))
		if gear != null:
			for x: float in [x0, x1]:
				ObjectLook.draw_turned(self, gear, Vector2(x, y), Vector2(gear_px, gear_px), gear_angle() * signf(travel.x), tint)
	var plank_h := float(plank.get_height()) / ObjectLook.texel("platform")
	_draw_plank(plank, Rect2(-size.x / 2.0, top, size.x, plank_h), ObjectLook.number(look, "cap_px", 24.0))
	if track == "rack" and gear != null:
		ObjectLook.draw_turned(self, gear, Vector2(0.0, top + plank_h), Vector2(gear_px, gear_px), gear_angle())


## The plank with its ends as drawn and its middle stretched between them.
func _draw_plank(plank: Texture2D, r: Rect2, cap: float) -> void:
	var texel := float(plank.get_height()) / maxf(r.size.y, 1.0)
	var cap_tex := cap * texel
	var w := float(plank.get_width())
	var h := float(plank.get_height())
	cap = minf(cap, r.size.x / 2.0)
	draw_texture_rect_region(plank, Rect2(r.position, Vector2(cap, r.size.y)), Rect2(0, 0, cap_tex, h))
	draw_texture_rect_region(plank, Rect2(r.position + Vector2(cap, 0.0), Vector2(r.size.x - 2.0 * cap, r.size.y)),
			Rect2(cap_tex, 0, w - 2.0 * cap_tex, h))
	draw_texture_rect_region(plank, Rect2(Vector2(r.end.x - cap, r.position.y), Vector2(cap, r.size.y)),
			Rect2(w - cap_tex, 0, cap_tex, h))
