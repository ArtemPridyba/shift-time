class_name Content
extends RefCounted
## Loads the JSON files from `data/` and checks them. The tests call
## `Content.validate()`, so a broken number shows up as a failed test.

const PLAYER_PATH := "res://data/player.json"
const TIME_PATH := "res://data/time.json"
const LEVELS_PATH := "res://data/levels.json"

const PLAYER_KEYS: Array[String] = [
	"walk_speed", "acceleration", "friction", "gravity",
	"jump_velocity", "max_fall_speed", "coyote_seconds", "jump_buffer_seconds",
]
const TIME_KEYS: Array[String] = [
	"physics_ticks_per_second", "snapshot_every_ticks", "history_seconds",
	"default_prelude_seconds", "max_state_step",
]
const LEVEL_KEYS: Array[String] = ["id", "scene", "prelude_seconds", "title"]


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func player() -> Dictionary:
	var data: Variant = load_json(PLAYER_PATH)
	return data if data is Dictionary else {}


static func time() -> Dictionary:
	var data: Variant = load_json(TIME_PATH)
	return data if data is Dictionary else {}


static func levels() -> Array:
	var data: Variant = load_json(LEVELS_PATH)
	return data if data is Array else []


## Returns a list of problems; an empty list means the data is fine.
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(validate_player(load_json(PLAYER_PATH)))
	var time_data: Variant = load_json(TIME_PATH)
	errors.append_array(validate_time(time_data))
	var history_seconds := 0.0
	if time_data is Dictionary and time_data.has("history_seconds") and _is_number(time_data["history_seconds"]):
		history_seconds = float(time_data["history_seconds"])
	errors.append_array(validate_levels(load_json(LEVELS_PATH), history_seconds))
	return errors


static func validate_player(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("player.json: expected an object")
		return errors
	for key in PLAYER_KEYS:
		if not data.has(key):
			errors.append("player.json: missing '%s'" % key)
		elif not _is_number(data[key]) or float(data[key]) <= 0.0:
			errors.append("player.json: '%s' must be a number above 0" % key)
	return errors


static func validate_time(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("time.json: expected an object")
		return errors
	for key in TIME_KEYS:
		if not data.has(key):
			errors.append("time.json: missing '%s'" % key)
		elif not _is_number(data[key]):
			errors.append("time.json: '%s' must be a number" % key)
	if not errors.is_empty():
		return errors
	for key in ["physics_ticks_per_second", "snapshot_every_ticks", "max_state_step"]:
		if int(data[key]) < 1:
			errors.append("time.json: '%s' must be at least 1" % key)
	if float(data["history_seconds"]) <= 0.0:
		errors.append("time.json: 'history_seconds' must be above 0")
	var prelude := float(data["default_prelude_seconds"])
	if prelude < 0.0 or prelude > float(data["history_seconds"]):
		errors.append("time.json: 'default_prelude_seconds' must be between 0 and 'history_seconds'")
	return errors


static func validate_levels(data: Variant, history_seconds: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Array:
		errors.append("levels.json: expected a list")
		return errors
	var seen := {}
	for i in data.size():
		var entry: Variant = data[i]
		var where := "levels.json[%d]" % i
		if not entry is Dictionary:
			errors.append("%s: expected an object" % where)
			continue
		for key in LEVEL_KEYS:
			if not entry.has(key):
				errors.append("%s: missing '%s'" % [where, key])
		if not errors.is_empty():
			continue
		var id: Variant = entry["id"]
		if not id is String or (id as String).is_empty():
			errors.append("%s: 'id' must be a non-empty string" % where)
		elif seen.has(id):
			errors.append("%s: duplicate id '%s'" % [where, id])
		else:
			seen[id] = true
		if not entry["scene"] is String or not ResourceLoader.exists(entry["scene"]):
			errors.append("%s: scene '%s' does not exist" % [where, entry["scene"]])
		if not _is_number(entry["prelude_seconds"]) \
				or float(entry["prelude_seconds"]) < 0.0 \
				or float(entry["prelude_seconds"]) > history_seconds:
			errors.append("%s: 'prelude_seconds' must be between 0 and the history length" % where)
		if not entry["title"] is String:
			errors.append("%s: 'title' must be a string" % where)
	return errors


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
