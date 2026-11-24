class_name Collapse
extends Node2D
## The gallery of level 05 «Crane» (card docs/levels/05.md, D139): girders hang
## from the crane's rail as a walkway, each with its lamp on its chain. The
## runaway crane's ram knocks each girder off as it reaches it, from the far end
## of the rail back towards the start; the girder falls and its lamp falls with
## it (`CollapsePlan`). Some girders land on stubs or on the floor; the lost
## ones fall to the bottom of the pit and hold nobody.
##
## A girder holds the heroine while it hangs, while it lies, and while it rises
## back under Shift, carrying her: a fallen girder is a lift back up (the one
## knocked last rises first). Coming down in normal time it holds nobody: she
## falls off it. A girder never crushes her: the world waits instead. The crane's stop lever (`Lever`
## on the crane's load, `MovingPlatform.brake`) pulled in the past stops the
## crane in the new history: the girders ahead of it keep hanging.
##
## A recorded object: its state is the ticks since the ram knocked each girder
## (-1 while it hangs) and since the crane slammed into its stop. Under Shift
## the girders rise back and the lamps come back on; after Shift is released the
## recorded collapse plays again (rule «A»).
## State: { "since": Array[int], "slam": int }. Numbers: `crane.collapse` of the
## level's entry in data/levels.json; the look: `kit_objects.collapse` of
## data/look.json.
##
## Temporal object contract: docs/architecture.md, section 4.1.

@export var object_id := "collapse"
## Where each girder hangs from the rail, in the room's coordinates, from the
## crane's start towards its stop (the order the ram reaches them is by x).
@export var girders: Array[Rect2] = []
## Where each girder lies once fallen.
@export var rests: Array[Rect2] = []
## Indices of girders lost to the bottom of the pit: once down, they hold nobody.
@export var lost := PackedInt32Array()

var since: Array[int] = []
var slam := -1
## Set by tests or read once from the level entry.
var plan: CollapsePlan
## The load phase on which the ram reaches each girder (-1: never).
var hits: Array[int] = []
var _crane: Crane
var _ceiling_y := 384.0
var _look := {}
var _bodies: Array[AnimatableBody2D] = []
## The direction of world time: girders on their way down hold her only backwards.
var _direction := 1
## Pixels of the player's feet inside a girder that are standing, not crushing:
## the kit's margin plus the most a girder moves in one tick, so a girder
## rising under her carries her instead of making the world wait.
var _carry_margin := 8.0


func _ready() -> void:
	add_to_group("temporal")
	_look = ObjectLook.of("collapse")
	_carry_margin = float(Content.objects().get("carry_margin_px", 8))
	var room := get_parent()
	if room != null:
		_crane = room.get_node_or_null("Crane") as Crane
	_plan()
	var fastest := 0.0
	for k in mini(girders.size(), rests.size()):
		# It sinks as x² over the last 0.7 of its fall: the speed peaks at the
		# end, 2 · distance / (0.7 · fall ticks).
		fastest = maxf(fastest, 2.0 * absf(rests[k].position.y - girders[k].position.y) / (0.7 * float(plan.fall_of(k))))
	_carry_margin += ceilf(fastest)
	since.clear()
	for rest in girders:
		since.append(-1)
		var body := AnimatableBody2D.new()
		body.sync_to_physics = true
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
		Content.world_ticks_per_second(Content.time()), ObjectLook.of("quake"), _look)
	_ceiling_y = WorldData.ceiling(WorldData.layout(entry)) * WorldData.CELL
	return plan


## Where the crane's ram reaches each girder: aimed once from the load's path.
func _aim() -> void:
	if hits.size() == girders.size() or _crane == null:
		return
	var load_platform := _crane.load_platform()
	if load_platform == null:
		return
	var start := load_platform.position_at(0).x
	var end := load_platform.position_at(load_platform.once_last_phase()).x
	var delay := load_platform.once_last_phase() - load_platform.move_ticks()
	var lead := _crane.plan.hook_lead_px if _crane.plan != null else 0.0
	hits.clear()
	for g in girders:
		hits.append(CollapsePlan.reach_phase(start, end, delay, load_platform.move_ticks(), g.get_center().x, lead))


func capture_state() -> Dictionary:
	return {"since": since.duplicate(), "slam": slam}


