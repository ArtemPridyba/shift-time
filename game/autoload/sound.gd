extends Node
## The sound of the game (task Д8, D183), an autoload. It loads
## `data/audio.json` and keeps the streams; plays what outlives a room (menu
## clicks, the exit, a failure), the rewind loop while Shift is held and the hum
## of the hall; and puts a `RoomSound` next to every `RoomTime` that enters the
## tree, so levels and objects need no edits. Everything is volume and pitch on
## the Master bus — no bus effects, which the browser build does not play.
## The two one-shots of Shift are `TimeSound`'s (`data/time_hud.json`).

const GLOBAL_PLAYERS := 6
## A menu that just opened grabs the focus; that is not a move to sound.
const QUIET_AFTER_BUTTON_MSEC := 200

var config := {}

var _streams := {}
var _global: Array[AudioStreamPlayer] = []
var _next_global := 0
var _rewind: AudioStreamPlayer
var _rewind_level := 0.0
var _gust: AudioStreamPlayer
var _gust_level := 0.0
var _was_rewinding := false
var _ambience: AudioStreamPlayer
var _ambience_rev: AudioStreamPlayer
var _ambience_level := 0.0
var _ambience_mix := 0.0
var _room: Node
var _in_level := false
var _quiet_until := 0
var _last_move := -1000000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = SoundRules.config()
	for i in GLOBAL_PLAYERS:
		_global.append(_player("Global%d" % i))
	_rewind = _player("Rewind")
	_gust = _player("Gust")
	_ambience = _player("Ambience")
	_ambience_rev = _player("AmbienceReversed")
	get_tree().node_added.connect(_on_node_added)
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		loader.connect("level_started", _on_level_started)
		loader.connect("level_finished", _on_level_finished)
		for signal_name in ["menu_opened", "list_opened", "final_opened"]:
			loader.connect(signal_name, _on_left_level)
		# The pause lives the whole game; its focus on opening is no move either.
		if loader.has_signal("pause_opening"):
			loader.connect("pause_opening", _hush_menu)
	_preload.call_deferred()
	_start_ambience.call_deferred()


## The stream of a sound (null without its file); `reversed` gives the twin.
## Loops are set to loop here, before they ever play.
func stream(sound_name: String, reversed := false) -> AudioStream:
	var path := SoundRules.path(config, sound_name, reversed)
	if _streams.has(path):
		return _streams[path]
	var result: AudioStream = null
	if not sound_name.is_empty() and ResourceLoader.exists(path):
		result = load(path) as AudioStream
	if result is AudioStreamOggVorbis:
		(result as AudioStreamOggVorbis).loop = SoundRules.is_loop(config, sound_name)
	_streams[path] = result
	return result


## Seconds of a sound's file; 0 without it.
func length(sound_name: String, reversed := false) -> float:
	var found := stream(sound_name, reversed)
	return found.get_length() if found != null else 0.0


## A sound everywhere at once (menus, the exit, a failure).
func play_global(sound_name: String) -> void:
	var found := stream(sound_name)
	if found == null:
		return
	var player := _global[_next_global]
	_next_global = (_next_global + 1) % _global.size()
	player.stream = found
	player.volume_db = SoundRules.volume_db(config, sound_name)
	player.play()


## The room whose world is heard (the last one that started).
func room() -> Node:
	return _room if is_instance_valid(_room) else null


func _process(delta: float) -> void:
	var manager := get_node_or_null("/root/TimeManager")
	var room_time := room()
	var rewinding: bool = manager != null and int(manager.direction) < 0 and room_time != null and not get_tree().paused
	_update_rewind(delta, rewinding, manager, room_time)
	_update_ambience(delta, rewinding)


func _update_rewind(delta: float, rewinding: bool, manager: Node, room_time: Node) -> void:
	var time_data: Dictionary = config.get("time", {})
	var sound_name := str(time_data.get("loop", ""))
	var fade := maxf(float(time_data.get("fade_seconds", 0.1)), 0.001)
	_rewind_level = move_toward(_rewind_level, 1.0 if rewinding else 0.0, delta / fade)
	var gust_name := str(time_data.get("gust", ""))
	if rewinding and not _was_rewinding:
		_rewind.stream = stream(sound_name)
		if _rewind.stream != null:
			_rewind.play()
		_gust.stream = stream(gust_name)
		_gust_level = 0.0
		if _gust.stream != null:
			_gust.play()
	_was_rewinding = rewinding
	if _rewind_level <= 0.0:
		for player: AudioStreamPlayer in [_rewind, _gust]:
			if player.playing:
				player.stop()
		return
	if not _rewind.playing:
		return   # stopped from outside (the test runners before they quit)
	var pinned: bool = room_time != null and room_time.get("last_step") == TimeWorld.Step.PINNED
	var db := SoundRules.volume_db(config, sound_name) + linear_to_db(_rewind_level)
	if pinned:
		db += float(time_data.get("pinned_db", 0.0))   # at frame 0 the world stands
	var speed := float(manager.rewind_speed) if manager != null else 1.0
	_rewind.volume_db = db
	_rewind.pitch_scale = SoundRules.rewind_pitch(config, speed)
	_update_gust(delta, time_data, gust_name, speed, rewinding and not pinned, room_time)


