shader_type canvas_item;
// The gauntlet's light on the heroine's own body (D76): every part of the doll
// draws with this material, so the light falls only on her pixels and never on
// the room. Weak in forward time, stronger under Shift; under Shift waves of
// the time colour also run over her body into the gauntlet. The rig sets every
// uniform from data/heroine.json and data/time_hud.json.

// The strip of the gauntlet in canvas pixels, and the light's reach there.
uniform vec2 light_pos = vec2(0.0);
uniform float radius = 30.0;
uniform float light = 0.1;
uniform vec4 accent : source_color = vec4(0.5, 0.9, 1.0, 1.0);
// 0 in forward time, up to wave_strength under Shift.
uniform float waves = 0.0;
uniform float wave_px = 16.0;
uniform float wave_phase = 0.0;
uniform float wave_width = 0.25;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float d = distance(world, light_pos);
	float near = 1.0 - smoothstep(0.0, radius, d);
	// A ring every wave_px: as the phase grows the rings close in on the light.
	float w = fract(d / wave_px + wave_phase);
	float half_w = wave_width * 0.5;
	float band = smoothstep(0.0, half_w, w) * (1.0 - smoothstep(half_w, wave_width, w));
	c.rgb += accent.rgb * (light * near * near + waves * band);
	COLOR = c;
}
