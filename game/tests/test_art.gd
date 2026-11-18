extends RefCounted
## Tests of the style sheet (task Д1): palettes by role from `art.json`, the
## `Art` singleton that switches them, and the style showcase scene.
## Run by test_runner.gd.

const SHOWCASE_PATH := "res://levels/style_test.tscn"
const ACTIONS: Array[String] = ["next_palette", "rewind"]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- palettes ---------------------------------------------------------------

func test_palette_gives_shades_by_role() -> void:
	var art := Content.art()
	var p := ArtPalette.from_art(art, str(art["active_palette"]))
	check(p != null, "the active palette must load")
	if p == null:
		return
	var ramp: Array = art["palettes"][p.id]["ramps"]["steel"]
	check(p.shade("steel") == Color.from_string(ramp[ArtPalette.BASE], Color.BLACK), "shade() must default to the main colour")
	check(p.shade("steel", -3) == p.shade("steel", 0), "a shade below the ramp must clamp to the darkest")
	check(p.shade("steel", 99) == p.shade("steel", Content.ART_RAMP_SIZE - 1), "a shade above the ramp must clamp to the lightest")
	check(p.dark() == p.shade("background", 0), "the common dark is the darkest background shade")
	check(p.shade("no_such_role") == Color.MAGENTA, "a missing role must show magenta, not fail")
	check(ArtPalette.from_art(art, "no_such_palette") == null, "an unknown palette gives null")


func test_palettes_cycle_main_first() -> void:
	var art := Content.art()
	var ids := ArtPalette.ids(art)
	check(ids.size() == (art["palettes"] as Dictionary).size(), "every palette must be listed")
	if ids.is_empty():
		return
	check(art["palettes"][ids[0]]["status"] == "main", "the main palette comes first")
	var seen := {}
	var current := ids[0]
	for i in ids.size():
		seen[current] = true
		current = ArtPalette.next_id(art, current)
	check(current == ids[0] and seen.size() == ids.size(), "cycling must visit every palette and wrap around")
	check(ArtPalette.next_id(art, ids[0], -1) == ids[-1], "stepping back from the first gives the last")
	check(ArtPalette.next_id(art, "unknown") == ids[0], "an unknown palette starts from the first")


func test_art_singleton_switches_and_resets() -> void:
	var art_node := _tree.root.get_node("Art")
	var active := str(Content.art()["active_palette"])
	check(art_node.palette.id == active, "Art must start from active_palette")
	var heard: Array[String] = []
	var listener := func(p: ArtPalette) -> void: heard.append(p.id)
	art_node.palette_changed.connect(listener)
	art_node.cycle()
	check(art_node.palette.id != active and heard.size() == 1, "cycle() must switch and tell once")
	check(not art_node.use_palette("no_such_palette"), "an unknown palette must be refused")
	art_node.reset()
	check(art_node.palette.id == active and heard.size() == 2, "reset() must go back to active_palette")
	art_node.use_palette(active)
	check(heard.size() == 2, "switching to the palette in use must not tell")
	art_node.palette_changed.disconnect(listener)


func test_material_numbers_are_checked() -> void:
	var art := Content.art()
	check(Content.art_material().size() == Content.ART_MATERIAL_KEYS.size(), "art.json must give every material number")
	var cases := {
		"a missing material": func(a: Dictionary) -> void: a.erase("material"),
		"a missing number": func(a: Dictionary) -> void: a["material"].erase("rim_px"),
		"a number as text": func(a: Dictionary) -> void: a["material"]["dust_px"] = "4",
		"a negative size": func(a: Dictionary) -> void: a["material"]["outline_px"] = -1,
		"a size past the shader's reach": func(a: Dictionary) -> void: a["material"]["dirt_px"] = Content.ART_MATERIAL_MAX_PX + 1,
		"bands past the shader's reach": func(a: Dictionary) -> void: a["material"]["shadow_px"] = Content.ART_MATERIAL_MAX_PX - a["material"]["outline_px"],
		"a zero noise scale": func(a: Dictionary) -> void: a["material"]["chip_scale_px"] = 0,
		"a share above 1": func(a: Dictionary) -> void: a["material"]["chip_density"] = 1.5,
		"an unknown key": func(a: Dictionary) -> void: a["material"]["glow"] = 1,
	}
	for name: String in cases:
		var broken: Dictionary = art.duplicate(true)
		(cases[name] as Callable).call(broken)
		check(not Content.validate_art(broken).is_empty(), "%s must be reported" % name)


