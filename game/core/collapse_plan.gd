class_name CollapsePlan
extends RefCounted
## The collapse of level 05 «Crane» (card docs/levels/05.md, D144): three
## quakes, three acts. Pure numbers, no nodes: `Collapse` (objects/) records
## two counters and asks this plan where everything is.
##
## Act 1, from the room's start (`clock`, ticks since the room began): the
## first quake, then the hanging platforms fall one by one, each followed by
## the lamp beside it; the last platform breaks on its stub and soon crumbles
## into the pit.
## Act 2, from the heroine's step onto the crane (`ride`, ticks since that
## step, -1 before it): the second quake, the crane breaks loose and rides down
## its sloping rail; the lamps over the rail fall as it passes under them.
## Act 3, from the crane's arrival at the end of the rail: the third quake, the
## crane sags and falls, the ceiling comes down in chunks, lamps fall among
## them still shining, and for a while the world runs slow (variant A: only the
## world, never the heroine). Act 3 is counted on a slowed clock: `slow_ticks`
## turns real ticks since the arrival into ticks of the world.
##
## Data: `collapse` of the level's entry in data/levels.json:
## { "quake_seconds": act 1's quake after the room's start,
##   "pieces": [{"act": 1 or 3, "second": after the act's quake,
##       "fall_seconds", "kind": "drop" (falls faster and faster) or "sink"
##       (slides down at an even speed), "breaks": bool (cracks on landing),
##       "crumble_seconds": how long it lies before it crumbles into the
##       pit (absent: never)}, ...] — one per piece of the scene, in order;
##   "lamps": [{"lamp", "act": 1 or 3, "second" after the act's quake,
##       "to_row", "fall_seconds" (absent: the kit's), "lit": shines on its
##       way down}] lamps that fall on their own;
##   "crane": {"delay_seconds" from the step to setting off, "speed" px per
##       world second, "lamps": [lamps over the rail], "lamp_lead_px",
##       "lamp_to_row", "sag_seconds", "sag_px", "tilt_degrees",
##       "fall_second" after act 3's quake, "fall_seconds"};
##   "slow": {"from_seconds" after act 3's quake, "ease_seconds", "tempo",
##       "hold_seconds"}: the world's tempo eases down to `tempo`, holds, eases
##       back (`slow_ticks`); these seconds run on the heroine's clock }.
## Seconds are of the world clock (D96). Lamp fall and shatter seconds:
## `kit_objects.quake` in look.json; the shake: `kit_objects.collapse`.

const KINDS: Array[String] = ["drop", "sink"]
## Share of a sinking piece's way spent speeding up from rest.
const SINK_EASE := 0.08

var quake_tick := 1
## Per piece: {"act", "at" (ticks after the act's quake), "fall" (ticks),
## "kind", "breaks", "crumble" (ticks lying before it crumbles, 0: never)}.
var pieces: Array[Dictionary] = []
## Lamps falling on their own: {"lamp", "act", "at", "to_row", "fall", "lit"}.
var lamps: Array[Dictionary] = []
var ride_delay := 1
## Pixels per tick the crane rides; ticks it takes (set by `aim`).
var ride_step := 1.0
var ride_ticks := 1
var crane_lamps: Array[int] = []
## Ride tick on which each of `crane_lamps` falls (set by `aim`, -1: never).
var crane_hits: Array[int] = []
var lamp_lead_px := 0.0
var lamp_to_row := 20.0
var sag_ticks := 1
var sag_px := 0.0
var tilt_degrees := 0.0
var crane_fall_at := 0
var crane_fall_ticks := 1
## The slow part of act 3, in real ticks since the crane's arrival.
var slow_from := 0
var slow_ease := 1
var slow_hold := 0
var tempo := 1.0
var lamp_fall_ticks := 1
var shatter_ticks := 1
var shake_ticks := 1
## Counters stop here, so the room stands still once all is down (D56).
var clock_end := 1
var ride_end := 1


