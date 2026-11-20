extends RefCounted
## Tests of the heroine's doll (task Д5, D72–D77): the data check, her height
## against the 44x92 hitbox, the feet on the floor, the indicator strip in the
## time colour from data, the mirror when she turns, the run by the distance
## walked with the soles on the floor, and the doll in the player scene. Run by
## test_runner.gd.

const PLAYER_SCENE := "res://objects/player.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_shipped_heroine_data_is_valid() -> void:
	for problem in HeroineData.validate(HeroineData.load_data()):
		check(false, problem)


func test_data_check_reports_broken_heroine_data() -> void:
	var data := HeroineData.load_data()
	check(not HeroineData.validate("text").is_empty(), "non-object heroine.json must be reported")
	var broken: Dictionary = data.duplicate(true)
	broken["parts"]["head"]["parent"] = "nobody"
	check(not HeroineData.validate(broken).is_empty(), "a parent that is not a part must be reported")
	broken = data.duplicate(true)
	broken["parts"]["pelvis"]["parent"] = "shin_near"
	check(not HeroineData.validate(broken).is_empty(), "a loop of parents must be reported")
	broken = data.duplicate(true)
	broken["parts"]["head"]["texture"] = "no_such_picture"
	check(not HeroineData.validate(broken).is_empty(), "a missing picture must be reported")
	broken = data.duplicate(true)
	broken["poses"]["idle"]["angles"]["tail"] = 10
	check(not HeroineData.validate(broken).is_empty(), "a pose that turns a missing part must be reported")
	broken = data.duplicate(true)
	(broken["poses"] as Dictionary).erase("idle")
	check(not HeroineData.validate(broken).is_empty(), "a missing idle pose must be reported")
	broken = data.duplicate(true)
	broken["cable"]["to"] = ["gauntlet", 1]
	check(not HeroineData.validate(broken).is_empty(), "a cable end without x and y must be reported")
	broken = data.duplicate(true)
	broken["scale"] = 0
	check(not HeroineData.validate(broken).is_empty(), "scale 0 must be reported")


func test_idle_height_fits_the_hitbox_and_stands_on_the_floor() -> void:
	var rig := _rig()
	var box := rig.body_rect()
	# D73: 92–96 px; the bun may stand over the 92 px hitbox by up to 4 px.
	check(box.size.y >= 92.0 and box.size.y <= 96.0, "idle height must be 92–96 px, got %.1f" % box.size.y)
	check(absf(box.end.y) <= 2.0, "the soles must stand on the rig's origin, got %.1f" % box.end.y)
	rig.free()


func test_strip_is_drawn_in_the_time_colour_from_data() -> void:
	var rig := _rig()
	var accent := String((Content.time_hud()["colors"] as Dictionary)["accent"])
	check(rig.strip() != null, "the gauntlet must have the indicator strip")
	if rig.strip() != null:
		check(rig.strip().color.is_equal_approx(Color.from_string(accent, Color.BLACK)), "the strip must use the time colour of time_hud.json")
		rig.set_pose("run")
		var gauntlet := rig.joint("gauntlet").global_transform
		check(rig.strip().global_position.is_equal_approx(gauntlet.origin) and is_equal_approx(rig.strip().global_rotation, gauntlet.get_rotation()), "the strip must move with the gauntlet")
	rig.free()


func test_turning_left_mirrors_the_doll_in_place() -> void:
	var rig := _rig()
	var right := rig.body_rect()
	rig.set_facing(-1.0)
	var left := rig.body_rect()
	check(is_equal_approx(left.size.y, right.size.y), "turning must not change her height")
	check(absf(left.position.x + right.end.x) < 0.01, "turning left must mirror her around her feet")
	rig.set_facing(1.0)
	check(rig.body_rect().is_equal_approx(right), "turning back must give the same doll")
	rig.free()


func test_run_cycle_is_closed_and_starts_from_its_first_key() -> void:
	var data := HeroineData.load_data()
	var first := String((data["run"]["keys"] as Array)[0])
	var start := HeroineData.run_pose(data, 0.0)
	var end := HeroineData.run_pose(data, 0.9999)
	var again := HeroineData.run_pose(data, 1.0)
	for part: String in start["angles"]:
		check(is_equal_approx(float(start["angles"][part]), float(HeroineData.pose_angles(data, first).get(part, 0.0))), "phase 0 must be the first key, %s differs" % part)
		check(absf(float(end["angles"][part]) - float(start["angles"][part])) < 0.1, "the end of the cycle must meet its start, %s jumps" % part)
		check(is_equal_approx(float(again["angles"][part]), float(start["angles"][part])), "phase 1 must repeat phase 0")


