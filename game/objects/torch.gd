class_name Torch
extends CharacterBody2D
## A torch on its stand (level 03 «Нить», D177). No key: she walks past the
## stand with empty hands and takes the torch; she walks past the empty stand
## with the torch and puts it back (D159). The step counts when her body comes
## to the stand, in normal time or under Shift; left of the head it is
## interference and the room branches.
##
## - On the stand it is recorded like everything but the player: it burns or
##   is out (`lit`), and rain over its head puts it out at the head, so under
##   Shift it burns again.
## - In the hands it is out of time, like everything the player holds: the
##   frames never take it. Its fire is live: rain over it puts it out there
##   too, in either direction of time, and nothing lights it again in the
##   hands. Carried past the lit end of a whole `FireRope` (group
##   `torch_lightable`) while it burns, it sets the rope burning, in normal
##   time or under Shift (the rope's change goes through `apply_change`).
## - Put back, it takes back the frames it spent in the hands
##   (`RoomTime.rewrite_past_where`, «held»): they now show it on the stand as
##   it was put back, so it never jumps; the frames before it was taken stay
##   as they were, so rewinding past the take shows it burning again where it
##   burnt.
##
## - A `burner` stand (level 03, D178) is a gas burner with a pilot flame that
##   never goes out: walking past it with the torch in the hands lights the
##   torch again and keeps it in the hands; such a stand never takes it back.
##   The torch's fire in the hands is live, so this changes no frame. A
##   `GasBurner` (D193) is the same burner without a torch of its own.
##   With `relights` off (the lower burner of level 03, D220) the stand only
##   gives the torch: its flame goes out once the torch is taken, and a torch
##   that went out stays out there, so it never lights a rope on its way.
##
## The node is the torch's foot on the stand; the flame is at its top.
##
## State recorded: { "position", "fall", "held", "lit", "mounted" }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const STICK_COLOR := Color("#6b4a2e")
const WRAP_COLOR := Color("#3a2a20")
const HOLDER_COLOR := Color("#4a5058")
const FLAME_COLOR := Color("#ff9a3a")
const FLAME_CORE_COLOR := Color("#ffe08a")
const LENGTH := 40.0
## Where the torch's foot sits in the hands, from the player's feet (facing right).
const HAND := Vector2(22, -30)

@export var object_id := "torch"
## Burning when the room loads.
@export var lit := true
## On its stand when the room loads.
@export var mounted := true
## Pixels from its foot down to the floor the player stands on in front of
## the stand: the stand's reach is measured from there.
@export var floor_offset_px := 0.0
## The stand is a gas burner that lights the torch again (see above).
@export var burner := false
## A burner stand lights a torch in the hands again; off, it only gives it.
@export var relights := true

var held := false
var fall_speed := 0.0
var time_direction := 1

## The stand: where the torch stands when put back (the node's place on load).
var home := Vector2.ZERO
var _stand_px := 40.0
var _reach := 24.0
var _follow := 24.0
var _per_second := 60.0
## Whether the player's body was at the stand last tick. Not recorded: the
## step is the player's, and the player is never in history.
var _at_stand := false
## The flame's own clock (live, never recorded).
var _live_t := 0.0


func _init() -> void:
	# After the player (0): the torch follows the hands where the player moved.
	process_physics_priority = 10
	collision_layer = 4
	collision_mask = 1
	var data: Dictionary = Content.objects().get("torch", {})
	_stand_px = float(data.get("stand_px", 40))
	_reach = float(data.get("reach_px", 24))
	_follow = float(data.get("follow_px", 24))
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("carried")
	add_to_group("plate")
	home = position
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(12.0, 8.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -4.0)
		shape.disabled = true
		add_child(shape)


## In the hands the frames are never read back, so they keep the stand as the
## place: a carried torch writes no new frame every tick and the history is
## not used up while she walks with it (the room may stand still, D56).
func capture_state() -> Dictionary:
	return {"position": home if held else position, "fall": fall_speed, "held": held, "lit": lit, "mounted": mounted}


## In the hands the frames are ignored, unless this is the put-back itself
## (`let_go` in the state).
func restore_state(state: Dictionary) -> void:
	if held and not bool(state.get("let_go", false)):
		return
	held = bool(state["held"])
	position = state["position"]
	fall_speed = float(state["fall"])
	lit = bool(state["lit"])
	mounted = bool(state["mounted"])
	queue_redraw()


## At the head: rain puts a torch on the stand out. Nothing while held.
func simulate_tick(_tick: int) -> void:
	if held:
		return
	if lit and is_wet():
		lit = false
		queue_redraw()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## True while it burns in the player's hands.
func is_burning() -> bool:
	return lit


## The flame in global pixels: the torch's head.
func flame_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8.0, -LENGTH - 14.0), Vector2(16.0, 22.0))


## True while rain or water covers the torch's head.
func is_wet() -> bool:
	if not is_inside_tree():
		return false
	var head := flame_rect()
	for node in get_tree().get_nodes_in_group("water"):
		if node.has_method("water_global_rect"):
			var water: Rect2 = node.call("water_global_rect")
			if water.has_area() and water.intersects(head):
				return true
	return false


## The stand's reach in the parent's pixels: `stand_px` to each side of the
## stand, from the floor in front of it up to a body's height.
func stand_rect() -> Rect2:
	var floor_y := home.y + floor_offset_px
	return Rect2(Vector2(home.x - _stand_px, floor_y - 96.0), Vector2(2.0 * _stand_px, 96.0))


