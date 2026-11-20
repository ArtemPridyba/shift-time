class_name HeroineData
extends RefCounted
## The heroine's doll as data (task Д5, D77): parts, joints, poses.
## `data/heroine.json` holds every number; this file loads and checks it, so a
## broken joint or a pose for a missing part shows up in the tests.

const PATH := "res://data/heroine.json"
const POSES: Array[String] = ["idle", "jump", "fall", "press", "land", "exit"]
const OVERLAYS: Array[String] = ["press", "land"]
const LIGHT_KEYS: Array[String] = ["forward", "rewind", "radius_px", "wave_px", "wave_hz", "wave_width", "wave_strength"]


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


## The run at `phase` (cycles of the run, any real number): the keys of
## `run.keys` follow each other evenly and blend linearly, the last into the
## first. Returns {"angles", "lift"}.
static func run_pose(data: Dictionary, phase: float) -> Dictionary:
	var keys: Array = (data.get("run", {}) as Dictionary).get("keys", [])
	if keys.is_empty():
		return {"angles": pose_angles(data, "idle"), "lift": pose_lift(data, "idle")}
	var at: float = fposmod(phase, 1.0) * keys.size()
	var i := int(floor(at)) % keys.size()
	var j := (i + 1) % keys.size()
	var t: float = at - floor(at)
	var a := String(keys[i])
	var b := String(keys[j])
	return {
		"angles": blend_angles(pose_angles(data, a), pose_angles(data, b), t),
		"lift": lerpf(pose_lift(data, a), pose_lift(data, b), t),
	}


## The pose in the air at vertical speed `speed_y` (px/s, down is positive):
## from `air.rise` while she goes up to `air.fall` while she comes down,
## halfway at 0, fully at `air.blend_speed_px`. Returns {"angles", "lift", "fall"}.
static func air_pose(data: Dictionary, speed_y: float) -> Dictionary:
	var air: Dictionary = data.get("air", {})
	var reach := maxf(float(air.get("blend_speed_px", 1.0)), 1.0)
	var t := clampf(0.5 + speed_y / (2.0 * reach), 0.0, 1.0)
	var rise := String(air.get("rise", "idle"))
	var fall := String(air.get("fall", "idle"))
	return {
		"angles": blend_angles(pose_angles(data, rise), pose_angles(data, fall), t),
		"lift": lerpf(pose_lift(data, rise), pose_lift(data, fall), t),
		"fall": t,
	}


## How much of an overlay shows `elapsed` seconds after it started: rises over
## `in_seconds`, holds, falls over `out_seconds`, 0 after `seconds`.
static func overlay_weight(data: Dictionary, overlay: String, elapsed: float) -> float:
	var entry: Dictionary = (data.get("overlays", {}) as Dictionary).get(overlay, {})
	var total := float(entry.get("seconds", 0.0))
	if elapsed < 0.0 or elapsed >= total:
		return 0.0
	var rise := float(entry.get("in_seconds", 0.0))
	var fall := float(entry.get("out_seconds", 0.0))
	var weight := 1.0
	if rise > 0.0:
		weight = minf(weight, elapsed / rise)
	if fall > 0.0:
		weight = minf(weight, (total - elapsed) / fall)
	return clampf(weight, 0.0, 1.0)


## `base` with the parts that pose `overlay` names turned towards it by `weight`.
static func lay_over(data: Dictionary, base: Dictionary, overlay: String, weight: float) -> Dictionary:
	var out := base.duplicate()
	if weight <= 0.0:
		return out
	var angles := pose_angles(data, overlay)
	for part: Variant in angles:
		out[part] = lerpf(float(base.get(part, 0.0)), float(angles[part]), weight)
	return out


