class_name Content
extends RefCounted
## Loads the JSON files from `data/` and checks them. The tests call
## `Content.validate()`, so a broken number shows up as a failed test.

const PLAYER_PATH := "res://data/player.json"
const TIME_PATH := "res://data/time.json"
const LEVELS_PATH := "res://data/levels.json"
const OBJECTS_PATH := "res://data/objects.json"
const TIME_HUD_PATH := "res://data/time_hud.json"

const PLAYER_KEYS: Array[String] = [
	"walk_speed", "acceleration", "friction", "gravity",
	"jump_velocity", "max_fall_speed", "coyote_seconds", "jump_buffer_seconds",
	"water_walk_factor", "water_gravity", "water_max_sink_speed", "water_drag",
	"water_jump_velocity", "water_float_up_speed", "head_px",
	"breath_seconds", "breath_refill_seconds", "breath_vignette_alpha", "breath_vignette_radius",
	"fire_seconds", "fire_cool_seconds",
]
const TIME_KEYS: Array[String] = [
	"physics_ticks_per_second", "snapshot_every_ticks", "history_seconds",
	"default_prelude_seconds", "max_state_step",
]
const LEVEL_KEYS: Array[String] = ["id", "scene", "prelude_seconds", "title"]
const DOOR_KEYS: Array[String] = ["open_seconds", "hold_open_seconds", "close_seconds", "hold_closed_seconds"]
const PLATFORM_KEYS: Array[String] = ["speed", "pause_seconds"]
const WATER_KEYS: Array[String] = ["full_seconds", "float_draft_px"]
## The look of water (decoration, task 2.3А): all numbers above 0.
const WATER_LOOK_KEYS: Array[String] = [
	"ripple_px", "ripple_length_px", "wave_px", "wave_length_px", "wave_speed_px",
	"wave_seconds", "drip_seconds", "drips_per_second", "drip_gravity_px", "streak_px",
	"jet_drops", "jet_cycles_per_second", "splash_drops", "outlet_inset_px", "valve_turns_per_tank",
]
const BUTTON_KEYS: Array[String] = ["interact_radius_px"]
const LEVER_KEYS: Array[String] = ["interact_radius_px"]
const LAMP_KEYS: Array[String] = ["break_seconds", "fall_seconds", "shatter_seconds", "fall_distance_px", "flash_seconds", "flash_radius_px", "light_radius_px"]
const DARKNESS_KEYS: Array[String] = ["ambient", "player_outline_alpha"]
## Fire (task 2.7): wood zones, the steam of a doused fire, the reverse flamethrower.
const WOOD_KEYS: Array[String] = ["burn_seconds", "flame_px", "flame_side_px", "flames_per_cell", "sparks"]
const STEAM_KEYS: Array[String] = ["seconds", "puffs", "rise_px", "radius_px"]
const FLAMETHROWER_KEYS: Array[String] = ["interact_radius_px", "reach_px", "jet_px", "follow_px", "gravity", "max_fall_speed"]
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


static func time_hud() -> Dictionary:
	var data: Variant = load_json(TIME_HUD_PATH)
	return data if data is Dictionary else {}


