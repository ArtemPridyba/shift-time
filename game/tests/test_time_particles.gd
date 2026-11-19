extends RefCounted
## Tests of the particles that run backwards (task Д2): `ParticleField` gives
## every particle as a formula of world time, and the presets in
## `data/look.json` pass the data check. The showcase run (the same frame of
## history shows the same particles after Shift) is in test_mech.gd.
## Run by test_runner.gd.

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _field(preset: String, noise_seed := 1) -> ParticleField:
	return ParticleField.from_preset(Content.look_particles()[preset], noise_seed)


func test_the_same_time_gives_the_same_particles() -> void:
	var dust := _field("dust", 3)
	var at_five := dust.sample(5.0)
	check(at_five.size() > 0, "the dust must have particles at 5 s")
	dust.sample(12.0)
	dust.sample(2.5)
	check(dust.sample(5.0) == at_five, "sampling other moments must not change the particles of 5 s")
	check(_field("dust", 3).sample(5.0) == at_five, "a new field with the same seed must give the same particles")
	check(_field("dust", 4).sample(5.0) != at_five, "another seed must give other particles")


func test_a_particle_moves_in_small_steps() -> void:
	var dust := _field("dust")
	var index := int(dust.rate * 2.0)
	var previous := PackedFloat32Array()
	var biggest := 0.0
	var frames := 0
	for tick in range(0, 60 * 14):
		var p := dust.stream_particle(tick / 60.0, index)
		if p.is_empty():
			previous = p
			continue
		frames += 1
		if not previous.is_empty():
			biggest = maxf(biggest, Vector2(p[0], p[1]).distance_to(Vector2(previous[0], previous[1])))
		previous = p
	check(frames > 60, "the tracked dust mote must live for more than a second, lived %d frames" % frames)
	check(biggest < 2.0, "dust must drift less than 2 px a frame, the biggest step was %.2f" % biggest)


func test_shards_burst_then_rest_on_the_floor() -> void:
	var shards := _field("shards")
	shards.extra_bursts = PackedFloat32Array([1.0])
	shards.set_floor(20.0)
	check(shards.sample(0.99).is_empty(), "no shard before the burst")
	var at_burst := shards.sample(1.0)
	check(at_burst.size() == shards.burst_count * ParticleField.STRIDE, "every shard appears at the burst moment")
	var resting := shards.sample(3.5)
	check(resting.size() == at_burst.size(), "no shard is lost while it lies on the floor")
	for k in resting.size() / ParticleField.STRIDE:
		check(is_equal_approx(resting[k * ParticleField.STRIDE + 1], 20.0), "shard %d must lie on the floor at 3.5 s" % k)
	var later := shards.sample(3.6)
	for k in later.size() / ParticleField.STRIDE:
		var o := k * ParticleField.STRIDE
		check(is_equal_approx(later[o], resting[o]) and is_equal_approx(later[o + 2], resting[o + 2]),
			"a shard on the floor must not move or spin")
	var biggest := 0.0
	var before := shards.sample(1.0)
	for tick in range(61, 61 + 150):
		var now := shards.sample(tick / 60.0)
		for k in mini(now.size(), before.size()) / ParticleField.STRIDE:
			var o := k * ParticleField.STRIDE
			biggest = maxf(biggest, Vector2(now[o], now[o + 1]).distance_to(Vector2(before[o], before[o + 1])))
		before = now
	check(biggest < 12.0, "a flying shard must move less than 12 px a frame, the biggest step was %.1f" % biggest)
	check(shards.sample(1.0 + shards.lifetime).is_empty(), "the shards are gone when their life ends")


func test_drops_end_at_the_floor() -> void:
	var drops := _field("drops")
	drops.set_floor(100.0)
	var seen := 0
	for tick in range(0, 60 * 10, 3):
		var now := drops.sample(tick / 60.0)
		for k in now.size() / ParticleField.STRIDE:
			seen += 1
			check(now[k * ParticleField.STRIDE + 1] <= 100.0, "a drop must not fall through the floor")
	check(seen > 0, "the pipe must drip")


