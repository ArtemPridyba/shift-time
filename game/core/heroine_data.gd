class_name HeroineData
extends RefCounted
## The heroine's doll as data (task Д5, D77): parts, joints, poses.
## `data/heroine.json` holds every number; this file loads and checks it, so a
## broken joint or a pose for a missing part shows up in the tests.

const PATH := "res://data/heroine.json"
const POSES: Array[String] = ["idle"]


static func load_data() -> Dictionary:
	var data: Variant = Content.load_json(PATH)
	return data if data is Dictionary else {}


## The angle of each part in a pose, in degrees; parts the pose leaves out are 0.
static func pose_angles(data: Dictionary, pose: String) -> Dictionary:
	var poses: Dictionary = data.get("poses", {})
	var entry: Dictionary = poses.get(pose, {})
	return entry.get("angles", {})


static func pose_lift(data: Dictionary, pose: String) -> float:
	var poses: Dictionary = data.get("poses", {})
	var entry: Dictionary = poses.get(pose, {})
	return float(entry.get("lift", 0.0))


## Game pixels per sheet pixel of each picture: tools/cut_heroine_parts.py
## shrinks every picture by this factor, the rig draws it back at sheet scale.
static func bake_factors(data: Dictionary) -> Dictionary:
	var factors: Dictionary = {}
	var parts: Dictionary = data.get("parts", {})
	for name: String in parts:
		var part: Dictionary = parts[name]
		var factor := float(data.get("scale", 1.0)) * float(part.get("size", 1.0))
		var texture := String(part.get("texture", ""))
		factors[texture] = maxf(float(factors.get(texture, 0.0)), factor)
	return factors


## Parts sorted so every parent comes before its children.
static func build_order(parts: Dictionary) -> Array[String]:
	var order: Array[String] = []
	var left: Array = parts.keys()
	while not left.is_empty():
		var placed := false
		for name: String in left.duplicate():
			var parent := String((parts[name] as Dictionary).get("parent", ""))
			if parent == "" or order.has(parent):
				order.append(name)
				left.erase(name)
				placed = true
		if not placed:
			break
	return order


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("heroine.json: must be an object")
		return errors
	var dir := String(data.get("parts_dir", ""))
	if not dir.begins_with("res://"):
		errors.append("heroine.json: parts_dir must be a res:// folder")
	if not _positive(data.get("scale")):
		errors.append("heroine.json: scale must be a number above 0")
	if Color.from_string(String(data.get("far_tint", "")), Color(0, 0, 0, 0)).a == 0.0:
		errors.append("heroine.json: far_tint must be a colour")
	var parts: Variant = data.get("parts")
	if not parts is Dictionary or (parts as Dictionary).is_empty():
		errors.append("heroine.json: parts must be a non-empty object")
		return errors
	var roots := 0
	for name: String in parts:
		var part: Variant = parts[name]
		var where := "heroine.json: part %s" % name
		if not part is Dictionary:
			errors.append(where + " must be an object")
			continue
		var texture := String(part.get("texture", ""))
		if texture == "" or not ResourceLoader.exists("%s/%s.png" % [dir, texture]):
			errors.append(where + ": texture %s.png is not in parts_dir" % texture)
		var parent := String(part.get("parent", ""))
		if parent == "":
			roots += 1
		elif not parts.has(parent) or parent == name:
			errors.append(where + ": parent %s is not a part" % parent)
		for key in ["at", "pivot"]:
			if not _point(part.get(key)):
				errors.append(where + ": %s must be [x, y]" % key)
		if part.has("size") and not _positive(part.get("size")):
			errors.append(where + ": size must be a number above 0")
		if not _number(part.get("z")):
			errors.append(where + ": z must be a number")
	if roots != 1:
		errors.append("heroine.json: exactly one part must have no parent, found %d" % roots)
	elif build_order(parts).size() != parts.size():
		errors.append("heroine.json: the parents of the parts form a loop")
	var strip: Variant = data.get("strip")
	if not strip is Dictionary or not parts.has(String(strip.get("part", ""))):
		errors.append("heroine.json: strip.part must be a part")
	elif not ResourceLoader.exists("%s/%s.png" % [dir, String(strip.get("texture", ""))]):
		errors.append("heroine.json: strip.texture must be a picture in parts_dir")
	var cable: Variant = data.get("cable")
	if not cable is Dictionary:
		errors.append("heroine.json: cable must be an object")
	else:
		for key in ["from", "to"]:
			var end: Variant = cable.get(key)
			if not end is Array or (end as Array).size() != 3 or not parts.has(String(end[0])) or not _number(end[1]) or not _number(end[2]):
				errors.append("heroine.json: cable.%s must be [part, x, y]" % key)
		if not _number(cable.get("sag")) or not _positive(cable.get("width")) or int(cable.get("points", 0)) < 2:
			errors.append("heroine.json: cable needs sag, width above 0 and at least 2 points")
	var poses: Variant = data.get("poses")
	if not poses is Dictionary:
		errors.append("heroine.json: poses must be an object")
		return errors
	for pose in POSES:
		if not poses.has(pose):
			errors.append("heroine.json: pose %s is missing" % pose)
	for pose: String in poses:
		var entry: Variant = poses[pose]
		if not entry is Dictionary or not _number(entry.get("lift", 0)) or not entry.get("angles", {}) is Dictionary:
			errors.append("heroine.json: pose %s needs lift and angles" % pose)
			continue
		for part: String in entry.get("angles", {}):
			if not parts.has(part):
				errors.append("heroine.json: pose %s turns %s, which is not a part" % [pose, part])
			elif not _number(entry["angles"][part]):
				errors.append("heroine.json: pose %s: the angle of %s must be a number" % [pose, part])
	return errors


static func _number(value: Variant) -> bool:
	return value is float or value is int


static func _positive(value: Variant) -> bool:
	return _number(value) and float(value) > 0.0


static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or (value as Array).size() != count:
		return false
	for item: Variant in value:
		if not _number(item):
			return false
	return true


static func _point(value: Variant) -> bool:
	return _numbers(value, 2)
