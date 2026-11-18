shader_type canvas_item;
// The shared material of the style (task Д1). It paints a shape from its mask
// in the colours of one palette role, by one rule for every object:
// dark outline, body in the main colour, lighter towards the light and darker
// towards the floor; wear: paint chipped to bare metal along the edges, dust
// on upper edges, dirt at the bottom, rust patches only where asked.
// Smooth, not pixel art (decision 18.11.2026): the outline is antialiased,
// shades blend along the role's ramp, wear comes in soft patches.
//
// The mask: alpha is the shape; red is the shade of the body, 0..1 over the
// ramp (0.5 = the main colour), so drawn art can carry its own darker and
// lighter parts. Wear comes from the object's own pixel grid and seed, never
// from time: it does not flicker and stays the same under Shift.
// All numbers come from `art.json` (`material`) through StyleShape.

uniform vec4 ramp[5];
uniform vec4 rust_ramp[5];
uniform vec4 dark_color;
uniform vec4 bare_color;
// Towards the light and towards the floor, in the mask's own space (the node
// turns them with its rotation, so a turning gear keeps its light on top).
uniform vec2 light_dir = vec2(-0.45, -0.9);
uniform vec2 down_dir = vec2(0.0, 1.0);
uniform float outline_px = 2.0;
uniform float rim_px = 3.0;
uniform float shadow_px = 3.0;
uniform float chip_reach_px = 5.0;
uniform float chip_density = 0.2;
uniform float chip_scale_px = 5.0;
uniform float dust_px = 4.0;
uniform float dust_strength = 0.35;
uniform float dirt_px = 18.0;
uniform float dirt_strength = 0.35;
uniform float rust_scale_px = 14.0;
// Per object: how worn (0..1) and how rusty (0..1), and its own seed.
uniform float wear = 1.0;
uniform float rust = 0.0;
uniform float seed = 0.0;

const int MAX_STEPS = 24;
const float NONE = 1000.0;

float alpha_at(sampler2D mask, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(mask, uv).a;
}

// Pixels from `uv` to the edge along `dir`, up to `limit`; between two
// samples the edge is placed by the mask's own antialiasing, so the result is
// smooth, not whole pixels.
float reach(sampler2D mask, vec2 uv, vec2 dir, float limit, vec2 px) {
	float last = alpha_at(mask, uv);
	for (int i = 1; i <= MAX_STEPS; i++) {
		float d = float(i);
		if (d > limit + 1.0) {
			break;
		}
		float a = alpha_at(mask, uv + dir * d * px);
		if (a < 0.5) {
			return d - 1.0 + clamp((last - 0.5) / max(last - a, 0.001), 0.0, 1.0);
		}
		last = a;
	}
	return NONE;
}

// Pixels to the nearest edge in any of twelve directions, up to `limit`.
float edge(sampler2D mask, vec2 uv, float limit, vec2 px) {
	float best = NONE;
	for (int k = 0; k < 12; k++) {
		float a = float(k) * 0.523599;
		best = min(best, reach(mask, uv, vec2(cos(a), sin(a)), limit, px));
	}
	return best;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.618);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Two octaves: soft patches with a ragged edge.
float patches(vec2 p) {
	return noise(p) * 0.7 + noise(p * 2.7 + 5.0) * 0.3;
}

// A colour of the ramp at a fractional shade: neighbours blend.
vec4 shade(float index) {
	float t = clamp(index, 0.0, 4.0);
	int lo = int(floor(t));
	int hi = min(lo + 1, 4);
	return mix(ramp[lo], ramp[hi], t - float(lo));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.02) {
		discard;
	}
	vec2 at = UV / px;
	vec2 to_light = normalize(light_dir);
	vec2 to_floor = normalize(down_dir);
	float index = clamp(mask.r, 0.0, 1.0) * 4.0;

	float o = outline_px;
	float up = reach(TEXTURE, UV, to_light, o + rim_px + dust_px, px);
	float low = reach(TEXTURE, UV, to_floor, o + shadow_px + dirt_px, px);
	float near = edge(TEXTURE, UV, o + chip_reach_px, px);
	// Light: a soft rim on the side of the light, a soft shadow on the far side.
	index += 1.0 - smoothstep(o, o + rim_px, up);
	index -= 1.0 - smoothstep(o, o + shadow_px, low);
	// Dust settles on upper edges, dirt gathers at the bottom: soft patches
	// towards the next shade of the same ramp.
	float dust_band = 1.0 - smoothstep(o + rim_px, o + rim_px + dust_px, up);
	index += 0.8 * dust_band * smoothstep(1.0 - dust_strength * wear, 1.05 - dust_strength * wear * 0.5, patches(at / 6.0 + 3.0));
	float dirt_band = 1.0 - smoothstep(o + shadow_px, o + shadow_px + dirt_px, low);
	index -= dirt_band * dirt_strength * wear * (0.5 + 0.5 * patches(at / 10.0 + 11.0));
	vec4 color = shade(index);

	// Rust: soft patches of the rust ramp, thicker towards the floor.
	if (rust > 0.0) {
		float r = patches(at / rust_scale_px);
		float low_bias = low < NONE ? 0.25 * (1.0 - low / (o + shadow_px + dirt_px)) : 0.0;
		float amount = smoothstep(1.0 - rust * 0.6, 1.08 - rust * 0.6, r + low_bias);
		vec4 rusty = mix(rust_ramp[1], rust_ramp[2], noise(at / (rust_scale_px * 0.5) + 7.0));
		color = mix(color, rusty, amount);
	}
	// Chips of paint down to bare metal, only near edges, with a soft rim.
	if (near < NONE && wear > 0.0) {
		float closeness = 1.0 - clamp((near - o) / max(chip_reach_px, 1.0), 0.0, 1.0);
		float chip = smoothstep(1.0 - chip_density * wear, 1.06 - chip_density * wear, patches(at / chip_scale_px) * (0.4 + 0.6 * closeness));
		color = mix(color, bare_color, chip * closeness);
	}
	// The outline: antialiased on both sides.
	float line = 1.0 - smoothstep(o - 0.5, o + 0.5, near);
	color = mix(color, dark_color, line);
	COLOR = vec4(color.rgb, smoothstep(0.02, 0.5, mask.a));
}
