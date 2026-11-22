extends RefCounted
## Tests of what level 01 needs (task 2.5): a door that closes once, per-level
## object settings in levels.json, the room after its prelude and the exit.

const DOOR_PATH := "res://objects/door.tscn"
const PLATFORM_PATH := "res://objects/platform.tscn"
const LEVEL_PATH := "res://levels/level_01.tscn"
const ONCE := {"cycle": "once", "hold_open_seconds": 1, "close_seconds": 5}

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_door_closes_once_and_stays_closed() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.apply_settings(ONCE)
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	check(door.open == Door.OPEN_MAX, "a door that runs once starts fully open, is %d" % door.open)
	for i in ticks - 1:
		door.simulate_tick(i)
	check(door.open == Door.OPEN_MAX, "the door stays open for hold_open_seconds, is %d" % door.open)
	var last := door.open
	var worst := 0
	for i in 5 * ticks + 1:
		door.simulate_tick(i)
		check(door.open <= last, "the door must only close, went from %d to %d" % [last, door.open])
		worst = maxi(worst, last - door.open)
		last = door.open
	check(door.open == 0, "the door is closed after close_seconds, is %d" % door.open)
	check(worst <= int(Content.time()["max_state_step"]), "the door jumps %d per tick" % worst)
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
	check(door.open == 0, "a door that runs once must never open again, is %d" % door.open)
	door.free()


func test_door_without_settings_still_loops() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	var opened := false
	for i in door.cycle_ticks() * 2:
		door.simulate_tick(i)
		opened = opened or door.open == Door.OPEN_MAX
	check(opened and not door.once, "a plain door keeps its cycle")
	door.free()


func test_platform_rides_once_and_stays() -> void:
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	platform.travel = Vector2(192, 0)
	platform.apply_settings({"cycle": "once", "speed": 96, "delay_seconds": 2})
	check(platform.once, "a platform with cycle 'once' must report it")
	var base := platform.position_at(0)
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	for i in 2 * ticks - 1:
		platform.simulate_tick(i)
	check(platform.position == base, "the platform waits at its start for delay_seconds, is at %s" % [platform.position])
	var last := platform.position
	var worst := 0.0
	for i in 2 * ticks + 1:
		platform.simulate_tick(i)
		worst = maxf(worst, platform.position.distance_to(last))
		check(platform.position.x >= last.x, "a platform that runs once must only ride forward")
		last = platform.position
	check(is_equal_approx(platform.position.x, base.x + 192.0), "the platform arrives at the end of its path, is at %s" % [platform.position])
	check(worst <= 96.0 / ticks + 0.01, "the platform moves %.2f px per tick, more than its speed" % worst)
	for i in platform.cycle_ticks() * 2:
		platform.simulate_tick(i)
	check(is_equal_approx(platform.position.x, base.x + 192.0), "a platform that runs once never comes back by itself")
	check(platform.position_at(platform.once_last_phase() - 1).x < base.x + 192.0, "the last tick before the arrival is still on the way")
	platform.free()


func test_platform_without_settings_still_loops() -> void:
	var platform: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	platform.travel = Vector2(96, 0)
	var base := platform.position_at(0)
	var went_far := false
	for i in platform.cycle_ticks() + 1:
		platform.simulate_tick(i)
		went_far = went_far or is_equal_approx(platform.position.x, base.x + 96.0)
	check(went_far and not platform.once, "a plain platform keeps its round trip")
	check(platform.position.is_equal_approx(platform.position_at(1)), "after a whole cycle the platform is at the start again")
	platform.free()


func test_level_object_settings_are_checked() -> void:
	var entry := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "objects": {"door": ONCE}}
	check(Content.validate_levels([entry], 20.0).is_empty(), "good object settings must pass: %s" % [Content.validate_levels([entry], 20.0)])
	for bad: Variant in [[], {"door": 3}, {"door": {"cycle": "twice"}}, {"door": {"close_seconds": 0}}, {"door": {"close_seconds": "fast"}}, {"platform_1": {"speed": 0}}, {"platform_1": {"speed": "fast"}}, {"platform_2": {"delay_seconds": -1}}]:
		var broken := entry.duplicate(true)
		broken["objects"] = bad
		check(not Content.validate_levels([broken], 20.0).is_empty(), "object settings %s must be reported" % [bad])
	var objects: Dictionary = Content.objects().duplicate(true)
	objects.erase("exit_zone")
	check(not Content.validate_objects(objects, Content.time()).is_empty(), "objects.json without exit_zone must be reported")