## Called by RoomTime after every tick (group `plate`) with the player's rect:
## her coming to the stand takes or puts back the torch; a burning torch in
## her hands lights the ropes it passes. Changes go through
## `room.apply_change`; the room is an argument, never kept.
func sense(room: Object, _direction: int, player_rect: Rect2) -> void:
	var at := player_rect.has_area() and stand_rect().intersects(player_rect)
	if at and held and burner:
		if relights:
			light_again()
	elif at and not _at_stand:
		if not held and mounted:
			room.call("apply_change", object_id, {"held": true, "mounted": false})
		elif held:
			room.call("apply_change", object_id, {"held": false, "let_go": true, "fall": 0.0,
				"position": home, "lit": lit, "mounted": true})
			room.call("rewrite_past_where", object_id, "held")
	_at_stand = at
	if held and lit:
		_light_ropes(room)


## A burner's pilot flame lights the torch in the hands again (its own
## burner or a `GasBurner`). Live fire: no frame changes.
func light_again() -> void:
	if held and not lit:
		lit = true
		queue_redraw()


## Back to the room as loaded: no step in progress.
func forget_step() -> void:
	_at_stand = false


## The room's reset: out of the hands, so the first frame can put it back.
func forget_hands() -> void:
	held = false


func _light_ropes(room: Object) -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	var reach := flame_rect().grow(_reach)
	for node in get_tree().get_nodes_in_group("torch_lightable"):
		if not parent.is_ancestor_of(node) or not node.has_method("light_rect"):
			continue
		if reach.intersects(node.call("light_rect") as Rect2):
			var change: Dictionary = node.call("torch_change")
			if not change.is_empty():
				room.call("apply_change", str(node.get("object_id")), change)


func _physics_process(_delta: float) -> void:
	if not held:
		return
	var player := _player()
	if player == null:
		return
	var facing := -1.0 if float(player.call("facing")) < 0.0 else 1.0
	var target: Vector2 = player.position + Vector2(HAND.x * facing, HAND.y)
	position = position.move_toward(target, _follow)
	# Her fire is live: rain puts it out in the hands too, in either direction.
	if lit and is_wet():
		lit = false
	queue_redraw()


func _process(delta: float) -> void:
	_live_t += delta
	if lit or burner:
		queue_redraw()


func _player() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_parent() == parent:
			return node as Node2D
	return null


func _draw() -> void:
	if burner:
		draw_burner(self, home - position, floor_offset_px, _live_t, relights or (mounted and not held))
	if mounted and not held:
		draw_rect(Rect2(Vector2(-9.0, -6.0), Vector2(18.0, 8.0)), HOLDER_COLOR)
	draw_line(Vector2.ZERO, Vector2(0.0, -LENGTH), STICK_COLOR, 6.0, true)
	draw_rect(Rect2(Vector2(-5.0, -LENGTH - 2.0), Vector2(10.0, 12.0)), WRAP_COLOR)
	if not lit:
		return
	# A flame that flickers by its own live clock: torch fire is never recorded.
	var t := _live_t
	var tip := Vector2(sin(t * 9.0) * 3.0, -LENGTH - 20.0 - sin(t * 13.0) * 3.0)
	var base := -LENGTH - 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, base), tip, Vector2(7.0, base), Vector2(0.0, base + 4.0)]), FLAME_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.5, base), tip * Vector2(0.6, 1.0) + Vector2(0.0, 7.0), Vector2(3.5, base)]), FLAME_CORE_COLOR)


## A gas burner on `canvas` at `at` (the torch's foot on it, in the canvas's
## pixels), `floor_px` above the floor: a pipe up from the floor, a nozzle and
## a small flame that flickers by the live clock `t` (none when `flame` is
## off). Also drawn by `GasBurner`.
static func draw_burner(canvas: CanvasItem, at: Vector2, floor_px: float, t: float, flame := true) -> void:
	var floor_at := at + Vector2(0.0, floor_px)
	canvas.draw_rect(Rect2(floor_at + Vector2(-4.0, -floor_px - 4.0), Vector2(8.0, floor_px + 4.0)), HOLDER_COLOR)
	canvas.draw_rect(Rect2(floor_at + Vector2(-12.0, -6.0), Vector2(24.0, 6.0)), HOLDER_COLOR.darkened(0.3))
	var nozzle := at + Vector2(14.0, -18.0)
	canvas.draw_rect(Rect2(at + Vector2(2.0, -14.0), Vector2(12.0, 5.0)), HOLDER_COLOR)
	canvas.draw_rect(Rect2(nozzle + Vector2(-2.0, 0.0), Vector2(6.0, 6.0)), HOLDER_COLOR.darkened(0.2))
	if not flame:
		return
	var tip := nozzle + Vector2(1.0 + sin(t * 11.0) * 1.5, -12.0 - sin(t * 17.0) * 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		nozzle + Vector2(-3.0, 1.0), tip, nozzle + Vector2(5.0, 1.0)]), FLAME_COLOR)
	canvas.draw_colored_polygon(PackedVector2Array([
		nozzle + Vector2(-1.0, 1.0), tip + Vector2(0.0, 5.0), nozzle + Vector2(3.0, 1.0)]), FLAME_CORE_COLOR)
