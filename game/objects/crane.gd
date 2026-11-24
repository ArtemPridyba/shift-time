class_name Crane
extends Node2D
## The runaway overhead crane of level 09 (card docs/levels/09.md): a trolley
## on a rail under the roof, its hook over the middle of the load, two slings
## from the hook down to the load. The load is a `once` platform of the room
## (`crane.load` of the level's entry in data/levels.json) that carries the
## heroine; on its way the hook strikes the hanging lamps and they fall
## (`CranePlan`). `WorldLight` asks `lamp_fall` here, as it asks `Quakes`.
##
## Like a mechanism, the crane keeps no history: what it draws and which lamp
## has fallen come from the load's recorded phase, so under Shift the load
## rides back, the lamps fly up and the light comes back without a jump, and
## after Shift is released the same strikes play again (rule «A»).
## The look: `kit_objects.crane` of data/look.json.

## Set by tests or read once from the level entry.
var plan: CranePlan
var _load: MovingPlatform
## The winch of one lamp (`Winch`), when the level has one.
var _winch: Winch
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
	if _winch != null and _winch.lamp == lamp and not _winch.torn:
		# Wound up under the roof, or still hanging low before the hook comes.
		var hanging := plan.lamp_fall(lamp, -1)
		hanging["lift"] = _winch.lift_px()
		return hanging
	return plan.lamp_fall(lamp, _load.phase)


## True while the hook is at lamp `lamp` (`CranePlan.strikes`), for the winch.
func strikes(lamp: int) -> bool:
	_aim()
	return plan != null and _load != null and plan.strikes(lamp, _load.phase)


## The crane never swings a lamp; only `Quakes` do.
func swing(_lamp: int) -> float:
	return 0.0


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
		if child is Winch:
			_winch = child
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
