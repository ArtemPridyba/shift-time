class_name MeshPainter
extends RefCounted
## Collects flat coloured shapes into one mesh, so a static picture of many
## lines and polygons costs one draw call instead of one per shape (the web
## build, task Д3). The calls mirror CanvasItem's draw_* methods; `build()`
## returns the mesh to give to `draw_mesh`. It stays sharp at any zoom.

var _points := PackedVector2Array()
var _colors := PackedColorArray()


func rect(r: Rect2, color: Color) -> void:
	_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), color)


func line(a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	var along := b - a
	if along.length_squared() < 0.0001:
		return
	var side := along.normalized().orthogonal() * (width / 2.0)
	_quad(a + side, b + side, b - side, a - side, color)


func polyline(points: PackedVector2Array, color: Color, width := 1.0) -> void:
	for i in points.size() - 1:
		line(points[i], points[i + 1], color, width)


func polygon(points: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	polygon_colors(points, colors)


func polygon_colors(points: PackedVector2Array, colors: PackedColorArray) -> void:
	var triangles := Geometry2D.triangulate_polygon(points)
	for index in triangles:
		_points.append(points[index])
		_colors.append(colors[index])


func circle(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 12:
		points.append(center + Vector2.from_angle(TAU * float(i) / 12.0) * radius)
	polygon(points, color)


func arc(center: Vector2, radius: float, from: float, to: float, segments: int, color: Color, width := 1.0) -> void:
	var points := PackedVector2Array()
	for i in segments + 1:
		points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / float(segments))) * radius)
	polyline(points, color, width)


func is_empty() -> bool:
	return _points.is_empty()


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _points.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _points
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_points.append_array(PackedVector2Array([a, b, c, a, c, d]))
	for i in 6:
		_colors.append(color)
