class_name ExitZone
extends Area2D
## The way out of a level: the player's body inside it ends the level. It is
## not a temporal object: it keeps no state and Shift does not touch it.
## `size` is the zone in pixels, centred on the node.

signal reached

const FRAME_COLOR := Color("#c9ced6")
const PLAYER_LAYER := 2

@export var size := Vector2(128, 192):
	set(value):
		size = value
		_fit()
		queue_redraw()


func _init() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false


func _ready() -> void:
	_fit()
	body_entered.connect(_on_body_entered)


func rect() -> Rect2:
	return Rect2(position - size / 2.0, size)


func _fit() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		return
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box


func _on_body_entered(body: Node) -> void:
	if body is Player:
		reached.emit()


## A doorway frame with an arrow: blockout look until the art comes.
func _draw() -> void:
	var half := size / 2.0
	draw_rect(Rect2(-half, size), FRAME_COLOR, false, 4.0)
	var mid := Vector2.ZERO
	draw_line(mid + Vector2(-24.0, 0.0), mid + Vector2(24.0, 0.0), FRAME_COLOR, 4.0)
	draw_line(mid + Vector2(24.0, 0.0), mid + Vector2(8.0, -14.0), FRAME_COLOR, 4.0)
	draw_line(mid + Vector2(24.0, 0.0), mid + Vector2(8.0, 14.0), FRAME_COLOR, 4.0)
