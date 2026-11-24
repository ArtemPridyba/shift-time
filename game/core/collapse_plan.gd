class_name CollapsePlan
extends RefCounted
## The gallery of level 05 «Crane» (card docs/levels/05.md, D139): girders hang
## from the crane's rail as a walkway, each with its lamp on its chain. The
## runaway crane rides along the rail and its ram knocks each girder off when it
## reaches it; the girder falls and its lamp falls with it. Some girders land on
## stubs or on the floor and stay solid; the lost ones fall to the bottom of the
## pit. A girder may come down slowly and sideways (the ram drags it along the
## rail, then its chains run out): it first slides to above where it will lie,
## then sinks. A stopped crane knocks nothing further: the girders ahead of it
## keep hanging and their lamps keep shining.
##
## Counted per girder in ticks since the ram knocked it (`since`, -1 while it
## hangs): `Collapse` keeps these as its recorded state. The tick the ram
## reaches a girder is a phase of the crane's load (`reach_phase`). Pure numbers,
## no nodes.
##
## Data: `crane.collapse` of the level's entry in data/levels.json:
## { "lamps": [index in world.lamps of each girder's lamp, -1 for none, ...],
##   "girder_fall_seconds": seconds of the world clock a girder comes down, one
##   number for all or a list with one per girder }.
## The lamp's fall and shatter seconds are those of `kit_objects.quake` in
## look.json; the shake of the crane's slam into its stop: `kit_objects.collapse`.

var lamps: Array[int] = []
## Ticks each girder takes to come down; `fall_ticks` for girders past the list.
var falls: Array[int] = []
var fall_ticks := 1
var lamp_fall_ticks := 1
var shatter_ticks := 1
var shake_ticks := 1


static func from_data(data: Variant, ticks_per_second: float, quake: Dictionary, look: Dictionary) -> CollapsePlan:
	var plan := CollapsePlan.new()
	var d: Dictionary = data if data is Dictionary else {}
	for lamp: Variant in d.get("lamps", []):
		plan.lamps.append(int(lamp))
	var ticks := func(seconds: float) -> int:
		return maxi(int(round(seconds * ticks_per_second)), 1)
	var fall: Variant = d.get("girder_fall_seconds", 1.0)
	if fall is Array:
		for one: Variant in fall:
			plan.falls.append(ticks.call(float(one)))
		plan.fall_ticks = plan.falls.max() if not plan.falls.is_empty() else 1
	else:
		plan.fall_ticks = ticks.call(float(fall))
	plan.lamp_fall_ticks = ticks.call(float(quake.get("fall_seconds", 0.8)))
	plan.shatter_ticks = ticks.call(float(quake.get("shatter_seconds", 0.6)))
	plan.shake_ticks = ticks.call(float(look.get("shake_seconds", 1.2)))
	return plan


## The load phase on which a ram riding from `start_x` to `end_x` (after
## `delay_ticks`, over `move_ticks`) comes within `lead_px` of `x`; -1 if it
## never does. The crane's lamp strikes use the same reach (`CranePlan`).
static func reach_phase(start_x: float, end_x: float, delay_ticks: int, move_ticks: int, x: float, lead_px: float) -> int:
	var dir := signf(end_x - start_x)
	var length := absf(end_x - start_x)
	if length <= 0.0:
		return -1
	var reach := (x - start_x) * dir - lead_px
	if reach > length:
		return -1
	var at := 0 if reach <= 0.0 else int(ceil(reach / length * float(move_ticks)))
	return delay_ticks + mini(at, move_ticks)


## Ticks girder `k` takes to come down.
func fall_of(k: int) -> int:
	return falls[k] if k < falls.size() else fall_ticks


## How far girder `k` knocked `since` ticks ago has come down: 0 hanging … 1 lying.
func drop(k: int, since: int) -> float:
	if since < 0:
		return 0.0
	return clampf(float(since) / float(fall_of(k)), 0.0, 1.0)


## Where girder `k` is on its way down `since` ticks after the knock: x and y
## from 0 (hanging) to 1 (lying). It slides sideways first, then sinks faster
## and faster; a girder that falls straight down only sinks.
func path(k: int, since: int) -> Vector2:
	var x := drop(k, since)
	var across := clampf(x / 0.4, 0.0, 1.0)
	var down := clampf((x - 0.3) / 0.7, 0.0, 1.0)
	return Vector2(across * across * (3.0 - 2.0 * across), down * down)


## The tick from which every knocked girder and its lamp have come to rest.
func settled_tick() -> int:
	var longest := fall_ticks
	for one in falls:
		longest = maxi(longest, one)
	return maxi(longest, lamp_fall_ticks + shatter_ticks)


## The fall of the lamp of a girder knocked `since` ticks ago, as `WorldLight`
## reads it; it lands on row `to_row` where its girder lies.
func lamp_fall(since: int, to_row: float) -> Dictionary:
	if since < 0:
		return {"drop": 0.0, "light": 1.0, "shatter": 0.0, "to_row": to_row}
	var x := clampf(float(since) / float(lamp_fall_ticks), 0.0, 1.0)
	var shatter := clampf(float(since - lamp_fall_ticks) / float(shatter_ticks), 0.0, 1.0)
	return {"drop": x * x, "light": 1.0 - x, "shatter": shatter, "to_row": to_row}


## How hard the hall shakes `since` ticks after the crane slammed into its stop.
func shake(since: int) -> float:
	if since < 0 or since >= shake_ticks:
		return 0.0
	var x := float(since) / float(shake_ticks)
	return (1.0 - x) * (1.0 - x)


## Problems of the `collapse` data; `lamp_count`: lamps in the level's world.
static func problems(data: Variant, where: String, lamp_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("%s: 'crane.collapse' must be an object" % where)
		return errors
	var list: Variant = data.get("lamps")
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: 'crane.collapse.lamps' must list a lamp for each girder" % where)
	else:
		for lamp: Variant in list:
			if not (lamp is float or lamp is int) or int(lamp) < -1 or int(lamp) >= lamp_count:
				errors.append("%s: 'crane.collapse.lamps' must hold lamps of world.lamps (0..%d) or -1" % [where, lamp_count - 1])
	var fall: Variant = data.get("girder_fall_seconds")
	var fall_list: Array = fall if fall is Array else [fall]
	var fall_ok := not fall_list.is_empty()
	for one: Variant in fall_list:
		fall_ok = fall_ok and (one is float or one is int) and float(one) > 0.0
	if not fall_ok:
		errors.append("%s: 'crane.collapse.girder_fall_seconds' must be a number above 0 or a list of them" % where)
	return errors
