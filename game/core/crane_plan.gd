class_name CranePlan
extends RefCounted
## When the hook of a runaway crane strikes each lamp (level 09, card
## docs/levels/09.md): the crane's load is a `once` platform, and the hook
## hangs over the load's middle. A lamp is struck on the tick the hook comes
## within `hook_lead_px` of it; from there it falls `fall_ticks`, then shatters
## for `shatter_ticks`. Everything is a function of the load's recorded phase,
## so the crane itself keeps no history: under Shift the load rides back and
## the lamps fly up, after Shift is released the same strikes play again
## (rule «A»). Pure numbers, no nodes: tests check it headless.
##
## Data: `crane` of the level's entry in data/levels.json:
## { "load": object id of the platform, "hook_lead_px": number,
##   "falls": [{"lamp": index in world.lamps, "to_row": the floor row}, ...] }.
## The fall and shatter seconds are those of `kit_objects.quake` in look.json.

var load_id := ""
var hook_lead_px := 0.0
## Per entry of `falls`: {"lamp": int, "to_row": float, "hit": int (load phase)}.
var falls: Array[Dictionary] = []
var fall_ticks := 1
var shatter_ticks := 1


## A plan from the level's `crane` data; the strikes are set by `aim()`.
static func from_data(data: Variant, ticks_per_second: float, look: Dictionary) -> CranePlan:
	var plan := CranePlan.new()
	var crane: Dictionary = data if data is Dictionary else {}
	plan.load_id = str(crane.get("load", ""))
	plan.hook_lead_px = float(crane.get("hook_lead_px", 0.0))
	plan.fall_ticks = maxi(int(round(float(look.get("fall_seconds", 0.8)) * ticks_per_second)), 1)
	plan.shatter_ticks = maxi(int(round(float(look.get("shatter_seconds", 0.6)) * ticks_per_second)), 1)
	var list: Variant = crane.get("falls", [])
	for one: Variant in (list if list is Array else []):
		if one is Dictionary:
			plan.falls.append({"lamp": int(one.get("lamp", 0)), "to_row": float(one.get("to_row", 0.0)), "hit": -1})
	return plan


## Sets the load phase of every strike. `start_x` and `end_x`: where the load's
## middle starts and stops, `delay_ticks` and `move_ticks` as the platform's;
## `lamp_x[i]`: where lamp i hangs. A lamp the hook never reaches is never hit.
func aim(start_x: float, end_x: float, delay_ticks: int, move_ticks: int, lamp_x: Array) -> void:
	var dir := signf(end_x - start_x)
	var length := absf(end_x - start_x)
	for fall: Dictionary in falls:
		var lamp := int(fall["lamp"])
		fall["hit"] = -1
		if lamp < 0 or lamp >= lamp_x.size() or length <= 0.0:
			continue
		# How far the hook has to ride before it touches the lamp.
		var reach := (float(lamp_x[lamp]) - start_x) * dir - hook_lead_px
		if reach > length:
			continue
		var at := 0 if reach <= 0.0 else int(ceil(reach / length * float(move_ticks)))
		fall["hit"] = delay_ticks + mini(at, move_ticks)


## The fall of lamp `lamp` at load phase `phase`: {"drop", "light", "shatter",
## "to_row"} as `WorldLight` reads it (the same as `Quakes.lamp_fall`), or {}
## for a lamp the crane never strikes.
func lamp_fall(lamp: int, phase: int) -> Dictionary:
	for fall: Dictionary in falls:
		if int(fall["lamp"]) != lamp or int(fall["hit"]) < 0:
			continue
		var elapsed := phase - int(fall["hit"])
		if elapsed < 0:
			return {"drop": 0.0, "light": 1.0, "shatter": 0.0, "to_row": fall["to_row"]}
		var x := clampf(float(elapsed) / float(fall_ticks), 0.0, 1.0)
		var shatter := clampf(float(elapsed - fall_ticks) / float(shatter_ticks), 0.0, 1.0)
		# Falls with growing speed; the light dies on the way down.
		return {"drop": x * x, "light": 1.0 - x, "shatter": shatter, "to_row": fall["to_row"]}
	return {}


## The load phase on which the last lamp has finished shattering; -1 without strikes.
func last_phase() -> int:
	var last := -1
	for fall: Dictionary in falls:
		if int(fall["hit"]) >= 0:
			last = maxi(last, int(fall["hit"]) + fall_ticks + shatter_ticks)
	return last


## Problems of the `crane` data; `lamp_count`: lamps in the level's world.
static func problems(data: Variant, where: String, lamp_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("%s: 'crane' must be an object" % where)
		return errors
	if not data.get("load") is String or str(data["load"]).is_empty():
		errors.append("%s: 'crane.load' must be the object id of its platform" % where)
	var lead: Variant = data.get("hook_lead_px")
	if not (lead is float or lead is int) or float(lead) < 0.0:
		errors.append("%s: 'crane.hook_lead_px' must be a number from 0" % where)
	var list: Variant = data.get("falls")
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: 'crane.falls' must be a non-empty list" % where)
		return errors
	for i in list.size():
		var one: Variant = list[i]
		var at := "%s: crane.falls[%d]" % [where, i]
		if not one is Dictionary or not (one.get("lamp") is float or one.get("lamp") is int) \
				or not (one.get("to_row") is float or one.get("to_row") is int):
			errors.append("%s needs numbers 'lamp' and 'to_row'" % at)
			continue
		if int(one["lamp"]) < 0 or int(one["lamp"]) >= lamp_count:
			errors.append("%s: 'lamp' must be a lamp of world.lamps (0..%d)" % [at, lamp_count - 1])
	return errors
