class_name BreathVignette
extends CanvasLayer
## The screen edges darken while the player runs out of air under water, as
## if the hero were going under. A child of the player; it reads the parent's
## `breath_fraction()` every frame. Presentation only.

var max_alpha := 0.85

var _rect: TextureRect


func _ready() -> void:
	layer = 5
	max_alpha = clampf(float(Content.player().get("breath_vignette_alpha", 0.85)), 0.0, 1.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 1))
	gradient.add_point(0.45, Color(0, 0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 144
	_rect = TextureRect.new()
	_rect.texture = texture
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_update()


func _process(_delta: float) -> void:
	_update()


## 0 with full lungs, `max_alpha` out of air.
func strength() -> float:
	var parent := get_parent()
	var fraction := 1.0
	if parent != null and parent.has_method("breath_fraction"):
		fraction = float(parent.call("breath_fraction"))
	return max_alpha * (1.0 - clampf(fraction, 0.0, 1.0))


func _update() -> void:
	_rect.modulate.a = strength()
	_rect.visible = _rect.modulate.a > 0.001
