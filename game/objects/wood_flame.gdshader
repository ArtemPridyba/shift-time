shader_type canvas_item;
// The flames of a burning wood zone (task 2.7А): ragged tongues above the
// zone and licks over its face. The turbulence moves up as world time grows,
// so under Shift the tongues flow back down into the wood (decoration plays
// backwards); while the world stands at frame 0 the flames stand still.

// The drawn rect and, inside it, the zone (pixels, from the rect's corner).
uniform vec2 rect_size = vec2(320.0, 160.0);
uniform vec2 zone_pos = vec2(32.0, 120.0);
uniform vec2 zone_size = vec2(256.0, 32.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float flame_px = 40.0;
uniform float rise_px = 90.0;
uniform float side_px = 16.0;
uniform vec4 red : source_color = vec4(0.78, 0.16, 0.05, 1.0);
uniform vec4 orange : source_color = vec4(1.0, 0.52, 0.14, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.88, 0.5, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 zp = UV * rect_size - zone_pos;
	float dx = max(max(-zp.x, zp.x - zone_size.x), 0.0);
	float side = 1.0 - smoothstep(0.0, side_px, dx);
	float above = -zp.y;
	// The height of the tongues at this x flickers in world time.
	float h = flame_px * strength * (0.6 + 1.0 * fbm(vec2(zp.x * 0.022, time * 1.3)));
	// Rising turbulence: it scrolls up with world time.
	float turb = fbm(vec2(zp.x * 0.06, (zp.y + time * rise_px) * 0.022));
	float body;
	if (above >= 0.0) {
		body = clamp(1.0 - above / max(h, 1.0), 0.0, 1.0);
	} else {
		// Licks over the face of the zone, thinning away from its top.
		// Full at the top edge, thinning into licks a little lower down.
		float depth = -above / max(zone_size.y, 1.0);
		body = mix(1.0, 0.5 - 0.45 * depth, smoothstep(0.0, 28.0, -above));
	}
	float f = body * side * (0.35 + 1.1 * turb) - 0.3;
	f = clamp(f * 1.8, 0.0, 1.0) * step(0.001, strength);
	vec3 col = mix(red.rgb, orange.rgb, smoothstep(0.05, 0.45, f));
	col = mix(col, yellow.rgb, smoothstep(0.55, 0.95, f));
	float alpha = smoothstep(0.02, 0.22, f) * (above >= 0.0 ? 1.0 : 0.55);
	COLOR = vec4(col, alpha);
}
