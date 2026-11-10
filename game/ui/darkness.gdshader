shader_type canvas_item;
// Darkness mask: black everywhere except round holes under lit lamps.
// `lights` holds (x, y, radius) in canvas pixels, `mask_size` is the size of the mask rectangle. `ambient` is how much of
// the world still shows in the dark (0 = nothing).

const int MAX_LIGHTS = 8;

uniform vec3 lights[MAX_LIGHTS];
uniform int light_count = 0;
uniform float ambient = 0.02;
uniform vec2 mask_size = vec2(1920.0, 1080.0);

void fragment() {
	// UV runs from the top-left corner of the mask, like the canvas transform.
	vec2 pixel = UV * mask_size;
	float lit = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		float d = distance(pixel, lights[i].xy);
		float r = lights[i].z;
		lit = max(lit, 1.0 - smoothstep(r * 0.6, r, d));
	}
	float dark = 1.0 - max(lit, ambient);
	COLOR = vec4(0.0, 0.0, 0.0, dark);
}
