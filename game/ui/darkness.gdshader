shader_type canvas_item;
// Darkness mask: black everywhere except round holes under lit lamps.
// `lights` holds (x, y, radius, intensity) in canvas pixels, `mask_size` is the size of the mask rectangle. `ambient` is how much of
// the world still shows in the dark (0 = nothing).

const int MAX_LIGHTS = 8;

uniform vec4 lights[MAX_LIGHTS];
uniform int light_count = 0;
uniform float ambient = 0.02;
uniform float falloff_power = 1.6;
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
		// Brightest at the lamp, fading smoothly to the edge (same curve as LightField).
		float t = clamp(d / r, 0.0, 1.0);
		lit = max(lit, lights[i].w * pow(1.0 - t, falloff_power));
	}
	float dark = 1.0 - max(lit, ambient);
	COLOR = vec4(0.0, 0.0, 0.0, dark);
}
