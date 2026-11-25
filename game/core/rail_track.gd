class_name RailTrack
extends RefCounted
## The rails of level 04 (card docs/levels/04.md, D168): named segments, each a
## polyline in room pixels, and what waits at the end of each one: the next
## segment, a switch that picks one of two segments, or a stop (a buffer at a
## dead end, or the station where the heroine gets off). A cart is a point on
## the rails, never physics (`CartRide`).
##
## Data: `[{ "id": String, "points": PackedVector2Array or [[x, y], ...],
##           "end": { "kind": "next", "to": id }
##                | { "kind": "switch", "switch": switch_id, "main": id, "side": id }
##                | { "kind": "stop", "stop": "dead_end" or "station" } }]`
## The segments after a switch start where the segment before it ends.

const END_NEXT := "next"
const END_SWITCH := "switch"
const END_STOP := "stop"
const STOP_DEAD_END := "dead_end"
const STOP_STATION := "station"

var _segments := {}
var _problems := PackedStringArray()


static func from_data(segments: Array) -> RailTrack:
	var track := RailTrack.new()
	for one: Variant in segments:
		track._add(one)
	track._check_links()
	return track


## What is wrong with the data: unknown segments, too few points, broken ends.
func problems() -> PackedStringArray:
	return _problems


func has(id: String) -> bool:
	return _segments.has(id)


func ids() -> Array:
	return _segments.keys()


func points(id: String) -> PackedVector2Array:
	return _segments[id]["points"] if _segments.has(id) else PackedVector2Array()


func length(id: String) -> float:
	if not _segments.has(id):
		return 0.0
	var marks: PackedFloat32Array = _segments[id]["marks"]
	return marks[marks.size() - 1]


func end_of(id: String) -> Dictionary:
	return _segments[id]["end"] if _segments.has(id) else {}


## The point `distance` pixels along the segment, clamped to its ends.
func point_at(id: String, distance: float) -> Vector2:
	var at := _locate(id, distance)
	if at.is_empty():
		return Vector2.ZERO
	var pts: PackedVector2Array = _segments[id]["points"]
	var i: int = at["index"]
	return pts[i].lerp(pts[i + 1], float(at["t"]))


## The unit direction of travel at `distance` along the segment.
func direction_at(id: String, distance: float) -> Vector2:
	var at := _locate(id, distance)
	if at.is_empty():
		return Vector2.LEFT
	var pts: PackedVector2Array = _segments[id]["points"]
	var i: int = at["index"]
	return (pts[i + 1] - pts[i]).normalized()


func _locate(id: String, distance: float) -> Dictionary:
	if not _segments.has(id):
		return {}
	var marks: PackedFloat32Array = _segments[id]["marks"]
	var d := clampf(distance, 0.0, marks[marks.size() - 1])
	for i in range(marks.size() - 1):
		if d <= marks[i + 1] or i == marks.size() - 2:
			var span := marks[i + 1] - marks[i]
			return {"index": i, "t": (d - marks[i]) / span if span > 0.0 else 0.0}
	return {}


func _add(one: Variant) -> void:
	if not one is Dictionary or not (one as Dictionary).has("id"):
		_problems.append("a rail segment must be an object with an 'id'")
		return
	var data := one as Dictionary
	var id := str(data["id"])
	var pts := PackedVector2Array()
	var raw: Variant = data.get("points", [])
	if raw is PackedVector2Array:
		pts = raw
	elif raw is Array:
		for p: Variant in raw:
			if p is Vector2:
				pts.append(p)
			elif p is Array and (p as Array).size() == 2:
				pts.append(Vector2(float(p[0]), float(p[1])))
	if pts.size() < 2:
		_problems.append("rail segment '%s' needs at least two points" % id)
		return
	var marks := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		marks.append(marks[i - 1] + pts[i - 1].distance_to(pts[i]))
	var end: Variant = data.get("end", {})
	_segments[id] = {"points": pts, "marks": marks, "end": end if end is Dictionary else {}}


func _check_links() -> void:
	for id: String in _segments:
		var end: Dictionary = _segments[id]["end"]
		var kind := str(end.get("kind", ""))
		var seg_pts: PackedVector2Array = _segments[id]["points"]
		var last: Vector2 = seg_pts[seg_pts.size() - 1]
		match kind:
			END_NEXT:
				_check_follows(id, str(end.get("to", "")), last)
			END_SWITCH:
				if str(end.get("switch", "")) == "":
					_problems.append("rail segment '%s' ends at a switch without an id" % id)
				_check_follows(id, str(end.get("main", "")), last)
				_check_follows(id, str(end.get("side", "")), last)
			END_STOP:
				if not str(end.get("stop", "")) in [STOP_DEAD_END, STOP_STATION]:
					_problems.append("rail segment '%s' must stop at '%s' or '%s'" % [id, STOP_DEAD_END, STOP_STATION])
			_:
				_problems.append("rail segment '%s' has an unknown end '%s'" % [id, kind])


func _check_follows(id: String, to: String, at: Vector2) -> void:
	if not _segments.has(to):
		_problems.append("rail segment '%s' leads to unknown segment '%s'" % [id, to])
	elif (_segments[to]["points"] as PackedVector2Array)[0].distance_to(at) > 1.0:
		_problems.append("rail segment '%s' does not start where '%s' ends" % [to, id])
