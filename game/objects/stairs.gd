class_name Stairs
extends StaticBody2D
## A flight of stairs (D120): she walks it step by step, never jumps. The
## collision is one slope over the flight's rect of cells, from its top-left
## corner down to its bottom-right one (or the mirror); the steps are drawn on
## it from the kit tiles — each tread centred on the slope, like the top face
## of a floor on its collision line — or the Gemini picture `stairs` of
## `world.textures` in look.json covers the rect (N-13). Not recorded: level
## geometry, like the blockout tiles. The room's builder places it from the
## '\' or '/' cells of its map; `WorldGround` leaves these cells to it.

## The flight in cells: it falls by `cells.size.y` over `cells.size.x`.
@export var cells := Rect2i()
## True: the top is on the left and it goes down to the right ('\').
@export var descends_right := true

var _world: Dictionary
## True when the level's picture draws the flight (D131).
var painted := false


func _ready() -> void:
	_world = WorldData.look()
	# The player finds the flight under her feet by this group (D120).
	add_to_group("stairs")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.name = "Slope"
	shape.polygon = slope_polygon()
	add_child(shape)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## The solid part in room pixels: the triangle under the slope.
func slope_polygon() -> PackedVector2Array:
	var r := rect_px()
	if descends_right:
		return PackedVector2Array([r.position, r.end, Vector2(r.position.x, r.end.y)])
	return PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end])


func rect_px() -> Rect2:
	return Rect2(Vector2(cells.position) * WorldData.CELL, Vector2(cells.size) * WorldData.CELL)


## The height of the slope at room x (its top surface), clamped to the flight.
func surface_y(x: float) -> float:
	var r := rect_px()
	var k := clampf((x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)
	return r.position.y + r.size.y * (k if descends_right else 1.0 - k)


## Whether feet at `at` (room px, relative to the node) stand on the flight or
## on the floor at its ends, and not on something above it, such as a platform
## riding over the stairs: her box of `half_width` rests on the slope by its
## uphill corner, so her feet are between the slope under her two sides, give
## or take half a step.
func holds_feet(at: Vector2, half_width: float) -> bool:
	var rise := float(_world.get("stair_rise_px", 20))
	var a := surface_y(at.x - half_width)
	var b := surface_y(at.x + half_width)
	return at.y >= minf(a, b) - rise * 0.5 and at.y <= maxf(a, b) + rise * 0.5


## The top of the tread at room x, where her soles stand (D120): steps of
## `tread_px` across, each level with the slope at its middle, as `_draw`
## draws them; left and right of the flight, the floor at its ends.
func tread_y(x: float) -> float:
	var r := rect_px()
	if x < r.position.x:
		return r.position.y if descends_right else r.end.y
	if x >= r.end.x:
		return r.end.y if descends_right else r.position.y
	var n := step_count()
	var column := mini(int(floor((x - r.position.x) / tread_px())), n - 1)
	var from_top := column if descends_right else n - 1 - column
	return r.position.y + r.size.y / float(n) * (float(from_top) + 0.5)


## The middle of every tread across, room x plus `offset_x` (the node's x in
## the room): where her feet land walking the flight (D143). A flight drawn
## another way gives its own treads here and in `tread_y`.
func tread_middles(offset_x := 0.0) -> PackedFloat32Array:
	var r := rect_px()
	var middles := PackedFloat32Array()
	for i in step_count():
		middles.append(offset_x + r.position.x + tread_px() * (float(i) + 0.5))
	return middles


## How deep one tread is across, in room pixels.
func tread_px() -> float:
	return rect_px().size.x / float(step_count())


## How many steps: each about `stair_rise_px` of look.json high.
func step_count() -> int:
	var rise := float(_world.get("stair_rise_px", 20))
	return maxi(1, roundi(rect_px().size.y / maxf(rise, 1.0)))


## The level's picture has the flight (`world.backdrop`, D131): only the
## collision stays.
func use_backdrop(_config: Dictionary) -> void:
	painted = true
	queue_redraw()


func _draw() -> void:
	if painted:
		return
	var r := rect_px()
	var picture := KitTextures.piece("stairs")
	if picture != null:
		draw_texture_rect(picture, r, false)
		return
	var n := step_count()
	var tread := r.size.x / float(n)
	var rise := r.size.y / float(n)
	var masonry := KitTextures.tile("masonry")
	var masonry_texel := KitTextures.texel("masonry")
	var concrete := KitTextures.tile("concrete")
	var concrete_texel := KitTextures.texel("concrete")
	var top := KitTextures.tile("concrete_top")
	var top_picture := KitTextures.piece("concrete_top")
	var edge_picture := KitTextures.piece("concrete_edge")
	var iron := WorldData.color(_world, "iron")
	var face := float(_world.get("top_face_px", 16))
	var strip := float(KitTextures.top_strip_px(_world))
	var texel := float(_world.get("kit_texel", 2))
	for i in n:
		# Step i from the top: its tread is level with the slope at its middle.
		var x := r.position.x + tread * float(i if descends_right else n - 1 - i)
		var y := r.position.y + rise * (float(i) + 0.5)
		var block := Rect2(x, y, tread, r.end.y - y)
		draw_texture_rect_region(masonry, block, KitTextures.region(block, masonry_texel))
		# The step itself: a slab of concrete one rise deep over the masonry,
		# lighter than the wall of the pit so the flight reads in the dark.
		var slab := Rect2(x, y, tread, rise + face / 2.0)
		draw_texture_rect_region(concrete, slab, KitTextures.region(slab, concrete_texel))
		# The profile of the step: a dark line down its open side.
		var open_x := block.end.x - 2.0 if descends_right else block.position.x
		draw_rect(Rect2(open_x, y, 2.0, rise), iron)
		# The worn top of the tread, seen a little from above, and its front edge.
		if top_picture != null:
			draw_texture_rect_region(top_picture, Rect2(x, y - face / 2.0, tread, face),
				Rect2(x * texel, 0.0, tread * texel, top_picture.get_height()))
		else:
			var scale_y := float(top.get_height()) / strip
			draw_texture_rect_region(top, Rect2(x, y - face / 2.0, tread, face), Rect2(x, 0.0, tread, face * scale_y))
		var edge := Rect2(x, y + face / 2.0, tread, minf(strip - face, rise))
		if edge_picture != null:
			var s := float(edge_picture.get_height()) / maxf(edge.size.y, 1.0)
			draw_texture_rect_region(edge_picture, edge, Rect2(x * s, 0.0, tread * s, edge_picture.get_height()))
		else:
			draw_rect(edge, iron)
