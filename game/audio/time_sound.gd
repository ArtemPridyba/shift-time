class_name TimeSound
extends Node
## The place for the sounds of the two directions of time. Task 1.5 leaves the
## sounds out: while `audio.forward` and `audio.rewind` in `data/time_hud.json`
## are empty, nothing plays and nothing breaks. To add a sound, put the file in
## `game/audio/` and write its path in the data file; the data check reports a
## path to a missing file.
##
## `TimeHud` creates one and calls `play_for` when the direction changes.

var _players: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	var audio := config.get("audio", {}) as Dictionary
	for entry: Array in [["forward", TimeIndicatorState.FORWARD], ["rewind", TimeIndicatorState.BACKWARD]]:
		var path := str(audio.get(entry[0], ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.name = "Sound_%s" % entry[0]
		add_child(player)
		_players[entry[1]] = player


## Starts the sound of `direction` and stops the other one. True if a sound started.
func play_for(direction: int) -> bool:
	for key: Variant in _players:
		(_players[key] as AudioStreamPlayer).stop()
	var player := _players.get(direction) as AudioStreamPlayer
	if player == null:
		return false
	player.play()
	return true


func has_sound(direction: int) -> bool:
	return _players.has(direction)
