shader_type canvas_item;
render_mode unshaded;
// The heroine as one picture (D81, 20.11.2026): the rig draws all her parts
// into a CanvasGroup and this material draws the group. It lifts her out of
// the dark room (gain, gamma) and lays a warm rim on the side of her
// silhouette that faces the room's lamps, so she reads against dark brick.
// Only the outer edge of the whole doll gets the rim, never the seams between
// her parts. The rig sets every uniform from `look` of data/heroine.json.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float gain = 1.0;
uniform float gamma = 1.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform float rim = 0.0;
// From her towards the light, in screen pixels: as wide as the rim.
uniform vec2 rim_offset = vec2(0.0, -2.0);

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(gamma)) * gain;
	// Opaque here but empty towards the light: the lit edge. Two steps keep it soft.
	vec2 step_uv = rim_offset * SCREEN_PIXEL_SIZE;
	float near = textureLod(screen_texture, SCREEN_UV + step_uv * 0.5, 0.0).a;
	float far = textureLod(screen_texture, SCREEN_UV + step_uv, 0.0).a;
	float edge = clamp(c.a - 0.5 * (near + far), 0.0, 1.0);
	c.rgb = mix(c.rgb, rim_color.rgb, clamp(edge * rim, 0.0, 1.0));
	COLOR *= c;
}
