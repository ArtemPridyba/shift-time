class_name Winch
extends Node2D
## The winch of one lamp in level 09 (card docs/levels/09.md, D131): a drum on
## a column in the lower hall, its cable up the column, along the roof and
## down to the lamp. A lever powers it (`powered`): the drum winds the lamp up
## into a hatch in the roof, so the crane's hook passes under it. A lamp still
## hanging low while the hook passes is torn down together with its power
## cable, the cable that feeds the exit door and its beacon (group
## `exit_power`): then the door stays shut, and the torn end sparks.
##
## Recorded object: under Shift the drum unwinds, the lamp flies back and the
## cable heals; after Shift is released the recorded history plays again
## (rule «A»). Only a pull of the lever in the past, before the hook comes,
## keeps the light and the door (interference).
##
## State recorded: { "powered": bool, "lift": int (0..FULL), "torn": bool }.
## Numbers: `crane.winch` of the level's entry in data/levels.json; the look:
## `kit_objects.winch` of data/look.json.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const FULL := 1000

@export var object_id := "winch"
## Where the power cable ends: the exit beacon, in the room's coordinates.
@export var power_to := Vector2.ZERO
## The floor under the lamp, in the room's coordinates: the torn end's sparks die there.
@export var floor_y := 896.0

var powered := false
var lift := 0
var torn := false
## The lamp of `world.lamps` this winch holds; set from the data.
var lamp := -1

var _lift_px := 80.0
var _step := 1
var _crane: Crane
var _anchor := Vector2.ZERO
var _ceiling_y := 384.0
var _look := {}
var _wire: SparkingWire


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("exit_power")
	_look = ObjectLook.of("winch")
	var room := get_parent()
	if room != null:
		_crane = room.get_node_or_null("Crane") as Crane
		_configure(Content.level_for_scene(room.scene_file_path))
	_wire = SparkingWire.new()
	_wire.name = "TornCable"
	_wire.position = to_local(_anchor)
	_wire.end = Vector2(ObjectLook.number(_look, "torn_end_x", 12.0), ObjectLook.number(_look, "torn_end_y", 60.0))
	_wire.floor_y = floor_y - _anchor.y
	_wire.visible = false
	add_child(_wire)


func _configure(entry: Dictionary) -> void:
	var crane: Variant = entry.get("crane", {})
	var data: Variant = crane.get("winch", {}) if crane is Dictionary else {}
	if not data is Dictionary:
		return
	lamp = int(data.get("lamp", -1))
	_lift_px = float(data.get("lift_px", 80.0))
	var ticks := float(data.get("lift_seconds", 1.0)) * Content.world_ticks_per_second(Content.time())
	_step = maxi(int(ceil(float(FULL) / maxf(ticks, 1.0))), 1)
	var layout := WorldData.layout(entry)
	var ceiling := WorldData.ceiling(layout)
	_ceiling_y = ceiling * WorldData.CELL
	var lamps: Array = layout.get("lamps", [])
	if lamp >= 0 and lamp < lamps.size():
		_anchor = Vector2(WorldData.lamp_at(lamps[lamp], ceiling).x, _ceiling_y)


## How far the lamp is wound up now, in pixels.
func lift_px() -> float:
	return _lift_px * float(lift) / float(FULL)


## True while the power cable is whole: the exit door may open, its beacon turns.
func feeds_power() -> bool:
	return not torn


func capture_state() -> Dictionary:
	return {"powered": powered, "lift": lift, "torn": torn}


func restore_state(state: Dictionary) -> void:
	powered = bool(state.get("powered", powered))
	lift = int(state.get("lift", lift))
	torn = bool(state.get("torn", torn))
	_show()


func simulate_tick(_tick: int) -> void:
	lift = clampi(lift + (_step if powered else -_step), 0, FULL)
	# The hook tears a lamp that is not wound fully up while it passes.
	if not torn and lift < FULL and _crane != null and _crane.strikes(lamp):
		torn = true
	_show()


func on_time_direction_changed(_direction: int) -> void:
	pass


## The winch is not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func _show() -> void:
	if _wire != null:
		_wire.visible = torn
	queue_redraw()


func _draw() -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var cable := ObjectLook.color(_look, "cable_color", Color("#1d1a18"))
	var width := ObjectLook.number(_look, "cable_px", 2.0)
	var radius := ObjectLook.number(_look, "drum_px", 14.0)
	var hatch_w := ObjectLook.number(_look, "hatch_px", 34.0)
	var anchor := to_local(_anchor)
	var top := to_local(Vector2(global_position.x, _ceiling_y))
	# The hatch in the roof the lamp is wound up into.
	var hatch_h := _lift_px + 14.0
	draw_rect(Rect2(anchor + Vector2(-hatch_w / 2.0, -hatch_h), Vector2(hatch_w, hatch_h)), ObjectLook.color(_look, "hatch_color", Color("#0b0b0f")))
	draw_rect(Rect2(anchor + Vector2(-hatch_w / 2.0 - 3.0, -3.0), Vector2(hatch_w + 6.0, 4.0)), iron)
	# The winch cable: up the column from the drum, along the roof to the hatch.
	draw_line(Vector2(radius, 0.0), Vector2(radius, top.y), cable, width, true)
	draw_line(Vector2(radius, top.y + 2.0), anchor + Vector2(0.0, 2.0), cable, width, true)
	# The power cable to the exit beacon: whole, or torn off at the hatch.
	var power := ObjectLook.color(_look, "power_color", Color("#3b2a1c"))
	var to := to_local(power_to)
	var from := anchor + Vector2(hatch_w / 2.0 + (ObjectLook.number(_look, "torn_gap_px", 30.0) if torn else 0.0), 6.0)
	draw_line(from, Vector2(to.x, from.y), power, width + 1.0, true)
	draw_line(Vector2(to.x, from.y), to + Vector2(0.0, -6.0), power, width + 1.0, true)
	# The drum: its spokes turn with the wound cable, backwards under Shift.
	var angle := float(lift) / float(FULL) * ObjectLook.number(_look, "drum_turns", 3.0) * TAU
	draw_circle(Vector2.ZERO, radius, iron)
	var rim := iron.lightened(0.35)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, rim, 2.0, true)
	for k in 3:
		draw_line(Vector2.ZERO, Vector2.from_angle(angle + float(k) * TAU / 3.0) * (radius - 2.0), rim, 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, ObjectLook.color(ObjectLook.mech(), "yellow", Color("#d4a21e")))
