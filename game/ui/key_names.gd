class_name KeyNames
extends RefCounted
## Names of the keys of the actions of project.godot, for the hints, the
## pause and the main menu (task 4.3): "E", "Shift", "Space or W or Up".
## Shorter names come from `key_names` of `data/controls.json`.


## All keys of an action, in the order of project.godot.
static func keys(action: String, names: Dictionary = {}) -> PackedStringArray:
	var list := PackedStringArray()
	if not InputMap.has_action(action):
		return list
	for event in InputMap.action_get_events(action):
		var label := event_name(event)
		label = str(names.get(label, label))
		if not label.is_empty() and not list.has(label):
			list.append(label)
	return list


## The first key of an action, or "" for an unknown one.
static func primary(action: String, names: Dictionary = {}) -> String:
	var list := keys(action, names)
	return list[0] if not list.is_empty() else ""


static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
			MOUSE_BUTTON_LEFT:
				return "Left click"
			MOUSE_BUTTON_RIGHT:
				return "Right click"
	return ""


## `text` with every `{action}` replaced by its first key and every
## `{action+}` by all its keys joined by " or "; `upper` writes the keys in
## capitals (the wall stencils).
static func format(text: String, names: Dictionary = {}, upper := false) -> String:
	var regex := RegEx.create_from_string("\\{([a-z_0-9]+)(\\+?)\\}")
	var result := text
	for found in regex.search_all(text):
		var action := found.get_string(1)
		var label := primary(action, names)
		if found.get_string(2) == "+":
			label = " or ".join(keys(action, names))
		if upper:
			label = label.to_upper()
		result = result.replace(found.get_string(0), label)
	return result