func test_level_01_starts_with_the_door_half_closed_and_closing() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	check(door.open > 350 and door.open < 650, "after the prelude the door is about half closed, is %d" % door.open)
	var gap := door.travel * door.open / Door.OPEN_MAX
	check(gap < player.body_rect().size.y + 16.0, "the doorway (%.0f px) must already be too low to promise a run through" % gap)
	var before := door.open
	await _ticks(30)
	check(door.open < before, "the door keeps closing in front of the player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed 4.5 s after the start, is %d" % door.open)
	check(not bool(room.get("is_completed")), "standing still never completes the level")
	await _free(room)


func test_level_01_shift_opens_the_door_and_holds_it_open() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var player: Player = room.get_node("Player")
	await _ticks(4 * 60)
	check(door.open == 0, "the door is closed before Shift")
	var start := player.global_position
	Input.action_press("rewind")
	var last := door.open
	for i in 9 * 60:
		await _ticks(1)
		check(door.open >= last, "under Shift the door must only open, went from %d to %d" % [last, door.open])
		last = door.open
	check(door.open == Door.OPEN_MAX, "at the start of the history the door is fully open, is %d" % door.open)
	await _ticks(120)
	check(door.open == Door.OPEN_MAX, "the door stays open while Shift is held")
	check(player.global_position.distance_to(start) < 1.0, "Shift must not move the player")
	Input.action_release("rewind")
	await _ticks(8 * 60)
	check(door.open == 0, "released Shift replays the closing (rule A), door is %d" % door.open)
	await _free(room)


func test_level_01_platform_1_has_left_and_platform_2_has_started_to_sink() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var first: MovingPlatform = room.get_node("Platform1")
	var second: MovingPlatform = room.get_node("Platform2")
	# The state comes from the phase: the body's own position lags a physics step.
	var start := first.position_at(0)
	var gap := first.position_at(first.phase).x - start.x
	check(gap > 100.0 and gap < first.travel.x, "after the prelude platform 1 is on its way, %.0f px from its start" % gap)
	var sunk := second.position_at(second.phase).y - second.position_at(0).y
	check(sunk > 0.0 and sunk < 3.0 * 64.0, "after the prelude platform 2 has started to sink but is still above platform 1's level, %.0f px down" % sunk)
	var jump_reach := float(Content.player()["walk_speed"]) * 2.0 * float(Content.player()["jump_velocity"]) / float(Content.player()["gravity"])
	check(player.global_position.x < start.x - 96.0, "the hero starts left of the pit, on the ground platform 1 has left")
	check(first.travel.x + 192.0 > jump_reach, "the pit is wider than a jump (%.0f px), so the platform is needed" % jump_reach)
	await _free(room)


