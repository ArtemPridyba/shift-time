class_name Crane
extends Node2D
## The runaway overhead crane of level 05 (card docs/levels/05.md): a trolley
## on a rail under the roof, its hook over the middle of the load, two slings
## from the hook down to the load. The load is a `once` platform of the room
## (`crane.load` of the level's entry in data/levels.json) that carries the
## heroine, or a ram that carries nobody (D139); on its way the hook strikes the
## hanging lamps and they fall (`CranePlan`), or the ram knocks the girders of
## the gallery off and their lamps fall with them (`Collapse`). `WorldLight` asks `lamp_fall` here, as it asks `Quakes`.
##
## Like a mechanism, the crane keeps no history: what it draws and which lamp
## has fallen come from the load's recorded phase, so under Shift the load
## rides back, the lamps fly up and the light comes back without a jump, and
## after Shift is released the same strikes play again (rule «A»).
## The look: `kit_objects.crane` of data/look.json.

## Set by tests or read once from the level entry.
var plan: CranePlan
var _load: MovingPlatform
## The gallery its ram knocks down (`Collapse`), when the level has one.
var _collapse: Collapse
var _look := {}
var _ceiling_y := 384.0
var _rail := Rect2()


func _ready() -> void:
	_look = ObjectLook.of("crane")


func _process(_delta: float) -> void:
	queue_redraw()


## The load platform, found by its object id among the room's children.
func load_platform() -> MovingPlatform:
	_aim()
	return _load


## The fall of lamp `lamp` now, for `WorldLight`: {} when the crane never strikes it.
func lamp_fall(lamp: int) -> Dictionary:
	_aim()
	if plan == null or _load == null:
		return {}
	if _collapse != null:
		var with_girder := _collapse.lamp_fall(lamp)
		if not with_girder.is_empty():
			return with_girder
	return plan.lamp_fall(lamp, _load.phase)


## True once the load has reached the stop at the end of the rail.
func has_slammed() -> bool:
	_aim()
	return _load != null and _load.phase >= _load.once_last_phase()


## A lamp swings while the hall shakes after the slam (`Collapse`).
func swing(lamp: int) -> float:
	if _collapse == null:
		return 0.0
	var amount := _collapse.shake_amount()
	return deg_to_rad(ObjectLook.number(ObjectLook.of("quake"), "swing_degrees", 7.0)) * amount * sin(float(_collapse.slam) * 0.17 + float(lamp) * 0.9)


func _aim() -> void:
	if plan != null and _load != null:
		return
	var room := get_parent()
	if room == null:
		return
	var entry := Content.level_for_scene(room.scene_file_path)
	var ticks := Content.world_ticks_per_second(Content.time())
	if plan == null:
		plan = CranePlan.from_data(entry.get("crane"), ticks, ObjectLook.of("quake"))
	for child in room.get_children():
		if child is MovingPlatform and (child as MovingPlatform).object_id == plan.load_id:
			_load = child
		if child is Collapse:
			_collapse = child
	if _load == null:
		return
	var layout := WorldData.layout(entry)
	_ceiling_y = WorldData.ceiling(layout) * WorldData.CELL
	var lamp_x: Array = []
	for lamp: Variant in layout.get("lamps", []):
		lamp_x.append(WorldData.lamp_at(lamp, WorldData.ceiling(layout)).x)
	var start := _load.position_at(0)
	var end := _load.position_at(_load.once_last_phase())
	var delay := _load.once_last_phase() - _load.move_ticks()
	plan.aim(start.x, end.x, delay, _load.move_ticks(), lamp_x)
	var beam_px := ObjectLook.number(_look, "rail_px", 14.0)
	var over := ObjectLook.number(_look, "rail_over_px", 64.0)
	var left := minf(start.x, end.x) - over
	_rail = Rect2(left, _ceiling_y, absf(end.x - start.x) + 2.0 * over, beam_px)


func _draw() -> void:
	_aim()
	if _load == null:
		return
	var iron := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var beam := ObjectLook.picture("crane_beam")
	if beam != null:
		KitTextures.draw_across(self, beam, _rail)
	else:
		draw_rect(_rail, iron)
	# The stop at the end of the rail the load slams into, on the side it rides to.
	var stop_px := ObjectLook.number(_look, "stop_px", 18.0)
	var over := ObjectLook.number(_look, "rail_over_px", 64.0)
	var to_right := _load.travel.x >= 0.0
	var stop_x := _rail.end.x - over + 12.0 if to_right else _rail.position.x + over - 12.0 - stop_px
	var stop := Rect2(Vector2(stop_x, _rail.end.y), Vector2(stop_px, stop_px * 2.0))
	draw_rect(stop, ObjectLook.color(ObjectLook.mech(), "yellow", Color("#d4a21e")).darkened(0.35))
	var x := _load.position.x
	var hook := ObjectLook.picture("crane")
	var size := Vector2(hook.get_size()) / ObjectLook.texel("crane") if hook != null else Vector2(20, 45)
	var hook_top := _rail.end.y - 2.0
	if hook != null:
		draw_texture_rect(hook, Rect2(Vector2(x - size.x / 2.0, hook_top), size), false)
	else:
		draw_rect(Rect2(Vector2(x - size.x / 2.0, hook_top), size), iron)
	# Two slings from the hook down to the ends of the load.
	var cable := ObjectLook.color(_look, "cable_color", iron)
	var width := ObjectLook.number(_look, "cable_px", 2.0)
	var inset := ObjectLook.number(_look, "sling_inset_px", 10.0)
	var hook_end := Vector2(x, hook_top + size.y - ObjectLook.number(_look, "hook_eye_px", 6.0))
	var load_rect := _load.rect_at(_load.position)
	for side in [-1.0, 1.0]:
		var foot := Vector2(x + side * (load_rect.size.x / 2.0 - inset), load_rect.position.y + 2.0)
		draw_line(hook_end, foot, cable, width, true)
