class_name RoomSound
extends Node
## The sound of one room (task Д8, D183). The `Sound` autoload puts one next to
## every `RoomTime`, so rooms need no edits. It records nothing and changes
## nothing: it listens. Every physics tick, after the world moved, it reads the
## fields named in `data/audio.json` from the frame at the cursor
## (`Timeline.peek`) and turns their changes into sounds at the objects
## (`SoundRules`):
## - forward, a change sounds when it happens;
## - under Shift a change is the recorded past undone, so the sound of the
##   recorded edge plays reversed, started early enough that its hit lands on
##   the frame (the frames ahead of the cursor are the past, so they are
##   known); when rewinding began too late for that, only its end plays;
## - an action of the heroine under Shift is a new present and sounds forward.
## Loops (a moving door, water, fire, rain) play while their rule holds — the
## reversed file under Shift, higher when the rewind speeds up (D62).
## It also gives the heroine her steps, jump and landing, sparks to the torn
## cables and to breakdowns, and the rolling of minecarts (they are outside
## time, so they always sound forward).

const POOL_SIZE := 12
const HEARD_MAX := 400
## When rewinding began too late to start a reversed sound early, it plays
## from this many seconds before its hit.
const FALLBACK_SECONDS := 0.05

var room_time: RoomTime
## What the room played, oldest first, for tests and the sound log: "<tick> <sound>",
## `_rev` when reversed, `loop:` when a loop starts. At most HEARD_MAX entries.
var heard: Array[String] = []
## Physics ticks this node has listened.
var ticks := 0

var _sound: Node
var _config := {}
var _still := 2
var _tps := 60.0
var _entries: Array[Dictionary] = []
var _last := {}             # entry key -> the field at the previous tick
var _since := {}            # entry key -> ticks since a move last changed
var _loops := {}            # entry key -> AudioStreamPlayer2D
var _loop_level := {}       # entry key -> fade level 0..1
var _loop_counts := {}      # sound -> loops of it playing at the last tick
var _ahead := {}            # entry key -> frames whose reversed sound started early
var _early: Array = []      # [player, msec of its hit] of reversed sounds started early
var _pool: Array[AudioStreamPlayer2D] = []
var _next_pool := 0
var _last_cursor := -1
var _last_direction := 1
var _held := 0              # ticks Shift has been held, for the rewind's speed-up
var _rewind_speed: RewindSpeed
var _lead_next := {}        # entry key + sound -> the next frame edge to look at ahead
var _forward_tick := {}     # entry key -> tick of its last forward one-shot
var _played := {}           # sound -> tick it last started: one start a tick
var _player: Node
var _walked := 0.0
var _was_on_floor := true
var _air_speed := 0.0
var _last_step := -1
var _wires: Array[Node2D] = []
var _faults: Array[Node2D] = []
var _clock := {}            # instance id -> world seconds at the last tick (sparks)
var _carts := {}            # instance id -> AudioStreamPlayer2D


## Called by the `Sound` autoload before the node enters the tree.
func setup(room: RoomTime, sound: Node) -> void:
	room_time = room
	_sound = sound
	_config = sound.get("config")
	_still = maxi(int(_config.get("still_ticks", 2)), 1)
	name = "RoomSound"
	# After the world (-50), the objects and the player (0) moved this tick.
	process_physics_priority = 10


func _ready() -> void:
	_tps = float(Engine.physics_ticks_per_second)
	_rewind_speed = RewindSpeed.from_config(Content.time())
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		_positional(player)
		add_child(player)
		_pool.append(player)
	_collect()
	_player = _find_player()
	if _player != null:
		for signal_name in ["drowned", "burned"]:
			if _player.has_signal(signal_name):
				_player.connect(signal_name, _on_failed)


## The rules of every recorded object of the room, by the class of its script.
func _collect() -> void:
	_entries.clear()
	var objects: Dictionary = _config.get("objects", {})
	for node: Variant in room_time.temporal_objects():
		if not node is Node:
			continue
		var rules: Variant = objects.get(_class_of(node), null)
		if not rules is Array:
			continue
		var id := str(node.get("object_id"))
		for i in (rules as Array).size():
			var rule: Dictionary = rules[i]
			_entries.append({
				"node": node, "id": id, "rule": rule, "key": "%s#%d" % [id, i],
				"field": str(rule.get("field", "")), "kind": str(rule.get("kind", "")),
				"shots": SoundRules.one_shots(rule), "live": bool(rule.get("live", false)),
				"at": _thresholds(node, rule.get("at")),
			})
	var room := room_time.get_parent()
	if room != null:
		for node in room.find_children("*", "Node2D", true, false):
			match _class_of(node):
				"SparkingWire":
					_wires.append(node as Node2D)
				"FaultFx":
					_faults.append(node as Node2D)


