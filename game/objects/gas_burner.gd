class_name GasBurner
extends Node2D
## A gas burner without a torch of its own (level 03 «Нить», D193): its pilot
## flame never goes out, and walking past it with a torch out in the hands
## lights the torch again, as the torch's own burner does (`Torch.burner`). It
## never takes a torch and never gives one. Nothing here is recorded: the
## torch's fire in the hands is live, so this changes no frame, in normal time
## or under Shift.
##
## The node is where a torch's foot would stand on it; `floor_offset_px` down
## to the floor in front of it, as for `Torch`. The reach is the torch's
## `stand_px` in objects.json.

@export var floor_offset_px := 0.0

var _stand_px := 40.0
## The pilot flame's own clock (live, never recorded).
var _live_t := 0.0


func _init() -> void:
	_stand_px = float(Content.objects().get("torch", {}).get("stand_px", 40))


func _ready() -> void:
	add_to_group("plate")


## The burner's reach in the parent's pixels, as a torch stand's.
func stand_rect() -> Rect2:
	var floor_y := position.y + floor_offset_px
	return Rect2(Vector2(position.x - _stand_px, floor_y - 96.0), Vector2(2.0 * _stand_px, 96.0))


## Called by RoomTime after every tick (group `plate`) with the player's rect:
## a torch in her hands that is out burns again.
func sense(_room: Object, _direction: int, player_rect: Rect2) -> void:
	if not player_rect.has_area() or not stand_rect().intersects(player_rect):
		return
	var parent := get_parent()
	for node in get_tree().get_nodes_in_group("carried"):
		if node is Torch and node.get_parent() == parent:
			(node as Torch).light_again()


func _process(delta: float) -> void:
	_live_t += delta
	queue_redraw()


func _draw() -> void:
	Torch.draw_burner(self, Vector2.ZERO, floor_offset_px, _live_t)
