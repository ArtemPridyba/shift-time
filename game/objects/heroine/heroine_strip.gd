class_name HeroineStrip
extends Sprite2D
## The indicator strip of the gauntlet (D76): a white mask cut from the
## picture, tinted by code with the time colour from data, so D70 can pick the
## colour in the game without a new picture.

var color := Color.WHITE:
	set(value):
		color = value
		self_modulate = value
