shader_type canvas_item;
// An object drawn by code over a painted room (24.11, level 01 notes): it
// takes the picture's light instead of the room's darkness and lamp islands,
// so it is dim in the dark and warm under a lamp's cone, its blacks
// lifted by the picture's haze; soft_px blurs it a little to match the soft picture. Unshaded: the
// room's CanvasModulate and its Light2D do not touch it.
render_mode unshaded;

#include "res://art/world/picture_light.gdshaderinc"

// The level's origin on the canvas: the cones are in room pixels.
uniform vec2 level_origin = vec2(0.0);
uniform float dark = 0.35;
uniform vec4 lit_color : source_color = vec4(1.0);
// How much brighter than its own colour it is in the middle of a cone.
uniform float lit_gain = 1.0;
// The picture's haze: dark parts of the object lift towards this colour.
uniform vec4 haze_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float haze = 0.0;
uniform float soft_px = 0.0;

varying vec2 room;

void vertex() {
	room = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - level_origin;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (soft_px > 0.0) {
		vec2 d = TEXTURE_PIXEL_SIZE * soft_px;
		c = (2.0 * c + texture(TEXTURE, UV + vec2(d.x, 0.0)) + texture(TEXTURE, UV - vec2(d.x, 0.0))
				+ texture(TEXTURE, UV + vec2(0.0, d.y)) + texture(TEXTURE, UV - vec2(0.0, d.y))) / 6.0;
	}
	c *= COLOR;
	float light = picture_light(room);
	c.rgb *= mix(vec3(dark), lit_color.rgb * lit_gain, light);
	c.rgb = mix(c.rgb, max(c.rgb, haze_color.rgb), haze);
	COLOR = c;
}
