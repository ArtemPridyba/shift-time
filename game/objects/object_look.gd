class_name ObjectLook
extends RefCounted
## The dressed look of a level's objects (task Д4): numbers from `kit_objects`
## of `data/look.json`, pictures of the Night shop kit by name
## (`world.textures`, KitTextures). Only presentation: nothing here is recorded.
## Objects redraw every tick while they move, so the data and the pictures are
## read once and kept (`Content` reads the file on every call).

static var _cache := {}


## The numbers of object `name` (shutter, platform, exit_door, clock, beacon).
static func of(name: String) -> Dictionary:
	var key := "of:" + name
	if not _cache.has(key):
		var all: Variant = Content.look().get("kit_objects")
		var one: Variant = (all as Dictionary).get(name) if all is Dictionary else null
		_cache[key] = one if one is Dictionary else {}
	return _cache[key]


## `mech` of look.json: the colours of cast iron.
static func mech() -> Dictionary:
	if not _cache.has("mech"):
		var value: Variant = Content.look().get("mech")
		_cache["mech"] = value if value is Dictionary else {}
	return _cache["mech"]


## A kit piece by name, or null (KitTextures.piece, kept).
static func picture(name: String) -> Texture2D:
	var key := "piece:" + name
	if not _cache.has(key):
		_cache[key] = KitTextures.piece(name)
	return _cache[key]


## A kit tile by name (KitTextures.tile, kept).
static func tile(name: String) -> Texture2D:
	var key := "tile:" + name
	if not _cache.has(key):
		_cache[key] = KitTextures.tile(name)
	return _cache[key]


## KitTextures.texel, kept.
static func texel(name: String) -> float:
	var key := "texel:" + name
	if not _cache.has(key):
		_cache[key] = KitTextures.texel(name)
	return _cache[key]


static func number(look: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = look.get(key)
	return float(value) if value is float or value is int else fallback


static func color(look: Dictionary, key: String, fallback: Color) -> Color:
	var value := str(look.get(key, ""))
	return Color(value) if Color.html_is_valid(value) else fallback


## A rect `[x, y, w, h]` of numbers, or `fallback`.
static func rect(look: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = look.get(key)
	if not value is Array or (value as Array).size() != 4:
		return fallback
	var a := value as Array
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


## The size of a kit picture in room pixels when it keeps its proportions and
## is `longest` pixels along its longer side.
static func fit(picture: Texture2D, longest: float) -> Vector2:
	var w := float(picture.get_width())
	var h := float(picture.get_height())
	var k := longest / maxf(maxf(w, h), 1.0)
	return Vector2(w * k, h * k)


## `picture` centred at `at`, `size` room pixels, turned by `angle`.
static func draw_turned(item: CanvasItem, picture: Texture2D, at: Vector2, size: Vector2,
		angle: float, modulate := Color.WHITE) -> void:
	item.draw_set_transform(at, angle, Vector2.ONE)
	item.draw_texture_rect(picture, Rect2(-size / 2.0, size), false, modulate)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## `region` of `picture` repeated down `r` as wide as `r`, the last copy cut.
## Works without texture repeat: every copy is its own draw.
static func draw_region_down(item: CanvasItem, picture: Texture2D, region: Rect2, r: Rect2,
		modulate := Color.WHITE) -> void:
	var step := r.size.x * region.size.y / maxf(region.size.x, 0.001)
	var y := 0.0
	while y < r.size.y - 0.01:
		var h := minf(step, r.size.y - y)
		var part := Rect2(region.position, Vector2(region.size.x, region.size.y * h / step))
		item.draw_texture_rect_region(picture, Rect2(r.position + Vector2(0.0, y), Vector2(r.size.x, h)), part, modulate)
		y += step


## Same along x, as tall as `r`.
static func draw_region_across(item: CanvasItem, picture: Texture2D, region: Rect2, r: Rect2,
		modulate := Color.WHITE, offset := 0.0) -> void:
	var step := r.size.y * region.size.x / maxf(region.size.y, 0.001)
	var x := -fposmod(offset, step)
	while x < r.size.x - 0.01:
		var x0 := maxf(x, 0.0)
		var x1 := minf(x + step, r.size.x)
		if x1 > x0:
			var u0 := region.size.x * (x0 - x) / step
			var u1 := region.size.x * (x1 - x) / step
			var part := Rect2(region.position + Vector2(u0, 0.0), Vector2(u1 - u0, region.size.y))
			item.draw_texture_rect_region(picture, Rect2(r.position + Vector2(x0, 0.0), Vector2(x1 - x0, r.size.y)), part, modulate)
		x += step


## A cast-iron frame of `px` round `r`, with rivets every `step` pixels.
static func draw_riveted_frame(item: CanvasItem, r: Rect2, px: float, iron: Color, rivet: Color,
		rivet_px: float, step: float) -> void:
	item.draw_rect(Rect2(r.position, Vector2(px, r.size.y)), iron)
	item.draw_rect(Rect2(Vector2(r.end.x - px, r.position.y), Vector2(px, r.size.y)), iron)
	item.draw_rect(Rect2(Vector2(r.position.x, r.end.y - px), Vector2(r.size.x, px)), iron)
	if step <= 0.0:
		return
	var y := r.position.y + step / 2.0
	while y < r.end.y - px:
		item.draw_circle(Vector2(r.position.x + px / 2.0, y), rivet_px / 2.0, rivet)
		item.draw_circle(Vector2(r.end.x - px / 2.0, y), rivet_px / 2.0, rivet)
		y += step
	var x := r.position.x + px + step / 2.0
	while x < r.end.x - px:
		item.draw_circle(Vector2(x, r.end.y - px / 2.0), rivet_px / 2.0, rivet)
		x += step
