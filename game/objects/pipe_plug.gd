class_name PipePlug
extends CharacterBody2D
## The plug of the pipe in level 02 (D168): an item the heroine carries from
## the future into the past. It sits loose in the hole of a `BurstPipe`; the
## pressure knocks it out and it falls to the floor (the pipe calls `eject`).
## E picks it up; E near the hole puts it back, firmly; E elsewhere puts it
## down (an interaction point that is nearer wins over the drop).
##
## Its body is recorded like everything but the player (the flamethrower's
## rules): lying, it falls at the head and moves back along its recorded past
## under Shift; in the hands it stays with the heroine and ignores the frames.
## Put back firmly, it stays in the hole and ignores the frames too, until E
## takes it out again. Putting it back while Shift has taken the world to
## before the burst is interference: a new branch in which the pipe holds.
## A drop rewrites the plug's earlier frames to where it was let go, so under
## Shift it never jumps.
##
## State recorded: { "position", "vel", "held", "seated", "firm" }.
## Numbers: `pipe_plug` of `data/objects.json`.
## Temporal object contract: docs/architecture.md, section 4.1.

const YELLOW := Color("#d9a520")
const YELLOW_DARK := Color("#8a6612")
const IRON := Color("#3a3a40")
const SIZE := Vector2(30, 18)
## Where the plug sits in the hands, from the heroine's feet (facing right).
const HAND := Vector2(22, -42)

@export var object_id := "plug"
## The pipe whose hole this plug fits, by path from this node.
@export var pipe_path: NodePath

## In the heroine's hands. Live while held: the frames never take it away.
var held := false
## In the hole of the pipe.
var seated := true
## Put back by the heroine: the pressure no longer knocks it out, and the
## frames no longer take it away.
var firm := false
## Pixels per second while it flies or falls.
var vel := Vector2.ZERO

var _radius := 80.0
var _insert := 130.0
var _gravity := 2200.0
var _max_fall := 1200.0
var _friction := 1600.0
var _follow := 24.0
var _per_second := 60.0


func _init() -> void:
	# After the player (0): the plug follows the hands where the player moved.
	process_physics_priority = 10
	var data: Dictionary = Content.objects().get("pipe_plug", {})
	_radius = float(data.get("interact_radius_px", _radius))
	_insert = float(data.get("insert_radius_px", _insert))
	_gravity = float(data.get("gravity", _gravity))
	_max_fall = float(data.get("max_fall_speed", _max_fall))
	_friction = float(data.get("friction_px", _friction))
	_follow = float(data.get("follow_px", _follow))
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("carried")
	if seated:
		position = hole_position()


func capture_state() -> Dictionary:
	return {"position": position, "vel": vel, "held": held, "seated": seated, "firm": firm}


## In the hands or firmly in the hole the frames are ignored, unless this is
## the heroine's own act (`act` in the state, from `get_interaction_change`).
func restore_state(state: Dictionary) -> void:
	if (held or firm) and not bool(state.get("act", false)):
		return
	held = bool(state["held"])
	seated = bool(state["seated"])
	firm = bool(state["firm"])
	position = state["position"]
	vel = state["vel"]
	queue_redraw()


## Flies and falls when loose; in the hands or in the hole nothing. The fall
## needs the physics space, so it waits for a real physics tick.
func simulate_tick(_tick: int) -> void:
	if held or seated or not is_inside_tree() or not Engine.is_in_physics_frame():
		return
	vel.y = minf(vel.y + _gravity / _per_second, _max_fall)
	velocity = vel
	move_and_slide()
	if is_on_floor():
		vel.y = 0.0
		vel.x = move_toward(vel.x, 0.0, _friction / _per_second)
	if is_on_wall():
		vel.x = 0.0
	velocity = Vector2.ZERO


func on_time_direction_changed(_direction: int) -> void:
	pass


## Not solid for the heroine: it never crushes.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## The pressure knocks the plug out of the hole (the pipe calls this at the head).
func eject(speed: Vector2) -> void:
	seated = false
	firm = false
	vel = speed


## Lying or in the hole: a pick-up point. In the hands: by the hole, putting it
## back; elsewhere, the drop, which counts only when nothing else is in reach.
func interaction_candidate() -> Dictionary:
	if not held:
		return {"id": object_id, "position": global_position, "radius": _insert if seated else _radius}
	if near_hole():
		return {"id": object_id, "position": _pipe_hole_global(), "radius": _insert}
	return {"id": object_id, "position": global_position, "radius": 1.0e9, "fallback": true}


func get_interaction_change(_objects: Array) -> Array:
	if not held:
		return [{"id": object_id, "state": {"held": true, "seated": false, "firm": false, "vel": Vector2.ZERO, "act": true}}]
	if near_hole():
		return [{"id": object_id, "state": {"held": false, "seated": true, "firm": true,
			"position": hole_position(), "vel": Vector2.ZERO, "act": true}}]
	# Put down at her feet, so it does not fall: its rewritten past is where it lies.
	var player := _player()
	var at := Vector2(position.x, player.position.y) if player != null else position
	return [{"id": object_id, "rewrite_past": true,
		"state": {"held": false, "seated": false, "firm": false, "position": at, "vel": Vector2.ZERO, "act": true}}]


## True when the heroine holding the plug stands close enough to the hole.
func near_hole() -> bool:
	var player := _player()
	return player != null and player.global_position.distance_to(_pipe_hole_global()) <= _insert


## The hole in the parent's coordinates.
func hole_position() -> Vector2:
	var parent := get_parent() as Node2D
	var hole := _pipe_hole_global()
	return parent.to_local(hole) if parent != null else hole


## The room's reset: out of the hands and out of the hole, so the first frame
## can put it back.
func forget_hands() -> void:
	held = false
	firm = false


func _physics_process(_delta: float) -> void:
	if held:
		var player := _player()
		if player != null:
			var facing := -1.0 if float(player.call("facing")) < 0.0 else 1.0
			var target: Vector2 = player.position + Vector2(HAND.x * facing, HAND.y)
			position = position.move_toward(target, _follow)
	elif seated:
		position = hole_position()
	queue_redraw()


func _pipe() -> BurstPipe:
	return get_node_or_null(pipe_path) as BurstPipe


func _pipe_hole_global() -> Vector2:
	var pipe := _pipe()
	return pipe.hole_global() if pipe != null else global_position


func _player() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_parent() == parent:
			return node as Node2D
	return null


func _draw() -> void:
	var shake := Vector2.ZERO
	var pipe := _pipe()
	if seated and not firm and pipe != null:
		shake = pipe.shake_offset()
	# A thick signal-yellow disc with a grip, worn paint at the rim (D65).
	var r := Rect2(-SIZE / 2.0 + shake + Vector2(0, -SIZE.y / 2.0), SIZE)
	draw_rect(r, YELLOW)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0)), YELLOW.lightened(0.25))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4.0), Vector2(r.size.x, 4.0)), YELLOW_DARK)
	draw_rect(Rect2(r.position + Vector2(r.size.x / 2.0 - 4.0, -8.0), Vector2(8.0, 8.0)), IRON)
	for x in [r.position.x + 5.0, r.end.x - 5.0]:
		draw_circle(Vector2(x, r.get_center().y), 2.0, IRON)
