shader_type canvas_item;
render_mode blend_add;
// A soft glow along the screen edges with thin streaks that run to the left,
// while the world is rewound (docs/setting.md, section 4). It is the same light
// as around the wrist device, added over the picture, never a dark frame.
//
// `amount` is eased in code: 0 forward, 1 rewind. `phase` comes from
// TimeIndicatorState and shrinks in rewind, so every streak runs left; it is
// not TIME, so the direction stays in the game's own state.

uniform vec4 glow_color : source_color = vec4(0.5, 0.91, 1.0, 1.0);
uniform float amount = 0.0;
uniform float phase = 0.0;
uniform float glow_strength = 0.35;
// Width of the glow as a fraction of the screen width.
uniform float width = 0.12;
uniform float streak_strength = 0.85;
// Share of the rows that carry a streak, and the streak length as a fraction
// of the screen width.
uniform float streak_density = 0.4;
uniform float streak_length = 0.12;
uniform float streak_rows = 54.0;
// Thickness of a streak as a fraction of its row.
uniform float streak_thickness = 0.07;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	// Equal width in pixels at the sides and at the top and bottom, a little
	// narrower there so the long streaks do not crowd the picture.
	float edge_x = 1.0 - smoothstep(0.0, width, d.x);
	float edge_y = 1.0 - smoothstep(0.0, width * 1.78 * 0.6, d.y);
	float edge = max(edge_x, edge_y * 0.6);
	float glow = edge * edge * glow_strength;

	float row = floor(UV.y * streak_rows);
	float present = step(1.0 - streak_density, hash(row + 1.0));
	float length_random = hash(row + 17.0);
	float speed = 0.6 + 0.8 * hash(row + 53.0);
	float head = fract(length_random * 7.0 + phase * speed);
	float length = streak_length * (0.6 + 0.8 * length_random);
	// 0 at the head (the left end of the streak), growing to the right.
	float along = fract(UV.x - head);
	float inside = step(along, length) * (1.0 - along / length);
	float line = 1.0 - smoothstep(streak_thickness, streak_thickness * 2.0, abs(fract(UV.y * streak_rows) - 0.5));
	float streak = present * inside * line * edge * streak_strength;

	COLOR = vec4(glow_color.rgb, clamp(glow + streak, 0.0, 1.0) * amount);
}
