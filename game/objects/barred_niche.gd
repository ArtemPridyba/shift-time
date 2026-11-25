class_name BarredNiche
extends Node2D
## A recess in the wall behind bars (level 02, D161): water passes through, the
## heroine does not; her reach stays outside, so what stands inside (a lever)
## is out of her hands. Decoration over the ground: the cells stay solid.

const BACK_COLOR := Color("#121214")
const BAR_COLOR := Color("#55555c")
const BAR_SHADOW := Color("#2a2a2e")

## The recess, from the node: its size in pixels; the bars on its `bars_side`.
@export var size := Vector2(128, 128)
@export_enum("Left:-1", "Right:1") var bars_side := 1
@export var bars := 4


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK_COLOR)
	var x := size.x - 6.0 if bars_side > 0 else 0.0
	draw_rect(Rect2(Vector2(x, 0.0), Vector2(6.0, size.y)), BAR_SHADOW)
	for i in bars + 1:
		var y := size.y * float(i) / bars
		draw_line(Vector2(x, y), Vector2(x + 6.0, y), BAR_COLOR, 3.0)
	for i in 3:
		var y := size.y * (0.2 + 0.3 * i)
		draw_line(Vector2(x - 2.0, y), Vector2(x + 8.0, y), BAR_COLOR, 4.0)
	for i in 2:
		draw_line(Vector2(x + 1.5 + i * 3.0, 0.0), Vector2(x + 1.5 + i * 3.0, size.y), BAR_COLOR, 2.0)