static func from_data(data: Variant, ticks_per_second: float, quake: Dictionary, look: Dictionary) -> CollapsePlan:
	var plan := CollapsePlan.new()
	var d: Dictionary = data if data is Dictionary else {}
	var ticks := func(seconds: Variant) -> int:
		return maxi(int(round(float(seconds) * ticks_per_second)), 0)
	plan.quake_tick = ticks.call(d.get("quake_seconds", 1.0))
	for one: Variant in d.get("pieces", []):
		var p: Dictionary = one if one is Dictionary else {}
		plan.pieces.append({"act": int(p.get("act", 1)), "at": ticks.call(p.get("second", 0.0)),
			"fall": maxi(ticks.call(p.get("fall_seconds", 1.0)), 1), "kind": str(p.get("kind", "drop")),
			"breaks": bool(p.get("breaks", false)), "crumble": ticks.call(p.get("crumble_seconds", 0.0))})
	plan.lamp_fall_ticks = maxi(ticks.call(quake.get("fall_seconds", 0.8)), 1)
	for one: Variant in d.get("lamps", []):
		var l: Dictionary = one if one is Dictionary else {}
		var fall: int = plan.lamp_fall_ticks if not l.has("fall_seconds") else maxi(ticks.call(l["fall_seconds"]), 1)
		plan.lamps.append({"lamp": int(l.get("lamp", 0)), "act": int(l.get("act", 1)), "at": ticks.call(l.get("second", 0.0)),
			"to_row": float(l.get("to_row", 20.0)), "fall": fall, "lit": bool(l.get("lit", false))})
	var crane: Dictionary = d.get("crane", {}) if d.get("crane", {}) is Dictionary else {}
	plan.ride_delay = ticks.call(crane.get("delay_seconds", 1.0))
	plan.ride_step = maxf(float(crane.get("speed", 100.0)), 1.0) / ticks_per_second
	for lamp: Variant in crane.get("lamps", []):
		plan.crane_lamps.append(int(lamp))
	plan.lamp_lead_px = float(crane.get("lamp_lead_px", 0.0))
	plan.lamp_to_row = float(crane.get("lamp_to_row", 20.0))
	plan.sag_ticks = maxi(ticks.call(crane.get("sag_seconds", 1.0)), 1)
	plan.sag_px = float(crane.get("sag_px", 0.0))
	plan.tilt_degrees = float(crane.get("tilt_degrees", 0.0))
	plan.crane_fall_at = ticks.call(crane.get("fall_second", 1.0))
	plan.crane_fall_ticks = maxi(ticks.call(crane.get("fall_seconds", 1.0)), 1)
	var slow: Dictionary = d.get("slow", {}) if d.get("slow", {}) is Dictionary else {}
	plan.slow_from = ticks.call(slow.get("from_seconds", 0.0))
	plan.slow_ease = maxi(ticks.call(slow.get("ease_seconds", 0.5)), 1)
	plan.slow_hold = ticks.call(slow.get("hold_seconds", 0.0))
	plan.tempo = clampf(float(slow.get("tempo", 1.0)), 0.01, 1.0)
	plan.shatter_ticks = maxi(ticks.call(quake.get("shatter_seconds", 0.6)), 1)
	plan.shake_ticks = maxi(ticks.call(look.get("shake_seconds", 1.2)), 1)
	plan.clock_end = plan.quake_tick + plan.shake_ticks
	for p in plan.pieces:
		if int(p["act"]) == 1:
			var crumble := int(p["crumble"]) + int(p["fall"]) if int(p["crumble"]) > 0 else 0
			plan.clock_end = maxi(plan.clock_end, plan.quake_tick + int(p["at"]) + int(p["fall"]) + crumble + plan.shatter_ticks)
	for l in plan.lamps:
		if int(l["act"]) == 1:
			plan.clock_end = maxi(plan.clock_end, plan.quake_tick + int(l["at"]) + int(l["fall"]) + plan.shatter_ticks)
	return plan