func test_material_shader_has_every_number() -> void:
	var code := (load("res://art/style/material.gdshader") as Shader).code
	for key in Content.ART_MATERIAL_KEYS:
		check(code.contains("uniform float %s" % key), "material.gdshader must have the uniform '%s'" % key)
	check(code.contains("MAX_STEPS = %d" % Content.ART_MATERIAL_MAX_PX), "the shader's reach must match ART_MATERIAL_MAX_PX")


# --- slabs ------------------------------------------------------------------

func test_perspective_numbers_are_checked() -> void:
	var art := Content.art()
	check(Content.art_perspective().size() == Content.ART_PERSPECTIVE_KEYS.size(), "art.json must give every perspective number")
	var cases := {
		"a missing perspective": func(a: Dictionary) -> void: a.erase("perspective"),
		"a missing number": func(a: Dictionary) -> void: a["perspective"].erase("top_face_px"),
		"a number as text": func(a: Dictionary) -> void: a["perspective"]["tile_px"] = "64",
		"a face over half a tile": func(a: Dictionary) -> void: a["perspective"]["top_face_px"] = 40,
		"a fractional face": func(a: Dictionary) -> void: a["perspective"]["top_face_px"] = 15.5,
		"feet past the face": func(a: Dictionary) -> void: a["perspective"]["feet_on_face"] = 1.2,
		"an unknown key": func(a: Dictionary) -> void: a["perspective"]["tilt"] = 1,
	}
	for name: String in cases:
		var broken: Dictionary = art.duplicate(true)
		(cases[name] as Callable).call(broken)
		check(not Content.validate_art(broken).is_empty(), "%s must be reported" % name)


func test_slab_draws_the_top_face_around_the_collision_line() -> void:
	var face := StyleSlab.face_px()
	var above := StyleSlab.face_above_px()
	check(face == int(Content.art_perspective()["top_face_px"]), "the top face must come from art.json")
	check(above == int(round(face * float(Content.art_perspective()["feet_on_face"]))), "the feet must stand where art.json says")
	for kind in StyleSlab.KINDS:
		var slab := StyleSlab.new()
		slab.kind = kind
		slab.size = Vector2(192, 48)
		slab.open_left = true
		slab.position = Vector2(100, 500)
		var drawn := slab.drawn_rect()
		check(slab.texture != null, "a %s slab must have a mask" % kind)
		if slab.texture != null:
			check(Vector2(slab.texture.get_size()) == drawn.size, "the %s mask must be the drawn size" % kind)
		check(is_equal_approx(drawn.position.y, 500.0 - above), "a %s must draw its top face above the collision line" % kind)
		check(drawn.position.x == 100.0 and drawn.size.x == 192.0, "a %s must keep the collision width" % kind)
		var below := face - above if kind == "wall" else 0
		check(is_equal_approx(drawn.end.y, 548.0 + below), "a %s must end at its collision bottom%s" % [kind, " and the floor's front edge" if below else ""])
		check(slab.position == Vector2(100, 500) and slab.size == Vector2(192, 48), "a slab must not change its collision rectangle")
		slab.free()


# --- the showcase -----------------------------------------------------------

func test_showcase_switches_palettes_and_rewinds() -> void:
	var art_node := _tree.root.get_node("Art")
	var active := str(Content.art()["active_palette"])
	var showcase: Node = (load(SHOWCASE_PATH) as PackedScene).instantiate()
	_tree.root.add_child(showcase)
	await _ticks(30)
	var tau_before: float = showcase.get("tau")
	check(tau_before > 0.4, "showcase time must run forward")
	Input.action_press("next_palette")
	await _ticks(2)
	Input.action_release("next_palette")
	check(art_node.palette.id == ArtPalette.next_id(Content.art(), active), "P must switch to the next palette once")
	Input.action_press("rewind")
	await _ticks(10)
	var tau_rewound: float = showcase.get("tau")
	check(tau_rewound < tau_before, "under Shift the showcase time must run back")
	await _ticks(60)
	check(is_zero_approx(showcase.get("tau")), "showcase time must stop at zero")
	_release_all()
	showcase.queue_free()
	await _tree.process_frame
	check(art_node.palette.id == active, "leaving the showcase must restore active_palette")
	check(Content.level_for_scene(SHOWCASE_PATH).is_empty(), "the showcase must not be a level")


func _release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
