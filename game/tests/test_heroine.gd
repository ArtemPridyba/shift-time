extends RefCounted
## Tests of the heroine's doll (task Д5, D72–D77): the data check, her height
## against the 44x92 hitbox, the feet on the floor, the indicator strip in the
## time colour from data, the mirror when she turns, and the doll in the
## player scene. Run by test_runner.gd.

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
		check(rig.strip().get_parent() == rig.joint("gauntlet"), "the strip must move with the gauntlet")
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


func test_player_scene_carries_the_doll() -> void:
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_tree.root.add_child(player)
	var rig := player.get_node_or_null("Heroine") as HeroineRig
	check(rig != null, "player.tscn must carry the heroine's doll as Heroine")
	if rig != null:
		check(rig.pose() == "idle", "standing still, she must take the idle pose")
	player.free()


func _rig() -> HeroineRig:
	var rig := HeroineRig.new()
	rig.build(HeroineData.load_data())
	return rig
