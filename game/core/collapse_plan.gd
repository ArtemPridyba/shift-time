class_name CollapsePlan
extends RefCounted
## When the girders and lamps fall after the runaway crane of level 05 slams
## into the stop at the end of its rail (card docs/levels/05.md, D135). Counted
## in ticks since the slam (`since`): first the girders fall one by one from the
## stop towards the exit and land as a broken bridge over the pit, then, after a
## pause, the lamps over the pit break one by one from the exit back towards the
## stop. Then the bridge goes (D137): after a pause the girders slip off their
## stubs one by one from the stop towards the exit and fall into the pit, each
## shuddering first. So the bridge lies only for a while: in the present the pit
## is empty and dark. A short Shift pushes the slipping back (the girder that
## slipped last comes back first); a long one lifts the girders still ahead back
## to the roof, the last to land first. Pure numbers, no nodes.
##
## Data: `crane.collapse` of the level's entry in data/levels.json:
## { "lamps": [index in world.lamps, ... from the stop to the exit],
##   "to_row": the row the lamps fall to (below the room: into the pit),
##   "girder_first_seconds", "girder_every_seconds", "girder_fall_seconds",
##   "lamp_pause_seconds" (from the last girder landing to the first lamp),
##   "lamp_every_seconds", "slip_pause_seconds" (from the last girder landing
##   to the first girder slipping), "slip_every_seconds", "slip_warn_seconds"
##   (it shudders this long before it slips), "slip_fall_seconds" }. Seconds of
##   the world clock. The lamp's fall and
## shatter seconds are those of `kit_objects.quake` in look.json.

const NUMBERS: Array[String] = ["girder_first_seconds", "girder_every_seconds", "girder_fall_seconds",
	"lamp_pause_seconds", "lamp_every_seconds", "slip_pause_seconds", "slip_every_seconds",
	"slip_warn_seconds", "slip_fall_seconds"]

var lamps: Array[int] = []
var to_row := 0.0
var girder_first := 0
var girder_every := 1
var girder_fall := 1
var lamp_pause := 0
var lamp_every := 1
var slip_pause := 0
var slip_every := 1
var slip_warn := 1
var slip_fall := 1
var fall_ticks := 1
var shatter_ticks := 1
var girder_count := 0


static func from_data(data: Variant, ticks_per_second: float, look: Dictionary, girders: int) -> CollapsePlan:
	var plan := CollapsePlan.new()
	var d: Dictionary = data if data is Dictionary else {}
	for lamp: Variant in d.get("lamps", []):
		plan.lamps.append(int(lamp))
	plan.to_row = float(d.get("to_row", 0.0))
	var ticks := func(key: String, fallback: float) -> int:
		return maxi(int(round(float(d.get(key, fallback)) * ticks_per_second)), 1)
	plan.girder_first = ticks.call("girder_first_seconds", 0.2)
	plan.girder_every = ticks.call("girder_every_seconds", 0.4)
	plan.girder_fall = ticks.call("girder_fall_seconds", 0.5)
	plan.lamp_pause = ticks.call("lamp_pause_seconds", 1.0)
	plan.lamp_every = ticks.call("lamp_every_seconds", 0.9)
	plan.slip_pause = ticks.call("slip_pause_seconds", 3.0)
	plan.slip_every = ticks.call("slip_every_seconds", 1.2)
	plan.slip_warn = ticks.call("slip_warn_seconds", 0.8)
	plan.slip_fall = ticks.call("slip_fall_seconds", 0.8)
	plan.fall_ticks = maxi(int(round(float(look.get("fall_seconds", 0.8)) * ticks_per_second)), 1)
	plan.shatter_ticks = maxi(int(round(float(look.get("shatter_seconds", 0.6)) * ticks_per_second)), 1)
	plan.girder_count = girders
	return plan


## The tick girder `k` (0 nearest the stop) starts to fall.
func girder_start(k: int) -> int:
	return girder_first + k * girder_every


## The tick the last girder has landed.
func girders_landed() -> int:
	return girder_start(maxi(girder_count - 1, 0)) + girder_fall


## How far girder `k` has fallen at `since`: 0 hanging … 1 lying, faster and faster.
func girder_drop(k: int, since: int) -> float:
	if since < 0:
		return 0.0
	var x := clampf(float(since - girder_start(k)) / float(girder_fall), 0.0, 1.0)
	return x * x


## The tick girder `k` slips off its stub: the one nearest the stop first.
func girder_slip(k: int) -> int:
	return girders_landed() + slip_pause + k * slip_every


## How far girder `k` has slid off into the pit at `since`: 0 still on its
## stub … 1 at the bottom, faster and faster.
func girder_slide(k: int, since: int) -> float:
	if since < 0:
		return 0.0
	var x := clampf(float(since - girder_slip(k)) / float(slip_fall), 0.0, 1.0)
	return x * x


## How hard girder `k` shudders at `since` before it slips: 0 … 1 at the slip.
func girder_shudder(k: int, since: int) -> float:
	if since < 0 or since >= girder_slip(k):
		return 0.0
	return clampf(1.0 - float(girder_slip(k) - since) / float(slip_warn), 0.0, 1.0)


## True while girder `k` lies on its stub and holds the heroine.
func girder_lies(k: int, since: int) -> bool:
	return girder_drop(k, since) >= 1.0 and girder_slide(k, since) <= 0.0


## The tick lamp number `i` of `lamps` is torn: the last of the list first.
func lamp_hit(i: int) -> int:
	return girders_landed() + lamp_pause + (lamps.size() - 1 - i) * lamp_every


## The fall of world lamp `lamp` at `since`, as `WorldLight` reads it, or {}
## for a lamp the collapse never touches.
func lamp_fall(lamp: int, since: int) -> Dictionary:
	var i := lamps.find(lamp)
	if i < 0:
		return {}
	var elapsed := since - lamp_hit(i) if since >= 0 else -1
	if elapsed < 0:
		return {"drop": 0.0, "light": 1.0, "shatter": 0.0, "to_row": to_row}
	var x := clampf(float(elapsed) / float(fall_ticks), 0.0, 1.0)
	var shatter := clampf(float(elapsed - fall_ticks) / float(shatter_ticks), 0.0, 1.0)
	return {"drop": x * x, "light": 1.0 - x, "shatter": shatter, "to_row": to_row}


## The tick everything has come down: the collapse's state stands from here.
func last_tick() -> int:
	var last := girders_landed()
	if girder_count > 0:
		last = maxi(last, girder_slip(girder_count - 1) + slip_fall)
	if not lamps.is_empty():
		last = maxi(last, lamp_hit(0) + fall_ticks + shatter_ticks)
	return last


## Problems of the `collapse` data; `lamp_count`: lamps in the level's world.
static func problems(data: Variant, where: String, lamp_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("%s: 'crane.collapse' must be an object" % where)
		return errors
	var list: Variant = data.get("lamps")
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: 'crane.collapse.lamps' must be a non-empty list" % where)
	else:
		for lamp: Variant in list:
			if not (lamp is float or lamp is int) or int(lamp) < 0 or int(lamp) >= lamp_count:
				errors.append("%s: 'crane.collapse.lamps' must hold lamps of world.lamps (0..%d)" % [where, lamp_count - 1])
	var row: Variant = data.get("to_row")
	if not (row is float or row is int):
		errors.append("%s: 'crane.collapse.to_row' must be a number" % where)
	for key: String in NUMBERS:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or float(value) <= 0.0:
			errors.append("%s: 'crane.collapse.%s' must be a number above 0" % [where, key])
	return errors
