shader_type canvas_item;
// The gauntlet's light on the heroine's own body (D76): every part of the doll
// draws with this material, so the light falls only on her pixels and never on
// the room. Weak in forward time, stronger under Shift. The even glow of the
// time colour under Shift is laid over the whole figure in heroine_look.gdshader
// (D80.1). The rig sets every uniform from data/heroine.json and
// data/time_hud.json.

// The strip of the gauntlet in canvas pixels, and the light's reach there.
uniform vec2 light_pos = vec2(0.0);
uniform float radius = 30.0;
uniform float light = 0.1;
uniform vec4 accent : source_color = vec4(0.5, 0.9, 1.0, 1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float d = distance(world, light_pos);
	float near = 1.0 - smoothstep(0.0, radius, d);
	c.rgb += accent.rgb * light * near * near;
	COLOR = c;
}
