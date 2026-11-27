extends RefCounted
## Tests of the sound (task Д8, D183): the data check, which edge of a recorded
## field makes which sound, the choice of the reversed twin by the direction of
## time, the arithmetic that lands a reversed hit on its frame, and a real room
## where a door sounds forward and then reversed under Shift.
## Run by test_runner.gd.

const ROOM_PATH := "res://tests/rooms/test_room.tscn"
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


# --- data ------------------------------------------------------------------------

func test_audio_data_is_valid_and_every_file_exists() -> void:
	var data := SoundRules.config()
	for problem in SoundRules.validate(data):
		check(false, problem)
	for class_key: String in data["objects"]:
		for rule: Dictionary in data["objects"][class_key]:
			for sound_name in SoundRules.rule_sounds(rule):
				check(ResourceLoader.exists(SoundRules.path(data, sound_name, true)),
					"%s: '%s' plays under Shift, so it needs its reversed twin" % [class_key, sound_name])


func test_audio_data_check_catches_broken_data() -> void:
	var good := SoundRules.config()
	check(not SoundRules.validate("text").is_empty(), "a non-object audio.json must be reported")
	for key in ["sounds", "folder", "still_ticks", "positional", "objects", "time", "heroine", "ambience", "ui", "sparks", "minecart"]:
		var broken := good.duplicate(true)
		broken.erase(key)
		check(not SoundRules.validate(broken, false).is_empty(), "missing '%s' in audio.json must be reported" % key)
	var cases := {
		"an unknown sound in a rule": func(d: Dictionary) -> void: d["objects"]["Door"][0]["stop"] = "no_such_sound",
		"a loop where a one-shot is needed": func(d: Dictionary) -> void: d["objects"]["Door"][0]["stop"] = "door_move",
		"a one-shot where a loop is needed": func(d: Dictionary) -> void: d["objects"]["Door"][0]["loop"] = "door_stop",
		"an unknown kind": func(d: Dictionary) -> void: d["objects"]["Door"][0]["kind"] = "wobble",
		"a rule without a field": func(d: Dictionary) -> void: d["objects"]["Door"][0].erase("field"),
		"a while without a condition": func(d: Dictionary) -> void: d["objects"]["Sprinkler"][0].erase("above"),
		"a volume out of range": func(d: Dictionary) -> void: d["sounds"]["door_stop"]["db"] = 40,
		"a negative climax": func(d: Dictionary) -> void: d["sounds"]["lever"]["climax"] = -1,
		"no steps": func(d: Dictionary) -> void: d["heroine"]["steps"] = [],
		"a rewind loop that does not loop": func(d: Dictionary) -> void: d["time"]["loop"] = "door_stop",
	}
	for what: String in cases:
		var broken := good.duplicate(true)
		(cases[what] as Callable).call(broken)
		check(not SoundRules.validate(broken, false).is_empty(), what + " must be reported")
	var missing := good.duplicate(true)
	missing["sounds"]["ghost"] = {"db": 0}
	check(not SoundRules.validate(missing).is_empty(), "a sound without its file must be reported")


# --- rules ---------------------------------------------------------------------------

