shader_type canvas_item;
// The painted room (D131): the dark picture everywhere, the lit one through a
// soft cone under every lamp, as bright as the lamp is now. Both pictures are
// the same room at the same size; TEXTURE is the lit one.

const int MAX_LAMPS = 8;

uniform sampler2D dark_picture : filter_linear, repeat_disable;
uniform int lamp_count = 0;
// The bulbs in this node's pixels and how bright each one is now, 0..1.
uniform vec2 lamp_at[MAX_LAMPS];
uniform float lamp_shine[MAX_LAMPS];
uniform float top_px = 30.0;
uniform float spread = 0.42;
uniform float length_px = 760.0;
uniform float soft = 0.35;
uniform float above_px = 60.0;

varying vec2 room;

void vertex() {
	room = VERTEX;
}

float cone(vec2 p, vec2 bulb) {
	float down = p.y - bulb.y;
	float half_width = top_px + spread * max(down, 0.0);
	float side = 1.0 - smoothstep(half_width * (1.0 - soft), half_width * (1.0 + soft), abs(p.x - bulb.x));
	float top = smoothstep(-above_px, 0.0, down);
	float end = 1.0 - smoothstep(length_px * 0.7, length_px, down);
	return side * top * end;
}

void fragment() {
	vec4 lit = texture(TEXTURE, UV);
	vec4 dark = texture(dark_picture, UV);
	float light = 0.0;
	for (int i = 0; i < MAX_LAMPS; i++) {
		if (i < lamp_count) {
			light = max(light, cone(room, lamp_at[i]) * clamp(lamp_shine[i], 0.0, 1.0));
		}
	}
	COLOR = mix(dark, lit, light);
}
