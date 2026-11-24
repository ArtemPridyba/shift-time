extends Node2D
## Decoration at the start of a level: the doorway the hero comes out of. A dark
## recess in the wall with a thin cold frame; it records nothing and changes
## nothing (docs/levels/01.md). `size` is in pixels, the node sits at the top
## left corner of the doorway.

const RECESS_COLOR := Color("#15181c")
const FRAME_COLOR := Color("#7FE8FF")

@export var size := Vector2(64, 192)

## True when the level's picture has the doorway (D131): nothing is drawn.
var painted := false


## The level's picture has the doorway (`world.backdrop`, D131).
func use_backdrop(_config: Dictionary) -> void:
	painted = true
	queue_redraw()


func _draw() -> void:
	if painted:
		return
	draw_rect(Rect2(Vector2.ZERO, size), RECESS_COLOR)
	var frame := Color(FRAME_COLOR, 0.55)
	draw_rect(Rect2(Vector2.ZERO, size), frame, false, 3.0)
	var glow := Color(FRAME_COLOR, 0.12)
	draw_rect(Rect2(Vector2(size.x - 10.0, 0.0), Vector2(10.0, size.y)), glow)
