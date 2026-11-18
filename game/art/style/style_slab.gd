class_name StyleSlab
extends StyleBlock
## A slab of level geometry (task Д1, step 3): a floor, a ledge or a wall, a
## StyleBlock `slab_depth_px` deep (`art.json`, `perspective`) whose front face
## shows what it is made of. The node's position and `size` are the
## collision rectangle, which this never changes. Decoration only.
##
## Kinds:
##   floor  steel plates with rivets on the first row, darker rows below
##   ledge  a girder: flanges and a web with round holes
##   wall   concrete blocks in a running bond
## An open end (`open_left`, `open_right`: the slab ends in the air, not at a
## wall or the screen edge) gets an end cap.

const KINDS: Array[String] = ["floor", "ledge", "wall"]
## Shades of the mask (see StyleMask): darkest, darker, main, lighter, lightest.
const S0 := "#000000"
const S1 := StyleMask.DARKER
const S2 := StyleMask.MAIN
const S3 := StyleMask.LIGHTER
const S4 := StyleMask.LIGHTEST
## Width of the end cap on an open end and the lit lip along the top.
const CAP_PX := 6
const LIP_PX := 3

@export_enum("floor", "ledge", "wall") var kind := "floor":
	set(value):
		kind = value
		_refresh()
@export var open_left := false:
	set(value):
		open_left = value
		_refresh()
@export var open_right := false:
	set(value):
		open_right = value
		_refresh()


func _init() -> void:
	super()
	depth = float(Content.art_perspective().get("slab_depth_px", 128))
	seams_px = int(Content.art_perspective().get("tile_px", 64))


func _refresh() -> void:
	if front != null:
		front.texture = null
		_rebuild()


func _front_svg(pixels: Vector2i) -> String:
	return mask(kind, pixels, int(Content.art_perspective().get("tile_px", 64)), open_left, open_right)


## The SVG mask of a slab's front face, `drawn` pixels big.
static func mask(slab_kind: String, drawn: Vector2i, tile: int, left: bool, right: bool) -> String:
	var w := drawn.x
	var h := drawn.y
	var body := ""
	match slab_kind:
		"ledge":
			body += _ledge_front(w, h, 0, tile)
		"wall":
			body += _wall_front(w, h, 0, tile)
		_:
			body += _floor_front(w, h, 0, tile)
	# The lit lip along the top edge, where the front meets the top face.
	body += _rect(0, 0, w, LIP_PX, S3)
	if left:
		body += _rect(0, 0, CAP_PX, h, S2) + _rect(CAP_PX, 0, 2, h, S1)
	if right:
		body += _rect(w - CAP_PX, 0, CAP_PX, h, S2) + _rect(w - CAP_PX - 2, 0, 2, h, S1)
	return StyleMask.svg(drawn, body)


static func _floor_front(w: int, h: int, face: int, tile: int) -> String:
	# First row: steel plates with rivets; deeper rows darker, into the ground.
	var body := _rect(0, face, w, h - face, S1)
	body += _rect(0, face, w, mini(tile, h - face), S2)
	for y in range(face + tile, h, tile):
		body += _rect(0, y, w, 2, S0)
	for x in range(tile, w, tile):
		body += _rect(x - 1, face, 2, h - face, S1 if x % (tile * 2) else S0)
	for x in range(0, w, tile):
		for rx: int in [x + 9, x + tile - 9]:
			if rx > CAP_PX + 4 and rx < w - CAP_PX - 4:
				body += _circle(rx, face + 11, 2.5, S3)
	return body


static func _ledge_front(w: int, h: int, face: int, tile: int) -> String:
	# A girder: two flanges and a darker web with lightening holes.
	var flange := clampi((h - face) / 6, 3, 8)
	var web_top := face + flange
	var web_h := h - face - flange * 2
	var d := "M0 %d H%d V%d H0 Z" % [web_top, w, web_top + web_h]
	var r := web_h * 0.5 - 3.0
	if r >= 3.0:
		for x in range(tile / 2, w, tile / 2):
			if x > CAP_PX + r + 3 and x < w - CAP_PX - r - 3:
				d += " " + StyleMask.circle_path(Vector2(x, web_top + web_h * 0.5), r)
	var body := _rect(0, face, w, flange, S2) + _rect(0, h - flange, w, flange, S2)
	body += '<path d="%s" fill="%s" fill-rule="evenodd"/>' % [d, S1]
	return body


static func _wall_front(w: int, h: int, face: int, tile: int) -> String:
	# Concrete blocks of a tile by half a tile, every other row shifted.
	var body := _rect(0, face, w, h - face, S2)
	var row := 0
	for y in range(face, h, tile / 2):
		body += _rect(0, y, w, 2, S1)
		var shift := (tile / 2) * (row % 2)
		for x in range(-shift, w, tile):
			if x > 0:
				body += _rect(x - 1, y, 2, tile / 2, S1)
			# A darker block here and there, so the wall does not look printed.
			if posmod(x / tile * 2 + row * 3, 7) == 2:
				body += _rect(maxi(x + 1, 0), y + 2, mini(tile - 2, w - maxi(x + 1, 0)), tile / 2 - 2, S1)
		row += 1
	return body


static func _rect(x: int, y: int, w: int, h: int, fill: String) -> String:
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [x, y, w, h, fill]


static func _circle(x: float, y: float, r: float, fill: String) -> String:
	return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % [x, y, r, fill]


static func _poly(points: Array, fill: String) -> String:
	return '<path d="%s" fill="%s"/>' % [StyleMask.path(PackedVector2Array(points)), fill]
