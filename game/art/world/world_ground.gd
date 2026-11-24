class_name WorldGround
extends Node2D
## The solid cells of a level as the Night shop draws them (task Д3): the fill
## of masonry (concrete inside `world.ground.concrete`), a top strip on every
## cell with air above — its top face is centred on the collision line, so her
## feet stand on the middle of the face (collision unchanged) — an iron angle on
## the sides and lower faces, then the rubble of `world.front` lying on the
## floor. Cells inside `world.ground.roof` are the dark roof over the hall
## (D120): no masonry, no top face, only an eave along their lower face and
## the dim beams of the roof. The cells of a flight of stairs (`Stairs`, a
## sibling) count as solid for their neighbours, the flight draws itself.
## Placed after the doors and platforms: a shutter that slides into the
## floor goes behind it. Decoration only, it collides with nothing: the
## blockout tiles stay the collision and are hidden.

@export var level_id := ""
@export var blocks_path := NodePath("../Blocks")

var _world: Dictionary
var _cells := {}
var _concrete: Array[Rect2i] = []
var _roof: Array[Rect2i] = []
var _stair_cells := {}
var _front: Array = []
var _cell := Vector2(64, 64)
## True when the level's picture (`world.backdrop`) draws the ground instead.
var painted := false


func _ready() -> void:
	_world = WorldData.look()
	var layout := WorldData.layout(WorldData.entry(level_id))
	# The painted room (D131) has the floors, the roof and the rubble.
	painted = not WorldData.backdrop(layout).is_empty()
	_front = layout.get("front", [])
	var ground: Variant = layout.get("ground", {})
	for r: Variant in (ground as Dictionary).get("concrete", []) if ground is Dictionary else []:
		_concrete.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	for r: Variant in (ground as Dictionary).get("roof", []) if ground is Dictionary else []:
		_roof.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	if get_parent() != null:
		for node in get_parent().get_children():
			if node is Stairs:
				var flight := (node as Stairs).cells
				for x in range(flight.position.x, flight.end.x):
					for y in range(flight.position.y, flight.end.y):
						_stair_cells[Vector2i(x, y)] = true
	var blocks := get_node_or_null(blocks_path) as TileMapLayer
	if blocks != null:
		_cell = Vector2(blocks.tile_set.tile_size)
		for cell in blocks.get_used_cells():
			_cells[cell] = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func is_solid(cell: Vector2i) -> bool:
	return _cells.has(cell)


func _is_concrete(cell: Vector2i) -> bool:
	for r in _concrete:
		if r.has_point(cell):
			return true
	return false


func is_roof(cell: Vector2i) -> bool:
	for r in _roof:
		if r.has_point(cell):
			return true
	return false


## Solid for its neighbours: a solid cell or a cell of a flight of stairs.
func _covered(cell: Vector2i) -> bool:
	return _cells.has(cell) or _stair_cells.has(cell)


