class_name StyleSlab
extends StyleShape
## A slab of level geometry in the slight look from above (task Д1, step 3):
## a floor, a ledge or a wall, painted by the shared material. The node's
## position and `size` are the collision rectangle, which this never changes:
## the top face (`top_face_px` of `art.json`, `perspective`) is drawn around
## the collision line so that the feet stand at `feet_on_face` of it, the
## front face below. Things that stand on a floor in its front plane (walls)
## reach down to the floor's front edge. Decoration only.
##
## Kinds:
##   floor  steel plates with rivets on the first row, darker rows below
##   ledge  a girder: flanges and a web with round holes
##   wall   concrete blocks in a running bond
## An open end (`open_left`, `open_right`: the slab ends in the air, not at a
## wall or the screen edge) bevels the top face and gets an end cap.

const KINDS: Array[String] = ["floor", "ledge", "wall"]
## Shades of the mask (see StyleMask): darkest, darker, main, lighter, lightest.
const S0 := "#000000"
const S1 := StyleMask.DARKER
const S2 := StyleMask.MAIN
const S3 := StyleMask.LIGHTER
const S4 := StyleMask.LIGHTEST
## Width of the end cap on an open end and the lit lip at the front of the top face.
const CAP_PX := 6
const LIP_PX := 2

@export_enum("floor", "ledge", "wall") var kind := "floor":
	set(value):
		kind = value
		_rebuild()
## The collision rectangle's size; its top left is the node's position.
@export var size := Vector2(256, 64):
	set(value):
		size = value
		_rebuild()
@export var open_left := false:
	set(value):
		open_left = value
		_rebuild()
@export var open_right := false:
	set(value):
		open_right = value
		_rebuild()


func _init() -> void:
	super()
	centered = false
	_rebuild()


## Pixels of the top face that show (`art.json`, `perspective`).
static func face_px() -> int:
	return int(Content.art_perspective().get("top_face_px", 16))


## Pixels of the top face above the collision line.
static func face_above_px() -> int:
	return int(round(face_px() * float(Content.art_perspective().get("feet_on_face", 0.5))))


## The drawn rectangle in the parent's space: the collision rectangle plus
## the top face above it (and, for a wall, down to the floor's front edge).
func drawn_rect() -> Rect2:
	var below := face_px() - face_above_px() if kind == "wall" else 0
	return Rect2(position + Vector2(0, -face_above_px()), size + Vector2(0, face_above_px() + below))


func _rebuild() -> void:
	var tile := int(Content.art_perspective().get("tile_px", 64))
	var drawn := drawn_rect().size
	offset = Vector2(0, -face_above_px())
	set_svg(mask(kind, Vector2i(drawn.round()), face_px(), tile, open_left, open_right))


## The SVG mask of a slab drawn `drawn` pixels big, its top face `face` pixels.
static func mask(slab_kind: String, drawn: Vector2i, face: int, tile: int, left: bool, right: bool) -> String:
	var w := drawn.x
	var h := drawn.y
	var body := ""
	# Front face, by kind.
	match slab_kind:
		"ledge":
			body += _ledge_front(w, h, face, tile)
		"wall":
			body += _wall_front(w, h, face, tile)
		_:
			body += _floor_front(w, h, face, tile)
	# Top face: bevelled at an open end, seams between tiles slant back.
	var bl := face if left else 0
	var br := face if right else 0
	body += _poly([Vector2(bl, 0), Vector2(w - br, 0), Vector2(w, face), Vector2(0, face)], S3)
	for x in range(tile, w, tile):
		body += _poly([Vector2(x + 2, 0), Vector2(x + 4, 0), Vector2(x + 1, face), Vector2(x - 1, face)], S2)
	body += _rect(0, face - LIP_PX, w, LIP_PX, S4)
	body += _rect(0, face, w, 3, S1)
	# End caps on open ends: an angle of steel down the front face.
	if left:
		body += _rect(0, face, CAP_PX, h - face, S2) + _rect(CAP_PX, face, 2, h - face, S1)
	if right:
		body += _rect(w - CAP_PX, face, CAP_PX, h - face, S2) + _rect(w - CAP_PX - 2, face, 2, h - face, S1)
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