func test_soles_stay_on_the_floor_through_the_run() -> void:
	var rig := _rig()
	var data := HeroineData.load_data()
	var scale_px := float(data["scale"])
	for i in 16:
		var phase := float(i) / 16.0
		rig.set_run_phase(phase)
		var lift := float(HeroineData.run_pose(data, phase)["lift"]) * scale_px
		check(absf(rig.sole_y() + lift) < 0.01, "at phase %.2f the lowest sole must stand on the floor (lifted by the pose's bob), got %.2f" % [phase, rig.sole_y()])
		check(rig.sole_y() <= 0.01 and rig.sole_y() > -3.0, "at phase %.2f the bob must stay within 3 px, got %.2f" % [phase, rig.sole_y()])
	rig.free()


func test_run_phase_follows_the_distance_not_the_time() -> void:
	var fast := _rig()
	var slow := _rig()
	for i in 60:
		fast.step(Vector2(360.0, 0.0), true, 1.0 / 60.0)
	for i in 120:
		slow.step(Vector2(180.0, 0.0), true, 1.0 / 60.0)
	check(fast.pose() == "run" and slow.pose() == "run", "moving on the floor she must run")
	check(is_equal_approx(fast.distance(), slow.distance()), "the same distance must give the same phase of the run, %.1f and %.1f" % [fast.distance(), slow.distance()])
	fast.step(Vector2.ZERO, true, 1.0 / 60.0)
	check(fast.pose() == "idle", "standing she must take the idle pose")
	slow.step(Vector2(360.0, 0.0), false, 1.0 / 60.0)
	check(slow.pose() != "run", "in the air she must not run")
	check(is_equal_approx(slow.distance(), 360.0), "in the air the run must not advance")
	fast.free()
	slow.free()


func test_air_blends_from_rise_to_fall_by_vertical_speed() -> void:
	var data := HeroineData.load_data()
	var reach := float(data["air"]["blend_speed_px"])
	var rise := HeroineData.air_pose(data, -reach * 2.0)
	var fall := HeroineData.air_pose(data, reach * 2.0)
	var top := HeroineData.air_pose(data, 0.0)
	for part: String in HeroineData.pose_angles(data, "jump"):
		check(is_equal_approx(float(rise["angles"][part]), float(HeroineData.pose_angles(data, "jump")[part])), "going up fast she takes the jump pose, %s differs" % part)
	for part: String in HeroineData.pose_angles(data, "fall"):
		check(is_equal_approx(float(fall["angles"][part]), float(HeroineData.pose_angles(data, "fall")[part])), "coming down fast she takes the fall pose, %s differs" % part)
	check(is_equal_approx(float(top["fall"]), 0.5), "at the top of the jump she is halfway between the poses")
	var rig := _rig()
	for i in 30:
		rig.step(Vector2(0, -700), false, 1.0 / 60.0)
	check(rig.pose() == "jump", "going up she must take the jump pose, got %s" % rig.pose())
	for i in 30:
		rig.step(Vector2(0, 700), false, 1.0 / 60.0)
	check(rig.pose() == "fall", "coming down she must take the fall pose, got %s" % rig.pose())
	rig.free()


func test_in_the_air_the_body_keeps_its_height_and_fits_the_hitbox() -> void:
	var rig := _rig()
	var idle := rig.body_rect()
	for pose in ["jump", "fall"]:
		rig.set_pose(pose)
		var box := rig.body_rect()
		check(absf(box.position.y - idle.position.y) < 6.0, "in the %s pose her head must stay near its idle height: %.1f against %.1f" % [pose, box.position.y, idle.position.y])
		check(box.end.y <= 0.5, "in the %s pose her feet must not hang below the hitbox: %.1f" % [pose, box.end.y])
		check(box.position.y >= -100.0, "in the %s pose she must not rise far over the hitbox: %.1f" % [pose, box.position.y])
	rig.free()


func test_landing_after_a_fall_plays_the_land_overlay_once() -> void:
	var data := HeroineData.load_data()
	var rig := _rig()
	for i in 20:
		rig.step(Vector2(0, 900), false, 1.0 / 60.0)
	rig.step(Vector2.ZERO, true, 1.0 / 60.0)
	check(rig.overlay() == "land", "touching down after a fall she must land, got '%s'" % rig.overlay())
	var seconds := float(data["overlays"]["land"]["seconds"])
	for i in int(ceil(seconds * 60.0)) + 1:
		rig.step(Vector2.ZERO, true, 1.0 / 60.0)
	check(rig.overlay() == "", "the landing must end after %.2f s" % seconds)
	check(absf(rig.sole_y()) < 0.01, "after landing she must stand on the floor, got %.2f" % rig.sole_y())
	var hop := _rig()
	hop.step(Vector2(0, 50), false, 1.0 / 60.0)
	hop.step(Vector2.ZERO, true, 1.0 / 60.0)
	check(hop.overlay() == "", "a step down slower than min_speed_px must not play the landing")
	rig.free()
	hop.free()