func _draw() -> void:
	if _cells.is_empty() or painted:
		return
	var masonry := KitTextures.tile("masonry")
	var concrete := KitTextures.tile("concrete")
	var masonry_texel := KitTextures.texel("masonry")
	var concrete_texel := KitTextures.texel("concrete")
	var iron := WorldData.color(_world, "iron")
	var edge_light := WorldData.color(_world, "iron_edge").darkened(0.3)
	var edge := float(_world.get("edge_px", 6))
	var face := float(_world.get("top_face_px", 16))
	var bounds := Rect2i()
	for cell: Vector2i in _cells:
		bounds = Rect2i(cell, Vector2i.ONE) if bounds.size == Vector2i.ZERO else bounds.expand(cell + Vector2i.ONE)
	# Fill, by runs of one material along each row, aligned to the room so
	# the tiles meet without seams.
	for r in _roof:
		_roof_fill(Rect2(Vector2(r.position) * _cell, Vector2(r.size) * _cell))
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			if not is_solid(Vector2i(x, y)) or is_roof(Vector2i(x, y)):
				x += 1
				continue
			var hard := _is_concrete(Vector2i(x, y))
			var start := x
			while x < bounds.end.x and is_solid(Vector2i(x, y)) and not is_roof(Vector2i(x, y)) \
					and _is_concrete(Vector2i(x, y)) == hard:
				x += 1
			var rect := Rect2(Vector2(start, y) * _cell, Vector2(x - start, 1) * _cell)
			draw_texture_rect_region(concrete if hard else masonry, rect,
				KitTextures.region(rect, concrete_texel if hard else masonry_texel))
	# Sides and lower faces: an iron angle along every face that meets air
	# (the side of a ledge from its picture, N-2d).
	var side := KitTextures.piece("ledge_side")
	for cell: Vector2i in _cells:
		var at := Vector2(cell) * _cell
		if is_roof(cell):
			if not _covered(cell + Vector2i.DOWN):
				draw_rect(Rect2(at + Vector2(0, _cell.y - edge * 2.0), Vector2(_cell.x, edge * 2.0)), iron.darkened(0.2))
			continue
		if not _covered(cell + Vector2i.LEFT):
			if side != null:
				_side(side, Rect2(at, Vector2(edge, _cell.y)))
			else:
				draw_rect(Rect2(at, Vector2(edge, _cell.y)), iron)
				draw_rect(Rect2(at, Vector2(1.5, _cell.y)), edge_light)
		if not _covered(cell + Vector2i.RIGHT):
			if side != null:
				_side(side, Rect2(at + Vector2(_cell.x - edge, 0), Vector2(edge, _cell.y)))
			else:
				draw_rect(Rect2(at + Vector2(_cell.x - edge, 0), Vector2(edge, _cell.y)), iron)
		if not _covered(cell + Vector2i.DOWN):
			draw_rect(Rect2(at + Vector2(0, _cell.y - edge), Vector2(_cell.x, edge)), iron)
			draw_rect(Rect2(at + Vector2(0, _cell.y - 1.5), Vector2(_cell.x, 1.5)), edge_light.darkened(0.3))
	# Top faces last: they reach half a face above the cell.
	var floor_top := KitTextures.tile("floor_top")
	var concrete_top := KitTextures.tile("concrete_top")
	var strip := float(KitTextures.top_strip_px(_world))
	for cell: Vector2i in _cells:
		if _covered(cell + Vector2i.UP) or is_roof(cell):
			continue
		var at := Vector2(cell) * _cell
		var hard := _is_concrete(cell)
		var picture := concrete_top if hard else floor_top
		if KitTextures.piece("concrete_top" if hard else "floor_top") != null:
			_top(picture, KitTextures.piece("concrete_edge" if hard else "floor_edge"), at, face, strip, iron)
			continue
		var scale_y := float(picture.get_height()) / strip
		var dest := Rect2(at.x, at.y - face / 2.0, _cell.x, strip)
		draw_texture_rect_region(picture, dest, Rect2(at.x, 0.0, _cell.x, strip * scale_y))
	for piece: Dictionary in _front:
		_front_piece(piece)


## The dark roof over the hall (D120): darker towards the top, the dim
## rafters and purlins of the roof in it; the lamps hardly reach it.
func _roof_fill(r: Rect2) -> void:
	var roof := WorldData.color(_world, "roof")
	var bands := 6
	for i in bands:
		var band := Rect2(r.position.x, r.position.y + r.size.y * float(i) / bands, r.size.x, r.size.y / bands + 1.0)
		draw_rect(band, roof.darkened(0.5 * (1.0 - float(i) / float(bands - 1))))
	var beam := roof.lightened(0.04)
	var y := r.end.y - _cell.y * 0.9
	while y > r.position.y + _cell.y * 0.5:
		draw_rect(Rect2(r.position.x, y, r.size.x, 6.0), beam)
		y -= _cell.y * 1.6
	var x := r.position.x + _cell.x * 2.0
	while x < r.end.x:
		draw_line(Vector2(x, r.end.y), Vector2(x + _cell.x * 1.5, r.position.y + _cell.y), beam, 5.0)
		draw_line(Vector2(x, r.end.y), Vector2(x - _cell.x * 1.5, r.position.y + _cell.y), beam, 5.0)
		x += _cell.x * 4.0


