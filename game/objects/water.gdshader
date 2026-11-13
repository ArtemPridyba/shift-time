shader_type canvas_item;
// The body of a tank of water (task 2.3А): darker with depth, with soft bands
// of light. The bands move with the world's clock (`world_time`, set by
// water.gd), never with TIME, so under Shift they run backward.
// UV is in pixels / 256: x across the tank, y down from the surface.

uniform float world_time = 0.0;
uniform vec4 deep_color : source_color = vec4(0.16, 0.23, 0.3, 0.75);
uniform float band_strength = 0.035;

void fragment() {
	float depth = clamp(UV.y / 1.5, 0.0, 1.0);
	vec4 color = mix(COLOR, deep_color, depth);
	// Two crossing waves make soft patches of light, brightest near the top.
	float a = sin(UV.x * 11.0 + UV.y * 5.0 + world_time * 0.9);
	float b = sin(UV.x * -7.0 + UV.y * 9.0 - world_time * 0.6);
	color.rgb += band_strength * smoothstep(0.4, 1.0, a * b) * (1.0 - depth);
	COLOR = color;
}
