class_name Content
extends RefCounted
## Loads the JSON files from `data/` and checks them. The tests call
## `Content.validate()`, so a broken number shows up as a failed test.

const PLAYER_PATH := "res://data/player.json"
const TIME_PATH := "res://data/time.json"
const LEVELS_PATH := "res://data/levels.json"
## Test rooms: same entries as levels.json, never in the level list. They live
## next to the tests and stay out of the export, where this file is missing.
const TEST_ROOMS_PATH := "res://tests/rooms/rooms.json"
const OBJECTS_PATH := "res://data/objects.json"
const TIME_HUD_PATH := "res://data/time_hud.json"
const ART_PATH := "res://data/art.json"
const LOOK_PATH := "res://data/look.json"
const CAMERA_PATH := "res://data/camera.json"
const MENU_PATH := "res://data/menu.json"
## Texts of the menu buttons (`menu.json`, `buttons`).
const MENU_BUTTONS: Array[String] = ["start", "continue", "levels", "quit", "back", "resume", "restart", "main_menu", "passed"]
## Numbers of `camera.json` (D83), each above 0.
const CAMERA_KEYS := ["zoom", "zoom_max", "zoom_step", "zoom_speed", "lead_px", "lead_speed", "follow_speed", "overview_start_seconds", "overview_blend_seconds", "feet_screen_y", "ride_lead_px", "ride_zoom"]
## Colour roles every palette in `art.json` must give, each as a ramp from dark to light.
const ART_ROLES: Array[String] = ["background", "steel", "mechanism", "suit", "helmet", "rust", "time", "fire", "interact", "water", "wood", "lamp_light"]
const ART_RAMP_SIZE := 5
const ART_STATUSES: Array[String] = ["main", "reserve"]
## Numbers of the shared material (`art.json`, `material`), each a shader
## uniform of `art/style/material.gdshader`: sizes in pixels, the rest 0..1.
const ART_MATERIAL_KEYS: Array[String] = [
	"outline_px", "rim_px", "shadow_px", "chip_reach_px", "chip_density", "chip_scale_px",
	"dust_px", "dust_strength", "dirt_px", "dirt_strength", "rust_scale_px",
]
## The one-point perspective of a room (`art.json`, `perspective`): the tile,
## the eye (a point of the screen everything recedes to), how far the eye is
## from the middle plane and how deep slabs are, all in pixels.
const ART_PERSPECTIVE_KEYS: Array[String] = ["tile_px", "eye_x", "eye_y", "distance_px", "slab_depth_px"]
## The shader looks at most this many pixels from an edge: the outline and
## the bands behind it (rim and dust, shadow and dirt, chips) must fit.
const ART_MATERIAL_MAX_PX := 24

const PLAYER_KEYS: Array[String] = [
	"walk_speed", "acceleration", "friction", "gravity",
	"jump_velocity", "max_fall_speed", "coyote_seconds", "jump_buffer_seconds",
	"water_walk_factor", "water_gravity", "water_max_sink_speed", "water_drag",
	"water_jump_velocity", "water_float_up_speed", "head_px",
	"breath_seconds", "breath_refill_seconds", "breath_vignette_alpha", "breath_vignette_radius",
	"fire_seconds", "fire_cool_seconds", "floor_snap_px", "floor_max_angle_deg",
]
## Bounds of `world_tempo` in `time.json` (D96).
const WORLD_TEMPO_MIN := 0.5
const WORLD_TEMPO_MAX := 2.0
const TIME_KEYS: Array[String] = [
	"physics_ticks_per_second", "snapshot_every_ticks", "history_seconds",
	"default_prelude_seconds", "max_state_step",
	"rewind_speed_max", "rewind_ramp_delay_seconds", "rewind_ramp_seconds", "world_tempo",
]
const LEVEL_KEYS: Array[String] = ["id", "scene", "prelude_seconds", "title"]
const LEVEL_DOOR_CYCLES: Array[String] = ["loop", "once", "opens_once"]
const EXIT_ZONE_KEYS: Array[String] = ["delay_seconds"]
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
const SHUTTER_KEYS: Array[String] = ["move_seconds"]
const TIME_PLATE_KEYS: Array[String] = ["contact_px"]
## Where a shutter of a level starts (level 04), and a rail switch (D168).
const SHUTTER_STARTS: Array[String] = ["open", "closed", "down", "up"]
## The rail switch of level 04 (D168).
const RAIL_SWITCH_KEYS: Array[String] = ["move_seconds"]
## The minecart of level 04 (D168), all above 0: speeds in px a second, the
## brake and the start in px a second squared, its shape in px.
const MINECART_KEYS: Array[String] = [
	"speed_px", "accel_px", "brake_px", "creep_px", "launch_seconds", "bump_seconds", "bounce_px",
	"shake_px", "hoist_speed_px", "length_px", "body_px", "platform_px", "platform_width_px", "seat_px", "board_px",
]
const LEVER_KEYS: Array[String] = ["interact_radius_px"]
## The plug of level 02's pipe (D164): an item, like the flamethrower; all above 0.
const PIPE_PLUG_KEYS: Array[String] = ["interact_radius_px", "insert_radius_px", "gravity", "max_fall_speed", "friction_px", "follow_px"]
const LAMP_KEYS: Array[String] = ["break_seconds", "fall_seconds", "shatter_seconds", "fall_distance_px", "flash_seconds", "flash_radius_px", "light_radius_px"]
const DARKNESS_KEYS: Array[String] = ["ambient", "player_outline_alpha"]
## Fire (task 2.7): wood zones, the steam of a doused fire, the reverse flamethrower.
const WOOD_KEYS: Array[String] = ["burn_seconds", "spread_seconds", "flame_px", "flame_side_px"]
## The look of fire (decoration, task 2.7А): all numbers above 0.
const FIRE_LOOK_KEYS: Array[String] = [
	"ignite_seconds", "fade_seconds", "flame_rise_px", "sparks", "spark_rise_px", "spark_seconds",
	"smoke_puffs", "smoke_rise_px", "smoke_seconds", "smoke_after_seconds", "ash_pieces",
	"ash_seconds", "ash_gravity_px", "glow_radius_px", "glow_alpha", "jet_speed_px",
]
## The sprinkler pipe of level 03 (D104): rain that puts burning wood out.
const SPRINKLER_KEYS: Array[String] = ["spin_up_seconds", "nozzle_spacing_px", "drop_speed_px", "drops_per_nozzle"]
const STEAM_KEYS: Array[String] = ["seconds", "puffs", "rise_px", "radius_px"]
## The torch of level 03 (D155): an item that carries fire from the past.
const RAMP_KEYS: Array[String] = ["fall_seconds", "thickness_px"]
const TORCH_KEYS: Array[String] = ["stand_px", "reach_px", "follow_px"]
const ROPE_KEYS: Array[String] = ["burn_seconds", "reach_px"]
const WINCH_RAMP_KEYS: Array[String] = ["thickness_px"]
const CAGE_KEYS: Array[String] = ["rise_seconds", "floor_px", "bars_px"]
## The poses of a winch ramp's schedule (`objects.<id>.keys`, level 03).
const WINCH_POSES: Array[String] = ["flat", "slope", "up"]
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