func _physics_process(delta: float) -> void:
	ticks += 1
	if room_time == null or not is_instance_valid(room_time) or room_time.world == null:
		return
	var timeline: Timeline = room_time.world.timeline
	var cursor := timeline.cursor()
	if cursor < 0:
		return
	var manager := get_node_or_null("/root/TimeManager")
	var direction: int = manager.direction if manager != null else TimeWorld.FORWARD
	var speed: float = maxf(float(manager.rewind_speed), 1.0) if manager != null else 1.0
	if direction != _last_direction:
		_on_direction_changed(direction)
	_held = _held + 1 if direction < 0 else 0
	var at_head := timeline.at_head()
	var reversed := SoundRules.plays_reversed(direction, at_head)
	if reversed and room_time.last_step == TimeWorld.Step.REWOUND and _last_cursor > cursor:
		_listen_ahead(timeline, cursor)
	var counts := {}
	for entry in _entries:
		_listen(entry, timeline.peek(cursor, entry.id, entry.field), reversed, at_head, speed, cursor, counts)
	_loop_counts = counts
	_prune_ahead(cursor, speed)
	_last_cursor = cursor
	_hear_heroine(delta)
	_hear_sparks(reversed)
	_hear_carts()


# --- recorded objects -----------------------------------------------------------

func _listen(entry: Dictionary, value: Variant, reversed: bool, at_head: bool, speed: float, cursor: int, counts: Dictionary) -> void:
	var key: String = entry.key
	var rule: Dictionary = entry.rule
	if entry.live and not at_head:
		# The heroine's own act (taking, dropping) sounds when she does it, not
		# when the past replays it.
		_last[key] = value
		return
	if not _last.has(key):
		# The first tick: how the room was is not an event.
		_last[key] = value
		_since[key] = _still
		if entry.kind == "while":
			_loop(entry, SoundRules.holds(rule, value), reversed, speed, counts)
		return
	var before: Variant = _last[key]
	_last[key] = value
	match entry.kind:
		"move":
			var was_moving: bool = int(_since[key]) < _still
			_since[key] = 0 if not SoundRules.same(before, value) else int(_since[key]) + 1
			var moving: bool = int(_since[key]) < _still
			_loop(entry, moving, reversed, speed, counts)
			if moving != was_moving:
				# Forward: start when it starts moving, stop when it stops. Under
				# Shift, starting to move undoes a recorded stop and stopping
				# undoes a start.
				_shots(entry, SoundRules.motion_sounds(rule, moving != reversed), reversed, cursor, speed)
		"while":
			_loop(entry, SoundRules.holds(rule, value), reversed, speed, counts)
		_:
			if reversed:
				# The recorded edge went from the value now to the one before.
				_shots(entry, SoundRules.edge_sounds(rule, value, before, entry.at), true, cursor, speed)
			else:
				_shots(entry, SoundRules.edge_sounds(rule, before, value, entry.at), false, cursor, speed)


## Under Shift: the recorded edges the cursor reaches in a reversed sound's
## lead start that sound now, so its hit lands on the edge's frame. The lead in
## frames grows as the rewind speeds up (`SoundRules.frames_ahead`); every
## edge is looked at once, from where the last tick stopped.
func _listen_ahead(timeline: Timeline, cursor: int) -> void:
	var first := timeline.first()
	for entry in _entries:
		var shots: Array = entry.shots
		if shots.is_empty() or entry.live:
			continue
		var id: String = entry.id
		var field: String = entry.field
		var value_at := func(n: int) -> Variant: return timeline.peek(n, id, field)
		for sound_name: String in shots:
			var seconds: float = _sound.call("length", sound_name, true) - SoundRules.climax(_config, sound_name)
			var lead := SoundRules.frames_ahead(seconds, _held, _rewind_speed, _tps)
			if lead <= 1:
				continue
			var lowest := cursor - lead + 1
			var slot: String = entry.key + "/" + sound_name
			var k: int = mini(int(_lead_next.get(slot, lowest)), cursor)
			while k >= lowest:
				if k - 1 >= first and sound_name in SoundRules.frame_edge_sounds(entry.rule, value_at, k, _still, entry.at):
					var player := _play(entry.node, sound_name, true, 0.0, float(entry.rule.get("pitch", 1.0)))
					if player != null:
						_early.append([player, Time.get_ticks_msec() + int(1000.0 * seconds)])
					(_ahead.get_or_add(entry.key, []) as Array).append(k)
				k -= 1
			_lead_next[slot] = lowest - 1