func test_press_reaches_with_the_near_arm_and_ends() -> void:
	var data := HeroineData.load_data()
	var rig := _rig()
	var rest := rig.joint("sleeve_near").rotation_degrees
	rig.play("press")
	var seconds := float(data["overlays"]["press"]["seconds"])
	var reach := 0.0
	for i in int(ceil(seconds * 60.0)) + 1:
		rig.step(Vector2.ZERO, true, 1.0 / 60.0)
		reach = minf(reach, rig.joint("sleeve_near").rotation_degrees - rest)
	check(reach < -45.0, "pressing, the near arm must swing forward, got %.1f degrees" % reach)
	check(rig.overlay() == "", "the press must end after %.2f s" % seconds)
	check(absf(rig.joint("sleeve_near").rotation_degrees - rest) < 1.0, "after the press the arm must come back")
	check(is_equal_approx(HeroineData.overlay_weight(data, "press", 0.0), 0.0), "the press must blend in, not jump")
	check(is_equal_approx(HeroineData.overlay_weight(data, "press", seconds / 2.0), 1.0), "halfway the press must be full")
	rig.free()


func test_walk_out_of_the_doorway_bows_her_and_brings_her_out_of_the_dark() -> void:
	var rig := _rig()
	var idle_torso := rig.joint("torso").rotation_degrees
	rig.set_exit(1.0)
	var dark := Color.from_string(String(HeroineData.load_data()["exit"]["dark"]), Color.BLACK)
	check(rig.modulate.is_equal_approx(dark), "stepping out of the doorway she is in the dark")
	check(rig.joint("torso").rotation_degrees > idle_torso + 5.0, "stepping out she bows through the opening")
	rig.set_exit(0.0)
	check(rig.modulate.is_equal_approx(Color.WHITE), "once out she has her own colours")
	check(is_equal_approx(rig.joint("torso").rotation_degrees, idle_torso), "once out she stands straight")
	rig.free()


func test_gauntlet_light_falls_on_her_body_from_the_strip() -> void:
	var rig := _rig()
	_tree.root.add_child(rig)
	rig.position = Vector2(100, 200)
	rig._process(0.0)
	var point: Vector2 = rig.light_parameter("light_pos")
	check(point.distance_to(rig.get_global_transform() * rig.device_point()) < 0.01, "the light must come from the strip")
	var box := rig.body_rect()
	check(box.has_point(rig.device_point()), "the strip must be on her body")
	var forward := rig.light_strength()
	rig.set_time_light(1.0, 1.0)
	rig._process(0.1)
	check(rig.light_strength() > forward * 2.0, "under Shift the light must be clearly stronger")
	check(float(rig.look_parameter("tint")) > 0.0, "under Shift her figure takes on the time colour")
	rig.queue_free()


func test_player_scene_carries_the_doll() -> void:
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_tree.root.add_child(player)
	var rig := player.get_node_or_null("Heroine") as HeroineRig
	check(rig != null, "player.tscn must carry the heroine's doll as Heroine")
	if rig != null:
		check(rig.pose() == "idle", "standing still, she must take the idle pose")
	player.free()


## D81, D84 (20.11.2026): the parts at sheet size with mipmaps, and the look
## of the whole doll from data, checked by the data check.
func test_parts_come_at_sheet_size_with_mipmaps_and_the_look_from_data() -> void:
	var data := HeroineData.load_data()
	var rig := _rig()
	var head := rig.joint("head")
	var picture: Sprite2D = null
	for child in rig.get_node("Body").get_children():
		if child.name == "Picture_head":
			picture = child
	check(picture != null, "the head's picture lies in the doll's group")
	if picture != null and bool(data.get("sheet_parts", false)):
		check(picture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "sheet-size parts are smoothed with mipmaps")
		check(picture.texture.resource_path.contains("/full/"), "sheet-size parts come from parts_dir/full")
		check(picture.global_position.is_equal_approx(head.global_position), "the picture follows its joint")
	check(rig.get_node("Body") is CanvasGroup, "the doll is one group, brightened as one picture")
	var look: Dictionary = data["look"]
	check(is_equal_approx(float(rig.look_parameter("gain")), float(look["gain"])), "the gain comes from look in heroine.json")
	var broken: Dictionary = data.duplicate(true)
	broken["look"]["gain"] = 0
	check(not HeroineData.validate(broken).is_empty(), "gain 0 must be reported")
	broken = data.duplicate(true)
	broken["sheet_parts"] = "yes"
	check(not HeroineData.validate(broken).is_empty(), "sheet_parts that is no true or false must be reported")
	rig.free()


