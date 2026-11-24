class_name SparkingWire
extends Node2D
## A torn cable hanging from the roof that sparks (task Д4): decoration. It
## sags from the node's origin to `end`, its bare copper end glows, and sparks
## fly out of it in bursts, the particle preset `sparks` of `data/look.json`
## (`TimeParticles`): a formula of world time, so under Shift they fly back
## into the end and at frame 0 they stand. Nothing here is recorded or collides.
## Numbers: `kit_objects.wire` of `data/look.json`.

## The torn end, from the node's origin.
@export var end := Vector2(14.0, 84.0)
## The floor below, from the node's origin: sparks die there.
@export var floor_y := 300.0
@export var noise_seed := 23

var sparks: TimeParticles
var _look := {}


func _ready() -> void:
	_look = ObjectLook.of("wire")
	sparks = TimeParticles.new()
	sparks.name = "Sparks"
	sparks.preset = "sparks"
	sparks.noise_seed = noise_seed
	sparks.position = end
	sparks.has_floor = true
	sparks.floor_y = floor_y - end.y
	add_child(sparks)


## Points of the cable: a sagging curve from the roof to the end.
func cable_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		var sag := sin(t * PI) * 10.0
		points.append(Vector2(end.x * t * t - sag, end.y * t))
	return points


func _draw() -> void:
	var width := ObjectLook.number(_look, "width_px", 3.0)
	draw_polyline(cable_points(), ObjectLook.color(_look, "color", Color("#1d1a18")), width, true)
	# Frayed copper at the end.
	var copper := ObjectLook.color(_look, "end_color", Color("#b8733c"))
	for k in 3:
		var dir := Vector2(float(k - 1) * 0.6, 1.0).normalized()
		draw_line(end, end + dir * 6.0, copper, 1.5, true)
