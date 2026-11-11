extends RefCounted
## Tests of the wrist device and the time indicator (task 1.5): the data check,
## the state of the indicator tick by tick, and the real `TimeHud` in the test
## room following `TimeManager`. The direction must read from more than color:
## the arrows, the sweep, the flicker and the flight of the motes all differ.
## Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room.tscn"
const STEP := 1.0 / 60.0
const ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "interact", "rewind", "reset_level", "pause",
]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- data check -------------------------------------------------------------

func test_shipped_time_hud_data_is_valid() -> void:
	var errors := Content.validate_time_hud(Content.load_json(Content.TIME_HUD_PATH))
	check(errors.is_empty(), "the shipped time_hud.json must pass: %s" % [errors])
	check(Content.validate().is_empty(), "Content.validate() must include time_hud.json and pass: %s" % [Content.validate()])


func test_data_check_reports_broken_time_hud_data() -> void:
	var good := Content.time_hud()
	check(not Content.validate_time_hud(null).is_empty(), "a missing file must be reported")
	var no_section: Dictionary = good.duplicate(true)
	no_section.erase("edges")
	check(not Content.validate_time_hud(no_section).is_empty(), "a missing section must be reported")
	var bad_color: Dictionary = good.duplicate(true)
	bad_color["colors"]["accent"] = "cyan-ish"
	check(not Content.validate_time_hud(bad_color).is_empty(), "a broken color must be reported")
	var deep_flicker: Dictionary = good.duplicate(true)
	deep_flicker["rewind"]["flicker_depth"] = 2.0
	check(not Content.validate_time_hud(deep_flicker).is_empty(), "a flicker depth above 1 must be reported")
	var no_dash: Dictionary = good.duplicate(true)
	no_dash["particles"]["dash_px"] = 0
	check(not Content.validate_time_hud(no_dash).is_empty(), "a zero streak length must be reported")
	var no_rows: Dictionary = good.duplicate(true)
	no_rows["edges"].erase("streak_rows")
	check(not Content.validate_time_hud(no_rows).is_empty(), "a missing edge streak field must be reported")
	var no_fade: Dictionary = good.duplicate(true)
	no_fade["edges"]["fade_seconds"] = 0
	check(not Content.validate_time_hud(no_fade).is_empty(), "a zero fade time must be reported")
	var missing_sound: Dictionary = good.duplicate(true)
	missing_sound["audio"]["rewind"] = "res://audio/does_not_exist.ogg"
	check(not Content.validate_time_hud(missing_sound).is_empty(), "a sound path to a missing file must be reported")


# --- the state of the indicator ---------------------------------------------

func test_arrows_differ_by_direction() -> void:
	var state := TimeIndicatorState.new(Content.time_hud())
	check(state.glyph() == ">>", "forward time must show '>>', got '%s'" % state.glyph())
	state.set_direction(-1)
	check(state.glyph() == "<<", "rewind must show '<<', got '%s'" % state.glyph())
	state.set_direction(1)
	check(state.glyph() == ">>", "forward time must show '>>' again, got '%s'" % state.glyph())


func test_forward_glows_steadily_and_rewind_flickers() -> void:
	var state := TimeIndicatorState.new(Content.time_hud())
	var forward_low := 1.0
	for i in 120:
		state.step(STEP)
		forward_low = minf(forward_low, state.glow())
	check(is_equal_approx(forward_low, 1.0), "the glow must be steady in forward time, got a low of %f" % forward_low)
	check(state.sweep_position() < 0.0, "there is no sweep along the arrows in forward time")
	state.set_direction(-1)
	var low := 1.0
	var high := 0.0
	for i in 120:
		state.step(STEP)
		low = minf(low, state.glow())
		high = maxf(high, state.glow())
	check(high - low > 0.2, "the glow must flicker in rewind, got a range of %f" % (high - low))


func test_sweep_runs_from_right_to_left_in_rewind() -> void:
	var state := TimeIndicatorState.new(Content.time_hud())
	state.set_direction(-1)
	state.step(STEP)
	var before := state.sweep_position()
	state.step(STEP)
	var after := state.sweep_position()
	check(before >= 0.0 and after >= 0.0, "the sweep must exist in rewind")
	check(after < before, "the sweep must move leftwards in rewind: %f then %f" % [before, after])


func test_streaks_run_left_only_in_rewind() -> void:
	var state := TimeIndicatorState.new(Content.time_hud())
	check(state.streak_count() > 0, "the device must have streaks")
	check(not state.streaks_active(), "there are no streaks in forward time")
	var phase := state.particle_phase
	for i in 30:
		state.step(STEP)
	check(state.particle_phase == phase, "the streaks must not move in forward time")
	state.set_direction(-1)
	check(state.streaks_active(), "the streaks must show in rewind")
	# A streak from the middle of its path, so no step wraps it around the ends.
	var index := int(float(state.streak_count()) / 2.0)
	var before := float(state.streak(index)["progress"])
	state.step(STEP)
	var after := float(state.streak(index)["progress"])
	check(after < before, "a streak must run left in rewind: %f then %f" % [before, after])
	var lane := float(state.streak(index)["lane"])
	check(lane >= 0.0 and lane < 1.0, "a lane must stay between 0 and 1, got %f" % lane)


