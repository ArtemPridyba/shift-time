class_name Door
extends AnimatableBody2D
## A recorded door that slides up to open. Place it closed in the scene; `travel`
## is how far it rises when fully open.
##
## Two operating modes, determined by whether `linked_id` is set:
##   - Standalone (no linked_id): runs its own open/hold/close/hold cycle from
##     `data/objects.json` — the behaviour before task 2.1.
##   - Powered (linked_id set): a button or lever drives the door through
##     `powered` in the state dict. `simulate_tick` opens the door when
##     `powered` is true and closes it when false. The cycle fields are still
##     used for the speed of opening/closing; hold times are ignored.
##     The door is registered in the room as the target of `linked_id`.
##
## A level may change a door through `objects` of its entry in
## `data/levels.json` (`apply_settings`): other cycle seconds, and
## `"cycle": "once"` for a door that starts open, waits `hold_open_seconds`,
## closes in `close_seconds` and then stays closed (level 01), and
## `"cycle": "opens_once"` for a door that starts closed, waits `delay_seconds`,
## opens in `open_seconds` and then stays open (the gate of level 03). Both run
## by the door's own phase, so a new branch of history plays them again.
##
## Dressed from the Night shop kit (task Д4): the blade is a strip of the
## steel shutter `shutter_slab` with its rack and yellow-black stripes. A door
## with `housing_height` hangs under a fixed brick housing in a riveted frame
## (D115, `docs/art/gemini/ref_shutter.jpg`) and rises into it; a wheel and a
## gear on the housing turn by the recorded `open`, so under Shift they turn
## back with the blade. Numbers: `kit_objects.shutter` of `data/look.json`.
## Without the kit picture the blockout look stays: a grey blade and a gauge
## ring beside the doorway that fills as the door opens.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")
## `open` runs from 0 (closed) to this (fully open).
const OPEN_MAX := 1000
const CYCLE_LOOP := "loop"
const CYCLE_ONCE := "once"
const CYCLE_OPENS_ONCE := "opens_once"
const GAUGE_OFFSET := Vector2(-40.0, -28.0)
const GAUGE_RADIUS := 12.0
const GAUGE_WIDTH := 5.0
const GAUGE_BACK_COLOR := Color("#23272d")

@export var object_id := "door"
@export var travel := 192.0
## The height of the door in pixels; 0 keeps the 192 of door.tscn. Doors are
## about 120 px next to the 94 px heroine (D82, 20.11.2026).
@export var height := 0.0
## The width of the door in pixels; 0 keeps the 32 of door.tscn.
@export var width := 0.0
## When set, this door is driven by a button or lever with this object_id.
## The cycle runs for looks (open/close speed) but hold times are ignored.
@export var linked_id := ""
## Height in pixels of the brick housing over the closed blade; 0: no housing.
## The housing is drawn over the room's ground (z 1), so the blade hides in it.
@export var housing_height := 0.0
## Width of the housing; 0: twice the blade.
@export var housing_width := 0.0

var open := 0
var locked := false
## Tick on the door's own cycle (unused in powered mode, kept for round-trip).
var phase := 0
## True when the linked control is active. Only present in state when linked_id != "".
var powered := false
## True for a door that closes once and stays closed (`"cycle": "once"`).
var once := false
## True for a door that opens once and stays open (`"cycle": "opens_once"`).
var opens_once := false
## +1 or -1, from TimeManager through TimeWorld; for looks and sound later.
var time_direction := 1
## The bottom of the player's body this deep inside the door is riding it, not
## being crushed: a door that rises under the hero's feet carries the hero like
## a platform. Same value as the platform's (`carry_margin_px` in objects.json).
var carry_margin := 8.0

var _closed_position := Vector2.ZERO
var _has_base := false
var _open_ticks := 1
var _hold_open_ticks := 1
var _close_ticks := 1
var _hold_closed_ticks := 1
## Ticks an `opens_once` door waits closed before it opens.
var _delay_ticks := 0
## The level's picture has the housing (`world.backdrop`, D131): {"clip_y",
## "wheel": [x, y, size], "gear": [x, y, size]} in room pixels; empty when the
## kit draws it.
var _painted := {}


func _init() -> void:
	sync_to_physics = true
	var data := Content.objects()
	configure(data.get("door", {}), Content.time())
	carry_margin = float(data.get("carry_margin_px", 8))


