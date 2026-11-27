class_name ControlsData
extends RefCounted
## The key hints, the controls list of the pause, the key line of the main
## menu and the wall stencils (`data/controls.json`, task 4.3, M1). Plain data
## and its check; the names of the keys come from `KeyNames` (ui/).

const PATH := "res://data/controls.json"
const HINT_KEYS: Array[String] = ["offset_px", "above_player_px", "height_px", "font_px", "fade_in_seconds", "fade_out_seconds"]
const STENCIL_KEYS: Array[String] = ["fade_seconds", "font_px", "line_scale"]
const TEXT_KEYS: Array[String] = ["menu_line", "controls_title", "volume"]


static func load_data() -> Dictionary:
	var data: Variant = Content.load_json(PATH)
	return data if data is Dictionary else {}


## The stencils of one level (an empty list for a level without any).
static func stencils_for(data: Dictionary, level_id: String) -> Array:
	var all: Variant = data.get("stencils", {})
	if not all is Dictionary:
		return []
	var list: Variant = (all as Dictionary).get(level_id, [])
	return list if list is Array else []


## The action names a text refers to with `{name}` or `{name+}`.
static func placeholders(text: String) -> PackedStringArray:
	var names := PackedStringArray()
	var regex := RegEx.create_from_string("\\{([a-z_0-9]+)\\+?\\}")
	for found in regex.search_all(text):
		names.append(found.get_string(1))
	return names


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("controls.json: expected an object")
		return errors
	var d := data as Dictionary
	for key in TEXT_KEYS:
		if not d.get(key) is String or str(d[key]).is_empty():
			errors.append("controls.json: '%s' must be a non-empty text" % key)
		else:
			_check_actions(errors, str(d[key]), key)
	var names: Variant = d.get("key_names")
	if not names is Dictionary:
		errors.append("controls.json: 'key_names' must be an object")
	else:
		for value: Variant in (names as Dictionary).values():
			if not value is String or str(value).is_empty():
				errors.append("controls.json: every 'key_names' entry must be a non-empty text")
	var volume: Variant = d.get("default_volume")
	if not Content._is_number(volume) or float(volume) < 0.0 or float(volume) > 1.0:
		errors.append("controls.json: 'default_volume' must be a number from 0 to 1")
	_check_section(errors, d.get("hint"), "hint", HINT_KEYS, ["color", "fill"])
	_check_section(errors, d.get("stencil"), "stencil", STENCIL_KEYS, ["color"])
	var stencil: Variant = d.get("stencil")
	if stencil is Dictionary:
		for key in ["dim_alpha", "lit_alpha"]:
			var value: Variant = (stencil as Dictionary).get(key)
			if not Content._is_number(value) or float(value) < 0.0 or float(value) > 1.0:
				errors.append("controls.json: 'stencil.%s' must be a number from 0 to 1" % key)
	var rows: Variant = d.get("controls")
	if not rows is Array or (rows as Array).is_empty():
		errors.append("controls.json: 'controls' must be a non-empty list")
	else:
		for row: Variant in rows:
			if not row is Dictionary or not (row as Dictionary).get("text") is String or str((row as Dictionary)["text"]).is_empty():
				errors.append("controls.json: every 'controls' row needs a non-empty 'text'")
				continue
			var most: Variant = (row as Dictionary).get("max_keys", 1)
			if not Content._is_number(most) or int(most) < 1:
				errors.append("controls.json: 'max_keys' of the row '%s' must be a whole number from 1" % (row as Dictionary)["text"])
			var actions: Variant = (row as Dictionary).get("actions")
			if not actions is Array or (actions as Array).is_empty():
				errors.append("controls.json: the row '%s' needs a list of 'actions'" % (row as Dictionary)["text"])
				continue
			for action: Variant in actions:
				if not InputMap.has_action(str(action)):
					errors.append("controls.json: the row '%s' names an unknown action '%s'" % [(row as Dictionary)["text"], action])
	var stencils: Variant = d.get("stencils")
	if not stencils is Dictionary:
		errors.append("controls.json: 'stencils' must be an object of level ids")
		return errors
	for level_id: Variant in (stencils as Dictionary).keys():
		var list: Variant = (stencils as Dictionary)[level_id]
		if not list is Array:
			errors.append("controls.json: 'stencils.%s' must be a list" % level_id)
			continue
		for entry: Variant in list:
			errors.append_array(_stencil_problems(entry, "stencils.%s" % level_id))
	return errors


static func _stencil_problems(entry: Variant, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not entry is Dictionary:
		errors.append("controls.json: every entry of '%s' must be an object" % where)
		return errors
	var e := entry as Dictionary
	var lines: Variant = e.get("text")
	if not lines is Array or (lines as Array).is_empty():
		errors.append("controls.json: a stencil of '%s' needs a list of 'text' lines" % where)
	else:
		for line: Variant in lines:
			if not line is String or str(line).is_empty():
				errors.append("controls.json: the lines of a stencil of '%s' must be texts" % where)
			else:
				_check_actions(errors, str(line), where)
	if not _is_numbers(e.get("position"), 2):
		errors.append("controls.json: a stencil of '%s' needs 'position' [x, y]" % where)
	var zone: Variant = e.get("zone")
	if not _is_numbers(zone, 4) or float((zone as Array)[2]) <= 0.0 or float((zone as Array)[3]) <= 0.0:
		errors.append("controls.json: a stencil of '%s' needs 'zone' [x, y, w, h] with w and h above 0" % where)
	return errors


static func _check_section(errors: PackedStringArray, section: Variant, section_name: String, numbers: Array[String], colors: Array) -> void:
	if not section is Dictionary:
		errors.append("controls.json: missing section '%s'" % section_name)
		return
	var s := section as Dictionary
	for key in numbers:
		if not Content._is_number(s.get(key)) or float(s[key]) <= 0.0:
			errors.append("controls.json: '%s.%s' must be a number above 0" % [section_name, key])
	for key: Variant in colors:
		if not s.get(key) is String or not Color.html_is_valid(str(s[key])):
			errors.append("controls.json: '%s.%s' must be a colour like #e0b02a" % [section_name, key])


static func _check_actions(errors: PackedStringArray, text: String, where: String) -> void:
	for action in placeholders(text):
		if not InputMap.has_action(action):
			errors.append("controls.json: '%s' names an unknown action '{%s}'" % [where, action])


static func _is_numbers(value: Variant, count: int) -> bool:
	if not value is Array or (value as Array).size() != count:
		return false
	for item: Variant in value:
		if not Content._is_number(item):
			return false
	return true