func test_dust_is_only_in_the_lamp_light() -> void:
	var dust := _field("dust")
	var spread := dust.cone_spread
	for t in [0.0, 3.0, 7.5, 19.0]:
		var now := dust.sample(t)
		check(now.size() > 0, "dust must be in the light at %s s, also at the start" % t)
		for k in now.size() / ParticleField.STRIDE:
			var p := Vector2(now[k * ParticleField.STRIDE], now[k * ParticleField.STRIDE + 1])
			check(p.y > 0.0 and absf(atan2(p.x, p.y)) < spread and p.length() < dust.cone_length,
				"a drawn dust mote must be inside the light cone")


func test_sparks_come_in_bursts_from_the_wire() -> void:
	var sparks := _field("sparks")
	var every := sparks.burst_every
	check(sparks.sample(0.0).is_empty(), "no burst is frozen at frame 0")
	check(sparks.sample(every).size() == sparks.burst_count * ParticleField.STRIDE, "the first burst is at burst_every")
	check(sparks.sample(every + sparks.lifetime + 0.01).is_empty(), "between bursts the wire is quiet")
	check(not sparks.sample(2.0 * every + 0.1).is_empty(), "the next burst comes burst_every later")


func test_capacity_covers_every_alive_particle() -> void:
	var presets := Content.look_particles()
	for name: String in presets:
		var field := _field(name)
		field.extra_bursts = PackedFloat32Array([2.0, 2.5])
		for tick in range(0, 60 * 30, 15):
			var alive := field.sample(tick / 60.0).size() / ParticleField.STRIDE
			check(alive <= field.capacity(), "'%s' has %d alive, more than its capacity %d" % [name, alive, field.capacity()])


func test_rand_is_fixed_and_spread() -> void:
	check(ParticleField.rand01(1, 2, 3) == ParticleField.rand01(1, 2, 3), "the hash must not change between calls")
	var low := 0
	for i in 1000:
		var r := ParticleField.rand01(9, i - 500, 4)
		check(r >= 0.0 and r < 1.0, "rand01 must be in [0, 1)")
		if r < 0.5:
			low += 1
	check(low > 420 and low < 580, "rand01 must spread evenly, %d of 1000 were below 0.5" % low)


# --- data ---------------------------------------------------------------------

func test_look_data_is_valid() -> void:
	var problems := Content.validate_look(Content.look())
	check(problems.is_empty(), "look.json must pass the data check: %s" % ", ".join(problems))


func test_broken_look_data_is_reported() -> void:
	var cases := {
		"no color": func(d: Dictionary) -> void: (d["particles"]["dust"] as Dictionary).erase("color"),
		"bad shape": func(d: Dictionary) -> void: d["particles"]["ash"]["shape"] = "smoke",
		"nothing emitted": func(d: Dictionary) -> void:
			d["particles"]["ash"]["rate"] = 0
			d["particles"]["ash"]["burst_count"] = 0,
		"wide cone": func(d: Dictionary) -> void: d["particles"]["dust"]["cone"]["spread"] = 2.0,
		"bad size": func(d: Dictionary) -> void: d["particles"]["drops"]["size"] = [4, 2],
		"no area": func(d: Dictionary) -> void: (d["particles"]["drops"] as Dictionary).erase("area"),
		"bad floor": func(d: Dictionary) -> void: d["particles"]["shards"]["on_floor"] = "bounce",
		"bad mech color": func(d: Dictionary) -> void: d["mech"]["iron"] = "iron",
		"no mech": func(d: Dictionary) -> void: d.erase("mech"),
	}
	for name: String in cases:
		var data: Dictionary = Content.look().duplicate(true)
		(cases[name] as Callable).call(data)
		check(not Content.validate_look(data).is_empty(), "the data check must catch: %s" % name)
	check(not Content.validate_look([]).is_empty(), "the data check must catch a file that is not an object")
