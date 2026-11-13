class_name Player
extends CharacterBody2D
## The player: reads input, applies PlayerMotion, follows the room with the camera.
## The player is not a temporal object: it is never recorded and does not
## listen to the direction of world time. In water the player sinks and holds
## the breath (`Breath`); out of air, `drowned` tells the room to reset.

## The air ran out under water: the room resets.
signal drowned

const BODY_COLOR := Color("#d9dde3")
const MARK_COLOR := Color("#7b828c")

var _motion: PlayerMotion
var _breath: Breath
var _facing := 1.0
var _size := Vector2(44, 92)
var _head_px := 28.0
var _head_under := false
var _bubbles: CPUParticles2D

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	var params := Content.player()
	_motion = PlayerMotion.new(params)
	_breath = Breath.new(params)
	_head_px = float(params.get("head_px", 28))
	_size = (_shape.shape as RectangleShape2D).size
	_bubbles = _make_bubbles()
	add_child(_bubbles)


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump := Input.is_action_just_pressed("jump")
	var water := water_contact()
	velocity = _motion.step(velocity, axis, jump, is_on_floor(), delta, water)
	move_and_slide()
	if axis != 0.0 and signf(axis) != _facing:
		_facing = signf(axis)
		queue_redraw()
	_head_under = bool(water.get("head_under", false))
	_bubbles.emitting = _head_under
	_bubbles.position.x = 8.0 * _facing
	if _breath.step(_head_under, delta):
		drowned.emit()
	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _draw() -> void:
	# Placeholder body: a light block with a dark mark on the side it faces.
	draw_rect(Rect2(Vector2(-_size.x / 2.0, -_size.y), _size), BODY_COLOR)
	var mark := Vector2(10, 16)
	var mark_x := _size.x / 2.0 - mark.x - 4.0 if _facing > 0.0 else -_size.x / 2.0 + 4.0
	draw_rect(Rect2(Vector2(mark_x, -_size.y + 14.0), mark), MARK_COLOR)


## The room tells the camera where the world ends (pixels).
func set_camera_limits(rect: Rect2i) -> void:
	_camera.limit_left = rect.position.x
	_camera.limit_top = rect.position.y
	_camera.limit_right = rect.end.x
	_camera.limit_bottom = rect.end.y


## +1 while the hero faces right, -1 while left; the wrist device follows it.
func facing() -> float:
	return _facing


## The player's body in the parent's coordinates (the origin is at the feet).
func body_rect() -> Rect2:
	return Rect2(position - Vector2(_size.x / 2.0, _size.y), _size)


## The deepest water the player is in this tick (`PlayerMotion.water_contact`);
## depth 0 on land.
func water_contact() -> Dictionary:
	var best := {"depth": 0.0, "rise": 0.0, "head_under": false}
	if not is_inside_tree():
		return best
	var body := Rect2(global_position - Vector2(_size.x / 2.0, _size.y), _size)
	for node in get_tree().get_nodes_in_group("water"):
		var water := node as Water
		if water == null:
			continue
		var contact := PlayerMotion.water_contact(body, water.tank_global_rect(), water.surface_global_y(), water.rise_px_per_second, _head_px)
		if float(contact["depth"]) > float(best["depth"]):
			best = contact
	return best


## 1 with full lungs, 0 out of air; the vignette reads it.
func breath_fraction() -> float:
	return _breath.fraction() if _breath != null else 1.0


func is_head_under_water() -> bool:
	return _head_under


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_motion.reset()
	if _breath != null:
		_breath.reset()
	_camera.reset_smoothing()


## Asks the parent RoomTime (if any) to handle an interact press.
func _try_interact() -> void:
	var room_time := _find_room_time()
	if room_time != null and room_time.has_method("player_interact"):
		room_time.call("player_interact", global_position)


func _find_room_time() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is RoomTime:
			return child
	return null


## Bubbles from the mouth while the head is under water: decoration, never
## recorded (the player is live).
func _make_bubbles() -> CPUParticles2D:
	var bubbles := CPUParticles2D.new()
	bubbles.name = "Bubbles"
	bubbles.position = Vector2(8.0, -_size.y + 18.0)
	bubbles.emitting = false
	bubbles.amount = 8
	bubbles.lifetime = 1.4
	bubbles.direction = Vector2.UP
	bubbles.spread = 20.0
	bubbles.gravity = Vector2(0, -40)
	bubbles.initial_velocity_min = 20.0
	bubbles.initial_velocity_max = 45.0
	bubbles.scale_amount_min = 2.0
	bubbles.scale_amount_max = 4.0
	bubbles.color = Color(0.85, 0.95, 1.0, 0.7)
	return bubbles
