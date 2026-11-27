shader_type canvas_item;
// The painted room (D131): the dark picture everywhere, the lit one through a
// soft cone under every lamp, as bright as the lamp is now. Both pictures are
// the same room at the same size; TEXTURE is the lit one.

#include "res://art/world/picture_light.gdshaderinc"

uniform sampler2D dark_picture : filter_linear_mipmap, repeat_disable;

varying vec2 room;

void vertex() {
	room = VERTEX;
}

void fragment() {
	vec4 lit = texture(TEXTURE, UV);
	vec4 dark = texture(dark_picture, UV);
	COLOR = mix(dark, lit, picture_light(room));
}
