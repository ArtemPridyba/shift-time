class_name Collapse
extends Node2D
## The collapse of level 05 (card docs/levels/05.md, D135): when the runaway
## crane's load slams into the stop at the end of its rail, the hall shakes, the
## girders hanging under the roof beyond the stop fall one by one and land on
## the stubs of old supports as a broken bridge over the pit, then the lamps over
## the pit break one by one from the exit back towards the stop (`CollapsePlan`).
## The bridge exists only in the present, and there it is dark.
##
## A girder is solid only while it lies: falling, or flying back up under
## Shift, it holds nobody, so a Shift held too long on the bridge drops the
## heroine into the pit.
##
## A recorded object: its state is the ticks since the slam (-1 before it),
## held once everything has come down. Under Shift the lamps fly back up first,
## then the girders; after Shift is released the recorded collapse plays again
## (rule «A»). Nothing here can be touched by the player.
## State: { "since": int }. Numbers: `crane.collapse` of the level's entry in
## data/levels.json; the look: `kit_objects.collapse` of data/look.json.
##
## Temporal object contract: docs/architecture.md, section 4.1.

@export var object_id := "collapse"
## Where each girder lies once fallen, in the room's coordinates, from the stop
## towards the exit. Set by the level builder.
@export var girders: Array[Rect2] = []

var since := -1
## Set by tests or read once from the level entry.
var plan: CollapsePlan
var _crane: Crane
var _ceiling_y := 384.0
var _look := {}
var _ticks_per_second := 48.0
var _bodies: Array[StaticBody2D] = []


func _ready() -> void:
	add_to_group("temporal")
	_look = ObjectLook.of("collapse")
	_ticks_per_second = Content.world_ticks_per_second(Content.time())
	var room := get_parent()
	if room != null:
		_crane = room.get_node_or_null("Crane") as Crane
	_plan()
	for rest in girders:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rest.size
		shape.shape = box
		body.position = rest.get_center()
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
	_show()


## The plan of this level, read once from the entry of the parent's scene.
func _plan() -> CollapsePlan:
	if plan != null:
		return plan
	var room := get_parent()
	var entry := Content.level_for_scene(room.scene_file_path if room != null else "")
	var crane: Variant = entry.get("crane", {})
	plan = CollapsePlan.from_data(crane.get("collapse") if crane is Dictionary else null,
		_ticks_per_second, ObjectLook.of("quake"), girders.size())
	_ceiling_y = WorldData.ceiling(WorldData.layout(entry)) * WorldData.CELL
	return plan


func capture_state() -> Dictionary:
	return {"since": since}


func restore_state(state: Dictionary) -> void:
	since = int(state["since"])
	_show()


## Counts from the tick the crane's load has reached the stop.
func simulate_tick(_tick: int) -> void:
	if since >= 0:
		since = mini(since + 1, _plan().last_tick())
	elif _crane != null and _crane.has_slammed():
		since = 0
	_show()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## True while girder `k` lies on its supports and can be stood on.
func girder_lies(k: int) -> bool:
	return _plan().girder_drop(k, since) >= 1.0


## The rect of girder `k` now, in the room's coordinates.
func girder_rect(k: int) -> Rect2:
	var rest := girders[k]
	var hang := _ceiling_y + ObjectLook.number(_look, "hang_below_ceiling_px", 40.0)
	var y := lerpf(hang, rest.position.y, _plan().girder_drop(k, since))
	return Rect2(Vector2(rest.position.x, y), rest.size)


## The fall of world lamp `lamp` now, for `Crane` and `WorldLight`; {} when
## the collapse never touches it.
func lamp_fall(lamp: int) -> Dictionary:
	return _plan().lamp_fall(lamp, since)


## How hard the hall shakes now: 0 to 1, from the slam dying away.
func shake_amount() -> float:
	var ticks := ObjectLook.number(_look, "shake_seconds", 1.2) * _ticks_per_second
	if since < 0 or float(since) >= ticks:
		return 0.0
	var x := float(since) / ticks
	return (1.0 - x) * (1.0 - x)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera == null:
		return
	var amount := shake_amount()
	var t := float(since) / _ticks_per_second * TAU * 9.0
	var px := ObjectLook.number(_look, "shake_px", 8.0) * amount
	camera.offset = Vector2(sin(t) * px, sin(t * 1.37 + 1.1) * px * 0.6)


func _show() -> void:
	for k in _bodies.size():
		var shape := _bodies[k].get_child(0) as CollisionShape2D
		shape.set_deferred("disabled", not girder_lies(k))
	queue_redraw()


## Rusty I-beams: a web with a lighter top flange and rivets; chains to the
## roof while they hang, torn stubs once they fall.
func _draw() -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron", Color("#4c4c53"))
	var light := ObjectLook.color(ObjectLook.mech(), "iron_light", Color("#6c6c72"))
	var dark := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2a30"))
	var rust := ObjectLook.color(_look, "rust", Color("#7a3a22"))
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	var flange := ObjectLook.number(_look, "flange_px", 6.0)
	for k in girders.size():
		var r := girder_rect(k)
		var drop := _plan().girder_drop(k, since)
		for side: float in [0.15, 0.85]:
			var x := r.position.x + r.size.x * side
			var to := r.position.y if drop <= 0.0 else _ceiling_y + ObjectLook.number(_look, "stub_px", 18.0)
			draw_line(Vector2(x, _ceiling_y), Vector2(x, to), chain, 2.0, true)
		draw_rect(r, dark)
		draw_rect(Rect2(r.position + Vector2(4.0, flange), Vector2(r.size.x - 8.0, r.size.y - 2.0 * flange)), iron)
		draw_rect(Rect2(r.position, Vector2(r.size.x, flange)), light)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - flange), Vector2(r.size.x, flange)), dark.lightened(0.1))
		var rivets := int(r.size.x / 24.0)
		for i in rivets:
			var at := Vector2(r.position.x + 12.0 + 24.0 * float(i), r.position.y + flange / 2.0)
			draw_circle(at, 1.6, dark)
		draw_rect(Rect2(r.position + Vector2(r.size.x * 0.3, flange), Vector2(r.size.x * 0.2, 3.0)), rust)
