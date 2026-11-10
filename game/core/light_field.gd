class_name LightField
extends RefCounted
## Plain rules of light: how bright a point is under a set of light sources.
## A source is a Dictionary `{ "position": Vector2, "radius": float,
## "intensity": float }` in the room's coordinates (`intensity` 0..1, 1 when
## missing). Brightest at the source, fading smoothly to nothing at the radius.
## No nodes, no drawing: the darkness mask and the glow items ask this class,
## and `darkness.gdshader` uses the same `FALLOFF_POWER`.

## How fast the light weakens from the source to the edge of its circle.
const FALLOFF_POWER := 1.6
## Below this brightness a place counts as dark: special items do not glow.
const LIT_THRESHOLD := 0.08


## Brightness 0..1 of one source at `point`.
static func source_brightness(point: Vector2, source: Dictionary) -> float:
	var radius := float(source["radius"])
	if radius <= 0.0:
		return 0.0
	var t := clampf(point.distance_to(source["position"] as Vector2) / radius, 0.0, 1.0)
	return float(source.get("intensity", 1.0)) * pow(1.0 - t, FALLOFF_POWER)


## Brightness 0..1 of the brightest source at `point`.
static func brightness(point: Vector2, sources: Array) -> float:
	var best := 0.0
	for source: Variant in sources:
		best = maxf(best, source_brightness(point, source as Dictionary))
	return best


## True when `point` is lit well enough for special items to glow.
static func is_lit(point: Vector2, sources: Array) -> bool:
	return brightness(point, sources) >= LIT_THRESHOLD
