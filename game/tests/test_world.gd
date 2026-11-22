extends RefCounted
## The world of a level (task Д3): the Night shop kit in data, darkness and
## islands of light, decoration that collides with nothing and follows world
## time.

const LEVEL_PATH := "res://levels/level_01.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_world_data_is_valid() -> void:
	var problems := WorldData.validate_look(WorldData.look())
	check(problems.is_empty(), "look.json world: %s" % ", ".join(problems))
	var layout := WorldData.layout(WorldData.entry("level_01"))
	check(not layout.is_empty(), "level_01 has a world layout")
	problems = WorldData.validate_layout(layout, "level_01")
	check(problems.is_empty(), "level_01 world: %s" % ", ".join(problems))


func test_broken_world_data_is_reported() -> void:
	var bad_kind := {"back": [{"kind": "dragon", "rect": [0, 0, 1, 1]}]}
	check(not WorldData.validate_layout(bad_kind, "x").is_empty(), "an unknown kind is reported")
	var bad_rect := {"front": [{"kind": "bricks", "rect": [0, 0, 0, 1]}]}
	check(not WorldData.validate_layout(bad_rect, "x").is_empty(), "a rect without width is reported")
	var bad_lamp := {"lamps": [{"x": 3, "drop": 0}]}
	check(not WorldData.validate_layout(bad_lamp, "x").is_empty(), "a lamp without cable is reported")
	var look := WorldData.look().duplicate(true)
	(look["colors"] as Dictionary).erase("darkness")
	check(not WorldData.validate_look(look).is_empty(), "a missing colour is reported")
	look = WorldData.look().duplicate(true)
	(look["textures"] as Dictionary)["brick"] = "res://nowhere.png"
	check(not WorldData.validate_look(look).is_empty(), "a picture that does not exist is reported")
	look = WorldData.look().duplicate(true)
	(look["lamp"] as Dictionary)["radius_px"] = -5
	check(not WorldData.validate_look(look).is_empty(), "a lamp radius below the range is reported")
	look = WorldData.look().duplicate(true)
	look["masonry_px"] = [48, 16]
	check(not WorldData.validate_look(look).is_empty(), "a masonry block that does not divide its 256 px tile is reported")
	look = WorldData.look().duplicate(true)
	look.erase("concrete_px")
	check(not WorldData.validate_look(look).is_empty(), "a missing concrete block size is reported")


func test_lamp_flicker_is_a_formula_of_world_time() -> void:
	var lamp: Dictionary = WorldData.look()["lamp"]
	var energy := float(lamp["energy"])
	var low := energy * (1.0 - float(lamp["flicker"]))
	var seen := {}
	for i in 600:
		var seconds := float(i) / 60.0
		var e := WorldData.lamp_energy(lamp, 1, seconds)
		check(e >= low - 0.0001 and e <= energy + 0.0001, "the energy %.3f stays within %.3f..%.3f" % [e, low, energy])
		check(is_equal_approx(e, WorldData.lamp_energy(lamp, 1, seconds)), "the same moment gives the same energy")
		seen[snappedf(e, 0.01)] = true
	check(seen.size() > 3, "the lamp flickers at all")
	check(not is_equal_approx(WorldData.lamp_energy(lamp, 0, 1.0), WorldData.lamp_energy(lamp, 1, 1.0)), "lamps do not flicker in step")


func test_level_01_world_collides_with_nothing_and_hides_the_blockout() -> void:
	var room := await _load()
	for name in ["WorldBack", "WorldGround", "WorldLight"]:
		var node := room.get_node_or_null(name)
		check(node != null, "level 01 has %s" % name)
		if node != null:
			check(_bodies(node) == 0, "%s holds no collision" % name)
	var blocks := room.get_node("Blocks") as TileMapLayer
	check(not blocks.visible, "the blockout tiles are hidden, the world draws the room")
	check(blocks.collision_enabled, "the blockout tiles still collide")
	await _free(room)


func test_level_01_is_dark_with_islands_of_light() -> void:
	var room := await _load()
	var light := room.get_node("WorldLight") as WorldLight
	var dark := light.get_node_or_null("Darkness") as CanvasModulate
	check(dark != null and dark.color.get_luminance() < 0.35, "the room is dark")
	var lamps: Array = WorldData.layout(WorldData.entry("level_01"))["lamps"]
	check(light.lights.size() == lamps.size() and lamps.size() >= 5, "a light for every lamp, at least 5: %d" % light.lights.size())
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	for a in light.lights:
		var near := 0
		for b in light.lights:
			if absf(b.position.x - a.position.x) < width / 2.0:
				near += 1
		check(near <= 6, "at most 6 lights on a screen for the web build, %d near x %d" % [near, a.position.x])
	var player := room.get_node("Player") as Node2D
	var own := player.get_node_or_null("OwnLight") as PointLight2D
	check(own != null and own.range_item_cull_mask == WorldLight.HEROINE_MASK, "her own light lights only her")
	await _free(room)


func test_level_01_lamps_flicker_back_under_shift() -> void:
	var room := await _load()
	var light := room.get_node("WorldLight") as WorldLight
	light.on_world_tick(120, true)
	var before := light.lights[2].energy
	light.on_world_tick(260, true)
	var later := light.lights[2].energy
	light.on_world_tick(120, false)
	check(is_equal_approx(light.lights[2].energy, before), "back at the same world tick, the lamp shines the same")
	check(not is_equal_approx(before, later), "the lamp changes over time")
	await _free(room)


func _bodies(node: Node) -> int:
	var count := 1 if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D else 0
	for child in node.get_children():
		count += _bodies(child)
	return count


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	room.queue_free()
	await _tree.process_frame
	_reset_time()


func _reset_time() -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
