class_name HeroineData
extends RefCounted
## The heroine's doll as data (task Д5, D77): parts, joints, poses.
## `data/heroine.json` holds every number; this file loads and checks it, so a
## broken joint or a pose for a missing part shows up in the tests.

const PATH := "res://data/heroine.json"
const POSES: Array[String] = ["idle", "jump", "fall", "press", "land", "exit"]
const OVERLAYS: Array[String] = ["press", "land"]
const LIGHT_KEYS: Array[String] = ["forward", "rewind", "radius_px", "tint"]
## Numbers of `light.motes` (D80.1), each above 0.
const MOTE_KEYS: Array[String] = ["count", "from_min_px", "from_max_px", "size_min_px", "size_max_px", "hz", "swirl", "flatten"]
## Numbers of `light.threads` (D85, Д5.1), each above 0.
const THREAD_KEYS: Array[String] = ["first", "max", "start_seconds", "every_seconds", "fade_in_seconds", "period_seconds", "travel_seconds", "trail", "pull", "curl", "segments", "margin_px", "core_px", "edge_px", "glow_px", "edge_alpha", "sharp_at", "edge_scale", "shrink_until", "alpha"]
## Numbers of `light.breath` (D86): the strip breathes in forward time.
const BREATH_KEYS: Array[String] = ["seconds", "low"]


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
## `run.keys` (or of another cycle and field, `stairs.keys_up`) follow each other evenly and
## blend linearly, the last into the first. Returns {"angles", "lift"}.
static func run_pose(data: Dictionary, phase: float, cycle := "run", field := "keys") -> Dictionary:
	var keys: Array = (data.get(cycle, {}) as Dictionary).get(field, [])
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
	if data.has("sheet_parts") and not data.get("sheet_parts") is bool:
		errors.append("heroine.json: sheet_parts must be true or false")
	errors.append_array(_validate_look(data.get("look")))
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
		if part.has("top") and (not _number(part.get("top")) or float(part.get("top")) < 0.0 or (_point(part.get("pivot")) and float(part.get("top")) >= float((part.get("pivot") as Array)[1]))):
			errors.append(where + ": top must be a number from 0 up to the pivot's y")
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
	errors.append_array(_validate_stairs(data, poses))
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


## Brightness of the whole doll (D81).
static func _validate_look(look: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not look is Dictionary:
		errors.append("heroine.json: look must be an object")
		return errors
	for key in ["gain", "gamma"]:
		if not _positive(look.get(key)):
			errors.append("heroine.json: look.%s must be above 0" % key)
	return errors


## The motes of time (D80.1, as the 4th heroine of the "Night shop" mock-up):
## `count` motes, each with its own angle, start distance, phase and size,
## the same every run (`seed`).
static func motes(light: Dictionary) -> Array[Dictionary]:
	var spec: Dictionary = light.get("motes", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 77))
	var list: Array[Dictionary] = []
	for i in int(spec.get("count", 0)):
		list.append({
			"angle": rng.randf() * TAU,
			"from": lerpf(float(spec.get("from_min_px", 50.0)), float(spec.get("from_max_px", 150.0)), rng.randf()),
			"phase": rng.randf(),
			"size": lerpf(float(spec.get("size_min_px", 1.0)), float(spec.get("size_max_px", 2.4)), rng.randf()),
		})
	return list


## Where a mote is at her time `t` (seconds, always forward: she is live), as an
## offset from the gauntlet, and how far along its way it is (0..1). Every mote
## spirals in from its start distance and vanishes in the gauntlet, faint far
## away and bright near it; then it starts again from afar.
static func mote_at(light: Dictionary, mote: Dictionary, t: float) -> Dictionary:
	var spec: Dictionary = light.get("motes", {})
	var along := fposmod(t * float(spec.get("hz", 0.7)) + float(mote["phase"]), 1.0)
	return {"offset": spiral(spec, float(mote["angle"]), float(mote["from"]), along), "along": along}


## The motes' way into the gauntlet: from `from` pixels away at `angle`,
## closing in faster at first, turning by `swirl` on the way, flattened in
## height by `flatten`. `along` runs 0..1.
static func spiral(motes: Dictionary, angle: float, from: float, along: float) -> Vector2:
	var distance := from * pow(1.0 - clampf(along, 0.0, 1.0), 1.2)
	var turned := angle + along * float(motes.get("swirl", 2.4))
	return Vector2(cos(turned) * distance, sin(turned) * distance * float(motes.get("flatten", 0.8)))


