class_name SoundRules
extends RefCounted
## What the recorded states of objects sound like (task Д8, D183): the rules of
## `data/audio.json`, the arithmetic of reversed sounds and the data check.
## Pure logic, no nodes and no playback: `RoomSound` asks which sound an edge of
## a recorded field makes and when a reversed one must start.
##
## Under Shift the world plays its past backwards (rule «A»). A change seen
## while rewinding is a recorded change undone, so it plays the sound of that
## recorded edge, reversed: a clank becomes a swell that ends on the frame of the
## impact. The hit of a reversed file is near its end, so it starts `lead`
## seconds before its frame; the frames ahead of the cursor are the recorded
## past, so the edge is known in advance. A change written under Shift by an
## action of the heroine (an interference) is a new present and sounds forward.

const PATH := "res://data/audio.json"
const REVERSED_SUFFIX := "_rev"
const KINDS: Array[String] = ["move", "flag", "set", "change", "reach", "while"]
## The keys of a rule of each kind that name sounds; the first of `move` and
## `while` is the loop.
const SOUND_KEYS := {
	"move": ["loop", "start", "stop"],
	"flag": ["on", "off"],
	"set": ["sound"],
	"change": ["sound"],
	"reach": ["sound"],
	"while": ["loop"],
}
const DB_MIN := -40.0
const DB_MAX := 12.0


static func config() -> Dictionary:
	var data: Variant = Content.load_json(PATH)
	return data if data is Dictionary else {}


## The file of a sound; `reversed` gives its reversed twin.
static func path(data: Dictionary, sound_name: String, reversed := false) -> String:
	return str(data.get("folder", "")) + sound_name + (REVERSED_SUFFIX if reversed else "") + ".ogg"


static func sound_entry(data: Dictionary, sound_name: String) -> Dictionary:
	var entry: Variant = (data.get("sounds", {}) as Dictionary).get(sound_name, {})
	return entry if entry is Dictionary else {}


static func volume_db(data: Dictionary, sound_name: String) -> float:
	return float(sound_entry(data, sound_name).get("db", 0.0))


## A menu move sounds only if the last one is at least `gap_seconds` old.
static func move_sounds(last_msec: int, now_msec: int, gap_seconds: float) -> bool:
	return now_msec - last_msec >= int(gap_seconds * 1000.0)


static func climax(data: Dictionary, sound_name: String) -> float:
	return float(sound_entry(data, sound_name).get("climax", 0.0))


static func is_loop(data: Dictionary, sound_name: String) -> bool:
	return bool(sound_entry(data, sound_name).get("loop", false))


## Whether this tick's changes sound reversed: under Shift (`direction` -1) the
## world plays its past backwards, except on the tick of an interference, which
## writes a new present at the cursor (the timeline is at its head after it).
static func plays_reversed(direction: int, at_head: bool) -> bool:
	return direction < 0 and not at_head


## The one-shot sounds a rule makes when its field goes from `before` to
## `after` in recorded, forward time. A `move` is about motion, not about two
## values: see `motion_sounds` and `frame_edge_sounds`. A `reach` sounds when
## the field passes one of `thresholds` (the object's own numbers, read once
## through the rule's `at`).
static func edge_sounds(rule: Dictionary, before: Variant, after: Variant, thresholds: Array = []) -> Array[String]:
	var out: Array[String] = []
	if before == null or after == null:
		return out
	match str(rule.get("kind", "")):
		"flag":
			var was := _truthy(before)
			var now := _truthy(after)
			if not was and now:
				_add(out, rule, "on")
			elif was and not now:
				_add(out, rule, "off")
		"set":
			if _number(before) < 0.0 and _number(after) >= 0.0:
				_add(out, rule, "sound")
		"change":
			if not same(before, after) and (not rule.has("to") or same(after, rule["to"])):
				_add(out, rule, "sound")
		"reach":
			for threshold: Variant in thresholds:
				if _number(before) < float(threshold) and _number(after) >= float(threshold):
					_add(out, rule, "sound")
					break
	return out


## The sound of a `move` rule when the motion starts (`started`) or stops.
static func motion_sounds(rule: Dictionary, started: bool) -> Array[String]:
	var out: Array[String] = []
	_add(out, rule, "start" if started else "stop")
	return out