func test_edges_of_each_kind() -> void:
	var flag := {"kind": "flag", "field": "pressed", "on": "button", "off": "button_up"}
	check(SoundRules.edge_sounds(flag, false, true) == ["button"], "a flag turning on plays 'on'")
	check(SoundRules.edge_sounds(flag, true, false) == ["button_up"], "a flag turning off plays 'off'")
	check(SoundRules.edge_sounds(flag, true, true).is_empty(), "a flag that stays plays nothing")
	var set_rule := {"kind": "set", "field": "burn", "sound": "ignite"}
	check(SoundRules.edge_sounds(set_rule, -1, 120) == ["ignite"], "-1 turning into a tick plays the sound")
	check(SoundRules.edge_sounds(set_rule, 120, 121).is_empty(), "a running tick plays nothing")
	var change := {"kind": "change", "field": "phase", "to": 1, "sound": "ignite"}
	check(SoundRules.edge_sounds(change, 0, 1.0) == ["ignite"], "a change to 'to' plays (int and float meet)")
	check(SoundRules.edge_sounds(change, 1, 2).is_empty(), "a change to another value plays nothing")
	var any_change := {"kind": "change", "field": "index", "sound": "quake"}
	check(SoundRules.edge_sounds(any_change, -1, 0) == ["quake"], "a change without 'to' plays on any change")
	check(SoundRules.edge_sounds(any_change, Vector2(1, 2), Vector2(1, 2)).is_empty(), "equal vectors are no change")
	check(SoundRules.holds({"kind": "while", "equals": 1}, 1.0), "while equals holds on the value")
	check(not SoundRules.holds({"kind": "while", "above": 0}, 0), "while above does not hold at the limit")
	var move := {"kind": "move", "field": "open", "loop": "door_move", "start": "lever", "stop": "door_stop"}
	check(SoundRules.motion_sounds(move, false) == ["door_stop"] and SoundRules.motion_sounds(move, true) == ["lever"],
		"a move plays 'start' and 'stop' at the ends of its motion")
	check(SoundRules.one_shots(move) == ["lever", "door_stop"], "the loop is not a one-shot")


func test_frames_show_where_a_move_starts_and_stops() -> void:
	# The field stands, moves for three frames and stands again.
	var values := [0, 0, 0, 1, 2, 3, 3, 3, 3]
	var value_at := func(n: int) -> Variant: return values[n] if n >= 0 and n < values.size() else null
	var move := {"kind": "move", "field": "open", "loop": "door_move", "start": "lever", "stop": "door_stop"}
	var found := {}
	for k in range(1, values.size()):
		for sound_name in SoundRules.frame_edge_sounds(move, value_at, k, 2):
			found[sound_name] = k
	check(found.get("lever") == 3, "the start is the frame of the first change, got %s" % found.get("lever"))
	check(found.get("door_stop") == 5, "the stop is the frame of the last change, got %s" % found.get("door_stop"))
	var flag := {"kind": "flag", "field": "on", "on": "lever"}
	var flags := [false, false, true, true]
	var flag_at := func(n: int) -> Variant: return flags[n] if n >= 0 and n < flags.size() else null
	check(SoundRules.frame_edge_sounds(flag, flag_at, 2, 2) == ["lever"], "a flag's edge is the frame where it turns")


func test_reach_waits_for_the_objects_own_number() -> void:
	var reach := {"kind": "reach", "field": "ride", "at": "plan.act3_at", "sound": "quake"}
	check(SoundRules.edge_sounds(reach, 236, 238, [238.0]) == ["quake"], "passing the number plays the sound")
	check(SoundRules.edge_sounds(reach, 238, 239, [238.0]).is_empty(), "after the number nothing plays")
	check(SoundRules.edge_sounds(reach, 10, 11, [5.0, 11.0]) == ["quake"], "any of a list of numbers counts")
	check(SoundRules.edge_sounds(reach, 10, 11).is_empty(), "without its numbers a reach stays quiet")
	var broken := SoundRules.config().duplicate(true)
	broken["objects"]["Collapse"][0].erase("at")
	check(not SoundRules.validate(broken, false).is_empty(), "a reach without 'at' must be reported")


func test_lead_grows_as_the_rewind_speeds_up() -> void:
	var rewind := RewindSpeed.new()
	rewind.delay_ticks = 30
	rewind.ramp_ticks = 90
	rewind.max_speed = 3.0
	check(SoundRules.frames_ahead(0.5, 0, rewind, 60.0) == 30, "before the speed-up a frame a tick")
	check(SoundRules.frames_ahead(1.0, 200, rewind, 60.0) == 180, "at full speed three frames a tick")
	var ramp := SoundRules.frames_ahead(1.5, 30, rewind, 60.0)
	check(ramp == 180, "over the ramp the speed rises from 1 to 3: 90 ticks, 180 frames, got %d" % ramp)
	var steps := 0
	var speed := RewindSpeed.new()
	speed.delay_ticks = 30
	speed.ramp_ticks = 90
	speed.max_speed = 3.0
	for i in 150:
		steps += speed.frames_for(-1)
	var predicted := SoundRules.frames_ahead(150.0 / 60.0, 0, rewind, 60.0)
	check(absi(steps - predicted) <= 2, "the lead must follow RewindSpeed: %d frames, predicted %d" % [steps, predicted])


