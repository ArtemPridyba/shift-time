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
	check(float(rig.light_parameter("waves")) > 0.0, "under Shift the waves must show")
	var phase := float(rig.light_parameter("wave_phase"))
	rig._process(0.1)
	check(not is_equal_approx(float(rig.light_parameter("wave_phase")), phase), "the waves must move")
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


func _rig() -> HeroineRig:
	var rig := HeroineRig.new()
	rig.build(HeroineData.load_data())
	return rig