## D80.1 (20.11.2026): under Shift motes of time spiral in from around her
## and vanish in the gauntlet, faint far away and bright near it; none in
## forward time. As the 4th heroine of the "Night shop" mock-up.
func test_motes_spiral_into_the_gauntlet_under_shift_only() -> void:
	var data := HeroineData.load_data()
	var light: Dictionary = data["light"]
	var spec: Dictionary = light["motes"]
	var list := HeroineData.motes(light)
	check(list.size() == int(spec["count"]), "%d motes, data says %d" % [list.size(), int(spec["count"])])
	check(HeroineData.motes(light) == list, "the motes are the same every run")
	var mote := list[0]
	var start := 0.05
	var before := HeroineData.mote_at(light, mote, start)
	var after := HeroineData.mote_at(light, mote, start + 0.1)
	if float(after["along"]) > float(before["along"]):
		check((after["offset"] as Vector2).length() < (before["offset"] as Vector2).length(), "a mote closes in on the gauntlet")
	for each in list:
		var spot := HeroineData.mote_at(light, each, 1.3)
		check((spot["offset"] as Vector2).length() <= float(spec["from_max_px"]) + 0.01, "no mote starts farther than from_max_px")
	var rig := _rig()
	rig.set_time_light(1.0, 0.0)
	check(rig.motes_now().is_empty() and rig.tint_strength() == 0.0, "no motes and no glow in forward time")
	rig.set_time_light(1.0, 1.0)
	check(rig.motes_now().size() == list.size() and rig.tint_strength() > 0.0, "motes and glow under Shift")
	var broken: Dictionary = data.duplicate(true)
	broken["light"]["motes"]["from_min_px"] = 500
	check(not HeroineData.validate(broken).is_empty(), "motes that start nearer than their minimum must be reported")
	broken = data.duplicate(true)
	broken["light"]["tint"] = 2
	check(not HeroineData.validate(broken).is_empty(), "tint above 1 must be reported")
	rig.free()


func _rig() -> HeroineRig:
	var rig := HeroineRig.new()
	rig.build(HeroineData.load_data())
	return rig


func test_threads_build_up_under_shift_to_a_limit() -> void:
	var spec: Dictionary = HeroineData.load_data()["light"]["threads"]
	var start := float(spec["start_seconds"])
	var top := int(spec["max"])
	check(TimeThreads.count(spec, 0.0) == 0 and TimeThreads.count(spec, start - 0.01) == 0, "no threads in the first moment of Shift: the motes come first (D86)")
	check(TimeThreads.count(spec, start) == int(spec["first"]), "the first threads come after start_seconds")
	var last := 0
	var grew := false
	for i in 400:
		var n := TimeThreads.count(spec, float(i) * 0.05)
		check(n >= last, "the threads never get fewer while Shift is held")
		grew = grew or n > last and last > 0
		last = n
	check(grew, "the longer Shift is held, the more threads")
	check(last == top, "the threads stop at max, got %d" % last)
	check(TimeThreads.count(spec, 1000.0) == top, "however long Shift is held, never more than max")
	check(TimeThreads.fade_in(spec, top - 1, start) == 0.0 and TimeThreads.fade_in(spec, 0, start + 1.0) == 1.0, "a new thread fades in, never pops")


