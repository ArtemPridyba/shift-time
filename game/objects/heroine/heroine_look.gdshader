shader_type canvas_item;
render_mode unshaded;
// The heroine as one picture (D81, 20.11.2026): the rig draws all her parts
// into a CanvasGroup and this material draws the group. It only lifts her out
// of the dark: gain multiplies, gamma below 1 opens her shadows. No coloured
// rim (Boris, 20.11: an orange edge in the dark looks wrong). The rig sets
// the uniforms from `look` of data/heroine.json.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float gain = 1.0;
uniform float gamma = 1.0;
// Under Shift a soft even glow of the time colour over the whole figure,
// laid on after the brightness, as in the "Night shop" mock-up (D80.1).
uniform vec4 accent : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float tint = 0.0;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(gamma)) * gain;
	c.rgb = mix(c.rgb, accent.rgb, tint);
	COLOR *= c;
}