func _shots(entry: Dictionary, sounds: Array[String], reversed: bool, cursor: int, speed: float) -> void:
	for sound_name in sounds:
		if not reversed:
			_forward_tick[entry.key] = ticks
			_play(entry.node, sound_name, false, 0.0, float(entry.rule.get("pitch", 1.0)))
			continue
		if _take_ahead(entry.key, cursor, speed):
			continue   # it started early; its hit is landing now
		if ticks - int(_forward_tick.get(entry.key, -1000)) < 15:
			continue   # an act under Shift just changed it; the rewind passing it again stays quiet
		var length: float = _sound.call("length", sound_name, true)
		var offset := SoundRules.reversed_offset(length, SoundRules.climax(_config, sound_name), FALLBACK_SECONDS)
		_play(entry.node, sound_name, true, offset, float(entry.rule.get("pitch", 1.0)))


## True (and forgets it) when an edge of this entry, just crossed, had its
## reversed sound started early. A move is noticed `still` ticks late.
func _take_ahead(key: String, cursor: int, speed: float) -> bool:
	var frames: Array = _ahead.get(key, [])
	var reach := cursor + 2 + int(ceil(float(_still + 1) * speed))
	for i in frames.size():
		var k := int(frames[i])
		if k > cursor and k <= reach:
			frames.remove_at(i)
			return true
	return false


func _prune_ahead(cursor: int, speed: float) -> void:
	var reach := cursor + 4 + int(ceil(float(_still + 2) * speed))
	for key: String in _ahead.keys():
		var frames: Array = _ahead[key]
		for i in range(frames.size() - 1, -1, -1):
			if int(frames[i]) > reach:
				frames.remove_at(i)


func _on_direction_changed(direction: int) -> void:
	_last_direction = direction
	if direction > 0:
		# Forward again: the edges announced by early reversed sounds will not
		# come; stop those whose hit is still ahead.
		var now := Time.get_ticks_msec()
		for item: Array in _early:
			var player := item[0] as AudioStreamPlayer2D
			if is_instance_valid(player) and player.playing and int(item[1]) > now:
				player.stop()
		_early.clear()
		_ahead.clear()
	_lead_next.clear()


func _loop(entry: Dictionary, active: bool, reversed: bool, speed: float, counts: Dictionary) -> void:
	var sound_name := str(entry.rule.get("loop", ""))
	if sound_name.is_empty():
		return
	var key: String = entry.key
	var player: AudioStreamPlayer2D = _loops.get(key)
	if player == null:
		if not active:
			return
		player = AudioStreamPlayer2D.new()
		_positional(player)
		add_child(player)
		_loops[key] = player
		_loop_level[key] = 0.0
	var want: AudioStream = _sound.call("stream", sound_name, reversed)
	if active and want != null and player.stream != want:
		var at := 0.0
		if player.playing and player.stream != null:
			# The same moment of the loop, read from the other end.
			at = maxf(player.stream.get_length() - player.get_playback_position(), 0.0)
		else:
			at = fposmod(float(hash(key) % 1000) * 0.618, 1.0) * want.get_length()
		player.stream = want
		player.play(at)
		_note("loop:" + sound_name + ("_rev" if reversed else ""))
	elif active and want != null and not player.playing:
		player.play(fposmod(float(hash(key) % 1000) * 0.618, 1.0) * want.get_length())
		_note("loop:" + sound_name + ("_rev" if reversed else ""))
	var fade := maxf(float(_config.get("loop_fade_seconds", 0.1)), 0.001)
	var level := move_toward(float(_loop_level[key]), 1.0 if active else 0.0, 1.0 / (_tps * fade))
	_loop_level[key] = level
	if level <= 0.0:
		if player.playing:
			player.stop()
		return
	counts[sound_name] = int(counts.get(sound_name, 0)) + 1
	# Many loops of one sound (a row of burning zones) share one loudness.
	var many := maxi(int(_loop_counts.get(sound_name, 1)), 1)
	player.volume_db = SoundRules.volume_db(_config, sound_name) + linear_to_db(level) - 10.0 * log(float(many)) / log(10.0)
	player.pitch_scale = float(entry.rule.get("pitch", 1.0)) * (SoundRules.rewind_pitch(_config, speed) if reversed else 1.0)
	player.global_position = _where(entry.node)