static func camera() -> Dictionary:
	var data: Variant = load_json(CAMERA_PATH)
	return data if data is Dictionary else {}


## Ticks in one second of the world's own clock: `physics_ticks_per_second`
## divided by `world_tempo` (D96). Doors, platforms, water and the prelude turn
## their seconds into ticks with this, so a tempo of 1.25 runs every mechanism
## and every tank a quarter faster, while the player, breath and fire keep
## real seconds. A missing key counts as 60 ticks and tempo 1.
static func world_ticks_per_second(time_data: Dictionary) -> float:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	return ticks / maxf(float(time_data.get("world_tempo", 1.0)), 0.01)


static func time() -> Dictionary:
	var data: Variant = load_json(TIME_PATH)
	return data if data is Dictionary else {}


static func objects() -> Dictionary:
	var data: Variant = load_json(OBJECTS_PATH)
	return data if data is Dictionary else {}


static func time_hud() -> Dictionary:
	var data: Variant = load_json(TIME_HUD_PATH)
	return data if data is Dictionary else {}


static func art() -> Dictionary:
	var data: Variant = load_json(ART_PATH)
	return data if data is Dictionary else {}


## The look of the Night Hall (task Д2): particle presets and mechanism colours.
## look.json, read once: the lamps, the crane and the world ask it while they
## draw, every frame while something falls, and parsing it each time made the
## game stutter (24.11.2026). Nobody changes it while the game runs; treat the
## Dictionary as read-only.
static var _look: Variant = null


static func look() -> Dictionary:
	if _look == null:
		var data: Variant = load_json(LOOK_PATH)
		_look = data if data is Dictionary else {}
	return _look


static func look_particles() -> Dictionary:
	var particles: Variant = look().get("particles")
	return particles if particles is Dictionary else {}


static func look_mech() -> Dictionary:
	var mech: Variant = look().get("mech")
	return mech if mech is Dictionary else {}


## The water pipes of level 03 (D108): sizes, colours, the running water.
static func look_pipe() -> Dictionary:
	var pipe: Variant = look().get("pipe")
	return pipe if pipe is Dictionary else {}


## The numbers of the shared material, `material` of `art.json`.
static func art_material() -> Dictionary:
	var material: Variant = art().get("material")
	return material if material is Dictionary else {}


## The numbers of the look from above, `perspective` of `art.json`.
static func art_perspective() -> Dictionary:
	var perspective: Variant = art().get("perspective")
	return perspective if perspective is Dictionary else {}


## The ramps of the active palette: role -> five colours, dark to light.
static func active_palette() -> Dictionary:
	var data := art()
	var palettes: Variant = data.get("palettes")
	if not palettes is Dictionary or not palettes.get(data.get("active_palette", "")) is Dictionary:
		return {}
	return palettes[data["active_palette"]]


## The entry of `levels.json` or of the test rooms whose scene is
## `scene_path`, or an empty dictionary (a scene opened on its own).
static func level_for_scene(scene_path: String) -> Dictionary:
	if scene_path.is_empty():
		return {}
	for entry: Variant in levels() + test_rooms():
		if entry is Dictionary and str((entry as Dictionary).get("scene", "")) == scene_path:
			return entry
	return {}


## The levels of the level list.
static func menu() -> Dictionary:
	var data: Variant = load_json(MENU_PATH)
	return data if data is Dictionary else {}


static func levels() -> Array:
	var data: Variant = load_json(LEVELS_PATH)
	return data if data is Array else []


## The test rooms; empty in the exported game.
static func test_rooms() -> Array:
	if not FileAccess.file_exists(TEST_ROOMS_PATH):
		return []
	var data: Variant = load_json(TEST_ROOMS_PATH)
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
	if FileAccess.file_exists(TEST_ROOMS_PATH):
		errors.append_array(validate_levels(load_json(TEST_ROOMS_PATH), history_seconds, "rooms.json"))
	if time_data is Dictionary and validate_time(time_data).is_empty():
		errors.append_array(validate_objects(load_json(OBJECTS_PATH), time_data))
	errors.append_array(validate_time_hud(load_json(TIME_HUD_PATH)))
	errors.append_array(validate_art(load_json(ART_PATH)))
	errors.append_array(validate_look(load_json(LOOK_PATH)))
	errors.append_array(HeroineData.validate(load_json(HeroineData.PATH)))
	errors.append_array(validate_camera(load_json(CAMERA_PATH)))
	errors.append_array(validate_menu(load_json(MENU_PATH)))
	errors.append_array(SoundRules.validate(load_json(SoundRules.PATH)))
	errors.append_array(ControlsData.validate(load_json(ControlsData.PATH)))
	return errors