## Aims the crane: it rides `travel_px` pixels from `start_x` (its middle);
## `lamp_x` are the x of every lamp of the world.
func aim(start_x: float, travel: Vector2, lamp_x: Array) -> void:
	ride_ticks = maxi(int(ceil(travel.length() / ride_step)), 1)
	crane_hits.clear()
	for lamp in crane_lamps:
		var hit := -1
		if lamp >= 0 and lamp < lamp_x.size() and absf(travel.x) > 0.0:
			for t in range(ride_delay, ride_delay + ride_ticks + 1):
				if (start_x + crane_way(t) * travel.x - float(lamp_x[lamp]) + lamp_lead_px * signf(travel.x)) * signf(travel.x) >= 0.0:
					hit = t
					break
		crane_hits.append(hit)
	# The last thing of act 3 to come to rest, in its own (slowed) ticks.
	var last := crane_fall_at + crane_fall_ticks + shake_ticks
	for p in pieces:
		if int(p["act"]) == 3:
			last = maxi(last, int(p["at"]) + int(p["fall"]) + shatter_ticks)
	for l in lamps:
		if int(l["act"]) == 3:
			last = maxi(last, int(l["at"]) + int(l["fall"]) + shatter_ticks)
	var real := 0
	while slow_ticks(float(real)) < float(last) and real < 100000:
		real += 1
	ride_end = arrival() + real
	for hit in crane_hits:
		ride_end = maxi(ride_end, hit + lamp_fall_ticks + shatter_ticks)


## The ride tick on which the crane reaches the end of its rail.
func arrival() -> int:
	return ride_delay + ride_ticks


## How far along its rail the crane is at ride tick `ride`: 0 … 1. It breaks
## loose slowly, then rides at an even speed.
func crane_way(ride: int) -> float:
	if ride < ride_delay:
		return 0.0
	return _eased(float(ride - ride_delay) / float(ride_ticks), 0.15)


## Ticks of act 3's world (slowed) for `ride`; -1 before the crane arrives.
func act3(ride: int) -> float:
	if ride < arrival():
		return -1.0
	return slow_ticks(float(ride - arrival()))


## World ticks that have passed `real` ticks after the crane's arrival: the
## world's tempo eases from 1 down to `tempo` from `slow_from`, holds it for
## `slow_hold`, eases back to 1.
func slow_ticks(real: float) -> float:
	var a := float(slow_from)
	var e := float(slow_ease)
	var h := float(slow_hold)
	var k := tempo
	var tau := minf(real, a)
	if real > a:
		var x := minf(real - a, e)
		tau += x - (1.0 - k) * x * x / (2.0 * e)
	if real > a + e:
		tau += minf(real - a - e, h) * k
	if real > a + e + h:
		var x := minf(real - a - e - h, e)
		tau += k * x + (1.0 - k) * x * x / (2.0 * e)
	if real > a + 2.0 * e + h:
		tau += real - a - 2.0 * e - h
	return tau


## How slow the world runs now, for the look: 0 normal … 1 at the slowest.
func slowness(ride: int) -> float:
	if ride < arrival() or tempo >= 1.0:
		return 0.0
	var r := float(ride - arrival())
	var a := float(slow_from)
	var e := float(slow_ease)
	var h := float(slow_hold)
	if r < a or r > a + 2.0 * e + h:
		return 0.0
	if r < a + e:
		return (r - a) / e
	if r < a + e + h:
		return 1.0
	return 1.0 - (r - a - e - h) / e


## Ticks since piece `k` broke off, on its act's clock; < 0 while it hangs.
func since(k: int, clock: int, ride: int) -> float:
	var p := pieces[k]
	if int(p["act"]) == 1:
		return float(clock - quake_tick - int(p["at"]))
	var t := act3(ride)
	return -1.0 if t < 0.0 else t - float(p["at"])


## How far piece `k` has come down: 0 hanging … 1 lying.
func drop(k: int, clock: int, ride: int) -> float:
	var s := since(k, clock, ride)
	if s < 0.0:
		return 0.0
	return clampf(s / float(pieces[k]["fall"]), 0.0, 1.0)


## How far down its way piece `k` is: 0 … 1 (a dropping piece falls faster and
## faster, a sinking one slides at an even speed once it has started).
func way(k: int, clock: int, ride: int) -> float:
	var x := drop(k, clock, ride)
	if str(pieces[k]["kind"]) == "sink":
		return _eased(x, SINK_EASE)
	return x * x


## How far piece `k` has crumbled into the pit: 0 whole (or never crumbles)
## … 1 its debris gone below; it crumbles `crumble` ticks after it landed and
## its debris falls as long as the piece fell.
func crumble(k: int, clock: int, ride: int) -> float:
	var wait := int(pieces[k]["crumble"])
	if wait <= 0:
		return 0.0
	var s := since(k, clock, ride) - float(int(pieces[k]["fall"]) + wait)
	return clampf(s / float(pieces[k]["fall"]), 0.0, 1.0)