## The air, the overlays, the walk out of the doorway and the light.
## `stairs` (D120): the walk on a flight, its own cycle of poses and how her
## legs find the treads.
static func _validate_stairs(data: Dictionary, poses: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var stairs: Variant = data.get("stairs")
	if not stairs is Dictionary:
		errors.append("heroine.json: stairs must be an object")
		return errors
	for field in ["keys_up", "keys_down"]:
		var keys: Variant = stairs.get(field)
		if not keys is Array or (keys as Array).size() < 2:
			errors.append("heroine.json: stairs.%s must list at least two poses" % field)
			continue
		for key: Variant in keys:
			if not poses.has(String(key)):
				errors.append("heroine.json: stairs.%s: %s is not a pose" % [field, key])
	var legs: Variant = stairs.get("legs")
	var parts: Dictionary = data.get("parts", {})
	if not legs is Array or (legs as Array).size() != 2:
		errors.append("heroine.json: stairs.legs must name two legs")
	else:
		for leg: Variant in legs:
			if not leg is Array or (leg as Array).size() != 2 or not parts.has(String(leg[0])) or not parts.has(String(leg[1])):
				errors.append("heroine.json: stairs.legs: each leg is [thigh, shin] of the parts")
			elif not (data.get("soles", {}) as Dictionary).has(String(leg[1])):
				errors.append("heroine.json: stairs.legs: the shin %s must have soles" % leg[1])
	for key in ["stride_px", "blend_seconds", "crouch_seconds", "sole_half_px"]:
		if not _positive(stairs.get(key)):
			errors.append("heroine.json: stairs.%s must be a number above 0" % key)
	for key in ["land_ahead_up_px", "land_ahead_down_px", "lift_px"]:
		if not _number(stairs.get(key)) or float(stairs.get(key)) < 0.0:
			errors.append("heroine.json: stairs.%s must be 0 or more" % key)
		elif _number(stairs.get("stride_px")) and key != "lift_px" and float(stairs.get(key)) >= float(stairs.get("stride_px")):
			errors.append("heroine.json: stairs.%s must be shorter than stride_px" % key)
	if not _number(stairs.get("max_crouch_px")) or float(stairs.get("max_crouch_px")) < 0.0:
		errors.append("heroine.json: stairs.max_crouch_px must be 0 or more")
	if not _number(stairs.get("max_reach")) or float(stairs.get("max_reach")) <= 0.0 or float(stairs.get("max_reach")) >= 1.0:
		errors.append("heroine.json: stairs.max_reach must be above 0 and below 1")
	return errors


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
		if not _positive(light.get("radius_px")):
			errors.append("heroine.json: light.radius_px must be above 0")
		if _number(light.get("tint")) and float(light.get("tint")) > 1.0:
			errors.append("heroine.json: light.tint must be at most 1")
		var spec: Variant = light.get("motes")
		if not spec is Dictionary:
			errors.append("heroine.json: light.motes must be an object")
		else:
			for key in MOTE_KEYS:
				if not _positive(spec.get(key)):
					errors.append("heroine.json: light.motes.%s must be above 0" % key)
			if errors.is_empty() and float(spec["from_min_px"]) > float(spec["from_max_px"]):
				errors.append("heroine.json: light.motes.from_min_px must be at most from_max_px")
			if errors.is_empty() and float(spec["size_min_px"]) > float(spec["size_max_px"]):
				errors.append("heroine.json: light.motes.size_min_px must be at most size_max_px")
			if _number(spec.get("seed")) == false:
				errors.append("heroine.json: light.motes.seed must be a number")
		errors.append_array(_validate_threads(light))
		errors.append_array(_validate_far_motes(light))
	return errors


## `light.far_motes` (D85.6, a trial): optional; `"enabled": false` or no
## section turns them off.
static func _validate_far_motes(light: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not light.has("far_motes"):
		return errors
	var spec: Variant = light["far_motes"]
	if not spec is Dictionary:
		errors.append("heroine.json: light.far_motes must be an object")
		return errors
	if not spec.get("enabled") is bool:
		errors.append("heroine.json: light.far_motes.enabled must be true or false")
	for key in ["count", "hz", "size_min_px", "size_max_px", "edge_scale", "shrink_until", "edge_alpha", "alpha", "swirl", "curl", "pull", "margin_px"]:
		if not _positive(spec.get(key)):
			errors.append("heroine.json: light.far_motes.%s must be above 0" % key)
	if errors.is_empty() and float(spec["size_min_px"]) > float(spec["size_max_px"]):
		errors.append("heroine.json: light.far_motes.size_min_px must be at most size_max_px")
	return errors


## `light.threads` and `light.breath` (D85, D86).
static func _validate_threads(light: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var threads: Variant = light.get("threads")
	if not threads is Dictionary:
		errors.append("heroine.json: light.threads must be an object")
	else:
		for key in THREAD_KEYS:
			if not _positive(threads.get(key)):
				errors.append("heroine.json: light.threads.%s must be above 0" % key)
		if errors.is_empty():
			if float(threads["travel_seconds"]) > float(threads["period_seconds"]):
				errors.append("heroine.json: light.threads.travel_seconds must be at most period_seconds")
			if int(threads["first"]) > int(threads["max"]):
				errors.append("heroine.json: light.threads.first must be at most max")
			if int(threads["max"]) > 32:
				errors.append("heroine.json: light.threads.max must be at most 32")
			if not _number(threads.get("swirl")) or not _number(threads.get("start_edge")):
				errors.append("heroine.json: light.threads.swirl and start_edge must be numbers")
			for key in ["trail", "shrink_until", "alpha", "edge_alpha", "sharp_at", "start_edge"]:
				if float(threads[key]) > 1.0:
					errors.append("heroine.json: light.threads.%s must be at most 1" % key)
	var breath: Variant = light.get("breath")
	if not breath is Dictionary:
		errors.append("heroine.json: light.breath must be an object")
	else:
		for key in BREATH_KEYS:
			if not _number(breath.get(key)) or float(breath.get(key)) < 0.0:
				errors.append("heroine.json: light.breath.%s must be 0 or more" % key)
		if _number(breath.get("low")) and float(breath.get("low")) > 1.0:
			errors.append("heroine.json: light.breath.low must be at most 1")
		if _number(breath.get("seconds")) and float(breath.get("seconds")) <= 0.0:
			errors.append("heroine.json: light.breath.seconds must be above 0")
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