## Reads the cycle from data: seconds into ticks.
func configure(door_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := Content.world_ticks_per_second(time_data)
	_open_ticks = maxi(int(round(float(door_data.get("open_seconds", 3)) * ticks)), 1)
	_hold_open_ticks = maxi(int(round(float(door_data.get("hold_open_seconds", 4)) * ticks)), 1)
	_close_ticks = maxi(int(round(float(door_data.get("close_seconds", 3)) * ticks)), 1)
	_hold_closed_ticks = maxi(int(round(float(door_data.get("hold_closed_seconds", 4)) * ticks)), 1)
	_delay_ticks = maxi(int(round(float(door_data.get("delay_seconds", 0)) * ticks)), 0)


## Settings of this door from the level's entry in `data/levels.json`: any of
## the cycle seconds, and `cycle` ("loop" or "once"). A door that runs once
## starts fully open at the beginning of its hold.
func apply_settings(settings: Dictionary) -> void:
	var door_data: Dictionary = (Content.objects().get("door", {}) as Dictionary).duplicate()
	door_data.merge(settings, true)
	configure(door_data, Content.time())
	once = str(settings.get("cycle", CYCLE_LOOP)) == CYCLE_ONCE
	opens_once = str(settings.get("cycle", CYCLE_LOOP)) == CYCLE_OPENS_ONCE
	if opens_once:
		phase = 0
		open = 0
		_apply()
	if once:
		phase = _open_ticks
		open = OPEN_MAX
		_apply()


func _ready() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if (height > 0.0 or width > 0.0) and shape != null and shape.shape is RectangleShape2D:
		var own := (shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		if height > 0.0:
			own.size.y = height
		if width > 0.0:
			own.size.x = width
		shape.shape = own
	if housing_height > 0.0:
		z_index = 1
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_base()


func capture_state() -> Dictionary:
	var state := {"open": open, "locked": locked, "phase": phase}
	if linked_id != "":
		state["powered"] = powered
	return state


func restore_state(state: Dictionary) -> void:
	open = int(state["open"])
	locked = bool(state["locked"])
	phase = int(state["phase"])
	if linked_id != "":
		powered = bool(state.get("powered", false))
	_apply()


func simulate_tick(_tick: int) -> void:
	if locked:
		return
	if linked_id != "":
		# Powered mode: open toward OPEN_MAX when powered, close toward 0 when not.
		var step := int(round(float(OPEN_MAX) / maxf(float(_open_ticks), 1.0)))
		if powered:
			open = mini(open + step, OPEN_MAX)
		else:
			open = maxi(open - step, 0)
	else:
		# Standalone cycle mode.
		if opens_once:
			phase = mini(phase + 1, _delay_ticks + _open_ticks)
			open = opens_once_at(phase)
			_apply()
			return
		if once:
			phase = mini(phase + 1, cycle_ticks() - 1)
		else:
			phase = (phase + 1) % cycle_ticks()
		open = open_at(phase)
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## True when the door in `state` would overlap the player (rects in the
## parent's coordinates) above the feet: standing on a rising door is riding,
## anything deeper (a door coming down on the head, a wall at the side) crushes.
## Touching is not overlapping.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, carry_margin))
	return rect_at(int(state["open"])).intersects(body)


func cycle_ticks() -> int:
	return _open_ticks + _hold_open_ticks + _close_ticks + _hold_closed_ticks


## How open an `opens_once` door is at a tick: closed for its delay, then
## opening, then open for good.
func opens_once_at(cycle_phase: int) -> int:
	var p := cycle_phase - _delay_ticks
	if p <= 0:
		return 0
	return int(round(float(OPEN_MAX) * mini(p, _open_ticks) / _open_ticks))


## How open the door is at a tick of its cycle: opening, open, closing, closed.
func open_at(cycle_phase: int) -> int:
	var p := cycle_phase
	if p < _open_ticks:
		return int(round(float(OPEN_MAX) * p / _open_ticks))
	p -= _open_ticks
	if p < _hold_open_ticks:
		return OPEN_MAX
	p -= _hold_open_ticks
	if p < _close_ticks:
		return int(round(float(OPEN_MAX) * (_close_ticks - p) / _close_ticks))
	return 0


## The door's body in the parent's coordinates when it is `amount` open.
func rect_at(amount: int) -> Rect2:
	var size := _size()
	return Rect2(_base() + Vector2(-size.x / 2.0, -size.y / 2.0 - travel * amount / OPEN_MAX), size)


## How far the door has moved from closed, in pixels, and the same as 0…1:
## mechanisms on it (task Д2) turn by the recorded `open`, never by their own
## clock.
func mech_travel() -> float:
	return travel * float(open) / float(OPEN_MAX)


func mech_fraction() -> float:
	return float(open) / float(OPEN_MAX)


func _apply() -> void:
	position = _base() + Vector2(0.0, -travel * open / OPEN_MAX)
	queue_redraw()


func _base() -> Vector2:
	if not _has_base:
		_closed_position = position
		_has_base = true
	return _closed_position


func _size() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size
	return Vector2(32, 192)


func _draw() -> void:
	var size := _size()
	var slab := ObjectLook.picture("shutter_slab")
	if slab != null:
		_draw_kit(slab, size)
		return
	draw_rect(Rect2(-size / 2.0, size), BODY_COLOR)
	draw_rect(Rect2(Vector2(-4.0, -size.y / 2.0 + 8.0), Vector2(8.0, size.y - 16.0)), ACCENT_COLOR)
	# The gauge stays on the wall above the doorway while the door slides.
	var ratio := float(open) / OPEN_MAX
	var center := Vector2(GAUGE_OFFSET.x, -size.y / 2.0 + GAUGE_OFFSET.y + travel * ratio)
	draw_arc(center, GAUGE_RADIUS, 0.0, TAU, 32, GAUGE_BACK_COLOR, GAUGE_WIDTH + 4.0)
	if ratio > 0.0:
		draw_arc(center, GAUGE_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, ACCENT_COLOR, GAUGE_WIDTH)


## The housing's rect in this node's coordinates: it stays where it is while
## the blade moves.
func housing_rect() -> Rect2:
	var size := _size()
	var w := housing_width if housing_width > 0.0 else size.x * 2.0
	return Rect2(Vector2(-w / 2.0, -size.y / 2.0 - housing_height + mech_travel()), Vector2(w, housing_height))


## A point of the room (the level's pixels) in this body's coordinates.
func _room_point(at: Vector2) -> Vector2:
	var level := get_parent() as Node2D
	return to_local(level.to_global(at) if level != null else at)


## The part of `r` below `cut`, showing the same part of `region`.
func _draw_below(slab: Texture2D, r: Rect2, region: Rect2, cut: float) -> void:
	var top := clampf(cut, r.position.y, r.end.y)
	if top >= r.end.y:
		return
	var scale := region.size.x / maxf(r.size.x, 0.001)
	var from := (top - r.position.y) * scale
	var h := minf((r.end.y - top) * scale, region.size.y - from)
	if h <= 0.0:
		return
	draw_texture_rect_region(slab, Rect2(r.position.x, top, r.size.x, h / scale),
			Rect2(region.position + Vector2(0.0, from), Vector2(region.size.x, h)))


## Under the painted gearbox (24.11, level 01 notes): the blade is the long
## strip of the shutter (`painted_blade_region`) hanging up to the gearbox at
## every travel, so no gap opens between a closed blade and the housing. With
## a painted `gear` its rack meshes with that gear: the gear turns by the
## blade's travel (rolling without slip) and the wheel with it.
func _draw_painted(slab: Texture2D, blade: Rect2, _blade_region: Rect2, stripe_rect: Rect2, stripes: Rect2) -> void:
	var look := ObjectLook.of("shutter")
	var cut := _room_point(Vector2(0.0, float(_painted.get("clip_y", -100000.0)))).y
	var long_region := ObjectLook.rect(look, "painted_blade_region", Rect2(0, 0, 64, 512))
	var long_h := blade.size.x * long_region.size.y / maxf(long_region.size.x, 0.001)
	var hanging := Rect2(blade.position.x, blade.end.y - long_h, blade.size.x, long_h)
	_draw_below(slab, hanging, long_region, cut)
	_draw_below(slab, stripe_rect, stripes, cut)
	var wheel_data: Variant = _painted.get("wheel")
	if not wheel_data is Array or (wheel_data as Array).size() != 3:
		return
	var wheel := ObjectLook.picture("shutter_wheel")
	var gear := ObjectLook.picture("shutter_gear_small")
	var wheel_px := float(wheel_data[2])
	var hub := _room_point(Vector2(float(wheel_data[0]), float(wheel_data[1])))
	var angle := wheel_angle()
	var gear_data: Variant = _painted.get("gear")
	if _meshes_painted_gear():
		var gear_size := float(gear_data[2])
		if gear != null:
			var gear_at := _room_point(Vector2(float(gear_data[0]), float(gear_data[1])))
			ObjectLook.draw_turned(self, gear, gear_at, Vector2(gear_size, gear_size), -mech_travel() / maxf(gear_size / 2.0, 1.0))
	elif gear != null:
		var gear_px := wheel_px * ObjectLook.number(look, "gear_px", 22.0) / maxf(ObjectLook.number(look, "wheel_px", 40.0), 1.0)
		var at := hub + Vector2(wheel_px / 2.0 - 2.0, wheel_px / 2.0 - gear_px / 2.0 + 2.0)
		ObjectLook.draw_turned(self, gear, at, Vector2(gear_px, gear_px), -angle * wheel_px / gear_px)
	if wheel != null:
		ObjectLook.draw_turned(self, wheel, hub, Vector2(wheel_px, wheel_px), angle)


## The wheel's angle on the housing: `wheel_turns` turns from closed to open;
## over a painted gear it rolls with the gear that drives the rack, so it turns
## by the blade's travel over its own radius.
func wheel_angle() -> float:
	if _meshes_painted_gear():
		return mech_travel() / maxf(float((_painted["wheel"] as Array)[2]) / 2.0, 1.0)
	return mech_fraction() * ObjectLook.number(ObjectLook.of("shutter"), "wheel_turns", 1.5) * TAU


## True when the level's picture has the gear whose teeth drive the rack.
func _meshes_painted_gear() -> bool:
	var wheel: Variant = _painted.get("wheel")
	var gear: Variant = _painted.get("gear")
	return wheel is Array and (wheel as Array).size() == 3 and gear is Array and (gear as Array).size() == 3


## The level's picture has the housing (D131): the blade hides above
## `clip_y` under the painted gearbox, the wheel turns over the painted one.
func use_backdrop(config: Dictionary) -> void:
	_painted = config
	queue_redraw()


func _draw_kit(slab: Texture2D, size: Vector2) -> void:
	var look := ObjectLook.of("shutter")
	var blade := Rect2(-size / 2.0, size)
	var blade_region := ObjectLook.rect(look, "blade_region", Rect2(0, 96, 64, 256))
	var stripes := ObjectLook.rect(look, "stripe_region", Rect2(64, 452, 64, 44))
	var stripe_h := size.x * stripes.size.y / maxf(stripes.size.x, 1.0)
	var stripe_rect := Rect2(blade.position.x, blade.end.y - stripe_h, size.x, stripe_h)
	if not _painted.is_empty():
		_draw_painted(slab, blade, blade_region, stripe_rect, stripes)
		return
	ObjectLook.draw_region_down(self, slab, blade_region, blade)
	draw_texture_rect_region(slab, stripe_rect, stripes)
	if housing_height <= 0.0:
		return
	var mech := ObjectLook.mech()
	var iron := Color(str(mech.get("iron_shadow", "#35353a")))
	var rivet := Color(str(mech.get("iron_light", "#6c6c72")))
	var box := housing_rect()
	var brick := ObjectLook.tile("brick")
	var texel := ObjectLook.texel("brick")
	var room := Rect2(box.position + position, box.size)
	draw_texture_rect_region(brick, box, KitTextures.region(room, texel),
			ObjectLook.color(look, "brick_tint", Color("#8a7a72")))
	ObjectLook.draw_riveted_frame(self, box, ObjectLook.number(look, "housing_frame_px", 6.0), iron, rivet,
			ObjectLook.number(look, "rivet_px", 2.5), ObjectLook.number(look, "rivet_step_px", 14.0))
	var wheel := ObjectLook.picture("shutter_wheel")
	var gear := ObjectLook.picture("shutter_gear_small")
	var wheel_px := ObjectLook.number(look, "wheel_px", 40.0)
	var gear_px := ObjectLook.number(look, "gear_px", 22.0)
	var hub := Vector2(0.0, box.end.y - wheel_px / 2.0 - 4.0)
	var angle := wheel_angle()
	if gear != null:
		var at := hub + Vector2(wheel_px / 2.0 - 2.0, wheel_px / 2.0 - gear_px / 2.0 + 2.0)
		ObjectLook.draw_turned(self, gear, at, Vector2(gear_px, gear_px), -angle * wheel_px / gear_px)
	if wheel != null:
		ObjectLook.draw_turned(self, wheel, hub, Vector2(wheel_px, wheel_px), angle)
