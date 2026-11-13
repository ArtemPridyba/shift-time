shader_type canvas_item;
// The wood of a wood zone (task 2.7А): planks along the long side, grain,
// and while it burns a char front that eats it from the top and from spots,
// with a glowing ember edge and hot cracks in the charred part. Everything
// comes from uniforms (the recorded burn and world time), so it rewinds.

uniform vec2 size = vec2(256.0, 32.0);
// 0 whole wood, 1 charred through (the front of the char).
uniform float charred : hint_range(0.0, 1.0) = 0.0;
// 0 to 1: how strong the flames are; the embers glow by it.
uniform float heat : hint_range(0.0, 1.0) = 0.0;
// World seconds.
uniform float time = 0.0;
uniform float plank_px = 16.0;
// 1 for a wall (planks stand up), 0 for a bridge.
uniform float vertical = 0.0;
uniform vec4 wood_color : source_color = vec4(0.49, 0.42, 0.33, 1.0);
uniform vec4 plank_color : source_color = vec4(0.36, 0.30, 0.24, 1.0);
uniform vec4 char_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform vec4 ember_hot_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);

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
	vec2 px = UV * size;
	float across = mix(px.y, px.x, vertical);
	float along = mix(px.x, px.y, vertical);
	float seam = step(plank_px - 1.5, mod(across, plank_px));
	float plank_id = floor(across / plank_px);
	float grain = fbm(vec2(along * 0.02 + plank_id * 7.0, across * 0.35));
	vec3 wood = mix(wood_color.rgb, plank_color.rgb, clamp(seam * 0.8 + grain * 0.45 - 0.1, 0.0, 1.0));

	// The char front: fire sits on top, so the top chars first, then spots.
	float n = fbm(px * 0.035 + vec2(3.1, 7.7));
	float v = n * 0.75 + UV.y * 0.25 * (1.0 - vertical) + (1.0 - UV.y) * 0.0;
	float front = charred * 1.15;
	float char_amount = smoothstep(v - 0.08, v, front);
	vec3 col = mix(wood, char_color.rgb, char_amount);

	// The ember edge right at the front, and hot cracks in the char.
	float pulse = 0.65 + 0.35 * sin(time * 7.0 + n * 20.0);
	float edge = clamp(1.0 - abs(front - v) / 0.05, 0.0, 1.0) * step(0.001, charred);
	float crack = smoothstep(0.58, 0.66, noise(px * 0.11 + vec2(13.0, 5.0))) * char_amount;
	float glow = clamp(edge * 0.9 + crack * 0.6 * pulse, 0.0, 1.0) * heat;
	col = mix(col, mix(ember_color.rgb, ember_hot_color.rgb, edge * pulse), glow);
	COLOR = vec4(col, 1.0);
}