func test_streaks_fade_at_both_ends() -> void:
	var state := TimeIndicatorState.new(Content.time_hud())
	state.set_direction(-1)
	for i in state.streak_count():
		var streak := state.streak(i)
		var progress := float(streak["progress"])
		var alpha := float(streak["alpha"])
		check(alpha >= 0.0 and alpha <= 1.0, "a streak's opacity must stay between 0 and 1, got %f" % alpha)
		if progress < 0.05 or progress > 0.95:
			check(alpha < 0.2, "a streak near an end must be faint, got %f at %f" % [alpha, progress])


func test_edge_glow_appears_in_rewind_and_clears_after() -> void:
	var config := Content.time_hud()
	var fade := float((config["edges"] as Dictionary)["fade_seconds"])
	var state := TimeIndicatorState.new(config)
	check(state.edge_amount == 0.0, "the edge glow must be off at the start")
	state.set_direction(-1)
	var ticks := int(ceil(fade / STEP)) + 2
	for i in ticks:
		state.step(STEP)
	check(is_equal_approx(state.edge_amount, 1.0), "the edge glow must be full after the fade, got %f" % state.edge_amount)
	state.set_direction(1)
	for i in ticks:
		state.step(STEP)
	check(is_equal_approx(state.edge_amount, 0.0), "the edge glow must clear after the release, got %f" % state.edge_amount)


# --- the grey block set -------------------------------------------------------

func test_grey_block_set_loads_with_collisions() -> void:
	var tile_set := load("res://art/blocks/grey_blocks.tres") as TileSet
	check(tile_set != null, "the grey block set must load")
	if tile_set == null:
		return
	check(tile_set.tile_size == Vector2i(64, 64), "blocks must sit on the 64 px grid")
	var source := tile_set.get_source(0) as TileSetAtlasSource
	check(source != null and source.get_tiles_count() == 3, "the set must hold three blocks: block, surface, hatch")
	if source != null:
		for i in source.get_tiles_count():
			var data := source.get_tile_data(source.get_tile_id(i), 0)
			check(data.get_collision_polygons_count(0) == 1, "block %d must have a collision shape" % i)


# --- the sound place ----------------------------------------------------------

func test_empty_sound_paths_play_nothing_and_break_nothing() -> void:
	var sound := TimeSound.new(Content.time_hud())
	check(not sound.has_sound(1) and not sound.has_sound(-1), "no sound is set yet")
	check(not sound.play_for(1), "play_for must return false when there is no sound")
	check(not sound.play_for(-1), "play_for must return false when there is no sound")
	var odd := TimeSound.new({"audio": {"forward": "res://audio/missing.ogg"}})
	check(not odd.has_sound(1), "a missing file must be skipped, not crash")
	sound.free()
	odd.free()


# --- the real device in the room -------------------------------------------

func test_hud_follows_time_manager_in_the_room() -> void:
	await _settle()
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _ticks(3)
	var hud := room.get_node_or_null("Player/TimeHud") as TimeHud
	check(hud != null, "the player must carry a TimeHud")
	if hud == null:
		room.queue_free()
		await _tree.process_frame
		return
	check(room.get_node_or_null("TimeDebugLabel") == null, "the temporary label must be gone")
	check(hud.state.glyph() == ">>", "the device must show '>>' at the start, got '%s'" % hud.state.glyph())
	Input.action_press("rewind")
	await _ticks(3)
	check(hud.state.glyph() == "<<", "the device must show '<<' while Shift is held, got '%s'" % hud.state.glyph())
	check(hud.state.is_rewinding(), "the indicator must be in rewind while Shift is held")
	var phase_before := float(hud.edge_parameter("phase"))
	await _ticks(10)
	var phase_after := float(hud.edge_parameter("phase"))
	check(phase_after < phase_before, "the edge streaks must run left in rewind: phase %f then %f" % [phase_before, phase_after])
	check(float(hud.edge_parameter("amount")) > 0.0, "the edge glow must show in rewind")
	Input.action_release("rewind")
	await _ticks(3)
	check(hud.state.glyph() == ">>", "the device must return to '>>' after the release, got '%s'" % hud.state.glyph())
	room.queue_free()
	await _tree.process_frame


func test_device_stays_on_the_hero_and_flips_with_facing() -> void:
	await _settle()
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _ticks(3)
	var hud := room.get_node_or_null("Player/TimeHud") as TimeHud
	var player := room.get_node_or_null("Player") as Player
	check(hud != null and player != null, "the room must have a player with a device")
	if hud != null and player != null:
		var offset_x := float((Content.time_hud()["device"] as Dictionary)["offset_x_px"])
		await _tree.process_frame
		check(is_equal_approx(hud.position.x, offset_x * player.facing()), "the device must sit on the side the hero faces")
		Input.action_press("move_left")
		await _ticks(5)
		Input.action_release("move_left")
		await _tree.process_frame
		check(player.facing() < 0.0, "the hero must face left after walking left")
		check(is_equal_approx(hud.position.x, -offset_x), "the device must move to the left side with the hero")
	room.queue_free()
	await _tree.process_frame


# --- helpers ----------------------------------------------------------------

func _settle() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	await _ticks(3)


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