func test_reversed_twin_plays_only_when_the_past_runs_back() -> void:
	check(not SoundRules.plays_reversed(1, false), "forward time plays the sound as recorded")
	check(not SoundRules.plays_reversed(1, true), "recording at the head plays forward")
	check(SoundRules.plays_reversed(-1, false), "under Shift the past plays reversed")
	check(not SoundRules.plays_reversed(-1, true), "an action under Shift is a new present: forward")


func test_a_reversed_hit_lands_on_its_frame() -> void:
	check(SoundRules.lead_frames(1.8, 0.0, 1.0, 60.0) == 108, "a 1.8 s clank starts 108 frames ahead")
	check(SoundRules.lead_frames(1.8, 0.0, 2.0, 60.0) == 216, "twice the rewind speed needs twice the frames")
	check(SoundRules.lead_frames(1.28, 0.25, 1.0, 60.0) == 62, "a hit later in the file needs less lead")
	check(is_equal_approx(SoundRules.reversed_offset(1.0, 0.25, 0.05), 0.7), "a late start skips to just before the hit")
	check(SoundRules.reversed_offset(0.1, 0.0, 0.5) == 0.0, "the offset never goes below the start")
	var data := SoundRules.config()
	check(SoundRules.rewind_pitch(data, 1.0) == 1.0, "a slow rewind keeps the pitch")
	check(SoundRules.rewind_pitch(data, 100.0) == float(data["rewind_pitch_max"]), "the pitch has a ceiling")


# --- a real room -------------------------------------------------------------------------

func test_a_door_sounds_forward_then_reversed_under_shift() -> void:
	await _settle()
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _ticks(3)
	var sound := room.get_node_or_null("RoomSound") as RoomSound
	check(sound != null, "the Sound autoload must put a RoomSound into every room")
	if sound == null:
		room.queue_free()
		return
	# Forward: the door of the test room opens and closes by its cycle.
	await _ticks(600)
	check(_heard(sound, "loop:door_move"), "a moving door must play its loop: %s" % [sound.heard])
	check(_heard(sound, "door_stop"), "a door reaching its end must clank: %s" % [sound.heard])
	check(not _heard(sound, "_rev"), "nothing plays reversed before Shift: %s" % [sound.heard])
	# Under Shift the recorded motion runs back: reversed loop, reversed clanks.
	Input.action_press("rewind")
	await _ticks(420)
	Input.action_release("rewind")
	check(_heard(sound, "loop:door_move_rev"), "a door moving back must play the reversed loop: %s" % [sound.heard])
	check(_heard(sound, "door_stop_rev"), "an undone stop must play the reversed clank: %s" % [sound.heard])
	room.queue_free()
	await _settle()


func test_sound_changes_nothing_in_the_world() -> void:
	# Two runs of the same room, with and without its RoomSound, end equal.
	var states: Array = []
	for keep_sound in [true, false]:
		await _settle()
		var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
		_tree.root.add_child(room)
		await _ticks(2)
		if not keep_sound and room.has_node("RoomSound"):
			room.get_node("RoomSound").queue_free()
		await _ticks(240)
		Input.action_press("rewind")
		await _ticks(120)
		Input.action_release("rewind")
		await _ticks(60)
		var clock := room.find_children("*", "RoomTime", true, false)[0] as RoomTime
		states.append([clock.cursor(), TemporalRecorder.new().capture(clock.temporal_objects())])
		room.queue_free()
	await _settle()
	check(states[0] == states[1], "the sound must only listen: %s vs %s" % states)


func _heard(sound: RoomSound, what: String) -> bool:
	for entry in sound.heard:
		if entry.ends_with(" " + what) or (what.begins_with("_") and entry.ends_with(what)):
			return true
	return false


func _settle() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	await _ticks(3)


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