## How broken piece `k` is: 0 whole … 1 broken on its stub (only `breaks`).
func broken(k: int, clock: int, ride: int) -> float:
	if not bool(pieces[k]["breaks"]):
		return 0.0
	var x := drop(k, clock, ride)
	return 1.0 if x >= 1.0 else clampf((x - 0.9) * 10.0, 0.0, 1.0)


## Where the crane is at `ride`: its offset in pixels from the start along
## `travel`, plus its sag at the end of the rail and its fall into the pit by
## `fall_px`. "tilt" is in radians (for the look).
func crane_pose(ride: int, travel: Vector2, fall_px: float) -> Dictionary:
	var at := travel * crane_way(ride)
	var tilt := 0.0
	var t := act3(ride)
	if t >= 0.0:
		var sag := clampf(t / float(sag_ticks), 0.0, 1.0)
		at.y += sag_px * sag
		tilt = deg_to_rad(tilt_degrees) * sag
		var f := clampf((t - float(crane_fall_at)) / float(crane_fall_ticks), 0.0, 1.0)
		at.y += fall_px * f * f
		tilt *= 1.0 + 2.0 * f
	return {"at": at, "tilt": tilt, "falling": t >= float(crane_fall_at), "down": crane_down(ride)}


## True once the crane lies at the bottom of the pit.
func crane_down(ride: int) -> bool:
	return act3(ride) >= float(crane_fall_at + crane_fall_ticks)


## The fall of lamp `lamp` now, as `WorldLight` reads it, or {} when this
## plan never drops it. A lamp carried by a piece gets "way" instead of a
## row: `Collapse` turns it into the piece's way down.
func lamp_fall(lamp: int, clock: int, ride: int) -> Dictionary:
	for l in lamps:
		if int(l["lamp"]) == lamp:
			var s := float(clock - quake_tick - int(l["at"]))
			if int(l["act"]) == 3:
				var t := act3(ride)
				s = -1.0 if t < 0.0 else t - float(l["at"])
			return _fall(s, float(l["to_row"]), int(l["fall"]), bool(l["lit"]))
	var i := crane_lamps.find(lamp)
	if i >= 0:
		var hit := crane_hits[i] if i < crane_hits.size() else -1
		return _fall(-1.0 if hit < 0 or ride < hit else float(ride - hit), lamp_to_row, lamp_fall_ticks, false)
	return {}


## How hard the hall shakes now: 0 to 1, from the latest of the three quakes.
func shake(clock: int, ride: int) -> float:
	var amount := _shake(clock - quake_tick)
	if ride >= 0:
		amount = maxf(amount, _shake(ride))
		amount = maxf(amount, _shake(ride - arrival()))
	return amount


## Ticks since the latest quake began (for the sway of the look), -1 before any.
func since_quake(clock: int, ride: int) -> int:
	if ride >= arrival():
		return ride - arrival()
	if ride >= 0:
		return ride
	return clock - quake_tick if clock >= quake_tick else -1


func _shake(since_quake_tick: int) -> float:
	if since_quake_tick < 0 or since_quake_tick >= shake_ticks:
		return 0.0
	var x := float(since_quake_tick) / float(shake_ticks)
	return (1.0 - x) * (1.0 - x)


## A lamp `since_tick` ticks after it broke loose, falling `fall` ticks onto
## `to_row`; a `lit` one shines all the way down, the others die out on the way.
func _fall(since_tick: float, to_row: float, fall: int, lit: bool) -> Dictionary:
	if since_tick < 0.0:
		return {"drop": 0.0, "light": 1.0, "shatter": 0.0, "to_row": to_row}
	var x := clampf(since_tick / float(fall), 0.0, 1.0)
	var shatter := clampf((since_tick - float(fall)) / float(shatter_ticks), 0.0, 1.0)
	var light := (0.0 if x >= 1.0 else 1.0) if lit else 1.0 - x
	return {"drop": x * x, "light": light, "shatter": shatter, "to_row": to_row}