## Angles from `a` towards `b` by `t` (0..1); a part missing in one is 0 there.
static func blend_angles(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in a.keys() + b.keys():
		out[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), t)
	return out


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
	elif not _point(strip.get("center")):
		errors.append("heroine.json: strip.center must be [x, y] in the gauntlet's picture")
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
	var run: Variant = data.get("run")
	if not run is Dictionary or not (run.get("keys") is Array) or (run.get("keys") as Array).size() < 2:
		errors.append("heroine.json: run.keys must list at least two poses")
	else:
		for key: Variant in run["keys"]:
			if not poses.has(String(key)):
				errors.append("heroine.json: run key %s is not a pose" % key)
		for number in ["cycle_px", "min_speed_px"]:
			if not _positive(run.get(number)):
				errors.append("heroine.json: run.%s must be a number above 0" % number)
		if not _number(run.get("blend_seconds")) or float(run.get("blend_seconds")) < 0.0:
			errors.append("heroine.json: run.blend_seconds must be 0 or more")
	errors.append_array(_validate_motion(data, poses))
	var soles: Variant = data.get("soles")
	if not soles is Dictionary or (soles as Dictionary).is_empty():
		errors.append("heroine.json: soles must name the boots and their sole points")
	else:
		for part: String in soles:
			if not parts.has(part) or not soles[part] is Array or (soles[part] as Array).is_empty():
				errors.append("heroine.json: soles.%s must be a part with [x, y] points" % part)
				continue
			for point: Variant in soles[part]:
				if not _point(point):
					errors.append("heroine.json: soles.%s: every point must be [x, y]" % part)
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


## The air, the overlays, the walk out of the doorway and the light.
static func _validate_motion(data: Dictionary, poses: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var air: Variant = data.get("air")
	if not air is Dictionary:
		errors.append("heroine.json: air must be an object")
	else:
		for key in ["rise", "fall"]:
			if not poses.has(String(air.get(key, ""))):
				errors.append("heroine.json: air.%s must be a pose" % key)
		if not _positive(air.get("blend_speed_px")):
			errors.append("heroine.json: air.blend_speed_px must be a number above 0")
	var overlays: Variant = data.get("overlays")
	if not overlays is Dictionary:
		errors.append("heroine.json: overlays must be an object")
	else:
		for name in OVERLAYS:
			var entry: Variant = overlays.get(name)
			if not entry is Dictionary:
				errors.append("heroine.json: overlay %s is missing" % name)
				continue
			if not poses.has(String(entry.get("pose", ""))):
				errors.append("heroine.json: overlay %s: pose must be a pose" % name)
			if not _positive(entry.get("seconds")):
				errors.append("heroine.json: overlay %s: seconds must be a number above 0" % name)
			for key in ["in_seconds", "out_seconds"]:
				if not _number(entry.get(key)) or float(entry.get(key)) < 0.0:
					errors.append("heroine.json: overlay %s: %s must be 0 or more" % [name, key])
			if _number(entry.get("in_seconds")) and _number(entry.get("out_seconds")) and _number(entry.get("seconds")) \
					and float(entry["in_seconds"]) + float(entry["out_seconds"]) > float(entry["seconds"]):
				errors.append("heroine.json: overlay %s: in_seconds and out_seconds must fit in seconds" % name)
		var land: Variant = overlays.get("land")
		if land is Dictionary and (not _number(land.get("min_speed_px")) or float(land.get("min_speed_px")) < 0.0):
			errors.append("heroine.json: overlay land: min_speed_px must be 0 or more")
	var exit: Variant = data.get("exit")
	if not exit is Dictionary or not poses.has(String(exit.get("pose", ""))):
		errors.append("heroine.json: exit.pose must be a pose")
	elif Color.from_string(String(exit.get("dark", "")), Color(0, 0, 0, 0)).a == 0.0:
		errors.append("heroine.json: exit.dark must be a colour")
	var light: Variant = data.get("light")
	if not light is Dictionary:
		errors.append("heroine.json: light must be an object")
	else:
		for key in LIGHT_KEYS:
			if not _number(light.get(key)) or float(light.get(key)) < 0.0:
				errors.append("heroine.json: light.%s must be 0 or more" % key)
		for key in ["radius_px", "wave_px"]:
			if not _positive(light.get(key)):
				errors.append("heroine.json: light.%s must be above 0" % key)
		if _number(light.get("wave_width")) and float(light.get("wave_width")) > 1.0:
			errors.append("heroine.json: light.wave_width must be at most 1")
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
