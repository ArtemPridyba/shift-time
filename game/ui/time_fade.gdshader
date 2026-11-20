shader_type canvas_item;
render_mode unshaded;
// The world fades a little while it is rewound (D86, task Д5.1): the room
// drawn so far loses some colour and light. TimeHud draws this layer at z 1,
// above the room and under the heroine, so she keeps her colour: she lives
// forward. Numbers: `rewind.world_saturation` and `rewind.world_brightness`
// in data/time_hud.json.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount = 0.0;
uniform float saturation = 0.7;
uniform float brightness = 0.95;

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(grey), c, mix(1.0, saturation, amount));
	COLOR = vec4(c * mix(1.0, brightness, amount), 1.0);
}
