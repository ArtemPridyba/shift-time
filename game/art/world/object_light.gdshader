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
// How much the signal yellow keeps its own hue in a cone (25.11, D165): the
// warm lit_color would turn the yellow edge orange, so saturated yellow takes
// only the cone's brightness and is never clipped into another hue.
uniform float yellow_keep = 0.0;

varying vec2 room;
// The draw's own colour (modulate). In fragment() COLOR already holds the
// texture times it, so taking COLOR there would square the picture: darker and
// more saturated, the yellow edge orange (fixed 25.11, D165).
varying vec4 tint;

void vertex() {
	room = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - level_origin;
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (soft_px > 0.0) {
		vec2 d = TEXTURE_PIXEL_SIZE * soft_px;
		c = (2.0 * c + texture(TEXTURE, UV + vec2(d.x, 0.0)) + texture(TEXTURE, UV - vec2(d.x, 0.0))
				+ texture(TEXTURE, UV + vec2(0.0, d.y)) + texture(TEXTURE, UV - vec2(0.0, d.y))) / 6.0;
	}
	c *= tint;
	float light = picture_light(room);
	vec3 lit = mix(vec3(dark), lit_color.rgb * lit_gain, light);
	vec3 warm = c.rgb * lit;
	vec3 own = c.rgb * dot(lit, vec3(0.299, 0.587, 0.114));
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = (hi - lo) / max(hi, 0.001);
	float hue = 60.0 * (c.g - c.b) / max(c.r - c.b, 0.001);
	float yellow = yellow_keep * smoothstep(0.40, 0.55, sat) * smoothstep(18.0, 28.0, hue)
			* (1.0 - smoothstep(75.0, 90.0, hue)) * step(c.b, c.r);
	own /= max(1.0, max(own.r, max(own.g, own.b)));
	c.rgb = mix(warm, own, yellow);
	c.rgb = mix(c.rgb, max(c.rgb, haze_color.rgb), haze);
	COLOR = c;
}
