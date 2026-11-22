class_name WorldGround
extends Node2D
## The solid cells of a level as the Night shop draws them (task Д3): the fill
## of masonry (concrete inside `world.ground.concrete`), a top strip on every
## cell with air above — its top face is centred on the collision line, so her
## feet stand on the middle of the face (collision unchanged) — an iron angle on
## the sides and lower faces, then the rubble of `world.front` lying on the
## floor. Placed after the doors and platforms: a shutter that slides into the
## floor goes behind it. Decoration only, it collides with nothing: the
## blockout tiles stay the collision and are hidden.

@export var level_id := ""
@export var blocks_path := NodePath("../Blocks")

var _world: Dictionary
var _cells := {}
var _concrete: Array[Rect2i] = []
var _front: Array = []
var _cell := Vector2(64, 64)


func _ready() -> void:
	_world = WorldData.look()
	var layout := WorldData.layout(WorldData.entry(level_id))
	_front = layout.get("front", [])
	var ground: Variant = layout.get("ground", {})
	for r: Variant in (ground as Dictionary).get("concrete", []) if ground is Dictionary else []:
		_concrete.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
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


func _draw() -> void:
	if _cells.is_empty():
		return
	var masonry := KitTextures.tile("masonry")
	var concrete := KitTextures.tile("concrete")
	var iron := WorldData.color(_world, "iron")
	var edge_light := WorldData.color(_world, "iron_edge").darkened(0.3)
	var edge := float(_world.get("edge_px", 6))
	var face := float(_world.get("top_face_px", 16))
	var bounds := Rect2i()
	for cell: Vector2i in _cells:
		bounds = Rect2i(cell, Vector2i.ONE) if bounds.size == Vector2i.ZERO else bounds.expand(cell + Vector2i.ONE)
	# Fill, by runs of one material along each row, aligned to the room so
	# the tiles meet without seams.
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			if not is_solid(Vector2i(x, y)):
				x += 1
				continue
			var hard := _is_concrete(Vector2i(x, y))
			var start := x
			while x < bounds.end.x and is_solid(Vector2i(x, y)) and _is_concrete(Vector2i(x, y)) == hard:
				x += 1
			var rect := Rect2(Vector2(start, y) * _cell, Vector2(x - start, 1) * _cell)
			draw_texture_rect_region(concrete if hard else masonry, rect, rect)
	# Sides and lower faces: an iron angle along every face that meets air.
	for cell: Vector2i in _cells:
		var at := Vector2(cell) * _cell
		if not is_solid(cell + Vector2i.LEFT):
			draw_rect(Rect2(at, Vector2(edge, _cell.y)), iron)
			draw_rect(Rect2(at, Vector2(1.5, _cell.y)), edge_light)
		if not is_solid(cell + Vector2i.RIGHT):
			draw_rect(Rect2(at + Vector2(_cell.x - edge, 0), Vector2(edge, _cell.y)), iron)
		if not is_solid(cell + Vector2i.DOWN):
			draw_rect(Rect2(at + Vector2(0, _cell.y - edge), Vector2(_cell.x, edge)), iron)
			draw_rect(Rect2(at + Vector2(0, _cell.y - 1.5), Vector2(_cell.x, 1.5)), edge_light.darkened(0.3))
	# Top faces last: they reach half a face above the cell.
	var floor_top := KitTextures.tile("floor_top")
	var concrete_top := KitTextures.tile("concrete_top")
	var strip := float(KitTextures.top_strip_px(_world))
	for cell: Vector2i in _cells:
		if is_solid(cell + Vector2i.UP):
			continue
		var at := Vector2(cell) * _cell
		var picture := concrete_top if _is_concrete(cell) else floor_top
		var scale_y := float(picture.get_height()) / strip
		var dest := Rect2(at.x, at.y - face / 2.0, _cell.x, strip)
		draw_texture_rect_region(picture, dest, Rect2(at.x, 0.0, _cell.x, strip * scale_y))
	for piece: Dictionary in _front:
		_front_piece(piece)


func _front_piece(piece: Dictionary) -> void:
	var kind := str(piece.get("kind"))
	var r := WorldData.piece_rect(piece)
	var picture := KitTextures.piece(kind)
	if picture != null:
		draw_texture_rect(picture, r, false)
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
		"glass":
			var glass := WorldData.color(_world, "glass").lightened(0.2)
			for i in 7:
				var x := r.position.x + ParticleField.rand01(seed, i, 0) * r.size.x
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 5.0, r.end.y),
					Vector2(x + 2.0, r.end.y - 3.0 - 4.0 * ParticleField.rand01(seed, i, 1))]), glass)