## The menu, transitions, pause and final screen (`menu.json`, tasks 4.2, 4.3).
static func validate_menu(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("menu.json: expected an object")
		return errors
	var menu_data := data as Dictionary
	for key in ["title", "pause_title"]:
		if not menu_data.get(key) is String or str(menu_data[key]).is_empty():
			errors.append("menu.json: '%s' must be a non-empty text" % key)
	var picture: Variant = menu_data.get("background")
	if not picture is String or not ResourceLoader.exists(str(picture)):
		errors.append("menu.json: 'background' must point to a picture of the game, got '%s'" % [picture])
	var dim: Variant = menu_data.get("dim")
	if not _is_number(dim) or float(dim) < 0.0 or float(dim) > 1.0:
		errors.append("menu.json: 'dim' must be a number from 0 to 1")
	for key in ["fade_seconds", "title_card_seconds"]:
		var value: Variant = menu_data.get(key)
		if not _is_number(value) or float(value) <= 0.0 or float(value) > 5.0:
			errors.append("menu.json: '%s' must be a number above 0 and at most 5" % key)
	for key in ["unlock_in_order", "pause_on_focus_loss"]:
		if not menu_data.get(key) is bool:
			errors.append("menu.json: '%s' must be true or false" % key)
	var buttons: Variant = menu_data.get("buttons")
	if not buttons is Dictionary:
		errors.append("menu.json: missing section 'buttons'")
	else:
		for key in MENU_BUTTONS:
			var text: Variant = (buttons as Dictionary).get(key)
			if not text is String or str(text).is_empty():
				errors.append("menu.json: 'buttons.%s' must be a non-empty text" % key)
	var final: Variant = menu_data.get("final")
	if not final is Dictionary:
		errors.append("menu.json: missing section 'final'")
	else:
		var heading: Variant = (final as Dictionary).get("heading")
		if not heading is String or str(heading).is_empty():
			errors.append("menu.json: 'final.heading' must be a non-empty text")
		var lines: Variant = (final as Dictionary).get("lines")
		if not lines is Array:
			errors.append("menu.json: 'final.lines' must be a list of texts")
		else:
			for line: Variant in lines:
				if not line is String:
					errors.append("menu.json: 'final.lines' must hold only texts")
					break
	return errors


static func validate_camera(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("camera.json: expected an object")
		return errors
	for key: String in CAMERA_KEYS:
		if not data.has(key):
			errors.append("camera.json: missing '%s'" % key)
		elif not _is_number(data[key]) or float(data[key]) <= 0.0:
			errors.append("camera.json: '%s' must be a number above 0" % key)
	if errors.is_empty() and float(data["zoom"]) < 1.0:
		errors.append("camera.json: 'zoom' must be at least 1: the level starts no farther than the room at its own size")
	if errors.is_empty() and float(data["zoom_max"]) < float(data["zoom"]):
		errors.append("camera.json: 'zoom_max' must be at least 'zoom': the level starts no closer than the closest view")
	if errors.is_empty() and (float(data["zoom_step"]) <= 1.0 or float(data["zoom_step"]) > 2.0):
		errors.append("camera.json: 'zoom_step' must be above 1 and at most 2: one wheel step multiplies the zoom by it")
	if errors.is_empty() and float(data["ride_zoom"]) > 1.0:
		errors.append("camera.json: 'ride_zoom' must be at most 1: in the cart the camera pulls back, never closer")
	if errors.is_empty() and (float(data["feet_screen_y"]) < 0.5 or float(data["feet_screen_y"]) > 0.95):
		errors.append("camera.json: 'feet_screen_y' must be from 0.5 to 0.95: her feet stay in the lower half of the screen")
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
	# Stairs are slopes (D120): she walks them, she does not climb walls; the
	# snap keeps her on a slope going down and never pulls her off a ledge.
	if float(data["floor_max_angle_deg"]) >= 60.0:
		errors.append("player.json: 'floor_max_angle_deg' must be below 60")
	if float(data["floor_snap_px"]) > 32.0:
		errors.append("player.json: 'floor_snap_px' must be at most 32 (half a cell)")
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
	if float(data["rewind_speed_max"]) < 1.0:
		errors.append("time.json: 'rewind_speed_max' must be at least 1")
	if float(data["rewind_ramp_delay_seconds"]) < 0.0:
		errors.append("time.json: 'rewind_ramp_delay_seconds' must be 0 or above")
	if float(data["rewind_ramp_seconds"]) <= 0.0:
		errors.append("time.json: 'rewind_ramp_seconds' must be above 0")
	if float(data["world_tempo"]) < WORLD_TEMPO_MIN or float(data["world_tempo"]) > WORLD_TEMPO_MAX:
		errors.append("time.json: 'world_tempo' must be between %s and %s" % [WORLD_TEMPO_MIN, WORLD_TEMPO_MAX])
	var prelude := float(data["default_prelude_seconds"])
	if prelude < 0.0 or prelude > float(data["history_seconds"]):
		errors.append("time.json: 'default_prelude_seconds' must be between 0 and 'history_seconds'")
	return errors


static func validate_levels(data: Variant, history_seconds: float, file := "levels.json") -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Array:
		errors.append("%s: expected a list" % file)
		return errors
	if data.is_empty():
		errors.append("%s: the list must hold at least one level" % file)
		return errors
	var seen := {}
	for i in data.size():
		var entry: Variant = data[i]
		var where := "%s[%d]" % [file, i]
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
		if entry.has("rewind_speed_max") and (not _is_number(entry["rewind_speed_max"]) or float(entry["rewind_speed_max"]) < 1.0):
			errors.append("%s: 'rewind_speed_max' must be a number, 1 or more" % where)
		if entry.has("intro_seconds") and (not _is_number(entry["intro_seconds"]) \
				or float(entry["intro_seconds"]) < 0.0 or float(entry["intro_seconds"]) > 10.0):
			errors.append("%s: 'intro_seconds' must be a number from 0 to 10" % where)
		if entry.has("objects"):
			errors.append_array(_object_settings_problems(entry["objects"], where))
		if entry.has("prelude_events") and _is_number(entry["prelude_seconds"]):
			errors.append_array(_prelude_event_problems(entry["prelude_events"], float(entry["prelude_seconds"]), where))
		if entry.has("world"):
			errors.append_array(WorldData.validate_layout(entry["world"], where))
		if entry.has("quakes"):
			var world: Variant = entry.get("world", {})
			var lamps: Variant = world.get("lamps", []) if world is Dictionary else []
			errors.append_array(QuakePlan.problems(entry["quakes"], where, lamps.size() if lamps is Array else 0))
		if entry.has("collapse"):
			var collapse_world: Variant = entry.get("world", {})
			var collapse_lamps: Variant = collapse_world.get("lamps", []) if collapse_world is Dictionary else []
			errors.append_array(CollapsePlan.problems(entry["collapse"], where, collapse_lamps.size() if collapse_lamps is Array else 0))
	return errors


## Per-level object settings: `object_id -> settings`. Every `*_seconds` and a
## `speed` must be a number above 0 and `cycle` one of the door's cycles.
static func _object_settings_problems(settings: Variant, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not settings is Dictionary:
		errors.append("%s: 'objects' must be an object" % where)
		return errors
	for id: Variant in settings:
		var one: Variant = settings[id]
		if not one is Dictionary:
			errors.append("%s: 'objects.%s' must be an object" % [where, id])
			continue
		for key: Variant in one:
			var value: Variant = one[key]
			if str(key).ends_with("_seconds") and (not _is_number(value) or float(value) <= 0.0):
				errors.append("%s: 'objects.%s.%s' must be a number above 0" % [where, id, key])
			elif str(key) == "speed" and (not _is_number(value) or float(value) <= 0.0):
				errors.append("%s: 'objects.%s.speed' must be a number above 0" % [where, id])
			elif str(key) == "lifts_player" and not value is bool:
				errors.append("%s: 'objects.%s.lifts_player' must be true or false" % [where, id])
			elif str(key) == "intro_ride":
				errors.append_array(_intro_ride_problems(value, "%s: 'objects.%s.intro_ride'" % [where, id]))
			elif str(key) == "outlet_inset_px" and (not _is_number(value) or float(value) < 0.0):
				errors.append("%s: 'objects.%s.outlet_inset_px' must be a number, 0 or more" % [where, id])
			elif str(key).ends_with("_level") and (not _is_number(value) or float(value) < 0.0 or float(value) > 10000.0):
				errors.append("%s: 'objects.%s.%s' must be a number from 0 to 10000" % [where, id, key])
			elif str(key) == "start" and not value in SHUTTER_STARTS:
				errors.append("%s: 'objects.%s.start' must be one of %s" % [where, id, SHUTTER_STARTS])
			elif str(key) == "keys":
				errors.append_array(_winch_key_problems(value, "%s: 'objects.%s.keys'" % [where, id]))
			elif str(key) == "cycle" and not value in LEVEL_DOOR_CYCLES:
				errors.append("%s: 'objects.%s.cycle' must be one of %s" % [where, id, LEVEL_DOOR_CYCLES])
			# A level's own sprinkler spin-up obeys max_state_step like the one
			# of objects.json (found by the monkey, D201). 1000 is Sprinkler.FLOW_MAX.
			if str(key) == "spin_up_seconds" and _is_number(value) and float(value) > 0.0:
				var time_data := time()
				if 1000.0 / (float(value) * float(time_data["physics_ticks_per_second"])) > float(time_data["max_state_step"]):
					errors.append("%s: 'objects.%s.spin_up_seconds' is too short: the flow would jump more than max_state_step per tick" % [where, id])
	return errors


## The intro ride of a minecart (D191, level 04 session 2): true or false
## (from the park), or the intro from the hoist: `{"segment": String,
## "distance_px": number 0 or more, "hoist_after_seconds": number above 0}`.
static func _intro_ride_problems(value: Variant, where: String) -> Array[String]:
	var errors: Array[String] = []
	if value is bool:
		return errors
	if not value is Dictionary:
		errors.append("%s must be true, false or an object" % where)
		return errors
	var d := value as Dictionary
	if not d.get("segment") is String or str(d.get("segment")) == "":
		errors.append("%s.segment must name a rail segment" % where)
	if not _is_number(d.get("distance_px")) or float(d.get("distance_px")) < 0.0:
		errors.append("%s.distance_px must be a number, 0 or more" % where)
	if not _is_number(d.get("hoist_after_seconds")) or float(d.get("hoist_after_seconds")) <= 0.0:
		errors.append("%s.hoist_after_seconds must be a number above 0" % where)
	return errors


## The schedule of a winch ramp (level 03, D177): a list of at least one
## [world seconds, pose], the seconds 0 or more and rising, the pose one of
## WINCH_POSES.
static func _winch_key_problems(keys: Variant, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not keys is Array or (keys as Array).is_empty():
		errors.append("%s must be a list of [seconds, pose]" % where)
		return errors
	var last := -1.0
	for key: Variant in keys:
		if not key is Array or (key as Array).size() != 2 or not _is_number(key[0]) or float(key[0]) < 0.0 \
				or not str(key[1]) in WINCH_POSES:
			errors.append("%s: every key must be [seconds 0 or more, one of %s]" % [where, WINCH_POSES])
			continue
		if float(key[0]) <= last:
			errors.append("%s: the seconds must rise" % where)
		last = float(key[0])
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
	# Doors, platforms and water count in world seconds (D96); a window to act
	# is checked in real seconds, the seconds the player has.
	var ticks := world_ticks_per_second(time_data)
	var tempo := maxf(float(time_data.get("world_tempo", 1.0)), 0.01)
	# Lamps, wood and reverse items keep real seconds for now (D96).
	var real_ticks := float(time_data["physics_ticks_per_second"])
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
		if float(door[key]) / tempo < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'door.%s' is a window to act and must last at least %d s at 'world_tempo'" % [key, MIN_WINDOW_SECONDS])
	for key in ["open_seconds", "close_seconds"]:
		if 1000.0 / (float(door[key]) * ticks) > max_step:
			errors.append("objects.json: 'door.%s' is too short: the door would jump more than max_state_step per tick" % key)
	var platform: Dictionary = data["platform"]
	if float(platform["pause_seconds"]) / tempo < MIN_WINDOW_SECONDS:
		errors.append("objects.json: 'platform.pause_seconds' is a window to act and must last at least %d s at 'world_tempo'" % MIN_WINDOW_SECONDS)
	var step := float(platform["speed"]) / ticks
	if step > max_step:
		errors.append("objects.json: 'platform.speed' moves more than max_state_step per tick")
	# The fastest rewind (D62) moves the platform `rewind_speed_max` steps a tick.
	if step * float(time_data["rewind_speed_max"]) >= float(data["carry_margin_px"]):
		errors.append("objects.json: 'platform.speed' per tick at the fastest rewind must stay below 'carry_margin_px', or a rider reads as crushed")
	# 10000 is Water.LEVEL_MAX (core/ does not refer to objects/).
	if 10000.0 / (float(data["water"]["full_seconds"]) * ticks) > max_step:
		errors.append("objects.json: 'water.full_seconds' is too short: the level would jump more than max_state_step per tick")
	for interact_section: Variant in [["button", BUTTON_KEYS], ["lever", LEVER_KEYS], ["pipe_plug", PIPE_PLUG_KEYS], ["lamp", LAMP_KEYS], ["wood", WOOD_KEYS], ["steam", STEAM_KEYS], ["fire_look", FIRE_LOOK_KEYS], ["flamethrower", FLAMETHROWER_KEYS], ["torch", TORCH_KEYS], ["rope", ROPE_KEYS], ["winch_ramp", WINCH_RAMP_KEYS], ["cage", CAGE_KEYS], ["ramp", RAMP_KEYS], ["sprinkler", SPRINKLER_KEYS], ["exit_zone", EXIT_ZONE_KEYS], ["shutter", SHUTTER_KEYS], ["time_plate", TIME_PLATE_KEYS], ["rail_switch", RAIL_SWITCH_KEYS], ["minecart", MINECART_KEYS]]:
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
		if 1000.0 / (float(data["shutter"]["move_seconds"]) * ticks) > max_step:
			errors.append("objects.json: 'shutter.move_seconds' is too short: the shutter would jump more than max_state_step per tick")
		if 1000.0 / (float(data["rail_switch"]["move_seconds"]) * ticks) > max_step:
			errors.append("objects.json: 'rail_switch.move_seconds' is too short: the blade would jump more than max_state_step per tick")
		var cart: Dictionary = data["minecart"]
		if float(cart["seat_px"]) + float(cart["platform_width_px"]) / 2.0 > float(cart["length_px"]) / 2.0 + 0.5:
			errors.append("objects.json: 'minecart.seat_px' puts the platform past the back of the cart")
		if float(cart["creep_px"]) >= float(cart["speed_px"]):
			errors.append("objects.json: 'minecart.creep_px' must be below 'speed_px': it is the last crawl to the station's buffer")
		if float(data["lamp"]["break_seconds"]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'lamp.break_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
		var lamp: Dictionary = data["lamp"]
		# The fall is quadratic: its last tick moves the lamp twice the average step.
		if 2000.0 / (float(lamp["fall_seconds"]) * real_ticks) > max_step:
			errors.append("objects.json: 'lamp.fall_seconds' is too short: the lamp would jump more than max_state_step per tick")
		if 1000.0 / (float(lamp["shatter_seconds"]) * real_ticks) > max_step:
			errors.append("objects.json: 'lamp.shatter_seconds' is too short: the shards would jump more than max_state_step per tick")
		if float(data["wood"]["burn_seconds"]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'wood.burn_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
		# 1000 is Sprinkler.FLOW_MAX (core/ does not refer to objects/).
		if 1000.0 / (float(data["sprinkler"]["spin_up_seconds"]) * real_ticks) > max_step:
			errors.append("objects.json: 'sprinkler.spin_up_seconds' is too short: the flow would jump more than max_state_step per tick")
		if float(data["fire_look"]["glow_alpha"]) > 1.0:
			errors.append("objects.json: 'fire_look.glow_alpha' must be at most 1")
		var thrower: Dictionary = data["flamethrower"]
		for key in ["follow_px"]:
			if float(thrower[key]) > max_step:
				errors.append("objects.json: 'flamethrower.%s' moves more than max_state_step per tick" % key)
		if float(thrower["max_fall_speed"]) / real_ticks > max_step:
			errors.append("objects.json: 'flamethrower.max_fall_speed' moves more than max_state_step per tick")
		# The ramp's tip (about 4.5 cells out) swings fastest at the end of the
		# fall, twice its average step (the fall is quadratic).
		if 2.0 * 288.0 * deg_to_rad(64.0) / (float(data["ramp"]["fall_seconds"]) * ticks) > max_step:
			errors.append("objects.json: 'ramp.fall_seconds' is too short: the ramp's tip would jump more than max_state_step per tick")
		if float(data["torch"]["follow_px"]) > max_step:
			errors.append("objects.json: 'torch.follow_px' must move at most max_state_step per tick")
		if float(data["rope"]["burn_seconds"]) < MIN_WINDOW_SECONDS:
			errors.append("objects.json: 'rope.burn_seconds' is a window to act and must be at least %d s" % MIN_WINDOW_SECONDS)
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
static func validate_art(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("art.json: expected an object")
		return errors
	var palettes: Variant = data.get("palettes")
	if not palettes is Dictionary or palettes.is_empty():
		errors.append("art.json: 'palettes' must be a non-empty object")
		return errors
	if not palettes.has(data.get("active_palette", "")):
		errors.append("art.json: 'active_palette' must name one of 'palettes'")
	var mains := 0
	for name: Variant in palettes:
		var where := "art.json: palette '%s'" % name
		var palette: Variant = palettes[name]
		if not palette is Dictionary:
			errors.append("%s must be an object" % where)
			continue
		if not palette.get("title") is String:
			errors.append("%s: 'title' must be text" % where)
		if not palette.get("status") in ART_STATUSES:
			errors.append("%s: 'status' must be one of %s" % [where, ART_STATUSES])
		elif palette["status"] == "main":
			mains += 1
		if not palette.get("skin") is String or not Color.html_is_valid(palette["skin"]):
			errors.append("%s: 'skin' must be a color like \"#eac4c7\"" % where)
		var ramps: Variant = palette.get("ramps")
		if not ramps is Dictionary:
			errors.append("%s: 'ramps' must be an object" % where)
			continue
		for role in ART_ROLES:
			var ramp: Variant = ramps.get(role)
			if not ramp is Array or ramp.size() != ART_RAMP_SIZE:
				errors.append("%s: ramp '%s' must list %d colors" % [where, role, ART_RAMP_SIZE])
				continue
			for color: Variant in ramp:
				if not color is String or not Color.html_is_valid(color):
					errors.append("%s: ramp '%s' has a bad color '%s'" % [where, role, color])
	if mains != 1:
		errors.append("art.json: exactly one palette must have status 'main'")
	errors.append_array(_validate_art_material(data.get("material")))
	errors.append_array(_validate_art_perspective(data.get("perspective")))
	return errors


static func _validate_art_material(material: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not material is Dictionary:
		errors.append("art.json: 'material' must be an object")
		return errors
	for key in ART_MATERIAL_KEYS:
		var value: Variant = material.get(key)
		if not (value is float or value is int):
			errors.append("art.json: material '%s' must be a number" % key)
		elif key.ends_with("_px") and (value < 0 or value > ART_MATERIAL_MAX_PX):
			errors.append("art.json: material '%s' must be 0..%d pixels" % [key, ART_MATERIAL_MAX_PX])
		elif key.ends_with("_scale_px") and value < 1:
			errors.append("art.json: material '%s' must be at least 1 pixel" % key)
		elif not key.ends_with("_px") and (value < 0.0 or value > 1.0):
			errors.append("art.json: material '%s' must be 0..1" % key)
	for key: Variant in material:
		if not str(key) in ART_MATERIAL_KEYS:
			errors.append("art.json: unknown material key '%s'" % key)
	if errors.is_empty():
		# The shader looks for an edge across the outline and the band behind it.
		for band: Array in [["rim_px", "dust_px"], ["shadow_px", "dirt_px"], ["chip_reach_px"]]:
			var total: float = material["outline_px"]
			for key: String in band:
				total += material[key]
			if total > ART_MATERIAL_MAX_PX:
				errors.append("art.json: material outline_px + %s must be at most %d pixels" % [" + ".join(band), ART_MATERIAL_MAX_PX])
	return errors


static func _validate_art_perspective(perspective: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not perspective is Dictionary:
		errors.append("art.json: 'perspective' must be an object")
		return errors
	for key in ART_PERSPECTIVE_KEYS:
		if not (perspective.get(key) is float or perspective.get(key) is int):
			errors.append("art.json: perspective '%s' must be a number" % key)
	for key: Variant in perspective:
		if not str(key) in ART_PERSPECTIVE_KEYS:
			errors.append("art.json: unknown perspective key '%s'" % key)
	if not errors.is_empty():
		return errors
	var tile: float = perspective["tile_px"]
	if tile < 16 or tile != int(tile):
		errors.append("art.json: perspective 'tile_px' must be a whole number of at least 16")
	for key: String in ["eye_x", "eye_y"]:
		if perspective[key] < 0 or perspective[key] > 1920:
			errors.append("art.json: perspective '%s' must be a point of the screen, 0..1920" % key)
	var distance: float = perspective["distance_px"]
	if distance < 400:
		errors.append("art.json: perspective 'distance_px' must be at least 400")
	elif perspective["slab_depth_px"] <= 0 or perspective["slab_depth_px"] > distance * 0.5:
		errors.append("art.json: perspective 'slab_depth_px' must be above 0 and at most half of 'distance_px'")
	return errors


static func validate_time_hud(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("time_hud.json: expected an object")
		return errors
	for section_name: String in ["colors", "device", "rewind", "particles", "vignette", "audio"]:
		if not data.get(section_name) is Dictionary:
			errors.append("time_hud.json: missing section '%s'" % section_name)
	if not errors.is_empty():
		return errors
	var colors: Dictionary = data["colors"]
	for key: String in ["accent", "core", "edge", "glyph"]:
		if not colors.get(key) is String or not Color.html_is_valid(colors[key]):
			errors.append("time_hud.json: 'colors.%s' must be a color like \"#7FE8FF\"" % key)
	var device: Dictionary = data["device"]
	for key: String in ["glyph_height_px", "stroke_px"]:
		_check_range(errors, device, "device", key, 0.0, 1000.0, true)
	_check_range(errors, device, "device", "offset_x_px", -1000.0, 1000.0)
	_check_range(errors, device, "device", "offset_y_px", -1000.0, 1000.0)
	var rewind: Dictionary = data["rewind"]
	_check_range(errors, rewind, "rewind", "flicker_hz", 0.0, 60.0, true)
	_check_range(errors, rewind, "rewind", "flicker_depth", 0.0, 1.0)
	_check_range(errors, rewind, "rewind", "sweep_hz", 0.0, 60.0, true)
	_check_range(errors, rewind, "rewind", "fade_seconds", 0.0, 10.0, true)
	_check_range(errors, rewind, "rewind", "world_saturation", 0.0, 1.0)
	_check_range(errors, rewind, "rewind", "world_brightness", 0.0, 1.0)
	_check_range(errors, rewind, "rewind", "world_fade_seconds", 0.0, 60.0, true)
	var particles: Dictionary = data["particles"]
	_check_range(errors, particles, "particles", "count", 0.0, 32.0)
	_check_range(errors, particles, "particles", "cycle_seconds", 0.0, 60.0, true)
	_check_range(errors, particles, "particles", "spread_px", 0.0, 1000.0, true)
	_check_range(errors, particles, "particles", "size_px", 0.0, 100.0, true)
	_check_range(errors, particles, "particles", "dash_px", 0.0, 200.0, true)
	_check_range(errors, particles, "particles", "lane_px", 0.0, 200.0, true)
	var vignette: Dictionary = data["vignette"]
	_check_range(errors, vignette, "vignette", "forward", 0.0, 1.0)
	_check_range(errors, vignette, "vignette", "rewind", 0.0, 1.0)
	_check_range(errors, vignette, "vignette", "ramp_seconds", 0.0, 120.0, true)
	_check_range(errors, vignette, "vignette", "release_seconds", 0.0, 60.0, true)
	_check_range(errors, vignette, "vignette", "inner", 0.0, 2.0)
	_check_range(errors, vignette, "vignette", "inner_rewind", 0.0, 2.0)
	_check_range(errors, vignette, "vignette", "outer", 0.0, 3.0, true)
	if errors.is_empty() and float(vignette["outer"]) <= maxf(float(vignette["inner"]), float(vignette["inner_rewind"])):
		errors.append("time_hud.json: 'vignette.outer' must be above 'vignette.inner'")
	var audio: Dictionary = data["audio"]
	for key: String in ["forward", "rewind"]:
		if not audio.get(key) is String:
			errors.append("time_hud.json: 'audio.%s' must be a path or an empty string" % key)
		elif str(audio[key]) != "" and not ResourceLoader.exists(audio[key]):
			errors.append("time_hud.json: 'audio.%s' points to a missing file '%s'" % [key, audio[key]])
	var timer: Variant = data.get("world_timer")
	if not timer is Dictionary:
		errors.append("time_hud.json: missing section 'world_timer'")
		return errors
	if not timer.get("show") is bool:
		errors.append("time_hud.json: 'world_timer.show' must be true or false")
	for key: String in ["x_px", "y_px", "outline_px"]:
		_check_range(errors, timer, "world_timer", key, 0.0, 2000.0)
	_check_range(errors, timer, "world_timer", "font_px", 0.0, 200.0, true)
	_check_range(errors, timer, "world_timer", "alpha", 0.0, 1.0, true)
	for key: String in ["color", "outline"]:
		if not timer.get(key) is String or not Color.html_is_valid(timer[key]):
			errors.append("time_hud.json: 'world_timer.%s' must be a color like \"#d8d0c0\"" % key)
	return errors


## A number between `low` and `high` (`low` itself is allowed unless `above_low`).
const LOOK_PIPE_COLORS: Array[String] = ["shell", "shell_light", "empty", "water", "dash"]
const LOOK_KIT_OBJECTS := {
	"fault": ["blink_hz", "blink_on_share", "blink_dark"],
	"shutter": ["blade_region", "painted_blade_region", "stripe_region", "housing_frame_px", "brick_tint", "wheel_px", "wheel_turns", "gear_px"],
	"picture_light": ["dark", "lit_color", "lit_gain", "haze_color", "haze", "soft_px", "yellow_keep"],
	"platform": ["cap_px", "rack_px", "chain_px", "gear_px", "track_above_px", "track_below_px", "chain_below_px",
		"deck_top_px", "trolley_at", "wheel_px", "wheel_left_at", "wheel_right_at", "frame_at", "frame_gear_px",
		"frame_gear_top_at", "frame_gear_bottom_at"],
	"exit_door": ["height_px", "open_distance_px", "floor_tolerance_px", "wheel_px", "wheel_turns",
		"wheel_seconds", "out_seconds", "out_px", "slide_seconds", "rail_px", "light", "light_energy", "light_radius_px"],
	"clock": ["diameter_px", "minute_turn_seconds", "start_minutes"],
	"beacon": ["size_px", "color", "turn_seconds", "energy", "radius_px"],
	"quake": ["shake_px", "shake_seconds", "shake_hz", "swing_degrees", "fall_seconds", "shatter_seconds",
		"dust_count", "dust_seconds", "lump_px", "lamp_shards", "lamp_bounce_px", "shard_speed_px", "shard_hop_px",
		"gravity_px", "sparks", "spark_px", "shard_glint"],
	"wire": ["width_px", "color", "end_color"],
	"lever": ["base_px", "handle_px", "pivot_from_top", "angle_degrees"],
	"button": ["base_px", "cap_px", "pressed_px"],
	"crate": ["size_px"],
	"crane": ["rail_px", "rail_over_px", "cable_px", "cable_color", "sling_inset_px", "hook_eye_px", "stop_px"],
	"collapse": ["stub_px", "flange_px", "chain", "rust", "chunk", "shake_seconds", "shake_px"],
}
const LOOK_PIPE_NUMBERS: Array[String] = ["feed_width_px", "main_width_px", "wall_px", "flange_every_px", "flange_px", "dash_length_px", "dash_gap_px", "dash_speed_px"]
const LOOK_MECH_COLORS: Array[String] = ["iron", "iron_light", "iron_shadow", "iron_dark", "outline", "valve", "valve_light", "rust", "yellow"]
const LOOK_PAIRS: Array[String] = ["velocity", "velocity_jitter", "gravity", "wobble_px", "wobble_hz", "size", "burst_area"]


## Particles that run backwards and the mechanisms' colours (task Д2).
static func validate_look(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("look.json: expected an object")
		return errors
	var particles: Variant = data.get("particles")
	if not particles is Dictionary or particles.is_empty():
		errors.append("look.json: 'particles' must be a non-empty object")
	else:
		for name: Variant in particles:
			errors.append_array(_particle_problems(particles[name], "look.json: particles '%s'" % name))
	var mech: Variant = data.get("mech")
	if not mech is Dictionary:
		errors.append("look.json: 'mech' must be an object")
		return errors
	for key in LOOK_MECH_COLORS:
		if not mech.get(key) is String or not Color.html_is_valid(mech[key]):
			errors.append("look.json: 'mech.%s' must be a color like \"#4c4c53\"" % key)
	if not _is_number(mech.get("outline_px")) or float(mech["outline_px"]) <= 0.0:
		errors.append("look.json: 'mech.outline_px' must be a number above 0")
	var pipe: Variant = data.get("pipe")
	if not pipe is Dictionary:
		errors.append("look.json: 'pipe' must be an object")
		return errors
	for key in LOOK_PIPE_COLORS:
		if not pipe.get(key) is String or not Color.html_is_valid(pipe[key]):
			errors.append("look.json: 'pipe.%s' must be a color like \"#5a6068\"" % key)
	for key in LOOK_PIPE_NUMBERS:
		if not _is_number(pipe.get(key)) or float(pipe[key]) <= 0.0:
			errors.append("look.json: 'pipe.%s' must be a number above 0" % key)
	if _is_number(pipe.get("wall_px")) and _is_number(pipe.get("feed_width_px")) and 2.0 * float(pipe["wall_px"]) >= float(pipe["feed_width_px"]):
		errors.append("look.json: 'pipe.wall_px' leaves no channel inside the feed pipe")
	errors.append_array(WorldData.validate_look(data.get("world")))
	errors.append_array(validate_kit_objects(data.get("kit_objects")))
	return errors


## The objects of a level dressed from the kit (task Д4): every object of
## LOOK_KIT_OBJECTS with its keys; `*_region` are [x, y, w, h] of a picture,
## `*_at` are [x, y] (any sign), strings are colours, other numbers are
## above 0 (`start_minutes`, `soft_px`, `haze`, `yellow_keep` from 0).
static func validate_kit_objects(objects: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not objects is Dictionary:
		errors.append("look.json: 'kit_objects' must be an object")
		return errors
	for name: String in LOOK_KIT_OBJECTS:
		var one: Variant = objects.get(name)
		var where := "look.json: 'kit_objects.%s'" % name
		if not one is Dictionary:
			errors.append("%s must be an object" % where)
			continue
		for key: String in LOOK_KIT_OBJECTS[name]:
			if not one.has(key):
				errors.append("%s needs '%s'" % [where, key])
		for key: String in one:
			var value: Variant = one[key]
			if key.begins_with("_"):
				continue
			if key.ends_with("_at"):
				var at_ok: bool = value is Array and value.size() == 2
				for n: Variant in (value if value is Array else []):
					at_ok = at_ok and _is_number(n)
				if not at_ok:
					errors.append("%s: '%s' must be [x, y], two numbers" % [where, key])
			elif key.ends_with("_region"):
				var ok: bool = value is Array and value.size() == 4
				for n: Variant in (value if value is Array else []):
					ok = ok and _is_number(n) and float(n) >= 0.0
				if not ok or float(value[2]) <= 0.0 or float(value[3]) <= 0.0:
					errors.append("%s: '%s' must be [x, y, w, h] with w and h above 0" % [where, key])
			elif value is String:
				if not Color.html_is_valid(value):
					errors.append("%s: '%s' must be a color like \"#9fd0ff\"" % [where, key])
			elif not _is_number(value) or float(value) < 0.0 or (float(value) == 0.0 and not key in ["start_minutes", "soft_px", "haze", "yellow_keep"]):
				errors.append("%s: '%s' must be a number above 0" % [where, key])
	return errors


static func _particle_problems(preset: Variant, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not preset is Dictionary:
		errors.append("%s must be an object" % where)
		return errors
	if not preset.get("shape") in ParticleField.SHAPES:
		errors.append("%s: 'shape' must be one of %s" % [where, ParticleField.SHAPES])
	if not preset.get("blend") in ParticleField.BLENDS:
		errors.append("%s: 'blend' must be one of %s" % [where, ParticleField.BLENDS])
	if not preset.get("on_floor") in ParticleField.FLOORS:
		errors.append("%s: 'on_floor' must be one of %s" % [where, ParticleField.FLOORS])
	var limits := {
		"rate": [0.0, 200.0], "lifetime": [0.01, 60.0], "lifetime_jitter": [0.0, 0.95],
		"spin": [-60.0, 60.0], "stretch": [0.0, 1.0], "alpha": [0.0, 1.0],
		"fade_in": [0.0, 1.0], "fade_out": [0.0, 1.0], "burst_count": [0.0, 200.0],
		"burst_every": [0.0, 60.0],
	}
	for key: String in limits:
		var value: Variant = preset.get(key)
		if not _is_number(value) or float(value) < limits[key][0] or float(value) > limits[key][1]:
			errors.append("%s: '%s' must be a number from %s to %s" % [where, key, limits[key][0], limits[key][1]])
	if _is_number(preset.get("rate")) and _is_number(preset.get("burst_count")) \
			and float(preset["rate"]) <= 0.0 and float(preset["burst_count"]) <= 0.0:
		errors.append("%s: needs 'rate' or 'burst_count' above 0" % where)
	for key in LOOK_PAIRS:
		var pair: Variant = preset.get(key)
		if not pair is Array or pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
			errors.append("%s: '%s' must be two numbers" % [where, key])
	var size: Variant = preset.get("size")
	if size is Array and size.size() == 2 and _is_number(size[0]) and _is_number(size[1]) \
			and (float(size[0]) <= 0.0 or float(size[0]) > float(size[1])):
		errors.append("%s: 'size' must be [min, max] with 0 < min <= max" % where)
	var cone: Variant = preset.get("cone")
	if cone != null:
		if not cone is Dictionary or not _is_number(cone.get("spread")) or not _is_number(cone.get("length_px")) \
				or float(cone["spread"]) <= 0.0 or float(cone["spread"]) >= 1.5 or float(cone["length_px"]) <= 0.0:
			errors.append("%s: 'cone' must be {spread above 0 and below 1.5, length_px above 0}" % where)
	else:
		var area: Variant = preset.get("area")
		if not area is Array or area.size() != 4 or not area.all(func(v: Variant) -> bool: return _is_number(v)) \
				or float(area[2]) < 0.0 or float(area[3]) < 0.0:
			errors.append("%s: 'area' must be [x, y, width, height] with width and height at least 0" % where)
	for key in ["color", "color_end"]:
		if key == "color_end" and not preset.has(key):
			continue
		if not preset.get(key) is String or not Color.html_is_valid(preset[key]):
			errors.append("%s: '%s' must be a color like \"#ffd9a8\"" % [where, key])
	return errors


static func _check_range(errors: PackedStringArray, section: Dictionary, section_name: String, key: String, low: float, high: float, above_low := false) -> void:
	if not section.has(key) or not _is_number(section[key]):
		errors.append("time_hud.json: '%s.%s' must be a number" % [section_name, key])
		return
	var value := float(section[key])
	if value < low or value > high or (above_low and value <= low):
		errors.append("time_hud.json: '%s.%s' must be %s %s and at most %s" % [section_name, key, "above" if above_low else "at least", low, high])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