## A Gemini top of a cell (D109): the flat picture seen from above squeezed
## into the top face, her feet on its middle; the front edge under it.
func _top(picture: Texture2D, edge_picture: Texture2D, at: Vector2, face: float, strip: float, iron: Color) -> void:
	var texel := float(_world.get("kit_texel", 2))
	draw_texture_rect_region(picture, Rect2(at.x, at.y - face / 2.0, _cell.x, face),
		Rect2(at.x * texel, 0.0, _cell.x * texel, picture.get_height()))
	var edge := Rect2(at.x, at.y + face / 2.0, _cell.x, strip - face)
	if edge_picture == null:
		draw_rect(edge, iron)
		return
	var s := float(edge_picture.get_height()) / edge.size.y
	draw_texture_rect_region(edge_picture, edge, Rect2(at.x * s, 0.0, _cell.x * s, edge_picture.get_height()))


## The side of a ledge: the picture squeezed to the edge's width, repeating
## down the room.
func _side(picture: Texture2D, r: Rect2) -> void:
	var s := float(picture.get_width()) / r.size.x
	draw_texture_rect_region(picture, r, Rect2(0.0, r.position.y * s, picture.get_width(), r.size.y * s))


func _front_piece(piece: Dictionary) -> void:
	var kind := str(piece.get("kind"))
	var r := WorldData.piece_rect(piece)
	var picture := KitTextures.piece(kind)
	if picture != null:
		var dest := KitTextures.fit_bottom(picture, r) if WorldData.KEEP_ASPECT.has(kind) else r
		draw_texture_rect(picture, dest, false)
		return
	var seed := int(r.position.x + r.position.y * 7.0)
	match kind:
		"bricks":
			var brick := WorldData.color(_world, "brick")
			for i in int(r.size.x / 7.0):
				var k := ParticleField.rand01(seed, i, 0)
				var x := r.position.x + k * (r.size.x - 18.0)
				var hump := 1.0 - absf((x + 9.0 - r.get_center().x) / (r.size.x * 0.5))
				var y := r.end.y - 9.0 - hump * (r.size.y - 9.0) * ParticleField.rand01(seed, i, 1)
				draw_rect(Rect2(x, y, 18.0, 9.0), brick.darkened(0.35 * ParticleField.rand01(seed, i, 2)))
		"beam":
			var iron := WorldData.color(_world, "iron")
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y - 6.0), Vector2(r.end.x, r.position.y),
				Vector2(r.end.x, r.position.y + 10.0), Vector2(r.position.x + 6.0, r.end.y)]), iron.lightened(0.04))
			draw_line(Vector2(r.position.x, r.end.y - 6.0), Vector2(r.end.x, r.position.y), WorldData.color(_world, "iron_edge").darkened(0.4), 1.5)
		"lump":
			var lump := WorldData.color(_world, "concrete").lightened(0.1)
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x + r.size.x * 0.2, r.position.y),
				Vector2(r.position.x + r.size.x * 0.7, r.position.y + 1.0), Vector2(r.end.x, r.end.y)]), lump)
		"glass":
			var glass := WorldData.color(_world, "glass").lightened(0.2)
			for i in 7:
				var x := r.position.x + ParticleField.rand01(seed, i, 0) * r.size.x
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 5.0, r.end.y),
					Vector2(x + 2.0, r.end.y - 3.0 - 4.0 * ParticleField.rand01(seed, i, 1))]), glass)
