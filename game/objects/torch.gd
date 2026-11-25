class_name Torch
extends CharacterBody2D
## A torch (level 03, D155): an item like the body of the reverse flamethrower.
## It hangs in a holder on a wall (`mounted`), E takes it, E drops it.
##
## - Lying or in the holder it is recorded like everything but the player: it
##   burns or is out (`lit`), and rain over it puts it out at the head, so
##   under Shift it burns again. A dropped torch falls at the head.
## - In the hands it is out of time, like everything the player holds: the
##   frames never take it, and rain never puts it out. A torch that was out
##   when taken is only a stick.
## - Its fire is live and never recorded; it lights wood only in normal time
##   and only one way: E near whole wood with the torch burning in the hands
##   thrusts it in (`host`). The wood burns from that tick, the torch stays in
##   the fire, can never be taken again, and burns up with the wood. The
##   earlier frames are rewritten to the torch in the wood, as a drop does
##   (decision 13.11.2026), so under Shift it never jumps; a torch stuck in
##   whole wood at the head (a branch before the thrust) lights it again.
##   Under Shift E with the torch in the hands only drops it.
##
## The node is the torch's foot; the flame is at its top.
##
## State recorded: { "position", "fall", "held", "lit", "mounted", "host" }
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
## In a holder on a wall when the room loads: it does not fall.
@export var mounted := false
## For a torch in a holder: pixels from its foot down to the floor the player
## stands on in front of it, so E reaches it from there.
@export var floor_offset_px := 0.0

var held := false
var fall_speed := 0.0
## The object_id of the wood the torch was thrust into; empty: none.
var host := ""
var time_direction := 1

var _radius := 80.0
var _reach := 40.0
var _follow := 24.0
var _gravity := 2200.0
var _max_fall := 1200.0
var _per_second := 60.0
## The flame's own clock (live, never recorded).
var _live_t := 0.0


func _init() -> void:
	# After the player (0): the torch follows the hands where the player moved.
	process_physics_priority = 10
	collision_layer = 4
	collision_mask = 1
	var data: Dictionary = Content.objects().get("torch", {})
	_radius = float(data.get("interact_radius_px", 80))
	_reach = float(data.get("reach_px", 40))
	_follow = float(data.get("follow_px", 24))
	_gravity = float(data.get("gravity", 2200))
	_max_fall = float(data.get("max_fall_speed", 1200))
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("carried")
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(12.0, 8.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -4.0)
		add_child(shape)


func capture_state() -> Dictionary:
	return {"position": position, "fall": fall_speed, "held": held, "lit": lit, "mounted": mounted, "host": host}


## In the hands the frames are ignored, unless this is the let-go itself
## (`let_go` in the state, from `get_interaction_change`).
func restore_state(state: Dictionary) -> void:
	if held and not bool(state.get("let_go", false)):
		return
	held = bool(state["held"])
	position = state["position"]
	fall_speed = float(state["fall"])
	lit = bool(state["lit"])
	mounted = bool(state["mounted"])
	host = str(state["host"])
	queue_redraw()


## At the head: rain puts a lying torch out, a dropped one falls, one in wood
## keeps the wood burning and burns up with it. Nothing while held.
func simulate_tick(_tick: int) -> void:
	if held:
		return
	if host != "":
		var wood := _wood(host)
		if wood != null:
			if wood.burn.phase == WoodBurn.Phase.BURNT:
				if lit:
					lit = false
					queue_redraw()
			elif lit:
				wood.catch_fire()
		return
	if lit and is_wet():
		lit = false
		queue_redraw()
	if mounted or not is_inside_tree() or not Engine.is_in_physics_frame():
		return
	fall_speed = minf(fall_speed + _gravity / _per_second, _max_fall)
	velocity = Vector2(0.0, fall_speed)
	move_and_slide()
	if is_on_floor():
		fall_speed = 0.0
	velocity = Vector2.ZERO


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## True while it burns in the player's hands or in wood: what is seen to burn.
func is_burning() -> bool:
	return lit and (host == "" or _host_burning())


## Gone into the fire of the wood it was thrust into.
func is_spent() -> bool:
	return host != "" and not lit


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


## The whole wood the burning torch in the hands can be thrust into now: in
## normal time, within `reach_px` of the flame. Null when there is none.
func wood_in_reach() -> WoodZone:
	if not held or not lit or time_direction < 0 or not is_inside_tree():
		return null
	var room := get_parent()
	var reach := flame_rect().grow(_reach)
	for node in get_tree().get_nodes_in_group("flammable"):
		var wood := node as WoodZone
		if wood == null or not room.is_ancestor_of(wood):
			continue
		if wood.burn.phase == WoodBurn.Phase.WHOLE and reach.intersects(wood.global_rect()):
			return wood
	return null


## Lying or in the holder: a pick-up point. In the hands: the thrust into
## wood when there is wood in reach, else the drop, which counts only when no
## other interaction point is in reach. In wood: nothing.
func interaction_candidate() -> Dictionary:
	if host != "":
		return {"id": object_id, "position": global_position, "radius": -1.0}
	if held:
		if wood_in_reach() != null:
			return {"id": object_id, "position": global_position, "radius": 1.0e9}
		return {"id": object_id, "position": global_position, "radius": 1.0e9, "fallback": true}
	var at := global_position + Vector2(0.0, floor_offset_px if mounted else 0.0)
	return {"id": object_id, "position": at, "radius": _radius}


func get_interaction_change(_objects: Array) -> Array:
	if not held:
		return [{"id": object_id, "state": {"held": true, "mounted": false}}]
	var wood := wood_in_reach()
	if wood != null:
		var at := wood.position + Vector2(0.0, wood.size.y * 0.25)
		return [
			{"id": object_id, "rewrite_past": true, "state": {"held": false, "let_go": true,
				"fall": 0.0, "position": at, "lit": true, "mounted": false, "host": wood.object_id}},
			{"id": wood.object_id, "state": wood.ignite_change()},
		]
	return [{"id": object_id, "rewrite_past": true, "state": {"held": false, "let_go": true,
		"fall": 0.0, "position": position, "lit": lit, "mounted": false, "host": ""}}]


## The room's reset: out of the hands, so the first frame can put it back.
func forget_hands() -> void:
	held = false


func _physics_process(_delta: float) -> void:
	if not held:
		return
	var player := _player()
	if player == null:
		return
	var facing := -1.0 if float(player.call("facing")) < 0.0 else 1.0
	var target: Vector2 = player.position + Vector2(HAND.x * facing, HAND.y)
	position = position.move_toward(target, _follow)
	queue_redraw()


func _process(delta: float) -> void:
	_live_t += delta
	if lit:
		queue_redraw()


func _player() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_parent() == parent:
			return node as Node2D
	return null


func _wood(id: String) -> WoodZone:
	if not is_inside_tree():
		return null
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("flammable"):
		if node is WoodZone and room.is_ancestor_of(node) and (node as WoodZone).object_id == id:
			return node as WoodZone
	return null


func _host_burning() -> bool:
	var wood := _wood(host)
	return wood != null and wood.burn.is_burning()


func _draw() -> void:
	if is_spent():
		return
	if mounted:
		draw_rect(Rect2(Vector2(-9.0, -14.0), Vector2(18.0, 6.0)), HOLDER_COLOR)
		draw_rect(Rect2(Vector2(-3.0, -14.0), Vector2(6.0, 20.0)), HOLDER_COLOR)
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
