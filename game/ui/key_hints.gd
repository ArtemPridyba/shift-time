class_name KeyHints
extends CanvasLayer
## The key hints of a room (task 4.3, M1). RoomTime adds one to every room
## with a player, so no level scene needs it:
## - a small key cap «E» comes up over the interaction point the heroine can
##   use now (button, lever, valve, a thing to pick up or put in) and fades
##   when she walks off; while she holds a jet item, «F» over her;
## - the wall stencils of the level (`stencils` of `data/controls.json`): almost
##   invisible, they light up while she stands in their zone.
## Signal yellow, never the time colour (D60). Above the darkness (layer 50),
## below the pause (90): the hint stays readable in a dark room.

const LAYER := 60

## The action the cap shows now ("" when hidden) and its alpha, for tests.
var shown_action := ""
var alpha := 0.0

var _data: Dictionary = {}
var _hint: Dictionary = {}
var _names: Dictionary = {}
var _cap: KeyCap
var _stencils: Array[Stencil] = []


func _init() -> void:
	layer = LAYER
	follow_viewport_enabled = true


func _ready() -> void:
	_data = ControlsData.load_data()
	_hint = _data.get("hint", {}) as Dictionary
	_names = _data.get("key_names", {}) as Dictionary
	_cap = KeyCap.new()
	_cap.name = "KeyCap"
	_cap.setup(_hint)
	_cap.modulate.a = 0.0
	add_child(_cap)
	var room := _room()
	if room == null:
		return
	var level := Content.level_for_scene(room.scene_file_path)
	var look := _data.get("stencil", {}) as Dictionary
	for entry: Variant in ControlsData.stencils_for(_data, str(level.get("id", ""))):
		var stencil := Stencil.new()
		stencil.name = "Stencil%d" % _stencils.size()
		stencil.setup(entry as Dictionary, look, _names, room)
		add_child(stencil)
		_stencils.append(stencil)


func _process(delta: float) -> void:
	var player := _player()
	var room_time := get_parent()
	if player == null or room_time == null or not room_time.has_method("interaction_candidates"):
		_show("", Vector2.ZERO, delta)
		return
	var pos := player.global_position
	var candidates: Array = room_time.call("interaction_candidates")
	var target := InteractionSystem.hint_target(pos, candidates)
	if not target.is_empty() and _would_change(target.get("node") as Node, room_time):
		_show("interact", target.get("position", pos) as Vector2, delta)
	else:
		var held := _held_action(candidates)
		_show(held, pos, delta)
	for stencil in _stencils:
		stencil.update(pos, delta)


## The stencils, for tests.
func stencils() -> Array[Stencil]:
	return _stencils


func _show(action: String, at: Vector2, delta: float) -> void:
	var on := not action.is_empty()
	if on:
		if action != shown_action:
			_cap.set_label(KeyNames.primary(action, _names))
		shown_action = action
		_cap.global_position = at - Vector2(0, float(_hint.get("offset_px", 72)))
	alpha = InteractionSystem.fade(alpha, on, delta, float(_hint.get("fade_in_seconds", 0.15)), float(_hint.get("fade_out_seconds", 0.35)))
	if alpha <= 0.0:
		shown_action = ""
	_cap.modulate.a = alpha


## Only a point that would do something now gets the hint (a pressed
## one-way button stays dark).
func _would_change(node: Node, room_time: Node) -> bool:
	if node == null or not node.has_method("get_interaction_change"):
		return false
	var changes: Variant = node.call("get_interaction_change", room_time.call("temporal_objects"))
	return changes is Array and not (changes as Array).is_empty()


## The action of an item in the hands that has one of its own (the jet: F).
func _held_action(candidates: Array) -> String:
	for c: Variant in candidates:
		var node := (c as Dictionary).get("node") as Node
		if bool((c as Dictionary).get("fallback", false)) and node != null and node.has_method("held_action"):
			return str(node.call("held_action"))
	return ""


func _player() -> Node2D:
	var room_time := get_parent()
	if room_time == null:
		return null
	var path: Variant = room_time.get("player_path")
	if not path is NodePath or (path as NodePath).is_empty():
		return null
	return room_time.get_node_or_null(path as NodePath) as Node2D


func _room() -> Node:
	var room_time := get_parent()
	return room_time.get_parent() if room_time != null else null


## A key cap: a rounded face with the key's name.
class KeyCap extends Node2D:
	var label := ""
	var _height := 34.0
	var _font_px := 22
	var _color := Color("#e0b02a")
	var _fill := Color(0.08, 0.07, 0.06, 0.8)

	func setup(hint: Dictionary) -> void:
		_height = float(hint.get("height_px", 34))
		_font_px = int(hint.get("font_px", 22))
		_color = Color(str(hint.get("color", "#e0b02a")))
		_fill = Color(str(hint.get("fill", "#141210d0")))

	func set_label(text: String) -> void:
		label = text
		queue_redraw()

	func _draw() -> void:
		if label.is_empty():
			return
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_px)
		var width := maxf(_height, text_size.x + _height * 0.6)
		var rect := Rect2(-width / 2.0, -_height / 2.0, width, _height)
		var box := StyleBoxFlat.new()
		box.bg_color = _fill
		box.border_color = _color
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(_height * 0.2))
		box.border_width_bottom = 4
		draw_style_box(box, rect)
		var base := Vector2(-text_size.x / 2.0, font.get_ascent(_font_px) - text_size.y / 2.0 - 1.0)
		draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_px, _color)


## A stencil painted on the wall: lines of capitals, the first bigger.
class Stencil extends Node2D:
	var lines := PackedStringArray()
	var zone := Rect2()
	var lit := 0.0
	var _dim := 0.1
	var _lit_alpha := 0.75
	var _fade := 0.6
	var _font_px := 34
	var _scale := 0.6
	var _color := Color("#d8cfbc")

	func setup(entry: Dictionary, look: Dictionary, names: Dictionary, room: Node) -> void:
		for line: Variant in entry.get("text", []):
			lines.append(KeyNames.format(str(line), names, true))
		var p: Array = entry.get("position", [0, 0])
		var z: Array = entry.get("zone", [0, 0, 1, 1])
		var to_global := (room as Node2D).global_transform if room is Node2D else Transform2D.IDENTITY
		position = to_global * Vector2(float(p[0]), float(p[1]))
		zone = to_global * Rect2(float(z[0]), float(z[1]), float(z[2]), float(z[3]))
		_dim = float(look.get("dim_alpha", 0.1))
		_lit_alpha = float(look.get("lit_alpha", 0.75))
		_fade = float(look.get("fade_seconds", 0.6))
		_font_px = int(look.get("font_px", 34))
		_scale = float(look.get("line_scale", 0.6))
		_color = Color(str(look.get("color", "#d8cfbc")))
		_apply()

	func update(player_pos: Vector2, delta: float) -> void:
		lit = InteractionSystem.fade(lit, zone.has_point(player_pos), delta, _fade, _fade)
		_apply()

	func _apply() -> void:
		modulate.a = lerpf(_dim, _lit_alpha, lit)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var y := 0.0
		for i in lines.size():
			var size := _font_px if i == 0 else int(_font_px * _scale)
			var width := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string(font, Vector2(-width / 2.0, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, _color)
			y += size * 1.3