## Platform 2 passes the level of platform 1's end at the very tick platform 1
## arrives there, right beside it, and sinks on past it: the player has nothing
## to wait for and sees the way up leave (task 3.2, 16.11.2026).
func test_level_01_platform_2_is_level_with_platform_1_when_it_arrives() -> void:
	var room := await _load()
	var first: MovingPlatform = room.get_node("Platform1")
	var second: MovingPlatform = room.get_node("Platform2")
	var arrival := first.once_last_phase()
	var first_end := first.position_at(arrival)
	var second_then := second.position_at(arrival)
	check(absf(second_then.y - first_end.y) < 1.0, "platform 2 is at y %.1f when platform 1 arrives at y %.1f" % [second_then.y, first_end.y])
	var width := float(((first.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.x)
	var between := (second_then.x - width / 2.0) - (first_end.x + width / 2.0)
	check(absf(between) < 1.0, "platform 2 stands %.1f px from the end of platform 1, it must be beside it" % between)
	var bottom := second.position_at(second.once_last_phase())
	check(bottom.y >= first_end.y + 2.0 * 64.0, "platform 2 sinks at least two cells below platform 1's level, ends at y %.0f" % bottom.y)
	check(second.position_at(arrival - 120).y < first_end.y - 64.0, "platform 2 is clearly above platform 1's level two seconds before")
	check(second.once and first.once, "both platforms of level 01 ride once")
	await _free(room)


## The level is wider than the screen and the camera may follow the hero over all
## of it (task 3.2, 16.11.2026).
func test_level_01_is_wider_than_one_screen_and_the_camera_follows() -> void:
	var room := await _load()
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := blocks.get_used_rect().size * blocks.tile_set.tile_size
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	# D112 (22.11.2026): the room was 1.5 screens wide while the world was
	# twice the heroine's size; sized to her it is a little over one screen.
	check(size.x > width and size.x <= 3 * width, "the room is %d px wide, the screen %d: it should be more than one screen, at most 3" % [size.x, width])
	check(size.y >= height and size.y < height + blocks.tile_set.tile_size.y, "the room is %d px tall, the screen %d" % [size.y, height])
	var camera: Camera2D = room.get_node("Player/Camera2D")
	check(camera.limit_right == size.x and camera.limit_left == 0, "the camera limits are %d..%d, the room is %d wide" % [camera.limit_left, camera.limit_right, size.x])
	await _free(room)


## The hero comes in from the doorway by himself: fades in, walks right, ignores
## the keys, then the level is his (task 3.2, 16.11.2026).
func test_level_01_hero_walks_in_and_then_is_free() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	var entrance := room.get_node("Entrance") as Node2D
	var frame := Rect2(entrance.position, entrance.get("size"))
	check(frame.has_point(spawn.global_position - Vector2(0, 10)), "the hero appears inside the entrance doorway")
	var entry := Content.level_for_scene(LEVEL_PATH)
	var expected := int(round(float(entry["intro_seconds"]) * float(Content.time()["physics_ticks_per_second"])))
	check(player.intro_ticks_left() > 0 and player.intro_ticks_left() <= expected, "the walk-in is running at the start, %d ticks left" % player.intro_ticks_left())
	check(player.modulate.a < 1.0, "the hero fades in")
	Input.action_press("move_left")
	await _ticks(20)
	check(player.global_position.x > spawn.global_position.x + 40.0, "during the walk-in the hero walks right whatever the keys say, x %.0f" % player.global_position.x)
	await _ticks(expected)
	Input.action_release("move_left")
	check(player.intro_ticks_left() == 0 and is_equal_approx(player.modulate.a, 1.0), "after the walk-in the hero is fully there and free")
	var after := player.global_position.x
	Input.action_press("move_left")
	await _ticks(20)
	Input.action_release("move_left")
	check(player.global_position.x < after - 40.0, "after the walk-in the keys steer the hero again")
	await _free(room)


func test_level_01_reset_brings_the_hero_in_again() -> void:
	var room := await _load()
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	await _ticks(int(round(float(Content.level_for_scene(LEVEL_PATH)["intro_seconds"]) * 60.0)) + 30)
	check(player.intro_ticks_left() == 0, "the first walk-in is over")
	room.call("restart")
	check(player.global_position.is_equal_approx(spawn.global_position) and player.intro_ticks_left() > 0, "a reset puts the hero back in the doorway and the walk-in starts again")
	await _free(room)


func test_intro_seconds_is_checked_in_levels_data() -> void:
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x", "intro_seconds": 1.5}
	check(Content.validate_levels([good], 20.0).is_empty(), "a valid intro_seconds must pass: %s" % [Content.validate_levels([good], 20.0)])
	for bad: Variant in [-1, "long", 11]:
		var entry := good.duplicate()
		entry["intro_seconds"] = bad
		check(not Content.validate_levels([entry], 20.0).is_empty(), "intro_seconds %s must be refused" % [bad])


func test_finish_level_needs_a_running_level() -> void:
	var loader := _tree.root.get_node_or_null("LevelLoader")
	check(loader != null, "LevelLoader autoload is missing")
	if loader != null:
		check(str(loader.get("current_id")).is_empty() and not bool(loader.call("finish_level")), "finish_level without a running level changes nothing")


## D82 (20.11.2026): the door and the entrance doorway are about 120 px next
## to the 94 px heroine, the door's body as tall as its doorway.
func test_level_01_door_is_about_120_px_and_she_fits_under_it() -> void:
	var room := await _load()
	var door: Door = room.get_node("Door")
	var shape := (door.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(shape.size.y >= 110.0 and shape.size.y <= 140.0, "the door is %.0f px tall, it should be about 120" % shape.size.y)
	check(is_equal_approx(door.travel, shape.size.y), "the door opens by its own height")
	var player_shape := (room.get_node("Player/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(shape.size.y > player_shape.size.y, "the hero fits under the door")
	var entrance := room.get_node("Entrance") as Node2D
	var size: Vector2 = entrance.get("size")
	check(size.y >= 110.0 and size.y <= 140.0, "the entrance is %.0f px tall" % size.y)
	await _free(room)


## D83 (20.11.2026): the level opens on the whole room, then the camera comes
## close behind the heroine; the overview key shows the room again.
func test_level_01_camera_shows_the_room_then_comes_close() -> void:
	PlayerCamera.forget_zoom()
	var room := await _load()
	var camera: PlayerCamera = room.get_node("Player/Camera2D")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := Vector2(blocks.get_used_rect().size * blocks.tile_set.tile_size)
	var screen := Vector2(int(ProjectSettings.get_setting("display/window/size/viewport_width")), int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	check(camera.overview_amount() == 1.0, "the level starts on the whole room")
	check(size.x * camera.zoom.x <= screen.x + 1.0 and size.y * camera.zoom.y <= screen.y + 1.0, "the whole room fits on the screen, zoom %.2f" % camera.zoom.x)
	var params := Content.camera()
	var per_second := float(Content.time()["physics_ticks_per_second"])
	await _ticks(int((float(params["overview_start_seconds"]) + float(params["overview_blend_seconds"])) * per_second) + 5)
	check(camera.overview_amount() == 0.0, "after the start the camera is close")
	check(is_equal_approx(camera.zoom.x, float(params["zoom"])), "close zoom is %.2f, data says %.2f" % [camera.zoom.x, float(params["zoom"])])
	Input.action_press("overview")
	await _ticks(int(float(params["overview_blend_seconds"]) * per_second) + 2)
	check(camera.overview_amount() == 1.0, "holding the overview key shows the whole room")
	Input.action_release("overview")
	await _free(room)


## In the close view her feet stand low on the screen, not in its middle,
## so the frame is not half floor (Д5.1, Boris 20.11).
func test_camera_puts_her_feet_low_on_the_screen() -> void:
	var data := Content.camera()
	var feet := float(data["feet_screen_y"])
	check(feet > 0.6, "her feet must stand below the middle of the screen, at %.2f" % feet)
	var zoom := float(data["zoom"])
	var up := CameraView.focus_height(1080.0, zoom, feet)
	var feet_on_screen := 540.0 + up * zoom
	check(absf(feet_on_screen - feet * 1080.0) < 0.5, "the camera looks %.1f px above her feet, so they stand at %.0f of 1080" % [up, feet_on_screen])
	var broken: Dictionary = data.duplicate(true)
	broken["feet_screen_y"] = 0.3
	check(not Content.validate_camera(broken).is_empty(), "feet above the middle of the screen must be reported")


## The overview is centred on the room along the side where the screen sees
## more than the room (D83).
func test_camera_overview_math() -> void:
	var room := Rect2(0, 0, 3072, 1088)
	var screen := Vector2(1920, 1080)
	var zoom := CameraView.overview_zoom(room, screen, 2.0)
	check(is_equal_approx(zoom, 0.625), "a wide room fits by its width, zoom %.3f" % zoom)
	var limits := CameraView.limits(room, screen, zoom)
	check(limits.position.x == 0 and limits.end.x == 3072, "the width stays the room's")
	check(limits.position.y < 0 and absi(limits.position.y + limits.end.y - 1088) <= 1, "the height grows evenly on both ends")
	check(CameraView.limits(room, screen, 2.0) == Rect2i(room), "close up the limits are the room")
	check(is_equal_approx(CameraView.overview_zoom(Rect2(0, 0, 800, 400), screen, 2.0), 2.0), "a small room is never shown closer than the close view")
	check(is_equal_approx(CameraView.blend_zoom(2.0, 0.5, 0.5), 1.0), "half way the zoom is even in scale")
	check(not Content.validate_camera({}).is_empty() and Content.validate_camera({}).size() == Content.CAMERA_KEYS.size(), "an empty camera.json must report every key")
	var broken := Content.camera().duplicate()
	broken["zoom"] = 0.5
	check(not Content.validate_camera(broken).is_empty(), "a close zoom below 1 must be reported")
	broken = Content.camera().duplicate()
	broken["zoom_max"] = float(broken["zoom"]) - 0.5
	check(not Content.validate_camera(broken).is_empty(), "a closest view nearer than the start zoom must be reported")
	broken = Content.camera().duplicate()
	broken["zoom_step"] = 1.0
	check(not Content.validate_camera(broken).is_empty(), "a wheel step that does not change the zoom must be reported")


## D95 (21.11.2026): a wheel step multiplies the zoom, which stays between the
## whole room and the closest view; the camera slides to it evenly.
func test_camera_wheel_zoom_math() -> void:
	check(is_equal_approx(CameraView.step_zoom(2.0, 1.0, 0.6, 3.0, 1.2), 2.4), "one step in multiplies by the step")
	check(is_equal_approx(CameraView.step_zoom(2.4, -1.0, 0.6, 3.0, 1.2), 2.0), "one step out undoes it")
	check(is_equal_approx(CameraView.step_zoom(2.9, 3.0, 0.6, 3.0, 1.2), 3.0), "never closer than the closest view")
	check(is_equal_approx(CameraView.step_zoom(0.7, -3.0, 0.6, 3.0, 1.2), 0.6), "never farther than the whole room")
	check(is_equal_approx(CameraView.step_zoom(2.0, -5.0, 4.0, 3.0, 1.2), 3.0), "a room smaller than the closest view keeps the closest view")
	var z := 1.0
	for i in 60:
		var next := CameraView.ease_zoom(z, 3.0, 10.0, 1.0 / 60.0)
		check(next >= z and next <= 3.0, "the zoom slides towards the chosen one without overshooting")
		z = next
	check(absf(z - 3.0) < 0.01, "after a second it is there, %.3f" % z)


## D95: the mouse wheel moves the close view between the whole room and
## zoom_max, and the next level starts at the chosen zoom.
func test_level_01_wheel_zooms_and_is_remembered() -> void:
	PlayerCamera.forget_zoom()
	var params := Content.camera()
	var per_second := float(Content.time()["physics_ticks_per_second"])
	var room := await _load()
	var camera: PlayerCamera = room.get_node("Player/Camera2D")
	check(is_equal_approx(camera.chosen_zoom(), float(params["zoom"])), "the level starts at the data zoom")
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	check(camera.overview_amount() == 1.0 and is_equal_approx(camera.chosen_zoom(), float(params["zoom"]) * float(params["zoom_step"])), "one wheel step up comes one step closer, %.2f" % camera.chosen_zoom())
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(camera.chosen_zoom(), float(params["zoom_max"])), "the wheel stops at zoom_max")
	await _ticks(int((float(params["overview_blend_seconds"]) + 1.0) * per_second))
	check(camera.overview_amount() == 0.0, "the wheel ends the start overview")
	check(absf(camera.zoom.x - float(params["zoom_max"])) < 0.01, "the camera has slid to the chosen zoom, %.2f" % camera.zoom.x)
	for i in 60:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(camera.chosen_zoom(), camera.far_zoom()) and camera.far_zoom() < 1.0, "the wheel stops at the whole room, %.2f" % camera.chosen_zoom())
	await _ticks(int(per_second))
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := Vector2(blocks.get_used_rect().size * blocks.tile_set.tile_size)
	check(size.x * camera.zoom.x <= 1921.0 and size.y * camera.zoom.y <= 1081.0, "zoomed all the way out the whole room is on the screen")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_EQUAL
	key.pressed = true
	_tree.root.push_input(key)
	var chosen := camera.chosen_zoom()
	check(chosen > camera.far_zoom(), "the = key comes closer too")
	await _free(room)
	room = await _load()
	camera = room.get_node("Player/Camera2D")
	check(is_equal_approx(camera.chosen_zoom(), chosen), "the next level starts at the chosen zoom, %.2f, not the data's" % camera.chosen_zoom())
	await _free(room)
	PlayerCamera.forget_zoom()


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	_tree.root.push_input(event)


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame
	_reset_time()


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame


func _reset_time() -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
