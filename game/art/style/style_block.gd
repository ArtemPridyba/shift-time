class_name StyleBlock
extends Node2D
## A solid thing in the one-point perspective of the room (task Д1, decision
## 18.11.2026): a box whose middle plane is the collision rectangle (the
## node's position and `size`), `depth` pixels deep. Its front face is a
## StyleShape painted by the shared material; the faces that show around it
## (the top below the eye, the bottom above it, the side turned to the eye)
## are drawn here, shaded by the role's ramp. The eye and its distance come
## from `art.json`, `perspective`; the room's camera is fixed, so the eye is a
## point of the screen. The feet stand on the middle plane: in the middle of a
## floor's top face. Decoration only: collision stays the blockout's.

const TOP_SHADE := 3.0
const SIDE_SHADE := 1.4
const BOTTOM_SHADE := 0.6
## How much a face darkens towards its far edge (0..1 of a shade).
const FAR_DARKEN := 0.8

## The collision rectangle's size; its top left is the node's position.
@export var size := Vector2(64, 64):
	set(value):
		size = value
		_rebuild()
@export var depth := 64.0:
	set(value):
		depth = value
		_rebuild()
## A role of `Content.ART_ROLES`.
@export var role := "steel":
	set(value):
		role = value
		if front != null:
			front.role = value
		queue_redraw()
## Lines across the top face every this many pixels (seams of floor plates); 0 is none.
@export var seams_px := 0

## The front face, painted by the shared material.
var front: StyleShape
var _last_global := Vector2.INF


func _init() -> void:
	front = StyleShape.new()
	front.name = "Front"
	front.centered = false
	add_child(front)
	_rebuild()


func _enter_tree() -> void:
	var art := get_tree().root.get_node_or_null("Art")
	if art != null and not art.palette_changed.is_connected(_on_palette_changed):
		art.palette_changed.connect(_on_palette_changed)


func _exit_tree() -> void:
	var art := get_tree().root.get_node_or_null("Art")
	if art != null and art.palette_changed.is_connected(_on_palette_changed):
		art.palette_changed.disconnect(_on_palette_changed)


func _process(_delta: float) -> void:
	if global_position != _last_global:
		_last_global = global_position
		_place_front()
		queue_redraw()


## The eye: the point of the screen that everything recedes to.
static func eye() -> Vector2:
	var p := Content.art_perspective()
	return Vector2(float(p.get("eye_x", 960)), float(p.get("eye_y", 360)))


## Where a point of the middle plane shows at depth `z` (negative is nearer).
static func project(point: Vector2, z: float) -> Vector2:
	var distance := float(Content.art_perspective().get("distance_px", 1600))
	return eye() + (point - eye()) * distance / (distance + z)


## The front face as a rectangle of the screen.
func front_rect() -> Rect2:
	var a := project(global_position, -depth * 0.5)
	var b := project(global_position + size, -depth * 0.5)
	return Rect2(a, b - a)


## The faces that show around the front, as quads of the screen:
## name -> [front edge a, front edge b, back edge b, back edge a].
func side_faces() -> Dictionary:
	var faces := {}
	var r := Rect2(global_position, size)
	var e := eye()
	var corners := {
		"top": [r.position, Vector2(r.end.x, r.position.y)],
		"bottom": [Vector2(r.position.x, r.end.y), r.end],
		"left": [r.position, Vector2(r.position.x, r.end.y)],
		"right": [Vector2(r.end.x, r.position.y), r.end],
	}
	var shows := {"top": r.position.y > e.y, "bottom": r.end.y < e.y, "left": r.position.x > e.x, "right": r.end.x < e.x}
	for name: String in corners:
		if shows[name]:
			var a: Vector2 = corners[name][0]
			var b: Vector2 = corners[name][1]
			faces[name] = PackedVector2Array([project(a, -depth * 0.5), project(b, -depth * 0.5), project(b, depth * 0.5), project(a, depth * 0.5)])
	return faces


## The mask of the front face, `pixels` big; slabs give their own.
func _front_svg(pixels: Vector2i) -> String:
	return StyleMask.rect(pixels)


func _rebuild() -> void:
	if front == null:
		return
	front.role = role
	_place_front()
	queue_redraw()


func _place_front() -> void:
	var rect := front_rect()
	var pixels := Vector2i(rect.size.round())
	if pixels.x <= 0 or pixels.y <= 0:
		return
	if front.texture == null or Vector2i(front.texture.get_size()) != pixels or front.get_meta("svg_for", Vector2i.ZERO) != pixels:
		front.set_svg(_front_svg(pixels))
		front.set_meta("svg_for", pixels)
	front.global_position = rect.position.round()


func _on_palette_changed(_palette: ArtPalette) -> void:
	queue_redraw()


func _draw() -> void:
	var art := get_tree().root.get_node_or_null("Art") if is_inside_tree() else null
	if art == null:
		return
	var p: ArtPalette = art.palette
	var faces := side_faces()
	var shade_of := {"top": TOP_SHADE, "bottom": BOTTOM_SHADE, "left": SIDE_SHADE, "right": SIDE_SHADE}
	var line := float(Content.art_material().get("outline_px", 2))
	for name: String in faces:
		var quad: PackedVector2Array = faces[name]
		var local := PackedVector2Array()
		for point in quad:
			local.append(to_local(point))
		var near := _shade(p, shade_of[name])
		var far := _shade(p, shade_of[name] - FAR_DARKEN)
		draw_polygon(local, PackedColorArray([near, near, far, far]))
		if name == "top" and seams_px > 0:
			var r := Rect2(global_position, size)
			var x := r.position.x + seams_px
			while x < r.end.x - 1.0:
				var point := Vector2(x, r.position.y)
				draw_line(to_local(project(point, -depth * 0.5)), to_local(project(point, depth * 0.5)), _shade(p, TOP_SHADE - 1.0), 1.5, true)
				x += seams_px
		local.append(local[0])
		draw_polyline(local, p.dark(), line, true)


func _shade(p: ArtPalette, index: float) -> Color:
	var lo := floori(index)
	return p.shade(role, lo).lerp(p.shade(role, lo + 1), index - lo)
