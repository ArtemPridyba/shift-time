class_name KitTextures
extends RefCounted
## The pictures of the Night shop kit (task Д3, D106): a Gemini file from
## `world.textures` of `data/look.json` when its path is set, otherwise a
## placeholder painted here once and kept. Tiles repeat (the node that draws
## them turns texture repeat on); pieces without a file return null and the
## node draws them by code.

const DISC_SIZE := 256

static var _cache := {}


## A tile: brick, masonry, concrete, floor_top or concrete_top.
static func tile(name: String) -> Texture2D:
	var file := _file(name)
	if file != null:
		return file
	if _cache.has(name):
		return _cache[name]
	var world := WorldData.look()
	var image: Image
	match name:
		"brick":
			image = _brick(world)
		"masonry":
			image = _blocks(WorldData.color(world, "masonry"), Vector2i(64, 32), 3)
		"concrete":
			image = _blocks(WorldData.color(world, "concrete").darkened(0.15), Vector2i(128, 64), 5)
		"floor_top":
			image = _top(world, WorldData.color(world, "iron").lightened(0.28), WorldData.color(world, "iron"))
		"concrete_top":
			image = _top(world, WorldData.color(world, "concrete"), WorldData.color(world, "iron"))
		_:
			image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			image.fill(Color.MAGENTA)
	var texture := ImageTexture.create_from_image(image)
	_cache[name] = texture
	return texture


## A piece's Gemini picture, or null: the node draws the placeholder.
static func piece(name: String) -> Texture2D:
	return _file(name)


## A soft round spot, white in the middle and clear at the rim: the shape of a
## lamp's island of light and of the halo round a bulb.
static func soft_disc() -> Texture2D:
	if _cache.has("_disc"):
		return _cache["_disc"]
	var gradient := Gradient.new()
	# (1 - r)^2, in eight steps so no ring shows where the slope changes.
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 9:
		var r := float(i) / 8.0
		offsets.append(r)
		colors.append(Color(1, 1, 1, pow(1.0 - r, 2.0)))
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = DISC_SIZE
	texture.height = DISC_SIZE
	_cache["_disc"] = texture
	return texture


## The height of the top strip (floor_top, concrete_top) in room pixels.
static func top_strip_px(world: Dictionary) -> int:
	return int(world.get("top_face_px", 16)) + int(world.get("edge_px", 6)) + 4


static func _file(name: String) -> Texture2D:
	var textures: Variant = WorldData.look().get("textures")
	if not textures is Dictionary:
		return null
	var path := str((textures as Dictionary).get(name, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return kept(path)


## The picture at `path`, loaded once and kept. A draw call holds only the
## texture's id: a picture nobody keeps is freed after `_draw` and the piece
## shows as a white box (22.11.2026, the first Gemini floor test).
static func kept(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	return _cache[path]


## 4 bricks across, 10 courses: running bond, mortar between, a few darker and
## lighter bricks and chips.
static func _brick(world: Dictionary) -> Image:
	var size_v: Array = world.get("brick_px", [64, 24])
	var brick := Vector2i(int(size_v[0]), int(size_v[1]))
	var image := Image.create(brick.x * 4, brick.y * 10, false, Image.FORMAT_RGBA8)
	image.fill(WorldData.color(world, "mortar"))
	var base := WorldData.color(world, "brick")
	for row in 10:
		var shift := (brick.x / 2) * (row % 2)
		for column in 5:
			var x := column * brick.x - shift
			var k := ParticleField.rand01(31, row * 8 + column, 0)
			var tone := base.darkened(0.25 * k) if k < 0.6 else base.lightened(0.12 * (k - 0.6))
			_fill_wrapped(image, Rect2i(x + 2, row * brick.y + 2, brick.x - 4, brick.y - 4), tone)
			var chip := ParticleField.rand01(32, row * 8 + column, 1)
			if chip > 0.55:
				var cx := x + 4 + int(chip * float(brick.x - 14))
				_fill_wrapped(image, Rect2i(cx, row * brick.y + 2, 5, 3), WorldData.color(world, "mortar"))
			# A darker lower edge gives each brick a little body, not a light.
			_fill_wrapped(image, Rect2i(x + 2, row * brick.y + brick.y - 5, brick.x - 4, 3), tone.darkened(0.18))
	return image


## Dark blocks of masonry or concrete, low contrast: mass, not a feature.
static func _blocks(base: Color, block: Vector2i, seed: int) -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(base.darkened(0.35))
	for row in 256 / block.y:
		var shift := (block.x / 2) * (row % 2)
		for column in 256 / block.x + 1:
			var k := ParticleField.rand01(seed, row * 16 + column, 0)
			_fill_wrapped(image, Rect2i(column * block.x - shift + 2, row * block.y + 2, block.x - 4, block.y - 4),
				base.darkened(0.14 * k))
	return image


## The top strip: the top face (top_face_px, lighter, worn plates), the edge
## below it (iron angle with rivets and a worn light line), clear below that:
## the fill of the cell shows there.
static func _top(world: Dictionary, face: Color, edge: Color) -> Image:
	var face_px := int(world.get("top_face_px", 16))
	var edge_px := int(world.get("edge_px", 6)) + 4
	var image := Image.create(128, face_px + edge_px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(0, 0, 128, face_px), face)
	for i in 16:
		var x := i * 8
		var y := 3 + (i % 2) * (face_px / 2 - 2)
		image.fill_rect(Rect2i(x + 1, y, 5, 2), face.darkened(0.25))
	image.fill_rect(Rect2i(0, 0, 128, 2), face.lightened(0.25))
	image.fill_rect(Rect2i(0, face_px, 128, edge_px), edge)
	image.fill_rect(Rect2i(0, face_px, 128, 1), WorldData.color(world, "iron_edge"))
	for x in [12, 44, 76, 108]:
		image.fill_rect(Rect2i(x, face_px + edge_px / 2 - 1, 3, 3), WorldData.color(world, "iron_edge").darkened(0.2))
	return image


static func _fill_wrapped(image: Image, rect: Rect2i, color: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for dx in [-w, 0, w]:
		var part := Rect2i(rect.position + Vector2i(dx, 0), rect.size).intersection(Rect2i(0, 0, w, h))
		if part.size.x > 0 and part.size.y > 0:
			image.fill_rect(part, color)
