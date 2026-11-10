class_name Content
extends RefCounted
## Loads the JSON files from `data/` and checks them. The tests call
## `Content.validate()`, so a broken number shows up as a failed test.

const PLAYER_PATH := "res://data/player.json"
const TIME_PATH := "res://data/time.json"
const LEVELS_PATH := "res://data/levels.json"
const OBJECTS_PATH := "res://data/objects.json"

const PLAYER_KEYS: Array[String] = [
	"walk_speed", "acceleration", "friction", "gravity",
	"jump_velocity", "max_fall_speed", "coyote_seconds", "jump_buffer_seconds",
]
const TIME_KEYS: Array[String] = [
	"physics_ticks_per_second", "snapshot_every_ticks", "history_seconds",
	"default_prelude_seconds", "max_state_step",
]
const LEVEL_KEYS: Array[String] = ["id", "scene", "prelude_seconds", "title"]
const DOOR_KEYS: Array[String] = ["open_seconds", "hold_open_seconds", "close_seconds", "hold_closed_seconds"]
const PLATFORM_KEYS: Array[String] = ["speed", "pause_seconds"]
const BUTTON_KEYS: Array[String] = ["interact_radius_px"]
const LEVER_KEYS: Array[String] = ["interact_radius_px"]
## Every window in which the player must act is at least this long (design rules).
const MIN_WINDOW_SECONDS := 3.0


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


static func objects() -> Dictionary:
	var data: Variant = load_json(OBJECTS_PATH)
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
	if time_data is Dictionary and validate_time(time_data).is_empty():
		errors.append_array(validate_objects(load_json(OBJECTS_PATH), time_data))
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
	var frames := float(data["history_seconds"]) * float(data["physics_ticks_per_second"]) \
			/ maxf(float(data["snapshot_every_ticks"]), 1.0)
	if frames < float(Timeline.MIN_CAPACITY):
		errors.append("time.json: the history must hold at least %d frames" % Timeline.MIN_CAPACITY)
	var prelude := float(data["default_prelude_seconds"])
	if prelude < 0.0 or prelude > float(data["history_seconds"]):
		errors.append("time.json: 'default_prelude_seconds' must be between 0 and 'history_seconds'")
	return errors


static func validate_levels(data: Variant, history_seconds: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Array:
		errors.append("levels.json: expected a list")
		return errors
	if data.is_empty():
		errors.append("levels.json: the list must hold at least one level")
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


## `time_data` must already be valid: steps per tick are checked against it.
static func validate_objects(data: Variant, time_data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("objects.json: expected an object")
		return errors
	var ticks := float(time_data["physics_ticks_per_second"])
	var max_step := float(time_data["max_state_step"])
	if not data.has("carry_margin_px") or not _is_number(data["carry_margin_px"]) or float(data["carry_margin_px"]) <= 0.0:
		errors.append("objects.json: 'carry_margin_px' must be a number above 0")
	for section: Variant in [["door", DOOR_KEYS], ["platform", PLATFORM_KEYS]]:
		var sec := section as Array
		var sec_name: String = sec[0]
		var entry: Variant = data.get(sec_name)
		if not entry is Dictionary:
			errors.append("objects.json: missing object '%s'" % sec_name)
			continue
		for key: Variant in sec[1]:
			if not entry.has(key) or not _is_number(entry[key]) or float(entry[key]) <= 0.0:
				errors.append("objects.json: '%s.%s' must be a number above 0" % [sec_name, key])
	if not errors.is_empty():
		return errors
	var door: Dictionary = data["door"]
	for key in ["hold_open_seconds", "hold_closed_seconds"]:
		if float(door[key]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'door.%s' is a window to act and must be at least %d s" % [key, MIN_WINDOW_SECONDS])
	for key in ["open_seconds", "close_seconds"]:
		if 1000.0 / (float(door[key]) * ticks) > max_step:
			errors.append("objects.json: 'door.%s' is too short: the door would jump more than max_state_step per tick" % key)
	var platform: Dictionary = data["platform"]
	if float(platform["pause_seconds"]) < MIN_WINDOW_SECONDS:
		errors.append("objects.json: 'platform.pause_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
	var step := float(platform["speed"]) / ticks
	if step > max_step:
		errors.append("objects.json: 'platform.speed' moves more than max_state_step per tick")
	if step >= float(data["carry_margin_px"]):
		errors.append("objects.json: 'platform.speed' per tick must stay below 'carry_margin_px', or a rider reads as crushed")
	for interact_section: Variant in [["button", BUTTON_KEYS], ["lever", LEVER_KEYS]]:
		var isec := interact_section as Array
		var isec_name: String = isec[0]
		var ientry: Variant = data.get(isec_name)
		if not ientry is Dictionary:
			errors.append("objects.json: missing object '%s'" % isec_name)
			continue
		for key: Variant in isec[1]:
			if not ientry.has(key) or not _is_number(ientry[key]) or float(ientry[key]) <= 0.0:
				errors.append("objects.json: '%s.%s' must be a number above 0" % [isec_name, key])
	return errors


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
