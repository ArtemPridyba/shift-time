shader_type canvas_item;
// A soft dark around the edges of the frame (D87, Д5.1): the eye stays on the
// heroine, and under Shift the threads of time come out of this dark. Drawn by
// TimeHud over the room and the heroine. Numbers: `vignette` in
// data/time_hud.json.

uniform float strength = 0.35;
// Where the dark starts and where it is full, as the distance from the centre:
// 1.0 is a corner of the screen.
uniform float inner = 0.5;
uniform float outer = 1.1;
uniform vec2 aspect = vec2(1.777, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p) / length(aspect * 0.5);
	COLOR = vec4(0.0, 0.0, 0.0, strength * smoothstep(inner, outer, d));
}
