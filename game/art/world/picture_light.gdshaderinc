// The light of a painted room (D131): a soft cone under every lamp, as bright
// as the lamp is now. Shared by the picture (backdrop.gdshader) and the
// objects drawn over it (object_light.gdshader), so both are lit alike.

const int MAX_LAMPS = 8;

uniform int lamp_count = 0;
// The bulbs in room pixels and how bright each one is now, 0..1.
uniform vec2 lamp_at[MAX_LAMPS];
uniform float lamp_shine[MAX_LAMPS];
uniform float top_px = 30.0;
uniform float spread = 0.42;
uniform float length_px = 760.0;
uniform float soft = 0.35;
uniform float above_px = 60.0;

float cone(vec2 p, vec2 bulb) {
	float down = p.y - bulb.y;
	float half_width = top_px + spread * max(down, 0.0);
	float side = 1.0 - smoothstep(half_width * (1.0 - soft), half_width * (1.0 + soft), abs(p.x - bulb.x));
	float top = smoothstep(-above_px, 0.0, down);
	float end = 1.0 - smoothstep(length_px * 0.7, length_px, down);
	return side * top * end;
}

// 0 in the dark, 1 in the middle of a cone of a lamp that shines fully.
float picture_light(vec2 room) {
	float light = 0.0;
	for (int i = 0; i < MAX_LAMPS; i++) {
		if (i < lamp_count) {
			light = max(light, cone(room, lamp_at[i]) * clamp(lamp_shine[i], 0.0, 1.0));
		}
	}
	return light;
}
