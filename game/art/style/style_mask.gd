class_name StyleMask
extends RefCounted
## Masks for the shared material (task Д1): a shape as SVG, rendered to a
## texture once and cached. Alpha is the shape, grey is the shade over the
## ramp (`MAIN` = the main colour, lighter is a lighter shade). SVG renders in
## the browser build too (Godot's built-in ThorVG), so shapes can be code,
## files from `game/art/` or, later, drawn art in the same form.

## The grey of the main colour: red 0.5 maps to ramp index 2.
const MAIN := "#808080"
const LIGHTER := "#c0c0c0"
const LIGHTEST := "#ffffff"
const DARKER := "#404040"

static var _cache := {}


## The texture of an SVG document, cached by its text.
static func texture(svg: String) -> Texture2D:
	if _cache.has(svg):
		return _cache[svg]
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		push_error("StyleMask: bad SVG")
		return null
	var result := ImageTexture.create_from_image(image)
	_cache[svg] = result
	return result


## An SVG document of `size` pixels holding `body` (SVG elements).
static func svg(size: Vector2i, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">%s</svg>' % [size.x, size.y, body]


## A filled rectangle over the whole mask.
static func rect(size: Vector2i, fill: String = MAIN) -> String:
	return svg(size, '<rect width="%d" height="%d" fill="%s"/>' % [size.x, size.y, fill])


## An SVG path for a closed polygon.
static func path(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for i in points.size():
		parts.append("%s%.2f %.2f" % ["M" if i == 0 else "L", points[i].x, points[i].y])
	parts.append("Z")
	return " ".join(parts)


## A circle as an SVG path (to cut holes with fill-rule evenodd).
static func circle_path(center: Vector2, radius: float) -> String:
	return "M%.2f %.2f a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 %.2f 0 Z" % [
		center.x - radius, center.y, radius, radius, radius * 2.0, radius, radius, -radius * 2.0]


## A gear: `teeth` teeth between `root` and `tip` radius, holes of `hole`
## radius on a ring, a lighter hub. Centred in a square mask.
static func gear(teeth: int, tip: float, root: float, holes: int = 4, hole: float = 0.0, hub: float = 0.0) -> String:
	var side := int(ceil(tip * 2.0)) + 4
	var c := Vector2(side, side) * 0.5
	var points := PackedVector2Array()
	for i in teeth * 4:
		var a := i * TAU / (teeth * 4)
		points.append(c + Vector2(cos(a), sin(a)) * (tip if (i % 4) in [1, 2] else root))
	var d := path(points)
	var ring := (root + hub) * 0.5
	for i in holes:
		var a := i * TAU / holes + PI / 4.0
		d += " " + circle_path(c + Vector2(cos(a), sin(a)) * ring, hole)
	var body := '<path d="%s" fill="%s" fill-rule="evenodd"/>' % [d, MAIN]
	if hub > 0.0:
		body += '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % [c.x, c.y, hub, LIGHTER]
		body += '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % [c.x, c.y, hub * 0.35, DARKER]
	return svg(Vector2i(side, side), body)