func test_threads_come_from_beyond_the_screen_edge_thick_and_thin_out() -> void:
	var data := HeroineData.load_data()
	var spec: Dictionary = data["light"]["threads"]
	var screen := Rect2(0, 0, 1920, 1080)
	# Wherever she stands, as many threads come from the left as from the right (D85.3).
	var left := 0
	var right := 0
	for i in 12:
		for cycle in 8:
			var trip := TimeThreads.trip(spec, i, float(spec["period_seconds"]) * float(cycle) + 0.01)
			var start := TimeThreads.start_point(screen, float(trip["edge"]), 40.0)
			check(not screen.has_point(start), "thread %d must start beyond the screen edge, starts at %s" % [i, start])
			if start.x < 960.0:
				left += 1
			else:
				right += 1
	check(absi(left - right) <= 16, "threads must come evenly from both sides: %d left, %d right" % [left, right])
	for gauntlet in [Vector2(300, 700), Vector2(1600, 800), Vector2(960, 540), Vector2(120, 950)]:
		var turned := 0
		for i in 12:
			var trip := TimeThreads.trip(spec, i, 0.7 * float(i))
			var from: Vector2 = TimeThreads.start_point(screen, float(trip["edge"]), 40.0) - gauntlet
			var swirl := TimeThreads.choose_swirl(spec, from, gauntlet, screen)
			if absf(swirl) > 1.0:
				turned += 1
			check(TimeThreads.offset(spec, from, 1.0, swirl).length() < 0.001, "thread %d must end in the gauntlet" % i)
			# A whirl into the gauntlet (D85.4) that closes in and never leaves the screen once in.
			check(TimeThreads.stays_on_screen(spec, from, gauntlet, screen, swirl), "thread %d from %s must not leave the screen once it is in" % [i, from])
			check(swirl >= 0.0, "every thread whirls clockwise (D85.5)")
			var last := INF
			for s in range(1, 41):
				var at := TimeThreads.offset(spec, from, float(s) / 40.0, swirl)
				check(at.length() <= last + 0.001, "thread %d must only close in on the gauntlet" % i)
				last = at.length()
		check(turned >= 8, "most threads must whirl in, not fly straight: %d of 12 at %s" % [turned, gauntlet])
	check(is_equal_approx(TimeThreads.width_scale(spec, 0.0), float(spec["edge_scale"])), "at the screen edge a thread is edge_scale times wider")
	check(TimeThreads.width_px(spec, 0.0) >= 40.0, "at the screen edge a thread is really wide (D85.5), got %.1f px" % TimeThreads.width_px(spec, 0.0))
	check(is_equal_approx(TimeThreads.width_scale(spec, 1.0), 1.0), "near the gauntlet a thread has its normal width")
	check(TimeThreads.width_scale(spec, 0.3) < TimeThreads.width_scale(spec, 0.1), "a thread narrows on its way in")
	check(TimeThreads.alpha(spec, 0.0, 0.5, 1.0) < TimeThreads.alpha(spec, 0.8, 0.5, 1.0) * 0.5, "a thread is nearly clear at the edge and bright near the gauntlet")
	check(TimeThreads.sharpness(spec, 0.0) == 0.0 and TimeThreads.sharpness(spec, 1.0) == 1.0, "a thread is soft at the edge and sharp near the gauntlet")
	var trail := TimeThreads.trail(spec, Vector2(800, 0), 0.5, 2.0)
	check(trail.size() == int(spec["segments"]) + 1, "a trail has segments + 1 points")
	check(TimeThreads.alpha(spec, 0.5, 0.5, 1.0) > TimeThreads.alpha(spec, 0.5, 0.5, 0.2), "a thread fades toward its tail")
	check(TimeThreads.alpha(spec, 1.0, 1.0, 1.0) < 0.01, "a thread is gone once it enters the gauntlet")
	var broken: Dictionary = data.duplicate(true)
	broken["light"]["threads"]["max"] = 0
	check(not HeroineData.validate(broken).is_empty(), "no threads at all must be reported")
	broken = data.duplicate(true)
	broken["light"]["threads"]["travel_seconds"] = 10
	check(not HeroineData.validate(broken).is_empty(), "a trip longer than its period must be reported")
	broken = data.duplicate(true)
	broken["light"].erase("breath")
	check(not HeroineData.validate(broken).is_empty(), "a missing breath must be reported")


func test_strip_breathes_in_forward_time_and_glows_under_shift() -> void:
	var rig := _rig()
	var colours: Dictionary = Content.time_hud()["colors"]
	var accent := Color(String(colours["accent"]))
	var core := Color(String(colours["core"]))
	rig.set_time_light(1.0, 0.0)
	var seen := {}
	var strongest := 0.0
	var weakest := 1.0
	for i in 60:
		rig._update_light(0.1)
		seen[rig.strip().color.to_html()] = true
		strongest = maxf(strongest, rig.light_strength())
		weakest = minf(weakest, rig.light_strength())
	check(seen.size() > 10, "in forward time the strip must breathe, not stand still")
	check(strongest > weakest * 2.0, "the light on her breathes with the strip: %f..%f" % [weakest, strongest])
	rig.set_time_light(1.0, 1.0)
	rig._update_light(0.0)
	check(rig.strip().color.is_equal_approx(core), "under Shift the strip shows the light core, got %s" % rig.strip().color.to_html())
	check(not accent.is_equal_approx(core), "the time colour and its core must differ")
	rig.free()
