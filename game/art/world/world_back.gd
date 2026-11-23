class_name WorldBack
extends Node2D
## The back wall of a level (task Д3): sooty red brick over the whole room,
## the night sky in the windows, then the pieces of `world.back` of the level's
## entry in `data/levels.json` — windows, iron, grime and background machines,
## darker and quieter than the play layer. Decoration only: drawn once, never
## recorded, collides with nothing. A piece with a Gemini picture in
## `world.textures` of `look.json` draws it over its rect, otherwise a code
## placeholder (D106).

## The level's id in levels.json.
@export var level_id := ""
## The blockout tiles: the room is their used rect.
@export var blocks_path := NodePath("../Blocks")

var _world: Dictionary
var _pieces: Array = []
var _room := Rect2()
var _mesh: ArrayMesh
var _sky_mesh: ArrayMesh


func _ready() -> void:
	z_index = -10
	_world = WorldData.look()
	_pieces = WorldData.layout(WorldData.entry(level_id)).get("back", [])
	var blocks := get_node_or_null(blocks_path) as TileMapLayer
	if blocks != null:
		var used := blocks.get_used_rect()
		_room = Rect2(Vector2(used.position * blocks.tile_set.tile_size), Vector2(used.size * blocks.tile_set.tile_size))
	var wall := _layer("Wall", _draw_wall)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var sky := _layer("Sky", _draw_sky)
	# The sky is far away and dim, the lamps of the hall do not reach it.
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sky.material = unshaded
	# Columns, pipes and the truss repeat their pictures along their length.
	var pieces := _layer("Pieces", _draw_pieces)
	pieces.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _layer(layer_name: String, painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.name = layer_name
	node.draw.connect(painter.bind(node))
	add_child(node)
	return node


func _draw_wall(node: Node2D) -> void:
	var brick := KitTextures.tile("brick")
	node.draw_texture_rect_region(brick, _room, KitTextures.region(_room, KitTextures.texel("brick")))


func _draw_sky(node: Node2D) -> void:
	if _sky_mesh == null:
		_sky_mesh = _paint_sky().build()
	node.draw_mesh(_sky_mesh, null)


func _paint_sky() -> MeshPainter:
	var painter := MeshPainter.new()
	var top := WorldData.color(_world, "sky_top")
	var bottom := WorldData.color(_world, "sky_bottom")
	for piece: Dictionary in _pieces:
		if str(piece.get("kind")) != "window":
			continue
		var r := WorldData.piece_rect(piece)
		var outline := _window_outline(r.grow(-4.0))
		var colors := PackedColorArray()
		for p in outline:
			colors.append(top.lerp(bottom, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
		painter.polygon_colors(outline, colors)
		# A few far lights of the city, warm and faint.
		for i in 3:
			var k := ParticleField.rand01(int(r.position.x), i, 0)
			var at := Vector2(r.position.x + 10.0 + k * (r.size.x - 20.0), r.end.y - 14.0 - 10.0 * ParticleField.rand01(int(r.position.x), i, 1))
			painter.rect(Rect2(at, Vector2(3, 2)), Color(1.0, 0.75, 0.45, 0.35))
	return painter


## The code placeholders of all pieces without a picture go into one mesh,
## drawn in one call (the web build); pictures and soft soot are drawn after.
func _draw_pieces(node: Node2D) -> void:
	if _mesh == null:
		_mesh = _paint_pieces().build()
	node.draw_mesh(_mesh, null)
	var dim := Color.WHITE.darkened(float(_world.get("machine_dim", 0.35)))
	for piece: Dictionary in _pieces:
		var kind := str(piece.get("kind"))
		var r := WorldData.piece_rect(piece)
		if kind == "crane":
			_crane_pictures(node, r)
			continue
		var picture := KitTextures.piece(kind)
		if picture == null:
			if kind == "soot" or kind == "stain":
				_soot(node, r, kind)
			continue
		var tint := dim if WorldData.MACHINE_KINDS.has(kind) else Color.WHITE
		if WorldData.MASK_COLORS.has(kind):
			tint = WorldData.color(_world, str(WorldData.MASK_COLORS[kind]))
		match kind:
			"column":
				KitTextures.draw_down(node, picture, r, tint)
			"pipe":
				_pipe_picture(node, picture, r, tint)
			"truss":
				KitTextures.draw_across(node, picture, r, tint)
			_:
				var dest := KitTextures.fit_bottom(picture, r) if WorldData.KEEP_ASPECT.has(kind) else r
				node.draw_texture_rect(picture, dest, false, tint)


## The crane beam repeats along the rect; the trolley with its hook hangs
## under it at its own size. Without pictures the placeholder is in the mesh.
func _crane_pictures(node: Node2D, r: Rect2) -> void:
	var hook := KitTextures.piece("crane")
	if hook == null:
		return
	var beam := KitTextures.piece("crane_beam")
	if beam != null:
		KitTextures.draw_across(node, beam, r)
	else:
		node.draw_rect(r, WorldData.color(_world, "iron"))
	var size := Vector2(hook.get_size()) / KitTextures.texel("crane")
	var x := r.position.x + r.size.x * 0.62
	node.draw_texture_rect(hook, Rect2(Vector2(x - size.x / 2.0, r.end.y - 2.0), size), false)


## A pipe runs along the longer side of its rect.
func _pipe_picture(node: Node2D, picture: Texture2D, r: Rect2, tint: Color) -> void:
	if r.size.y >= r.size.x:
		KitTextures.draw_down(node, picture, r, tint)
		return
	node.draw_set_transform(r.get_center(), PI / 2.0)
	KitTextures.draw_down(node, picture, Rect2(-r.size.y / 2.0, -r.size.x / 2.0, r.size.y, r.size.x), tint)
	node.draw_set_transform(Vector2.ZERO)


func _paint_pieces() -> MeshPainter:
	var painter := MeshPainter.new()
	for piece: Dictionary in _pieces:
		var kind := str(piece.get("kind"))
		if KitTextures.piece(kind) != null:
			continue
		var r := WorldData.piece_rect(piece)
		if kind == "crane":
			_crane(painter, r)
			continue
		match kind:
			"window": _window(painter, r)
			"column": _column(painter, r)
			"truss": _truss(painter, r)
			"plaster": _plaster(painter, r)
			"rust": _rust(painter, r)
			"cracks": _cracks(painter, r)
			"tank": _tank(painter, r)
			"hopper": _hopper(painter, r)
			"pipe": _pipe(painter, r)
			"catwalk": _catwalk(painter, r)
	return painter


## The arch on top, the straight part below.
func _window_outline(r: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := r.size.x / 2.0
	var center := Vector2(r.position.x + radius, r.position.y + radius)
	points.append(Vector2(r.position.x, r.end.y))
	for i in 17:
		points.append(center + Vector2(-cos(PI * float(i) / 16.0), -sin(PI * float(i) / 16.0)) * radius)
	points.append(Vector2(r.end.x, r.end.y))
	return points


func _window(node: MeshPainter, r: Rect2) -> void:
	var iron := WorldData.color(_world, "iron")
	var brick := WorldData.color(_world, "brick").darkened(0.3)
	var radius := r.size.x / 2.0
	var center := Vector2(r.position.x + radius, r.position.y + radius)
	node.arc(center, radius + 4.0, PI, TAU, 24, brick, 14.0)
	node.rect(Rect2(r.position.x - 4.0, r.position.y + radius, 8.0, r.size.y - radius), brick)
	node.rect(Rect2(r.end.x - 4.0, r.position.y + radius, 8.0, r.size.y - radius), brick)
	# Panes: 3 across, the straight part in 5 rows; some still hold dirty glass.
	var inner := r.grow(-4.0)
	var top := inner.position.y + radius
	var pane := Vector2(inner.size.x / 3.0, (inner.end.y - top) / 5.0)
	var glass := WorldData.color(_world, "glass")
	for row in 5:
		for column in 3:
			var k := ParticleField.rand01(int(r.position.x) + 7, row * 3 + column, 0)
			var cell := Rect2(Vector2(inner.position.x + column * pane.x, top + row * pane.y), pane)
			if k < 0.32:
				node.rect(cell, glass)
			elif k < 0.7:
				# A shard left in the corner of a broken pane.
				var corner := cell.position + Vector2(0.0 if k < 0.5 else pane.x, 0.0)
				var dx := pane.x * 0.45 * (1.0 if k < 0.5 else -1.0)
				node.polygon(PackedVector2Array([corner, corner + Vector2(dx, 0), corner + Vector2(0, pane.y * 0.6)]), glass)
	node.polyline(_window_outline(inner), iron, 5.0)
	for column in [1, 2]:
		var x: float = inner.position.x + column * pane.x
		var y_top := center.y - sqrt(maxf(radius * radius - pow(x - center.x, 2.0), 0.0))
		node.line(Vector2(x, y_top), Vector2(x, inner.end.y), iron, 3.0)
	for row in 5:
		var y := top + row * pane.y
		node.line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), iron, 3.0)
	node.rect(Rect2(r.position.x - 8.0, r.end.y, r.size.x + 16.0, 10.0), WorldData.color(_world, "concrete").darkened(0.2))


func _column(node: MeshPainter, r: Rect2) -> void:
	var iron := WorldData.color(_world, "iron")
	var edge := WorldData.color(_world, "iron_edge").darkened(0.35)
	node.rect(r, iron)
	node.rect(Rect2(r.position.x + 5.0, r.position.y, r.size.x - 10.0, r.size.y), iron.darkened(0.3))
	node.line(r.position + Vector2(1, 0), Vector2(r.position.x + 1.0, r.end.y), edge, 2.0)
	node.line(Vector2(r.end.x - 1.0, r.position.y), Vector2(r.end.x - 1.0, r.end.y), edge.darkened(0.3), 2.0)
	var y := r.position.y + 20.0
	while y < r.end.y:
		node.circle(Vector2(r.position.x + 3.0, y), 1.6, edge)
		node.circle(Vector2(r.end.x - 3.0, y), 1.6, edge)
		y += 36.0
	y = r.position.y + 150.0
	while y < r.end.y:
		node.rect(Rect2(r.position.x - 3.0, y, r.size.x + 6.0, 22.0), iron.lightened(0.05))
		y += 320.0


func _truss(node: MeshPainter, r: Rect2) -> void:
	var iron := WorldData.color(_world, "iron")
	node.rect(Rect2(r.position, Vector2(r.size.x, 7.0)), iron)
	node.rect(Rect2(r.position.x, r.end.y - 7.0, r.size.x, 7.0), iron)
	var x := r.position.x
	var up := true
	while x < r.end.x:
		var next := minf(x + 48.0, r.end.x)
		node.line(Vector2(x, r.end.y - 4.0 if up else r.position.y + 4.0),
			Vector2(next, r.position.y + 4.0 if up else r.end.y - 4.0), iron, 3.0)
		up = not up
		x = next


func _crane(node: MeshPainter, r: Rect2) -> void:
	var iron := WorldData.color(_world, "iron")
	node.rect(r, iron)
	node.line(r.position, Vector2(r.end.x, r.position.y), WorldData.color(_world, "iron_edge").darkened(0.4), 2.0)
	var trolley := Vector2(r.position.x + r.size.x * 0.62, r.end.y)
	node.rect(Rect2(trolley - Vector2(22, 0), Vector2(44, 16)), iron.lightened(0.05))
	var y := trolley.y + 18.0
	while y < trolley.y + 150.0:
		node.arc(Vector2(trolley.x, y), 3.0, 0.0, TAU, 8, iron.lightened(0.1), 2.0)
		y += 7.0
	node.arc(Vector2(trolley.x + 6.0, y + 8.0), 9.0, -PI * 0.2, PI * 1.1, 12, iron.lightened(0.15), 4.0)


func _plaster(node: MeshPainter, r: Rect2) -> void:
	var color := WorldData.color(_world, "concrete").lightened(0.15)
	color.a = 0.3
	node.polygon(_blob(r, 11), color)


## Soft soot and water stains without their masks: a soft dark spot.
func _soot(node: Node2D, r: Rect2, kind: String) -> void:
	var color := Color(0, 0, 0, 0.6) if kind == "soot" else WorldData.color(_world, "stain")
	node.draw_texture_rect(KitTextures.soft_disc(), r, false, color)


func _rust(node: MeshPainter, r: Rect2) -> void:
	var rust := WorldData.color(_world, "rust")
	var clear := rust
	clear.a = 0.0
	rust.a = 0.65
	for i in 6:
		var k := ParticleField.rand01(int(r.position.x) + 3, i, 0)
		var x := r.position.x + k * r.size.x
		var width := 2.0 + 5.0 * ParticleField.rand01(int(r.position.x) + 3, i, 1)
		var length := r.size.y * (0.35 + 0.65 * ParticleField.rand01(int(r.position.x) + 3, i, 2))
		node.polygon_colors(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + width, r.position.y),
			Vector2(x + width * 0.4, r.position.y + length), Vector2(x, r.position.y + length)]),
			PackedColorArray([rust, rust, clear, clear]))


