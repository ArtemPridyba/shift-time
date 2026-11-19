class_name HeroineStrip
extends Node2D
## The indicator strip of the gauntlet (D76): drawn by code in the time colour
## from data, so D70 can pick the colour in the game without a new picture.

var rect := Rect2()
var color := Color.CYAN:
	set(value):
		color = value
		queue_redraw()
var glow_px := 0.0
var glow_alpha := 0.0


func _draw() -> void:
	if glow_px > 0.0:
		var glow := color
		glow.a = glow_alpha
		draw_rect(rect.grow(glow_px), glow)
	draw_rect(rect, color)