## The strong layer of Shift's wind (C1): it grows as the rewind speeds up and
## as the world rolls back, and calms when the world stands at frame 0.
func _update_gust(delta: float, time_data: Dictionary, gust_name: String, speed: float, blowing: bool, room_time: Node) -> void:
	var room_sound: Node = room_time.get_parent().get_node_or_null("RoomSound") if room_time != null and room_time.get_parent() != null else null
	var motion: int = int(room_sound.get("motion")) if room_sound != null else 0
	var kicks: int = int(room_sound.call("take_kicks")) if room_sound != null else 0
	var speed_max := float(Content.time().get("rewind_speed_max", 1.0))
	var target := SoundRules.gust_target(time_data, speed, speed_max, motion) if blowing else 0.0
	_gust_level = SoundRules.gust_step(time_data, _gust_level, target, kicks if blowing else 0, delta)
	if not _gust.playing:
		return
	_gust.volume_db = SoundRules.volume_db(config, gust_name) + linear_to_db(maxf(_gust_level * _rewind_level, 0.0001))
	_gust.pitch_scale = _rewind.pitch_scale


## The hum of the hall, quieter in the menus; under Shift it crossfades into
## its reversed twin, so far clanks turn into swells.
func _update_ambience(delta: float, rewinding: bool) -> void:
	var ambience: Dictionary = config.get("ambience", {})
	var sound_name := str(ambience.get("sound", ""))
	if not _ambience.playing and not _ambience_rev.playing:
		return   # not started, or stopped from outside (the test runners before they quit)
	var fade := maxf(float(ambience.get("fade_seconds", 0.8)), 0.001)
	_ambience_level = move_toward(_ambience_level, 1.0, delta / fade)
	_ambience_mix = move_toward(_ambience_mix, 1.0 if rewinding else 0.0, delta / fade)
	var db := SoundRules.volume_db(config, sound_name) + (0.0 if _in_level else float(ambience.get("menu_db", 0.0)))
	db += linear_to_db(_ambience_level)
	_ambience.volume_db = db + linear_to_db(cos(_ambience_mix * PI / 2.0))
	_ambience_rev.volume_db = db + linear_to_db(sin(_ambience_mix * PI / 2.0))


## The hum starts once and loops for the whole game; both twins play at once
## and `_update_ambience` mixes them.
func _start_ambience() -> void:
	var sound_name := str((config.get("ambience", {}) as Dictionary).get("sound", ""))
	_ambience.stream = stream(sound_name)
	_ambience_rev.stream = stream(sound_name, true)
	_ambience.volume_db = -80.0
	_ambience_rev.volume_db = -80.0
	if _ambience.stream != null:
		_ambience.play()
	if _ambience_rev.stream != null:
		_ambience_rev.play()


func _on_node_added(node: Node) -> void:
	if node is RoomTime:
		_attach.call_deferred(node)
	elif node is BaseButton:
		_quiet_until = Time.get_ticks_msec() + QUIET_AFTER_BUTTON_MSEC
		(node as BaseButton).pressed.connect(_on_button_pressed)
		(node as BaseButton).focus_entered.connect(_on_button_focused)


func _attach(room_time: Node) -> void:
	if not is_instance_valid(room_time) or not room_time.is_inside_tree():
		return
	var parent := room_time.get_parent()
	if parent == null or parent.has_node("RoomSound"):
		return
	var room_sound := RoomSound.new()
	room_sound.setup(room_time as RoomTime, self)
	parent.add_child(room_sound)
	_room = room_time


## Every file of `sounds`, both ways, loaded once at the start (about 15 ms):
## the first Shift or the first lever must not wait for a file (D207).
func _preload() -> void:
	for sound_name: Variant in (config.get("sounds", {}) as Dictionary).keys():
		stream(str(sound_name))
		stream(str(sound_name), true)


## The streams loaded so far (tests).
func loaded_count() -> int:
	return _streams.size()


func _hush_menu() -> void:
	_quiet_until = Time.get_ticks_msec() + QUIET_AFTER_BUTTON_MSEC


func _on_button_pressed() -> void:
	_quiet_until = Time.get_ticks_msec() + QUIET_AFTER_BUTTON_MSEC
	play_global(str((config.get("ui", {}) as Dictionary).get("click", "")))


func _on_button_focused() -> void:
	var now := Time.get_ticks_msec()
	if now < _quiet_until:
		return
	var ui := config.get("ui", {}) as Dictionary
	# The mouse sweeping a list focuses every button it crosses: one tick per gap (C1).
	if not SoundRules.move_sounds(_last_move, now, float(ui.get("move_gap_seconds", 0.0))):
		return
	_last_move = now
	play_global(str(ui.get("move", "")))


func _on_level_started(_id: String) -> void:
	_in_level = true


func _on_level_finished(_id: String) -> void:
	play_global(str((config.get("ui", {}) as Dictionary).get("level_done", "")))


func _on_left_level() -> void:
	_in_level = false
	_room = null


func _player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player