# --- one-shots ------------------------------------------------------------------

## Plays a sound at a node; returns the player, or null without a file.
func _play(node: Variant, sound_name: String, reversed: bool, offset: float, pitch := 1.0, at := Vector2.INF) -> AudioStreamPlayer2D:
	var stream: AudioStream = _sound.call("stream", sound_name, reversed)
	if stream == null or int(_played.get(sound_name, -1)) == ticks:
		return null   # one start of a sound a tick: three sparks at once are one crackle
	_played[sound_name] = ticks
	var player := _free_player()
	player.stream = stream
	player.volume_db = SoundRules.volume_db(_config, sound_name)
	player.pitch_scale = pitch
	player.global_position = at if at != Vector2.INF else _where(node)
	player.play(offset)
	_note(sound_name + ("_rev" if reversed else ""))
	return player


func _note(text: String) -> void:
	heard.append("%d %s" % [ticks, text])
	if heard.size() > HEARD_MAX:
		heard.remove_at(0)


func _free_player() -> AudioStreamPlayer2D:
	for i in _pool.size():
		var player := _pool[(_next_pool + i) % _pool.size()]
		if not player.playing:
			_next_pool = (_next_pool + i + 1) % _pool.size()
			return player
	var oldest := _pool[_next_pool]
	_next_pool = (_next_pool + 1) % _pool.size()
	return oldest


func _positional(player: AudioStreamPlayer2D) -> void:
	var positional: Dictionary = _config.get("positional", {})
	player.max_distance = float(positional.get("max_distance_px", 2600.0))
	player.attenuation = float(positional.get("attenuation", 1.0))
	player.panning_strength = float(positional.get("panning", 0.5))


func _where(node: Variant) -> Vector2:
	if node is Node2D and is_instance_valid(node):
		return (node as Node2D).global_position
	if _player is Node2D and is_instance_valid(_player):
		return (_player as Node2D).global_position
	return Vector2.ZERO


## The numbers a `reach` rule waits for: its `at`, or the object's own number
## or list of numbers at that path ("plan.quake_tick"), read once.
static func _thresholds(node: Object, at: Variant) -> Array:
	var value: Variant = at
	if at is String:
		value = node
		for part in (at as String).split("."):
			if value is Object and is_instance_valid(value):
				value = (value as Object).get(part)
			elif value is Dictionary:
				value = (value as Dictionary).get(part)
			else:
				value = null
	var out := []
	if value is int or value is float:
		out.append(float(value))
	elif value is Array or value is PackedInt32Array or value is PackedFloat32Array:
		for item: Variant in value:
			if (item is int or item is float) and float(item) >= 0.0:
				out.append(float(item))
	return out


static func _class_of(node: Object) -> String:
	var script := node.get_script() as Script
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return node.get_class()


# --- the heroine, sparks, carts -------------------------------------------------

func _find_player() -> Node:
	if not room_time.player_path.is_empty():
		var node := room_time.get_node_or_null(room_time.player_path)
		if node != null:
			return node
	var room := room_time.get_parent()
	for node in get_tree().get_nodes_in_group("player"):
		if room != null and room.is_ancestor_of(node):
			return node
	return null


## Steps by the distance walked (two a cycle of the run, `step_px`), a jump
## when she leaves the floor fast upwards, a landing after a fast fall. She is
## live: her sounds are always forward.
func _hear_heroine(delta: float) -> void:
	if not _player is CharacterBody2D or not is_instance_valid(_player):
		return
	var body := _player as CharacterBody2D
	var heroine: Dictionary = _config.get("heroine", {})
	var on_floor := body.is_on_floor()
	var velocity := body.velocity
	var step_px := maxf(float(heroine.get("step_px", 55.0)), 1.0)
	if on_floor and absf(velocity.x) >= float(heroine.get("min_speed_px", 20.0)):
		_walked += absf(velocity.x) * delta
		if _walked >= step_px:
			_walked = fmod(_walked, step_px)
			_heroine_sound(_next_step(heroine))
	elif on_floor:
		_walked = step_px * 0.5   # the first step comes soon after she sets off
	if _was_on_floor and not on_floor and velocity.y <= -float(heroine.get("jump_speed_px", 300.0)):
		_heroine_sound(str(heroine.get("jump", "")))
	if not _was_on_floor and on_floor and _air_speed >= float(heroine.get("land_speed_px", 300.0)):
		_heroine_sound(str(heroine.get("land", "")))
	if not on_floor:
		_air_speed = velocity.y
	_was_on_floor = on_floor


