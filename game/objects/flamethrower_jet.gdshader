shader_type canvas_item;
// The jet of the reverse flamethrower (task 2.7А), drawn from the nozzle
// along +x. `flow` 1: fire bursts out (under Shift); -1: air and fire stream
// into the nozzle (normal time). The item's own live time drives it, so the
// jet always reads the way it acts.

uniform vec2 rect_size = vec2(224.0, 120.0);
uniform float time = 0.0;
uniform float flow = 1.0;
uniform float speed_px = 420.0;
uniform vec4 red : source_color = vec4(0.78, 0.16, 0.05, 1.0);
uniform vec4 orange : source_color = vec4(1.0, 0.52, 0.14, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.88, 0.5, 1.0);
uniform vec4 air : source_color = vec4(0.82, 0.85, 0.86, 1.0);

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
	vec2 px = UV * rect_size;
	float along = px.x / rect_size.x;
	// The cone widens away from the nozzle.
	float half_width = rect_size.y * (0.08 + 0.42 * along);
	float d = abs(px.y - rect_size.y * 0.5) / max(half_width, 1.0);
	float moving = px.x - time * speed_px * flow;
	if (flow > 0.0) {
		float turb = fbm(vec2(moving * 0.03, px.y * 0.05));
		float f = (1.0 - d) * (0.55 + 0.9 * turb) * (1.0 - along * 0.85) - 0.2;
		f = clamp(f * 1.7, 0.0, 1.0);
		vec3 col = mix(red.rgb, orange.rgb, smoothstep(0.05, 0.45, f));
		col = mix(col, yellow.rgb, smoothstep(0.6, 0.95, f));
		COLOR = vec4(col, smoothstep(0.02, 0.2, f));
	} else {
		// Thin streaks of air pulled in, brighter near the nozzle.
		float streak = smoothstep(0.72, 0.9, noise(vec2(moving * 0.04, px.y * 0.22)));
		float f = streak * (1.0 - d) * (1.0 - along * 0.6);
		float lick = smoothstep(0.75, 0.95, fbm(vec2(moving * 0.05, px.y * 0.08))) * (1.0 - d) * (1.0 - along);
		vec3 col = mix(air.rgb, orange.rgb, lick);
		COLOR = vec4(col, clamp(f * 0.7 + lick * 0.8, 0.0, 1.0));
	}
}
