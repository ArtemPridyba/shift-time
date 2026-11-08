class_name Player
extends CharacterBody2D
## The player: reads input, applies PlayerMotion, follows the room with the camera.
## The player is not a temporal object: it is never recorded and does not
## listen to the direction of world time.

const BODY_COLOR := Color("#d9dde3")
const MARK_COLOR := Color("#7b828c")

var _motion: PlayerMotion
var _facing := 1.0
var _size := Vector2(44, 92)

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_motion = PlayerMotion.new(Content.player())
	_size = (_shape.shape as RectangleShape2D).size


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump := Input.is_action_just_pressed("jump")
	velocity = _motion.step(velocity, axis, jump, is_on_floor(), delta)
	move_and_slide()
	if axis != 0.0 and signf(axis) != _facing:
		_facing = signf(axis)
		queue_redraw()


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


## The player's body in the parent's coordinates (the origin is at the feet).
func body_rect() -> Rect2:
	return Rect2(position - Vector2(_size.x / 2.0, _size.y), _size)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_motion.reset()
	_camera.reset_smoothing()
