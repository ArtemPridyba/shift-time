class_name SolutionScript
extends RefCounted
## One recorded solution of a level (`tests/solutions/level_NN.json`, the same
## file the headless solution test plays): which actions are held on which
## physics tick of the level. Used by the in-game replay (`SolutionReplay`,
## task И1 27.11.2026), which plays it in the real game, in the browser too.
##
##   { "level": "level_01", "expect": "exit",
##     "segments": [ { "actions": ["move_right", "rewind"], "ticks": 90 } ] }
##
## Tick 0 is the first physics tick of the level's scene. The level stands
## without input for `settle_ticks` first, as in the headless test, then the
## segments follow one after another.

const SOLUTIONS_DIR := "res://tests/solutions"
## The request that plays every level of the list in order.
const CHAPTER := "chapter"

var level := ""
## [[actions: Array, ticks: int], ...]
var segments: Array = []
var settle_ticks := 1


## A solution from the data of its file; null when the data is broken.
static func from_data(data: Variant, settle := 1) -> SolutionScript:
	if not problems(data).is_empty():
		return null
	var script := SolutionScript.new()
	script.level = str(data["level"])
	script.settle_ticks = maxi(settle, 0)
	for segment: Variant in data["segments"]:
		script.segments.append([(segment["actions"] as Array).duplicate(), int(segment["ticks"])])
	return script


## The solution file of a level (`level_01` → `tests/solutions/level_01.json`),
## or null when it is missing or broken.
static func for_level(id: String, settle := 1) -> SolutionScript:
	var path := SOLUTIONS_DIR.path_join(id.trim_suffix(".json") + ".json")
	if not FileAccess.file_exists(path):
		return null
	return from_data(Content.load_json(path), settle)


## What is wrong with a solution's data, for the replay; empty when it plays.
## The headless test checks the files more strictly (test_solutions.gd).
static func problems(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary or not data.get("level") is String or not data.get("segments") is Array:
		errors.append("expected an object with 'level' and 'segments'")
		return errors
	if (data["segments"] as Array).is_empty():
		errors.append("no segments")
	for segment: Variant in data["segments"]:
		if not segment is Dictionary or not segment.get("actions") is Array or not Content._is_number(segment.get("ticks")):
			errors.append("a segment needs 'actions' (a list) and 'ticks' (a number)")
		elif int(segment["ticks"]) < 1:
			errors.append("a segment needs at least one tick")
	return errors


## Level ids a request names, in order: `chapter` is every id of `order`,
## otherwise ids separated by commas (`level_01,level_03`). Unknown ids are
## dropped, so a mistyped request plays nothing.
static func levels_for(request: String, order: Array) -> Array[String]:
	var ids: Array[String] = []
	var text := request.strip_edges()
	if text == CHAPTER:
		for id: Variant in order:
			ids.append(str(id))
		return ids
	for part in text.split(",", false):
		var id := part.strip_edges().trim_suffix(".json")
		if id in order and not id in ids:
			ids.append(id)
	return ids


## The tick after the last segment: the solution has ended by then.
func end_tick() -> int:
	var total := settle_ticks
	for segment: Array in segments:
		total += int(segment[1])
	return total


## Actions held on this tick of the level; empty before the first segment and
## after the last.
func actions_at(tick: int) -> Array:
	var from := settle_ticks
	if tick < from:
		return []
	for segment: Array in segments:
		var to := from + int(segment[1])
		if tick < to:
			return segment[0]
		from = to
	return []


## Every action the solution ever holds.
func all_actions() -> Array:
	var all := []
	for segment: Array in segments:
		for action: Variant in segment[0]:
			if not action in all:
				all.append(action)
	return all
