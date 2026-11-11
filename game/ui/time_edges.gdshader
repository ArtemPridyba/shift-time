shader_type canvas_item;
// Darkened screen edges and a light grain while the world is rewound
// (docs/setting.md, section 4). `amount` is eased in code: 0 forward, 1 rewind.

uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amount = 0.0;
uniform float strength = 0.55;
uniform float width = 0.22;
uniform float grain = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = (1.0 - smoothstep(0.0, width, min(d.x, d.y))) * strength * amount;
	float noise = (hash(floor(UV * vec2(480.0, 270.0)) + floor(TIME * 24.0)) - 0.5) * grain * amount;
	float noise_alpha = abs(noise);
	vec3 noise_color = noise > 0.0 ? vec3(0.9) : edge_color.rgb;
	float alpha = edge + noise_alpha * (1.0 - edge);
	vec3 color = (edge_color.rgb * edge + noise_color * noise_alpha * (1.0 - edge)) / max(alpha, 0.0001);
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