## The sounds of the recorded edge between frames `k - 1` and `k`: what
## rewinding across it undoes. `value_at` gives the field in a frame (null
## outside the history). A move starts at k when the field stood for `still`
## frames before and changes at k; it stops at k when it changes at k and
## stands for `still` frames after — the same test as the forward one, which
## waits `still` ticks without a change.
static func frame_edge_sounds(rule: Dictionary, value_at: Callable, k: int, still: int, thresholds: Array = []) -> Array[String]:
	var at: Variant = value_at.call(k)
	var before: Variant = value_at.call(k - 1)
	if str(rule.get("kind", "")) != "move":
		return edge_sounds(rule, before, at, thresholds)
	var out: Array[String] = []
	if before == null or at == null or same(before, at):
		return out
	if rule.has("start") and _stands(value_at, k - 1, -1, still):
		_add(out, rule, "start")
	if rule.has("stop") and _stands(value_at, k, 1, still):
		_add(out, rule, "stop")
	return out


## True while a `while` rule's loop plays.
static func holds(rule: Dictionary, value: Variant) -> bool:
	if value == null:
		return false
	if rule.has("equals"):
		return same(value, rule["equals"])
	if rule.has("above"):
		return _number(value) > float(rule["above"])
	return _truthy(value)


## How many frames ahead of the cursor a reversed sound starts so that its hit
## (`climax` seconds into the forward file, `length - climax` into the
## reversed one) sounds on its frame, while the world rewinds `speed` frames a
## tick (D62).
static func lead_frames(length: float, hit: float, speed: float, ticks_per_second: float) -> int:
	return maxi(int(round(maxf(length - hit, 0.0) * ticks_per_second * maxf(speed, 1.0))), 0)


## The frames a hold of Shift rewinds in the next `seconds`, once it has been
## held `held_ticks` ticks: the rewind speeds up (`RewindSpeed`, D62), so a
## reversed sound that must hit in `seconds` looks this many frames ahead.
static func frames_ahead(seconds: float, held_ticks: int, rewind: RewindSpeed, ticks_per_second: float) -> int:
	var start := float(maxi(held_ticks, 0))
	return int(round(_rewound(start + maxf(seconds, 0.0) * ticks_per_second, rewind) - _rewound(start, rewind)))


## Frames rewound from the start of a hold to tick `h`: the area under the speed,
## 1 for `delay_ticks`, then rising to `max_speed` over `ramp_ticks`.
static func _rewound(h: float, rewind: RewindSpeed) -> float:
	var delay := float(rewind.delay_ticks)
	var ramp := float(maxi(rewind.ramp_ticks, 1))
	var top := maxf(rewind.max_speed, 1.0)
	if h <= delay:
		return h
	if h <= delay + ramp:
		var x := h - delay
		return delay + x + (top - 1.0) * x * x / (2.0 * ramp)
	return delay + ramp + (top - 1.0) * ramp / 2.0 + top * (h - delay - ramp)


## Where to start a reversed file whose hit must sound `seconds` from now.
static func reversed_offset(length: float, hit: float, seconds: float) -> float:
	return clampf(length - hit - seconds, 0.0, maxf(length, 0.0))


## The pitch of loops while rewinding `speed` frames a tick: higher the faster.
static func rewind_pitch(data: Dictionary, speed: float) -> float:
	var per_frame := float(data.get("rewind_pitch_per_frame", 0.0))
	return clampf(1.0 + (maxf(speed, 1.0) - 1.0) * per_frame, 1.0, maxf(float(data.get("rewind_pitch_max", 1.0)), 1.0))