## 0 … 1 with a gentle start over the first `ease` of the way, even after it.
static func _eased(x: float, ease: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x < ease:
		return x * x / (2.0 * ease) / (1.0 - ease / 2.0)
	return (x - ease / 2.0) / (1.0 - ease / 2.0)


## Problems of the `collapse` data; `lamp_count`: lamps in the level's world.
static func problems(data: Variant, where: String, lamp_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("%s: 'collapse' must be an object" % where)
		return errors
	var d: Dictionary = data
	var lamp_ok := func(lamp: Variant) -> bool:
		return (lamp is float or lamp is int) and int(lamp) >= -1 and int(lamp) < lamp_count
	var positive := func(value: Variant) -> bool:
		return (value is float or value is int) and float(value) > 0.0
	var not_negative := func(value: Variant) -> bool:
		return (value is float or value is int) and float(value) >= 0.0
	if not not_negative.call(d.get("quake_seconds")):
		errors.append("%s: 'collapse.quake_seconds' must be a number from 0" % where)
	var list: Variant = d.get("pieces")
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: 'collapse.pieces' must list the falling pieces" % where)
	else:
		for one: Variant in list:
			var p: Dictionary = one if one is Dictionary else {}
			if not (p.get("act") is float or p.get("act") is int) or not int(p.get("act")) in [1, 3]:
				errors.append("%s: each of 'collapse.pieces' needs 'act' 1 or 3" % where)
			if not not_negative.call(p.get("second")) or not positive.call(p.get("fall_seconds")):
				errors.append("%s: each of 'collapse.pieces' needs 'second' from 0 and 'fall_seconds' above 0" % where)
			if not str(p.get("kind", "drop")) in KINDS:
				errors.append("%s: 'collapse.pieces' kind must be one of %s" % [where, KINDS])
			if p.has("crumble_seconds") and not positive.call(p.get("crumble_seconds")):
				errors.append("%s: 'collapse.pieces' crumble_seconds must be a number above 0" % where)
	for one: Variant in d.get("lamps", []):
		var l: Dictionary = one if one is Dictionary else {}
		if not lamp_ok.call(l.get("lamp")) or int(l.get("lamp", -1)) < 0 or not not_negative.call(l.get("second")) or not positive.call(l.get("to_row")):
			errors.append("%s: each of 'collapse.lamps' needs a 'lamp' of world.lamps, 'second' and 'to_row'" % where)
		if not int(l.get("act", 1)) in [1, 3] or (l.has("fall_seconds") and not positive.call(l.get("fall_seconds"))):
			errors.append("%s: 'collapse.lamps' act must be 1 or 3 and fall_seconds above 0" % where)
	var crane: Variant = d.get("crane")
	if not crane is Dictionary:
		errors.append("%s: 'collapse.crane' must be an object" % where)
	else:
		var c: Dictionary = crane
		for key: String in ["speed", "sag_seconds", "fall_seconds", "lamp_to_row"]:
			if not positive.call(c.get(key)):
				errors.append("%s: 'collapse.crane.%s' must be a number above 0" % [where, key])
		for key: String in ["delay_seconds", "fall_second", "sag_px", "lamp_lead_px", "tilt_degrees"]:
			if not not_negative.call(c.get(key)):
				errors.append("%s: 'collapse.crane.%s' must be a number from 0" % [where, key])
		for lamp: Variant in c.get("lamps", []):
			if not lamp_ok.call(lamp) or int(lamp) < 0:
				errors.append("%s: 'collapse.crane.lamps' must hold lamps of world.lamps" % where)
	var slow: Variant = d.get("slow")
	if not slow is Dictionary:
		errors.append("%s: 'collapse.slow' must be an object" % where)
	else:
		var s: Dictionary = slow
		var t: Variant = s.get("tempo")
		if not (t is float or t is int) or float(t) <= 0.0 or float(t) > 1.0:
			errors.append("%s: 'collapse.slow.tempo' must be above 0 and at most 1" % where)
		for key: String in ["from_seconds", "hold_seconds"]:
			if not not_negative.call(s.get(key)):
				errors.append("%s: 'collapse.slow.%s' must be a number from 0" % [where, key])
		if not positive.call(s.get("ease_seconds")):
			errors.append("%s: 'collapse.slow.ease_seconds' must be a number above 0" % where)
	return errors