func _cracks(node: MeshPainter, r: Rect2) -> void:
	var dark := WorldData.color(_world, "mortar").darkened(0.5)
	var at := Vector2(r.position.x + r.size.x * 0.5, r.position.y)
	var seed := int(r.position.x * 3.0 + r.position.y)
	var points := PackedVector2Array([at])
	for i in 7:
		at += Vector2((ParticleField.rand01(seed, i, 0) - 0.5) * r.size.x * 0.5, r.size.y / 7.0)
		points.append(at)
		if i == 3:
			node.polyline(PackedVector2Array([at, at + Vector2(r.size.x * 0.35, r.size.y * 0.18),
				at + Vector2(r.size.x * 0.45, r.size.y * 0.34)]), dark, 1.5)
	node.polyline(points, dark, 2.0)


func _machine_color() -> Color:
	return WorldData.color(_world, "machine").darkened(float(_world.get("machine_dim", 0.35)))


func _tank(node: MeshPainter, r: Rect2) -> void:
	var body := _machine_color()
	var radius := r.size.x / 2.0
	node.rect(Rect2(r.position.x, r.position.y + radius * 0.5, r.size.x, r.size.y - radius * 0.5), body)
	node.polygon(_half_ellipse(Vector2(r.position.x + radius, r.position.y + radius * 0.5), Vector2(radius, radius * 0.5)), body)
	var line := body.lightened(0.08)
	var y := r.position.y + radius
	while y < r.end.y:
		node.line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 2.0)
		y += 56.0
	var ladder := r.end.x - 18.0
	node.line(Vector2(ladder, r.position.y + radius), Vector2(ladder, r.end.y), line, 2.0)
	node.line(Vector2(ladder + 12.0, r.position.y + radius), Vector2(ladder + 12.0, r.end.y), line, 2.0)
	y = r.position.y + radius
	while y < r.end.y:
		node.line(Vector2(ladder, y), Vector2(ladder + 12.0, y), line, 2.0)
		y += 14.0