## Recorded values compare as numbers when both are numbers (JSON floats meet
## int fields), else by value.
static func same(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## Every sound a rule names.
static func rule_sounds(rule: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in SOUND_KEYS.get(str(rule.get("kind", "")), []):
		if rule.has(key):
			out.append(str(rule[key]))
	return out


## The one-shot sounds a rule names (not its loop).
static func one_shots(rule: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in SOUND_KEYS.get(str(rule.get("kind", "")), []):
		if key != "loop" and rule.has(key) and not out.has(str(rule[key])):
			out.append(str(rule[key]))
	return out


static func _stands(value_at: Callable, from: int, step: int, still: int) -> bool:
	var value: Variant = value_at.call(from)
	for i in range(1, maxi(still, 1) + 1):
		var other: Variant = value_at.call(from + step * i)
		if other == null:
			return step < 0   # the start of the history counts as standing
		if not same(other, value):
			return false
	return true


static func _add(out: Array[String], rule: Dictionary, key: String) -> void:
	if rule.has(key) and str(rule[key]) != "" and not out.has(str(rule[key])):
		out.append(str(rule[key]))


static func _truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if _is_number(value):
		return float(value) != 0.0
	return value != null


static func _number(value: Variant) -> float:
	return float(value) if _is_number(value) else -1.0


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


# --- the data check -------------------------------------------------------------

## Problems of `audio.json`. `check_files`: every named sound must have its file
## (and its reversed twin where the world uses it) — off for broken copies in tests.
static func validate(data: Variant, check_files := true) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("audio.json: must be an object")
		return errors
	var d := data as Dictionary
	var sounds: Variant = d.get("sounds")
	if not sounds is Dictionary or (sounds as Dictionary).is_empty():
		errors.append("audio.json: 'sounds' must be a non-empty object")
		return errors
	var folder := str(d.get("folder", ""))
	if not folder.begins_with("res://") or not folder.ends_with("/"):
		errors.append("audio.json: 'folder' must be a res:// folder ending with /")
	for key in ["still_ticks"]:
		if not _is_number(d.get(key)) or int(d[key]) < 1:
			errors.append("audio.json: '%s' must be a whole number of at least 1" % key)
	for key in ["loop_fade_seconds", "rewind_pitch_per_frame"]:
		if not _is_number(d.get(key)) or float(d[key]) < 0.0:
			errors.append("audio.json: '%s' must be a number of at least 0" % key)
	if not _is_number(d.get("rewind_pitch_max")) or float(d["rewind_pitch_max"]) < 1.0:
		errors.append("audio.json: 'rewind_pitch_max' must be a number of at least 1")
	var positional: Variant = d.get("positional")
	if not positional is Dictionary:
		errors.append("audio.json: 'positional' must be an object")
	else:
		for key in ["max_distance_px", "attenuation", "panning"]:
			if not _is_number((positional as Dictionary).get(key)) or float(positional[key]) < 0.0:
				errors.append("audio.json: positional.%s must be a number of at least 0" % key)
	for sound_name: String in sounds:
		var entry: Variant = sounds[sound_name]
		var where := "audio.json: sounds.%s" % sound_name
		if not entry is Dictionary:
			errors.append(where + " must be an object")
			continue
		if not _is_number(entry.get("db")) or float(entry["db"]) < DB_MIN or float(entry["db"]) > DB_MAX:
			errors.append(where + ".db must be a number from %d to %d" % [DB_MIN, DB_MAX])
		if entry.has("climax") and (not _is_number(entry["climax"]) or float(entry["climax"]) < 0.0):
			errors.append(where + ".climax must be a number of at least 0")
		if entry.has("loop") and not entry["loop"] is bool:
			errors.append(where + ".loop must be true or false")
		if check_files and not ResourceLoader.exists(path(d, sound_name)):
			errors.append(where + ": no file %s" % path(d, sound_name))
	var world := PackedStringArray()   # sounds that also play reversed
	var objects: Variant = d.get("objects")
	if not objects is Dictionary:
		errors.append("audio.json: 'objects' must be an object")
	else:
		for class_key: String in objects:
			var rules: Variant = objects[class_key]
			if not rules is Array:
				errors.append("audio.json: objects.%s must be a list of rules" % class_key)
				continue
			for i in (rules as Array).size():
				errors.append_array(_rule_problems(rules[i], "audio.json: objects.%s[%d]" % [class_key, i], sounds, world))
	_expect_name(errors, sounds, d, ["time", "loop"], true)
	if d.get("time") is Dictionary:
		if not _is_number(d["time"].get("pinned_db")) or not _is_number(d["time"].get("fade_seconds")):
			errors.append("audio.json: time.pinned_db and time.fade_seconds must be numbers")
	var heroine: Variant = d.get("heroine")
	if not heroine is Dictionary:
		errors.append("audio.json: 'heroine' must be an object")
	else:
		var steps: Variant = heroine.get("steps")
		if not steps is Array or (steps as Array).is_empty():
			errors.append("audio.json: heroine.steps must be a non-empty list of sounds")
		else:
			for step: Variant in steps:
				if not (sounds as Dictionary).has(str(step)):
					errors.append("audio.json: heroine.steps names an unknown sound '%s'" % step)
		for key in ["jump", "land", "fail"]:
			_expect_name(errors, sounds, d, ["heroine", key], false)
		for key in ["step_px", "min_speed_px", "jump_speed_px", "land_speed_px"]:
			if not _is_number(heroine.get(key)) or float(heroine[key]) <= 0.0:
				errors.append("audio.json: heroine.%s must be a number above 0" % key)
	_expect_name(errors, sounds, d, ["ambience", "sound"], true)
	if d.get("ambience") is Dictionary:
		for key in ["menu_db", "fade_seconds"]:
			if not _is_number(d["ambience"].get(key)):
				errors.append("audio.json: ambience.%s must be a number" % key)
		world.append(str(d["ambience"].get("sound", "")))
	for key in ["move", "click", "level_done"]:
		_expect_name(errors, sounds, d, ["ui", key], false)
	if d.get("ui") is Dictionary and (not _is_number(d["ui"].get("move_gap_seconds")) or float(d["ui"]["move_gap_seconds"]) < 0.0):
		errors.append("audio.json: ui.move_gap_seconds must be a number >= 0")
	_expect_name(errors, sounds, d, ["sparks", "sound"], false)
	if d.get("sparks") is Dictionary:
		world.append(str(d["sparks"].get("sound", "")))
	_expect_name(errors, sounds, d, ["minecart", "loop"], true)
	if d.get("minecart") is Dictionary:
		for key in ["full_speed_px", "min_pitch"]:
			if not _is_number(d["minecart"].get(key)) or float(d["minecart"][key]) <= 0.0:
				errors.append("audio.json: minecart.%s must be a number above 0" % key)
	if check_files:
		for sound_name in world:
			if (sounds as Dictionary).has(sound_name) and not ResourceLoader.exists(path(d, sound_name, true)):
				errors.append("audio.json: the world plays '%s' reversed, but there is no file %s" % [sound_name, path(d, sound_name, true)])
	return errors


static func _rule_problems(rule: Variant, where: String, sounds: Dictionary, world: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if not rule is Dictionary:
		errors.append(where + " must be an object")
		return errors
	var kind := str(rule.get("kind", ""))
	if not kind in KINDS:
		errors.append(where + ".kind must be one of " + ", ".join(KINDS))
		return errors
	if not rule.get("field") is String or str(rule["field"]).is_empty():
		errors.append(where + ".field must name a field of the object's state")
	var names := rule_sounds(rule)
	if names.is_empty():
		errors.append(where + " names no sound (%s)" % ", ".join(SOUND_KEYS[kind]))
	for key: String in SOUND_KEYS[kind]:
		if not rule.has(key):
			continue
		var sound_name := str(rule[key])
		if not sounds.has(sound_name):
			errors.append(where + ".%s names an unknown sound '%s'" % [key, sound_name])
			continue
		var loops := bool((sounds[sound_name] as Dictionary).get("loop", false))
		if key == "loop" and not loops:
			errors.append(where + ".loop '%s' must be a loop in sounds" % sound_name)
		elif key != "loop" and loops:
			errors.append(where + ".%s '%s' is a loop, a one-shot is needed" % [key, sound_name])
		world.append(sound_name)
	if kind == "while" and not rule.has("equals") and not rule.has("above"):
		errors.append(where + " needs 'equals' or 'above'")
	if kind == "reach" and not (_is_number(rule.get("at")) or (rule.get("at") is String and not str(rule["at"]).is_empty())):
		errors.append(where + ".at must be a number or the path of the object's number (\"plan.quake_tick\")")
	if rule.has("live") and not rule["live"] is bool:
		errors.append(where + ".live must be true or false")
	if rule.has("pitch") and (not _is_number(rule["pitch"]) or float(rule["pitch"]) <= 0.0):
		errors.append(where + ".pitch must be a number above 0")
	return errors


## Checks that `keys` (a path into the data) names a known sound, a loop or not.
static func _expect_name(errors: PackedStringArray, sounds: Dictionary, data: Dictionary, keys: Array, loop: bool) -> void:
	var section: Variant = data.get(keys[0])
	var where := "audio.json: " + ".".join(keys)
	if not section is Dictionary:
		errors.append("audio.json: '%s' must be an object" % keys[0])
		return
	var sound_name := str((section as Dictionary).get(keys[1], ""))
	if not sounds.has(sound_name):
		errors.append(where + " names an unknown sound '%s'" % sound_name)
	elif bool((sounds[sound_name] as Dictionary).get("loop", false)) != loop:
		errors.append(where + " '%s' must %sbe a loop" % [sound_name, "" if loop else "not "])
