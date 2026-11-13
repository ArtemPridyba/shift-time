class_name Player
extends CharacterBody2D
## The player: reads input, applies PlayerMotion, follows the room with the camera.
## The player is not a temporal object: it is never recorded and does not
## listen to the direction of world time.

const BODY_COLOR := Color("#d9dde3")
const MARK_COLOR := Color("#7b828c")
## Feet this close above a water surface still count as in the water, so the
## hero carried up by rising water does not flicker in and out of it.
const WATER_CONTACT_PX := 2.0

var _motion: PlayerMotion
var _facing := 1.0
var _size := Vector2(44, 92)
## The last surface seen of each water (instance id to global y), to know how
## fast it rises.
var _surfaces := {}

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_motion = PlayerMotion.new(Content.player())
	_size = (_shape.shape as RectangleShape2D).size


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump := Input.is_action_just_pressed("jump")
	var water := _water_contact(delta)
	velocity = _motion.step(velocity, axis, jump, is_on_floor(), delta, water.x, water.y)
	move_and_slide()
	if axis != 0.0 and signf(axis) != _facing:
		_facing = signf(axis)
		queue_redraw()
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


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_surfaces.clear()
	_motion.reset()
	_camera.reset_smoothing()


## The water the feet are in: x is the depth below its surface (px, -1 out of
## water), y how fast that surface rises (px/s). The world moved this tick
## already (RoomTime runs first), so the rise is the surface's motion now.
func _water_contact(delta: float) -> Vector2:
	var parent := get_parent()
	var contact := Vector2(-1.0, 0.0)
	var deepest := -INF
	if parent == null:
		return contact
	for node in get_tree().get_nodes_in_group("water"):
		if not parent.is_ancestor_of(node) or not node.has_method("depth_of"):
			continue
		var id := node.get_instance_id()
		var surface: float = node.call("surface_y")
		var rise := 0.0
		if _surfaces.has(id) and delta > 0.0:
			rise = (float(_surfaces[id]) - surface) / delta
		_surfaces[id] = surface
		var depth: float = node.call("depth_of", global_position)
		if depth >= -WATER_CONTACT_PX and depth > deepest:
			deepest = depth
			contact = Vector2(maxf(depth, 0.0), rise)
	return contact


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
