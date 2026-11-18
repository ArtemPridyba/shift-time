shader_type canvas_item;
// The shared material of the style (task Д1). It paints a shape from its mask
// in the colours of one palette role, by one rule for every object:
// dark outline, body in the main colour, a light edge on the side of the light,
// a shadow on the far side; wear: paint chipped to bare metal along the edges,
// dust on upper edges, dirt at the bottom, rust patches only where asked.
// Every colour it puts out is a colour of the palette: no blending.
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

float inside(sampler2D mask, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return step(0.5, texture(mask, uv).a);
}

// Pixels from `uv` to the nearest outside pixel along `dir`, up to `limit`.
float reach(sampler2D mask, vec2 uv, vec2 dir, float limit, vec2 px) {
	for (int i = 1; i <= MAX_STEPS; i++) {
		float d = float(i);
		if (d > limit) {
			break;
		}
		if (inside(mask, uv + dir * d * px) < 0.5) {
			return d;
		}
	}
	return NONE;
}

// Pixels to the nearest edge in any of eight directions, up to `limit`.
float edge(sampler2D mask, vec2 uv, float limit, vec2 px) {
	float best = NONE;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
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

vec4 shade(int index) {
	return ramp[clamp(index, 0, 4)];
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.5) {
		discard;
	}
	vec2 at = UV / px;
	vec2 to_light = normalize(light_dir);
	vec2 to_floor = normalize(down_dir);
	int index = int(round(clamp(mask.r, 0.0, 1.0) * 4.0));

	// Bands are counted from the inner side of the outline.
	float o = outline_px;
	float up = reach(TEXTURE, UV, to_light, o + rim_px + dust_px, px);
	float low = reach(TEXTURE, UV, to_floor, o + shadow_px + dirt_px, px);
	float near = edge(TEXTURE, UV, o + chip_reach_px, px);
	if (up <= o + rim_px) {
		index += 1;
	} else if (low <= o + shadow_px) {
		index -= 1;
	}
	// Dust settles on upper edges, dirt gathers at the bottom: specks of the
	// next shade of the same ramp, so every colour stays in the palette.
	if (up > o + rim_px && up <= o + rim_px + dust_px && noise(at / 2.0 + 3.0) > 1.0 - dust_strength * wear) {
		index += 1;
	}
	if (low > o + shadow_px && low <= o + shadow_px + dirt_px) {
		float depth = 1.0 - (low - o - shadow_px) / max(dirt_px, 1.0);
		if (noise(at / 3.0 + 11.0) * depth > 1.0 - dirt_strength * wear) {
			index -= 1;
		}
	}
	vec4 color = shade(index);

	// Rust: patches of the rust ramp, thicker towards the floor.
	if (rust > 0.0) {
		float r = noise(at / rust_scale_px) * 0.7 + noise(at / (rust_scale_px * 0.35)) * 0.3;
		float low_bias = low < NONE ? 0.25 * (1.0 - low / (o + shadow_px + dirt_px)) : 0.0;
		if (r + low_bias > 1.0 - rust * 0.6) {
			color = rust_ramp[noise(at / (rust_scale_px * 0.5) + 7.0) > 0.5 ? 2 : 1];
		}
	}
	// Chips of paint down to bare metal, only near edges.
	if (near < NONE && wear > 0.0) {
		float closeness = 1.0 - (near - o - 1.0) / max(chip_reach_px, 1.0);
		if (noise(at / chip_scale_px) * closeness > 1.0 - chip_density * wear) {
			color = bare_color;
		}
	}
	if (near <= o) {
		color = dark_color;
	}
	COLOR = vec4(color.rgb, 1.0);
}
