class_name WorldData
extends RefCounted
## The world of a level (task Д3, the "Night shop" kit, D61, D64, D106): the
## numbers of the kit in `world` of `data/look.json` and the layout of a level
## in `world` of its entry in `data/levels.json`. Pure data and formulas, no
## nodes: the pieces are drawn by `art/world/`. Decoration only, nothing here
## is recorded or collides.
##
## A layout places pieces by grid cells: `{"kind": "window", "rect": [x, y, w, h]}`.
## `back` pieces stand on the back wall behind everything, `front` pieces lie
## on the floor in front of it; `lamps` hang from the ceiling (`x` cell, `drop`
## cells of cable); `ground.concrete` lists the rects of solid cells drawn as
## concrete instead of iron plates on masonry.

const CELL := 64.0

## Back wall pieces. Machines are drawn darker and quieter than the play layer.
const BACK_KINDS: Array[String] = ["window", "column", "truss", "crane", "plaster",
	"soot", "rust", "cracks", "tank", "hopper", "pipe", "catwalk"]
const MACHINE_KINDS: Array[String] = ["tank", "hopper", "pipe", "catwalk"]
## Pieces lying on the floor, in front of the ground.
const FRONT_KINDS: Array[String] = ["bricks", "beam", "glass"]

## Pictures a Gemini file can replace (D106): an empty path draws the code
## placeholder. Tiles repeat; the other pictures stretch over the piece's rect.
const TILE_TEXTURES: Array[String] = ["brick", "masonry", "concrete", "floor_top", "concrete_top"]
const PIECE_TEXTURES: Array[String] = ["window", "column", "truss", "crane", "plaster",
	"soot", "rust", "cracks", "tank", "hopper", "pipe", "catwalk", "bricks", "beam", "glass", "lamp"]

const COLORS: Array[String] = ["brick", "mortar", "masonry", "iron", "iron_edge", "concrete",
	"sky_top", "sky_bottom", "glass", "machine", "rust", "lamp_shade", "bulb", "darkness"]


static func look() -> Dictionary:
	var world: Variant = Content.look().get("world")
	return world if world is Dictionary else {}


## The entry of level `id` in levels.json, or an empty Dictionary.
static func entry(id: String) -> Dictionary:
	for level: Variant in Content.levels():
		if level is Dictionary and str((level as Dictionary).get("id", "")) == id:
			return level
	return {}


## The layout of a level entry (`world` of its entry in levels.json).
static func layout(entry: Dictionary) -> Dictionary:
	var world: Variant = entry.get("world")
	return world if world is Dictionary else {}


static func color(world: Dictionary, key: String) -> Color:
	var colors: Variant = world.get("colors")
	if colors is Dictionary and (colors as Dictionary).get(key) is String:
		return Color.from_string(str(colors[key]), Color.MAGENTA)
	return Color.MAGENTA


## A piece's rect in room pixels.
static func piece_rect(piece: Dictionary) -> Rect2:
	var r: Array = piece.get("rect", [0, 0, 0, 0])
	return Rect2(float(r[0]) * CELL, float(r[1]) * CELL, float(r[2]) * CELL, float(r[3]) * CELL)


## Where lamp `lamp` of a layout hangs: the bulb, in room pixels. The cable
## starts at the ceiling's lower face (row 1).
static func lamp_at(lamp: Dictionary) -> Vector2:
	return Vector2(float(lamp.get("x", 0.0)) * CELL, CELL + float(lamp.get("drop", 1.0)) * CELL)


## The energy of lamp number `index` at world second `seconds`: a slow uneven
## flicker that is a formula of world time, so under Shift it plays backwards
## and the same moment always looks the same (nothing is recorded).
static func lamp_energy(lamp: Dictionary, index: int, seconds: float) -> float:
	var energy := float(lamp.get("energy", 1.0))
	var depth := float(lamp.get("flicker", 0.0))
	var hz := float(lamp.get("flicker_hz", 0.5))
	var phase := float(index) * 2.399963
	var wave := 0.55 * sin(TAU * hz * seconds + phase) \
		+ 0.3 * sin(TAU * hz * 2.71 * seconds + phase * 1.7) \
		+ 0.15 * sin(TAU * hz * 6.13 * seconds + phase * 0.3)
	return energy * (1.0 - depth * (0.5 + 0.5 * wave))


