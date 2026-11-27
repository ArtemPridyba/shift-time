extends RefCounted
## Tests of level 07 «Plates» (card docs/levels/07.md, D190–D192): the time
## plates of level 04 as a puzzle on one screen. Plate A and shutter A teach
## the step: in normal time it keeps the shutter closed, with Shift held it
## opens it once time runs forward. Then the same rule under the wheels: plate
## B lies at the buffer of the dead end and pulls switch B; the cart's wheels
## press it in the direction of time she holds. At the start the empty cart
## rides by itself into the dead end and comes back (the intro ride), and a
## barrier keeps her out of the shaft while the cart is away. The solutions in
## tests/solutions/level_07*.json play the level.

const LEVEL_PATH := "res://levels/level_07.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _objects(room: Node) -> Dictionary:
	var objects := {}
	for node in room.find_children("*", "", true, false):
		if node.get("object_id") != null:
			objects[str(node.get("object_id"))] = node
	return objects


func _free(room: Node) -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	room.queue_free()
	await _tree.process_frame


func test_data_check_knows_the_intro_ride() -> void:
	check(Content._object_settings_problems({"minecart": {"intro_ride": true}}, "x").is_empty(), "'intro_ride': true is valid level data")
	check(not Content._object_settings_problems({"minecart": {"intro_ride": 1}}, "x").is_empty(), "'intro_ride' must be true or false")


func test_level_fits_one_screen_with_the_lesson_the_dead_end_plate_and_the_cart() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var blocks := room.get_node("Blocks") as TileMapLayer
	var used := blocks.get_used_rect()
	check(used.size == Vector2i(30, 17), "level 07 is one screen of 30x17 cells, is %s" % used.size)
	var objects := _objects(room)
	check(objects.has("shutter_a") and (objects["shutter_a"] as Shutter).closed == Shutter.CLOSED_MAX, "shutter A starts closed")
	check(objects.has("switch_b") and not (objects["switch_b"] as RailSwitch).leads_main(), "switch B starts towards the dead end")
	var plates := room.find_children("*", "TimePlate", true, false)
	check(plates.size() == 2, "level 07 has plates A and B, has %d" % plates.size())
	for plate: Node in plates:
		for id in (plate as TimePlate).target_ids:
			check(objects.has(id), "%s drives %s, which is in the level" % [(plate as TimePlate).object_id, id])
	var rails := room.get_node("Rails") as Rails
	check(rails.track().problems().is_empty(), "the rails of level 07 are whole: %s" % ", ".join(rails.track().problems()))
	# Plate B lies on the rail of the dead end, where only the wheels reach it.
	var plate_b := objects.get("plate_b") as TimePlate
	var spur := rails.track().points("spur")
	var end := spur[spur.size() - 1]
	check(plate_b != null and absf(plate_b.position.y - end.y) < 0.5, "plate B lies on the rail of the dead end")
	check(plate_b != null and plate_b.touches(Rect2(end - Vector2(70, 12), Vector2(140, 12))), "the wheels at the buffer stand on plate B")
	# With Shift held its step throws switch B to the main line.
	var to_main := false
	for change: Variant in plate_b.step_changes(-1):
		if str((change as Dictionary)["id"]) == "switch_b":
			to_main = int((change as Dictionary)["state"]["target"]) == 0
	check(to_main, "a step on plate B with Shift held sends switch B up, to the main line")
	var cart := room.get_node("Minecart") as Minecart
	check(cart.intro_ride, "the level asks for the intro ride")
	await _free(room)


func test_intro_ride_runs_the_empty_cart_into_the_dead_end_and_back() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var cart := room.get_node("Minecart") as Minecart
	var plate_b := room.get_node("PlateB") as TimePlate
	var switch := room.get_node("SwitchB") as RailSwitch
	var bumped := false
	var gate_shut_away := true
	var ticks := 0
	while ticks < 1200:
		await _tree.physics_frame
		ticks += 1
		if cart.ride.mode == CartRide.Mode.BUMPED:
			bumped = true
		if cart.ride.mode != CartRide.Mode.PARKED and not cart.gate_closed():
			gate_shut_away = false
		if bumped and cart.ride.mode == CartRide.Mode.PARKED:
			break
	check(bumped, "the empty cart rides into the dead end by itself")
	check(plate_b.mark == TimePlate.MARK_CLOSE, "its wheels pressed plate B in normal time")
	check(not switch.leads_main(), "switch B still leads into the dead end")
	check(cart.ride.mode == CartRide.Mode.PARKED and not cart.has_rider(), "the hoist brings it back to the park, empty")
	check(ticks <= 900, "the intro ride is over in 15 s, took %.1f s" % (ticks / 60.0))
	check(gate_shut_away, "the barrier stands closed while the cart is away")
	check(not cart.gate_closed(), "the barrier opens once the cart is parked")
	# A reset runs the intro again.
	(room.get_node("RoomTime") as RoomTime).reset()
	await _tree.physics_frame
	await _tree.physics_frame
	check(cart.ride.mode != CartRide.Mode.PARKED and not cart.has_rider(), "after a reset the empty cart leaves again")
	await _free(room)


func test_barrier_keeps_her_out_of_the_empty_shaft() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var cart := room.get_node("Minecart") as Minecart
	var player := room.get_node("Player") as Player
	# On the walkway left of the barrier while the empty cart is away.
	player.respawn(Vector2(cart.gate_rect.position.x - 120.0, cart.gate_rect.end.y))
	Input.action_press("move_right")
	for i in 90:
		await _tree.physics_frame
	var away := cart.ride.mode != CartRide.Mode.PARKED
	var x_stopped := player.body_rect().end.x
	Input.action_release("move_right")
	check(away, "the cart is still on its intro ride")
	check(x_stopped <= cart.gate_rect.position.x + 1.0, "she stops at the closed barrier (right edge %.0f)" % x_stopped)
	check(player.global_position.y <= cart.gate_rect.end.y + 1.0, "she stays on the walkway")
	await _free(room)