func _hopper(node: MeshPainter, r: Rect2) -> void:
	var body := _machine_color()
	var cone := r.position.y + r.size.y * 0.6
	node.polygon(PackedVector2Array([r.position + Vector2(0, 10), Vector2(r.end.x, r.position.y + 10.0),
		Vector2(r.position.x + r.size.x * 0.6, cone), Vector2(r.position.x + r.size.x * 0.4, cone)]), body)
	node.polygon(_half_ellipse(Vector2(r.get_center().x, r.position.y + 10.0), Vector2(r.size.x / 2.0, 10.0)), body)
	for x in [r.position.x + 8.0, r.end.x - 14.0]:
		node.rect(Rect2(x, r.position.y + 10.0, 6.0, r.size.y - 10.0), body.darkened(0.2))


func _pipe(node: MeshPainter, r: Rect2) -> void:
	var body := _machine_color().lightened(0.04)
	var edge := body.lightened(0.1)
	node.rect(r, body)
	var upright := r.size.y > r.size.x
	if upright:
		node.line(r.position + Vector2(2, 0), Vector2(r.position.x + 2.0, r.end.y), edge, 2.0)
		var y := r.position.y + 90.0
		while y < r.end.y:
			node.rect(Rect2(r.position.x - 4.0, y, r.size.x + 8.0, 9.0), body.lightened(0.05))
			y += 190.0
	else:
		node.line(r.position + Vector2(0, 2), Vector2(r.end.x, r.position.y + 2.0), edge, 2.0)
		var x := r.position.x + 90.0
		while x < r.end.x:
			node.rect(Rect2(x, r.position.y - 4.0, 9.0, r.size.y + 8.0), body.lightened(0.05))
			x += 190.0


func _catwalk(node: MeshPainter, r: Rect2) -> void:
	var body := _machine_color().lightened(0.06)
	node.line(r.position, Vector2(r.end.x, r.position.y), body, 3.0)
	node.line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), body, 2.0)
	var x := r.position.x
	while x <= r.end.x:
		node.line(Vector2(x, r.position.y), Vector2(x, r.end.y), body, 3.0)
		x += 48.0


func _half_ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


func _blob(r: Rect2, seed: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := r.get_center()
	for i in 10:
		var a := TAU * float(i) / 10.0
		var k := 0.7 + 0.3 * ParticleField.rand01(seed + int(r.position.x), i, 0)
		points.append(center + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5) * k)
	return points