## Problems of `world` in look.json; an empty list means it is fine.
static func validate_look(world: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "look.json: world"
	if not world is Dictionary:
		errors.append("%s must be an object" % where)
		return errors
	var colors: Variant = world.get("colors")
	if not colors is Dictionary:
		errors.append("%s.colors must be an object" % where)
	else:
		for key in COLORS:
			if not (colors as Dictionary).get(key) is String or not Color.html_is_valid(colors[key]):
				errors.append("%s.colors.%s must be a color like \"#74382a\"" % [where, key])
	var textures: Variant = world.get("textures")
	if not textures is Dictionary:
		errors.append("%s.textures must be an object" % where)
	else:
		for key: Variant in textures:
			if not TILE_TEXTURES.has(str(key)) and not PIECE_TEXTURES.has(str(key)):
				errors.append("%s.textures.%s: no such picture" % [where, key])
			var path: Variant = textures[key]
			if not path is String or (not (path as String).is_empty() and not ResourceLoader.exists(path)):
				errors.append("%s.textures.%s: '%s' must be empty or an existing file" % [where, key, path])
	_number(errors, world, where, "top_face_px", 2.0, 48.0)
	_number(errors, world, where, "edge_px", 1.0, 32.0)
	_number(errors, world, where, "machine_dim", 0.0, 1.0)
	var brick: Variant = world.get("brick_px")
	if not brick is Array or brick.size() != 2 or not _is_number(brick[0]) or not _is_number(brick[1]) \
			or float(brick[0]) < 8.0 or float(brick[1]) < 4.0:
		errors.append("%s.brick_px must be [width, height], at least [8, 4]" % where)
	var lamp: Variant = world.get("lamp")
	if not lamp is Dictionary:
		errors.append("%s.lamp must be an object" % where)
	else:
		var l := lamp as Dictionary
		if not l.get("color") is String or not Color.html_is_valid(l["color"]):
			errors.append("%s.lamp.color must be a color" % where)
		_number(errors, l, where + ".lamp", "energy", 0.0, 8.0)
		_number(errors, l, where + ".lamp", "radius_px", 32.0, 1200.0)
		_number(errors, l, where + ".lamp", "below_px", 0.0, 600.0)
		_number(errors, l, where + ".lamp", "flicker", 0.0, 1.0)
		_number(errors, l, where + ".lamp", "flicker_hz", 0.0, 20.0)
		_number(errors, l, where + ".lamp", "halo_px", 0.0, 400.0)
		_number(errors, l, where + ".lamp", "halo_alpha", 0.0, 1.0)
	var own: Variant = world.get("heroine_light")
	if not own is Dictionary:
		errors.append("%s.heroine_light must be an object" % where)
	else:
		_number(errors, own, where + ".heroine_light", "energy", 0.0, 4.0)
		_number(errors, own, where + ".heroine_light", "radius_px", 16.0, 600.0)
	return errors


## Problems of a level's `world` layout; `where` names the level.
static func validate_layout(layout: Variant, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not layout is Dictionary:
		errors.append("%s: 'world' must be an object" % where)
		return errors
	for side in ["back", "front"]:
		var kinds: Array[String] = BACK_KINDS if side == "back" else FRONT_KINDS
		var pieces: Variant = layout.get(side, [])
		if not pieces is Array:
			errors.append("%s: world.%s must be a list" % [where, side])
			continue
		for i in (pieces as Array).size():
			var piece: Variant = pieces[i]
			var at := "%s: world.%s[%d]" % [where, side, i]
			if not piece is Dictionary or not kinds.has(str((piece as Dictionary).get("kind", ""))):
				errors.append("%s: 'kind' must be one of %s" % [at, kinds])
				continue
			if not _is_rect(piece.get("rect")):
				errors.append("%s: 'rect' must be [x, y, w, h] in cells, w and h above 0" % at)
	var lamps: Variant = layout.get("lamps", [])
	if not lamps is Array:
		errors.append("%s: world.lamps must be a list" % where)
	else:
		for i in (lamps as Array).size():
			var lamp: Variant = lamps[i]
			if not lamp is Dictionary or not _is_number(lamp.get("x")) or not _is_number(lamp.get("drop")) \
					or float(lamp["drop"]) <= 0.0:
				errors.append("%s: world.lamps[%d] must be {\"x\": cell, \"drop\": cells above 0}" % [where, i])
	var ground: Variant = layout.get("ground", {})
	if not ground is Dictionary:
		errors.append("%s: world.ground must be an object" % where)
	else:
		var concrete: Variant = (ground as Dictionary).get("concrete", [])
		if not concrete is Array:
			errors.append("%s: world.ground.concrete must be a list of rects" % where)
		else:
			for rect: Variant in concrete:
				if not _is_rect(rect):
					errors.append("%s: world.ground.concrete: %s is not [x, y, w, h]" % [where, rect])
	return errors


static func _is_rect(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 4:
		return false
	for n: Variant in value:
		if not _is_number(n):
			return false
	return float(value[2]) > 0.0 and float(value[3]) > 0.0


static func _number(errors: PackedStringArray, section: Dictionary, where: String, key: String, low: float, high: float) -> void:
	if not _is_number(section.get(key)) or float(section[key]) < low or float(section[key]) > high:
		errors.append("%s.%s must be a number from %s to %s" % [where, key, low, high])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
