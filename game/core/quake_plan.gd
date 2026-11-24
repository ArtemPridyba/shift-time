class_name QuakePlan
extends RefCounted
## The quakes of a level (task Д4): moments of world time when the room shakes,
## and what falls down at them. Pure numbers, no nodes: `Quakes` (objects/)
## records the state, the look reads it.
##
## Data: `quakes` of the level's entry in `data/levels.json`:
##   "list": [{"second": 6, "strength": 0.35}, ...]  world seconds (D96), growing
##   "repeat_every_seconds", "repeat_strength"  after the last one listed, more
##       of them this far apart, for as long as the room runs (0: none)
##   "falls": [{"kind": "lamp", "lamp": n, ...} or {"kind": "lump", "at": [x, y], ...}]
##       `quake` (1-based) starts the fall, `delay_seconds` after its start;
##       `lamp` is the 1-based number in `world.lamps`, `at` is in cells;
##       `to_row` is the floor row it lands on.
## The look of a quake (how long it shakes, how fast things fall) is
## `kit_objects.quake` of `data/look.json`.

const FALL_KINDS: Array[String] = ["lamp", "lump"]

## Start ticks and strengths of the listed quakes.
var starts := PackedInt32Array()
var strengths := PackedFloat32Array()
var repeat_ticks := 0
var repeat_strength := 0.0
## Each: {"kind", "lamp" (0-based, lamps only), "at" (Vector2 cells, lumps
## only), "quake" (0-based), "delay" (ticks), "to_row" (float)}.
var falls: Array[Dictionary] = []


## The plan of `data` (the `quakes` of a level entry; anything else is an
## empty plan) with world seconds turned into ticks.
static func from_data(data: Variant, ticks_per_second: float) -> QuakePlan:
	var plan := QuakePlan.new()
	if not data is Dictionary:
		return plan
	for one: Variant in data.get("list", []):
		if one is Dictionary:
			plan.starts.append(int(round(float(one.get("second", 0.0)) * ticks_per_second)))
			plan.strengths.append(float(one.get("strength", 1.0)))
	plan.repeat_ticks = int(round(float(data.get("repeat_every_seconds", 0.0)) * ticks_per_second))
	plan.repeat_strength = float(data.get("repeat_strength", 0.0))
	for one: Variant in data.get("falls", []):
		if not one is Dictionary:
			continue
		var at: Array = one.get("at", [0, 0]) if one.get("at") is Array else [0, 0]
		plan.falls.append({
			"kind": str(one.get("kind", "")),
			"lamp": int(one.get("lamp", 0)) - 1,
			"at": Vector2(float(at[0]), float(at[1])) if at.size() == 2 else Vector2.ZERO,
			"quake": int(one.get("quake", 1)) - 1,
			"delay": int(round(float(one.get("delay_seconds", 0.0)) * ticks_per_second)),
			"to_row": float(one.get("to_row", 0.0)),
		})
	return plan


func is_empty() -> bool:
	return starts.is_empty()


## The quake that started last at world tick `tick`, or -1 before the first.
func index_at(tick: int) -> int:
	if starts.is_empty() or tick < starts[0]:
		return -1
	var last := starts.size() - 1
	for i in starts.size():
		if tick < starts[i]:
			return i - 1
	if repeat_ticks <= 0:
		return last
	return last + int((tick - starts[last]) / repeat_ticks)


## The world tick quake `index` starts on.
func start_tick(index: int) -> int:
	if index < 0 or starts.is_empty():
		return 0
	var last := starts.size() - 1
	if index <= last:
		return starts[index]
	return starts[last] + (index - last) * repeat_ticks


## How hard quake `index` shakes: 0 to 1.
func strength(index: int) -> float:
	if index < 0:
		return 0.0
	return strengths[index] if index < strengths.size() else repeat_strength


## Ticks since fall `fall` started, for the state (`index`, `since`) of
## `Quakes`: -1 before it starts; `done` once a later quake has come.
func fall_elapsed(fall: Dictionary, index: int, since: int, done: int) -> int:
	var quake := int(fall["quake"])
	if index < quake:
		return -1
	if index > quake:
		return done
	var elapsed := since - int(fall["delay"])
	return elapsed if elapsed >= 0 else -1


## The problems of `quakes` in a level entry: messages for the data check.
## `lamp_count` is the size of the level's `world.lamps`.
static func problems(data: Variant, where: String, lamp_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("%s: 'quakes' must be an object" % where)
		return errors
	var list: Variant = data.get("list")
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: 'quakes.list' must be a non-empty list" % where)
		return errors
	var before := -1.0
	for i in list.size():
		var one: Variant = list[i]
		var at := "%s: quakes.list[%d]" % [where, i]
		if not one is Dictionary or not _number(one.get("second")) or not _number(one.get("strength")):
			errors.append("%s needs numbers 'second' and 'strength'" % at)
			continue
		if float(one["second"]) <= before:
			errors.append("%s: 'second' must be later than the one before" % at)
		before = float(one["second"])
		if float(one["strength"]) <= 0.0 or float(one["strength"]) > 1.0:
			errors.append("%s: 'strength' must be above 0 and at most 1" % at)
	for key in ["repeat_every_seconds", "repeat_strength"]:
		if data.has(key) and (not _number(data[key]) or float(data[key]) < 0.0):
			errors.append("%s: 'quakes.%s' must be a number from 0" % [where, key])
	var falls: Variant = data.get("falls", [])
	if not falls is Array:
		errors.append("%s: 'quakes.falls' must be a list" % where)
		return errors
	for i in falls.size():
		var fall: Variant = falls[i]
		var at := "%s: quakes.falls[%d]" % [where, i]
		if not fall is Dictionary:
			errors.append("%s must be an object" % at)
			continue
		var kind := str(fall.get("kind", ""))
		if not kind in FALL_KINDS:
			errors.append("%s: 'kind' must be one of %s" % [at, FALL_KINDS])
		elif kind == "lamp" and (not _number(fall.get("lamp")) or int(fall["lamp"]) < 1 or int(fall["lamp"]) > lamp_count):
			errors.append("%s: 'lamp' must be a number of world.lamps, 1 to %d" % [at, lamp_count])
		elif kind == "lump":
			var cells: Variant = fall.get("at")
			if not cells is Array or cells.size() != 2 or not _number(cells[0]) or not _number(cells[1]):
				errors.append("%s: 'at' must be [x, y] in cells" % at)
		if not _number(fall.get("quake")) or int(fall["quake"]) < 1 or int(fall["quake"]) > list.size():
			errors.append("%s: 'quake' must be a number of quakes.list, 1 to %d" % [at, list.size()])
		if not _number(fall.get("to_row")):
			errors.append("%s needs the number 'to_row'" % at)
		if fall.has("delay_seconds") and (not _number(fall["delay_seconds"]) or float(fall["delay_seconds"]) < 0.0):
			errors.append("%s: 'delay_seconds' must be a number from 0" % at)
	return errors


static func _number(value: Variant) -> bool:
	return value is float or value is int