func restore_state(state: Dictionary) -> void:
	var list: Array = state["since"]
	for k in mini(list.size(), since.size()):
		since[k] = int(list[k])
	slam = int(state["slam"])
	_show()


## Counts from the tick the crane's ram reaches each girder, and from its slam.
func simulate_tick(_tick: int) -> void:
	_aim()
	var load_platform := _crane.load_platform() if _crane != null else null
	var phase := load_platform.phase if load_platform != null else -1
	var settled := _plan().settled_tick()
	for k in since.size():
		if since[k] >= 0:
			since[k] = mini(since[k] + 1, settled)
		elif k < hits.size() and hits[k] >= 0 and phase >= hits[k]:
			since[k] = 0
	if slam >= 0:
		slam = mini(slam + 1, _plan().shake_ticks)
	elif _crane != null and _crane.has_slammed():
		slam = 0
	_show()


func on_time_direction_changed(direction: int) -> void:
	_direction = direction
	_show()


## True when a girder in `state` would overlap the player's body above the
## feet: standing on it is riding, anything deeper would crush her.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, _carry_margin))
	var list: Array = state["since"]
	for k in mini(list.size(), girders.size()):
		if _solid(k, int(list[k])) and _rect(k, int(list[k])).intersects(body):
			return true
	return false


## True while girder `k` hangs from the rail.
func girder_hangs(k: int) -> bool:
	return since[k] < 0


## True while girder `k` lies where it fell.
func girder_lies(k: int) -> bool:
	return _plan().drop(k, since[k]) >= 1.0


## True while girder `k` can be stood on now.
func girder_holds(k: int) -> bool:
	if since[k] < 0:
		return true
	if girder_lies(k):
		return not lost.has(k)
	return _direction < 0


## The rect of girder `k` now, in the room's coordinates.
func girder_rect(k: int) -> Rect2:
	return _rect(k, since[k])


## The fall of world lamp `lamp` now, for `Crane` and `WorldLight`; {} when no
## girder carries it.
func lamp_fall(lamp: int) -> Dictionary:
	var k := _plan().lamps.find(lamp)
	if k < 0 or k >= girders.size():
		return {}
	return _plan().lamp_fall(since[k], rests[k].position.y / WorldData.CELL)


## How hard the hall shakes now: 0 to 1, from the slam dying away.
func shake_amount() -> float:
	return _plan().shake(slam)


## True when girder `k` knocked `ticks` ago is in the way of her body: anything
## but a lost girder at the bottom of the pit.
func _solid(k: int, ticks: int) -> bool:
	return not (lost.has(k) and _plan().drop(k, ticks) >= 1.0)


func _rect(k: int, ticks: int) -> Rect2:
	var hang := girders[k]
	var rest := rests[k] if k < rests.size() else hang
	var way := _plan().path(k, ticks)
	var at := Vector2(lerpf(hang.position.x, rest.position.x, way.x), lerpf(hang.position.y, rest.position.y, way.y))
	return Rect2(at, hang.size)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera == null:
		return
	var amount := shake_amount()
	var t := float(slam) * 0.4
	var px := ObjectLook.number(_look, "shake_px", 8.0) * amount
	camera.offset = Vector2(sin(t * 3.0) * px, sin(t * 4.1 + 1.1) * px * 0.6)


func _show() -> void:
	for k in _bodies.size():
		_bodies[k].position = girder_rect(k).get_center()
		var shape := _bodies[k].get_child(0) as CollisionShape2D
		shape.set_deferred("disabled", not girder_holds(k))
	queue_redraw()


## Rusty I-beams: a web with a lighter top flange and rivets; chains to the
## rail while they hang, torn stubs once they fall.
func _draw() -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron", Color("#4c4c53"))
	var light := ObjectLook.color(ObjectLook.mech(), "iron_light", Color("#6c6c72"))
	var dark := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2a30"))
	var rust := ObjectLook.color(_look, "rust", Color("#7a3a22"))
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	var flange := ObjectLook.number(_look, "flange_px", 6.0)
	for k in girders.size():
		var r := girder_rect(k)
		for side: float in [0.15, 0.85]:
			var x := r.position.x + r.size.x * side
			var to := r.position.y if since[k] < 0 else _ceiling_y + ObjectLook.number(_look, "stub_px", 18.0)
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