func _next_step(heroine: Dictionary) -> String:
	var steps: Array = heroine.get("steps", [])
	if steps.is_empty():
		return ""
	var index := randi() % steps.size()
	if index == _last_step and steps.size() > 1:
		index = (index + 1) % steps.size()
	_last_step = index
	return str(steps[index])


func _heroine_sound(sound_name: String) -> void:
	if not sound_name.is_empty():
		_play(_player, sound_name, false, 0.0)


func _on_failed() -> void:
	_sound.call("play_global", str((_config.get("heroine", {}) as Dictionary).get("fail", "")))


## Torn cables spark in bursts every `burst_every` world seconds (the particle
## preset `sparks`), and a breakdown sparks once at its failure; both are drawn
## from world time, so under Shift the reversed crackle starts early and ends
## on the burst. Without a recorded edge there is no late fallback: the next
## burst comes soon.
func _hear_sparks(reversed: bool) -> void:
	var sound_name := str((_config.get("sparks", {}) as Dictionary).get("sound", ""))
	if sound_name.is_empty():
		return
	var lead_seconds: float = _sound.call("length", sound_name, true) - SoundRules.climax(_config, sound_name)
	for wire in _wires:
		if not is_instance_valid(wire):
			continue
		var particles: Variant = wire.get("sparks")
		if particles == null or particles.get("field") == null:
			continue
		var period := float(particles.field.burst_every)
		if period <= 0.0:
			continue
		var now := float(particles.world_seconds)
		var at := wire.to_global(wire.get("end")) if wire.get("end") is Vector2 else wire.global_position
		var before: Variant = _clock.get(wire.get_instance_id())
		_clock[wire.get_instance_id()] = now
		if before == null:
			continue
		if now > float(before) and not reversed:
			var burst := floorf(now / period)
			if burst >= 1.0 and burst > floorf(float(before) / period):
				_play(null, sound_name, false, 0.0, 1.0, at)
		elif now < float(before) and reversed:
			var lead := lead_seconds * _tps * (float(before) - now)
			var burst := floorf((float(before) - lead) / period)
			if burst >= 1.0 and burst > floorf((now - lead) / period):
				_play(null, sound_name, true, 0.0, 1.0, at)
	for fault in _faults:
		if not is_instance_valid(fault) or not fault.has_method("fault_seconds"):
			continue
		var now := float(fault.call("fault_seconds"))
		var before: Variant = _clock.get(fault.get_instance_id())
		_clock[fault.get_instance_id()] = now
		if before == null:
			continue
		if not reversed and float(before) < 0.0 and now >= 0.0:
			_play(fault, sound_name, false, 0.0)
		elif reversed and now < float(before) and now >= 0.0:
			var lead := lead_seconds * _tps * (float(before) - now)
			if float(before) > lead and now <= lead:
				_play(fault, sound_name, true, 0.0)


## A minecart rolls louder and higher the faster it goes. It is outside time,
## so its sound is always forward.
func _hear_carts() -> void:
	var cart_data: Dictionary = _config.get("minecart", {})
	var sound_name := str(cart_data.get("loop", ""))
	if sound_name.is_empty():
		return
	var room := room_time.get_parent()
	for cart in get_tree().get_nodes_in_group("minecart"):
		if room == null or not room.is_ancestor_of(cart) or not cart is Node2D:
			continue
		var ride: Variant = cart.get("ride")
		var speed := absf(float(ride.get("speed"))) if ride is Object else 0.0
		var ratio := clampf(speed / maxf(float(cart_data.get("full_speed_px", 400.0)), 1.0), 0.0, 1.0)
		var player: AudioStreamPlayer2D = _carts.get(cart.get_instance_id())
		if player == null:
			if ratio <= 0.0:
				continue
			player = AudioStreamPlayer2D.new()
			_positional(player)
			add_child(player)
			_carts[cart.get_instance_id()] = player
		if ratio <= 0.02:
			if player.playing:
				player.stop()
			continue
		if not player.playing:
			player.stream = _sound.call("stream", sound_name, false)
			if player.stream == null:
				continue
			player.play()
			_note("loop:" + sound_name)
		player.volume_db = SoundRules.volume_db(_config, sound_name) + linear_to_db(ratio)
		player.pitch_scale = lerpf(float(cart_data.get("min_pitch", 0.7)), 1.0, ratio)
		player.global_position = (cart as Node2D).global_position