## The entry of `levels.json` whose scene is `scene_path`, or an empty
## dictionary (a room opened on its own, a test scene).
static func level_for_scene(scene_path: String) -> Dictionary:
	if scene_path.is_empty():
		return {}
	for entry: Variant in levels():
		if entry is Dictionary and str((entry as Dictionary).get("scene", "")) == scene_path:
			return entry
	return {}


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
	errors.append_array(validate_time_hud(load_json(TIME_HUD_PATH)))
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
	if not errors.is_empty():
		return errors
	for key in ["water_walk_factor", "breath_vignette_alpha", "breath_vignette_radius"]:
		if float(data[key]) > 1.0:
			errors.append("player.json: '%s' must be at most 1" % key)
	if float(data["breath_seconds"]) < MIN_WINDOW_SECONDS:
		errors.append("player.json: 'breath_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
	if float(data["fire_seconds"]) < MIN_WINDOW_SECONDS:
		errors.append("player.json: 'fire_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
	if not data.has("fire_vignette_color") or not data["fire_vignette_color"] is String or not Color.html_is_valid(str(data["fire_vignette_color"])):
		errors.append("player.json: 'fire_vignette_color' must be a color like \"#5c1800\"")
	# 92 px is the body of player.tscn.
	if float(data["head_px"]) >= 92.0:
		errors.append("player.json: 'head_px' must be less than the player's height (92 px)")
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
		if entry.has("prelude_events") and _is_number(entry["prelude_seconds"]):
			errors.append_array(_prelude_event_problems(entry["prelude_events"], float(entry["prelude_seconds"]), where))
	return errors


## Scripted events of a level's prelude (section 2.2): each at a `second`
## inside the prelude, and either `press` (an interaction point) or `id` with
## a `state` to set.
static func _prelude_event_problems(events: Variant, prelude_seconds: float, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not events is Array:
		errors.append("%s: 'prelude_events' must be a list" % where)
		return errors
	for i in (events as Array).size():
		var event: Variant = events[i]
		var at := "%s.prelude_events[%d]" % [where, i]
		if not event is Dictionary:
			errors.append("%s: expected an object" % at)
			continue
		var second: Variant = event.get("second")
		if not _is_number(second) or float(second) < 0.0 or float(second) > prelude_seconds:
			errors.append("%s: 'second' must be a number inside the prelude (0 to %s)" % [at, prelude_seconds])
		var press: bool = event.has("press")
		var sets: bool = event.has("id") or event.has("state")
		if press == sets:
			errors.append("%s: give either 'press' or 'id' with 'state'" % at)
		elif press and (not event["press"] is String or (event["press"] as String).is_empty()):
			errors.append("%s: 'press' must be an object id" % at)
		elif sets and (not event.get("id") is String or (event.get("id") as String).is_empty() \
				or not event.get("state") is Dictionary or (event.get("state") as Dictionary).is_empty()):
			errors.append("%s: 'id' must be an object id and 'state' a non-empty object" % at)
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
	for section: Variant in [["door", DOOR_KEYS], ["platform", PLATFORM_KEYS], ["water", WATER_KEYS], ["water_look", WATER_LOOK_KEYS]]:
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
	# 10000 is Water.LEVEL_MAX (core/ does not refer to objects/).
	if 10000.0 / (float(data["water"]["full_seconds"]) * ticks) > max_step:
		errors.append("objects.json: 'water.full_seconds' is too short: the level would jump more than max_state_step per tick")
	for interact_section: Variant in [["button", BUTTON_KEYS], ["lever", LEVER_KEYS], ["lamp", LAMP_KEYS], ["wood", WOOD_KEYS], ["steam", STEAM_KEYS], ["flamethrower", FLAMETHROWER_KEYS]]:
		var isec := interact_section as Array
		var isec_name: String = isec[0]
		var ientry: Variant = data.get(isec_name)
		if not ientry is Dictionary:
			errors.append("objects.json: missing object '%s'" % isec_name)
			continue
		for key: Variant in isec[1]:
			if not ientry.has(key) or not _is_number(ientry[key]) or float(ientry[key]) <= 0.0:
				errors.append("objects.json: '%s.%s' must be a number above 0" % [isec_name, key])
	if errors.is_empty():
		if float(data["lamp"]["break_seconds"]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'lamp.break_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
		var lamp: Dictionary = data["lamp"]
		# The fall is quadratic: its last tick moves the lamp twice the average step.
		if 2000.0 / (float(lamp["fall_seconds"]) * ticks) > max_step:
			errors.append("objects.json: 'lamp.fall_seconds' is too short: the lamp would jump more than max_state_step per tick")
		if 1000.0 / (float(lamp["shatter_seconds"]) * ticks) > max_step:
			errors.append("objects.json: 'lamp.shatter_seconds' is too short: the shards would jump more than max_state_step per tick")
		if float(data["wood"]["burn_seconds"]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'wood.burn_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
		var thrower: Dictionary = data["flamethrower"]
		for key in ["follow_px"]:
			if float(thrower[key]) > max_step:
				errors.append("objects.json: 'flamethrower.%s' moves more than max_state_step per tick" % key)
		if float(thrower["max_fall_speed"]) / ticks > max_step:
			errors.append("objects.json: 'flamethrower.max_fall_speed' moves more than max_state_step per tick")
		var dark: Variant = data.get("darkness")
		if not dark is Dictionary:
			errors.append("objects.json: missing object 'darkness'")
		else:
			for key: Variant in DARKNESS_KEYS:
				if not dark.has(key) or not _is_number(dark[key]) or float(dark[key]) < 0.0 or float(dark[key]) > 1.0:
					errors.append("objects.json: 'darkness.%s' must be a number from 0 to 1" % key)
	return errors


## The wrist device and the time indicator (task 1.5): colors, sizes, flicker,
## streaks, the glow and streaks along the screen edges and the (still empty)
## sound paths.
static func validate_time_hud(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("time_hud.json: expected an object")
		return errors
	for section_name: String in ["colors", "device", "rewind", "particles", "edges", "audio"]:
		if not data.get(section_name) is Dictionary:
			errors.append("time_hud.json: missing section '%s'" % section_name)
	if not errors.is_empty():
		return errors
	var colors: Dictionary = data["colors"]
	for key: String in ["accent", "plate", "pin"]:
		if not colors.get(key) is String or not Color.html_is_valid(colors[key]):
			errors.append("time_hud.json: 'colors.%s' must be a color like \"#7FE8FF\"" % key)
	var device: Dictionary = data["device"]
	for key: String in ["plate_width_px", "plate_height_px", "glyph_height_px", "glow_radius_px"]:
		_check_range(errors, device, "device", key, 0.0, 1000.0, true)
	_check_range(errors, device, "device", "offset_x_px", -1000.0, 1000.0)
	_check_range(errors, device, "device", "offset_y_px", -1000.0, 1000.0)
	_check_range(errors, device, "device", "glow_alpha", 0.0, 1.0)
	var rewind: Dictionary = data["rewind"]
	_check_range(errors, rewind, "rewind", "flicker_hz", 0.0, 60.0, true)
	_check_range(errors, rewind, "rewind", "flicker_depth", 0.0, 1.0)
	_check_range(errors, rewind, "rewind", "sweep_hz", 0.0, 60.0, true)
	var particles: Dictionary = data["particles"]
	_check_range(errors, particles, "particles", "count", 0.0, 32.0)
	_check_range(errors, particles, "particles", "cycle_seconds", 0.0, 60.0, true)
	_check_range(errors, particles, "particles", "spread_px", 0.0, 1000.0, true)
	_check_range(errors, particles, "particles", "size_px", 0.0, 100.0, true)
	_check_range(errors, particles, "particles", "dash_px", 0.0, 200.0, true)
	_check_range(errors, particles, "particles", "lane_px", 0.0, 200.0, true)
	var edges: Dictionary = data["edges"]
	_check_range(errors, edges, "edges", "glow_strength", 0.0, 1.0)
	_check_range(errors, edges, "edges", "width", 0.0, 0.5, true)
	_check_range(errors, edges, "edges", "fade_seconds", 0.0, 10.0, true)
	_check_range(errors, edges, "edges", "streak_strength", 0.0, 1.0)
	_check_range(errors, edges, "edges", "streak_density", 0.0, 1.0)
	_check_range(errors, edges, "edges", "streak_length", 0.0, 1.0, true)
	_check_range(errors, edges, "edges", "streak_rows", 1.0, 200.0)
	_check_range(errors, edges, "edges", "streak_thickness", 0.0, 0.5, true)
	var audio: Dictionary = data["audio"]
	for key: String in ["forward", "rewind"]:
		if not audio.get(key) is String:
			errors.append("time_hud.json: 'audio.%s' must be a path or an empty string" % key)
		elif str(audio[key]) != "" and not ResourceLoader.exists(audio[key]):
			errors.append("time_hud.json: 'audio.%s' points to a missing file '%s'" % [key, audio[key]])
	return errors


## A number between `low` and `high` (`low` itself is allowed unless `above_low`).
static func _check_range(errors: PackedStringArray, section: Dictionary, section_name: String, key: String, low: float, high: float, above_low := false) -> void:
	if not section.has(key) or not _is_number(section[key]):
		errors.append("time_hud.json: '%s.%s' must be a number" % [section_name, key])
		return
	var value := float(section[key])
	if value < low or value > high or (above_low and value <= low):
		errors.append("time_hud.json: '%s.%s' must be %s %s and at most %s" % [section_name, key, "above" if above_low else "at least", low, high])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
