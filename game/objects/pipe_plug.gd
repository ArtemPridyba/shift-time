class_name PipePlug
extends CharacterBody2D
## The valve of the pipe in level 02 (D169, D171): a signal-yellow handwheel on
## a short stem, the part missing from the open flange of a `BurstPipe`. It
## lies on the bottom of pool 2 from the start, so the heroine can take it only
## while the pool is empty: in the past, under Shift. E picks it up; E near the
## flange puts it on, firmly; E elsewhere puts it down (an interaction point
## that is nearer wins over the drop).
##
## Taking it or putting it down is no interference (D171): nothing else in the
## room depends on where it lies, so the room's history is not cut; the
## valve's own frames, past and future, are rewritten to its new state
## (`rewrite_all`), so under Shift it never jumps and the world keeps the
## button presses of its future. Putting it on the flange while Shift has taken
## the world to before the gush is interference: a new branch in which the pipe
## holds. In the hands and on the flange it ignores the frames.
##
## Its body is recorded like everything but the player: lying, it falls at the
## head and follows its recorded past under Shift.
##
## State recorded: { "position", "vel", "held", "seated", "firm" }.
## Numbers: `pipe_plug` of `data/objects.json`.
## Temporal object contract: docs/architecture.md, section 4.1.

const YELLOW := Color("#d9a520")
const YELLOW_DARK := Color("#8a6612")
const IRON := Color("#3a3a40")
## The handwheel's radius and the stem under it.
const WHEEL_R := 15.0
const STEM := Vector2(8, 12)
## Where the plug sits in the hands, from the heroine's feet (facing right).
const HAND := Vector2(22, -42)

@export var object_id := "plug"
## The pipe whose flange this valve fits, by path from this node.
@export var pipe_path: NodePath
## On the flange from the start (the first version of D169); false: it lies
## where the level puts it.
@export var start_seated := false

## In the heroine's hands. Live while held: the frames never take it away.
var held := false
## On the flange of the pipe.
var seated := false
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
	seated = start_seated
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
		return [{"id": object_id, "rewrite_all": true,
			"state": {"held": true, "seated": false, "firm": false, "vel": Vector2.ZERO, "act": true}}]
	if near_hole():
		return [{"id": object_id, "state": {"held": false, "seated": true, "firm": true,
			"position": hole_position(), "vel": Vector2.ZERO, "act": true}}]
	# Put down at her feet, so it does not fall: its rewritten frames are where it lies.
	var player := _player()
	var at := Vector2(position.x, player.position.y) if player != null else position
	return [{"id": object_id, "rewrite_all": true,
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
	if seated and pipe != null:
		shake = pipe.shake_offset()
	# A signal-yellow handwheel with four spokes on a short iron stem (D65):
	# on the flange the stem points down into it, lying it rests on its rim.
	var c := shake + Vector2(0.0, -WHEEL_R - STEM.y if seated else -WHEEL_R)
	if seated:
		draw_rect(Rect2(c + Vector2(-STEM.x / 2.0, WHEEL_R - 2.0), Vector2(STEM.x, STEM.y + 2.0)), IRON)
		draw_rect(Rect2(c + Vector2(-STEM.x, WHEEL_R + STEM.y - 4.0), Vector2(STEM.x * 2.0, 5.0)), IRON)
	draw_arc(c, WHEEL_R - 2.0, 0.0, TAU, 24, YELLOW_DARK, 6.0, true)
	draw_arc(c, WHEEL_R - 2.5, PI * 1.1, PI * 1.9, 10, YELLOW.lightened(0.25), 2.0, true)
	draw_arc(c, WHEEL_R - 2.0, PI * 0.1, PI * 0.9, 10, YELLOW, 4.0, true)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		draw_line(c, c + Vector2(cos(a), sin(a)) * (WHEEL_R - 3.0), YELLOW, 3.0, true)
	draw_circle(c, 4.0, IRON)
	# Worn paint on the rim.
	for a in [0.4, 2.3, 4.1]:
		draw_circle(c + Vector2(cos(a), sin(a)) * (WHEEL_R - 2.0), 1.6, YELLOW_DARK)
