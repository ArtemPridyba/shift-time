@tool
class_name MechPart
extends Node2D
## Base of the mechanisms drawn by code (task Д2): gear, rail roller, rack,
## chain, valve wheel. A mechanism keeps no history and is not in the group
## `temporal`: every frame it reads how far its recorded object has moved
## (`mech_travel()` and `mech_fraction()` of a door or a platform, see
## MechDrive) and draws itself from that. So under Shift it turns back exactly
## as the object goes back. It does not glow under Shift (D60). Colours come
## from `mech` in `data/look.json`.

## The recorded object this part follows (a door, a platform). Empty: it stands still.
@export var driven_path: NodePath:
	set(value):
		driven_path = value
		refresh()
## Multiplies the travel: negative turns the other way, 0.5 turns half as far.
@export var ratio := 1.0:
	set(value):
		ratio = value
		refresh()

## The driven object's travel in pixels, times `ratio`, and its 0…1 fraction.
var travel := 0.0
var fraction := 0.0

var _look := {}
var _drawn := false


func _ready() -> void:
	_look = Content.look_mech()
	refresh()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		refresh()


## Reads the driven object and redraws if it moved.
func refresh() -> void:
	if not is_inside_tree():
		return
	var driven: Node = null
	if not driven_path.is_empty():
		driven = get_node_or_null(driven_path)
	var t := MechDrive.travel_of(driven) * ratio
	var f := MechDrive.fraction_of(driven)
	if _drawn and is_equal_approx(t, travel) and is_equal_approx(f, fraction):
		return
	travel = t
	fraction = f
	_drawn = true
	queue_redraw()


func look_color(key: String) -> Color:
	if _look.is_empty():
		_look = Content.look_mech()
	return Color.from_string(str(_look.get(key, "")), Color.MAGENTA)


func outline_px() -> float:
	return float(_look.get("outline_px", 1.8))


## A closed outline for `draw_polyline`.
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out
