class_name BreathVignette
extends CanvasLayer
## Darkness closes in from the screen edges while the player runs out of air
## under water: the clear circle in the middle shrinks as the hidden breath
## gauge fills, and just before drowning the screen is almost black. In fire
## the same closing-in comes in a deep ember colour (`fire_vignette_color`) as
## the heat grows (task 2.7). A child of the player; it reads the parent's
## `breath_fraction()` and `heat_fraction()` every frame.
## Presentation only.

const SHADER := """
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.97;
uniform float start_radius = 0.9;
uniform float softness = 0.35;
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec3 tint = vec3(0.0);

void fragment() {
	// Distance from the centre, 1.0 at a corner whatever the screen shape.
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p) / length(aspect * 0.5);
	// The clear radius shrinks from start_radius to below zero: at the end
	// even the centre is dark.
	float clear = mix(start_radius, -softness, amount);
	float dark = smoothstep(clear, clear + softness, d);
	// The darkness itself also deepens: faint at first, nearly black at the end.
	COLOR = vec4(tint, dark * max_alpha * pow(amount, 0.6));
}
"""

var max_alpha := 0.97
var start_radius := 0.9
## The colour of the edges while the heat, not the lack of air, is the danger.
var fire_color := Color("#5c1800")
## The width of the soft edge between clear and dark, as in the shader.
const SOFTNESS := 0.35

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 5
	var data := Content.player()
	max_alpha = clampf(float(data.get("breath_vignette_alpha", 0.97)), 0.0, 1.0)
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("max_alpha", max_alpha)
	start_radius = float(data.get("breath_vignette_radius", 0.9))
	fire_color = Color.from_string(str(data.get("fire_vignette_color", "#5c1800")), fire_color)
	_material.set_shader_parameter("start_radius", start_radius)
	_material.set_shader_parameter("softness", SOFTNESS)
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_update()


func _process(_delta: float) -> void:
	_update()


## How close the player is to the end: the larger of the air gone (0 with full
## lungs, 1 out of air) and the heat taken in fire (0 cool, 1 burned).
func amount() -> float:
	return maxf(_air_gone(), _heat())


## True while the heat is the larger danger: the edges take the ember colour.
func is_fire() -> bool:
	return _heat() > _air_gone()


func _air_gone() -> float:
	var parent := get_parent()
	var fraction := 1.0
	if parent != null and parent.has_method("breath_fraction"):
		fraction = float(parent.call("breath_fraction"))
	return 1.0 - clampf(fraction, 0.0, 1.0)


func _heat() -> float:
	var parent := get_parent()
	if parent != null and parent.has_method("heat_fraction"):
		return clampf(float(parent.call("heat_fraction")), 0.0, 1.0)
	return 0.0


## The darkness at the screen edges: 0 with full lungs, `max_alpha` out of air.
func strength() -> float:
	return max_alpha * amount()


## The radius of the clear middle, as a share of the distance to a corner:
## `breath_vignette_radius` with full lungs, below 0 (all dark) out of air.
func clear_radius() -> float:
	return start_radius * (1.0 - amount()) - SOFTNESS * amount()


func _update() -> void:
	var a := amount()
	_material.set_shader_parameter("amount", a)
	var c := fire_color if is_fire() else Color.BLACK
	_material.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	var size := _rect.get_viewport_rect().size
	if size.y > 0.0:
		_material.set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
	_rect.visible = a > 0.001
