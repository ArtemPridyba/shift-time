class_name FireLook
extends RefCounted
## The look of a wood zone on fire (task 2.7А): how strong the flames are,
## sparks, smoke, the ash of a zone that burns out, the steam of a fire put out.
## Decoration only: nothing here is recorded and nothing changes the world.
##
## Everything is a function of world time and of the recorded state of the
## zone (phase, burn ticks, the frame it burnt out on, the frame its fire was
## put out on), so the same world tick looks the same going forward and
## rewinding: under Shift sparks fall back into the wood, smoke and steam sink
## back into it, the ash flies back up and becomes the plank again. While the
## world stands at frame 0 the fire stands still with it. No random numbers:
## every particle has a fixed seed from its number.
##
## Pure rules: no nodes, no references to the game or the level. Zone
## coordinates: the zone's centre is (0, 0), y grows down.

var per_second := 60.0
## Seconds the flames take to catch after the zone is lit, and to die down
## at the end of burning.
var ignite_seconds := 0.35
var fade_seconds := 0.6
## How high the flames reach above the zone (the player's danger area too).
var flame_px := 40.0
var sparks := 12
var spark_rise_px := 120.0
var spark_seconds := 1.1
var smoke_puffs := 6
var smoke_rise_px := 170.0
var smoke_seconds := 2.4
var smoke_after_seconds := 2.0
var ash_pieces := 24
var ash_seconds := 1.4
var ash_gravity_px := 700.0
var steam_seconds := 2.5
var steam_puffs := 10
var steam_rise_px := 150.0
var steam_radius_px := 18.0


func configure(objects: Dictionary, time_data: Dictionary) -> void:
	per_second = float(time_data.get("physics_ticks_per_second", 60))
	var look: Dictionary = objects.get("fire_look", {})
	var wood: Dictionary = objects.get("wood", {})
	var steam: Dictionary = objects.get("steam", {})
	flame_px = float(wood.get("flame_px", flame_px))
	ignite_seconds = float(look.get("ignite_seconds", ignite_seconds))
	fade_seconds = float(look.get("fade_seconds", fade_seconds))
	sparks = int(look.get("sparks", sparks))
	spark_rise_px = float(look.get("spark_rise_px", spark_rise_px))
	spark_seconds = float(look.get("spark_seconds", spark_seconds))
	smoke_puffs = int(look.get("smoke_puffs", smoke_puffs))
	smoke_rise_px = float(look.get("smoke_rise_px", smoke_rise_px))
	smoke_seconds = float(look.get("smoke_seconds", smoke_seconds))
	smoke_after_seconds = float(look.get("smoke_after_seconds", smoke_after_seconds))
	ash_pieces = int(look.get("ash_pieces", ash_pieces))
	ash_seconds = float(look.get("ash_seconds", ash_seconds))
	ash_gravity_px = float(look.get("ash_gravity_px", ash_gravity_px))
	steam_seconds = float(steam.get("seconds", steam_seconds))
	steam_puffs = int(steam.get("puffs", steam_puffs))
	steam_rise_px = float(steam.get("rise_px", steam_rise_px))
	steam_radius_px = float(steam.get("radius_px", steam_radius_px))


## 0 to 1: the flames catch in `ignite_seconds` after the zone is lit and die
## down to a glow in the last `fade_seconds` of burning. Burn ticks count
## only at the head, so this rewinds with the frames.
func flame_strength(phase: int, burn: int, burn_ticks: int) -> float:
	if phase != WoodBurn.Phase.BURNING:
		return 0.0
	var lit := (float(burn) + 1.0) / per_second
	var left := float(burn_ticks - burn) / per_second
	var catch := clampf(lit / maxf(ignite_seconds, 0.01), 0.0, 1.0)
	var die := clampf(left / maxf(fade_seconds, 0.01), 0.3, 1.0)
	return smoothstep(0.0, 1.0, catch) * die


## Seconds between frame `since` and frame `clock`; negative before it or
## when `since` is -1 (never).
func age(clock: int, since: int) -> float:
	if since < 0:
		return -1.0
	return float(clock - since) / per_second


## Sparks rising from a burning zone: (x, y, alpha) in zone coordinates. They
## rise with world time, so under Shift they fall back into the wood.
func sparks_at(t: float, size: Vector2, strength: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if strength <= 0.0:
		return result
	for i in sparks:
		var period := spark_seconds * (0.7 + 0.6 * _hash(i + 17))
		var life := fposmod(t / period + _hash(i), 1.0)
		var x0 := size.x * (_hash(i + 31) - 0.5)
		var drift := (_hash(i + 5) - 0.5) * 40.0
		var x := x0 + drift * life + sin(t * 2.3 + i) * 5.0 * life
		var y := -size.y / 2.0 - flame_px * 0.3 * strength - life * spark_rise_px
		result.append(Vector3(x, y, (1.0 - life) * strength))
	return result


## Smoke puffs while the zone burns and for `smoke_after_seconds` after it
## burnt out: (x, y, radius, alpha).
func smoke_at(t: float, size: Vector2, strength: float, burnt_age: float) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var after := 0.0
	if burnt_age >= 0.0 and burnt_age < smoke_after_seconds:
		after = 1.0 - burnt_age / smoke_after_seconds
	var amount := maxf(strength, after)
	if amount <= 0.0:
		return result
	for i in smoke_puffs:
		var life := fposmod(t / smoke_seconds + _hash(i + 71), 1.0)
		var x := size.x * (_hash(i + 43) - 0.5) * 0.8 + (_hash(i + 9) - 0.5) * 50.0 * life
		var y := -size.y / 2.0 - flame_px * 0.5 - life * smoke_rise_px
		result.append(Vector4(x, y, 10.0 + 26.0 * life, 0.3 * sin(PI * life) * amount))
	return result


## The ash and embers of a zone that just burnt out, `burnt_age` seconds ago:
## (x, y, size, glow) with glow 1 for a hot ember, 0 for grey ash; empty
## outside `ash_seconds`. Under Shift the age shrinks and the ash flies back.
func ash_at(burnt_age: float, size: Vector2) -> Array[Vector4]:
	var result: Array[Vector4] = []
	if burnt_age < 0.0 or burnt_age > ash_seconds:
		return result
	var fade := 1.0 - burnt_age / ash_seconds
	for i in ash_pieces:
		var x0 := size.x * (_hash(i + 101) - 0.5)
		var y0 := size.y * (_hash(i + 131) - 0.5)
		var vx := (_hash(i + 151) - 0.5) * 80.0
		var vy := -_hash(i + 171) * 120.0
		var x := x0 + vx * burnt_age
		var y := y0 + vy * burnt_age + 0.5 * ash_gravity_px * burnt_age * burnt_age
		var glow := clampf(1.0 - burnt_age / (ash_seconds * 0.4), 0.0, 1.0) if _hash(i + 191) > 0.5 else 0.0
		result.append(Vector4(x, y, (2.0 + 3.0 * _hash(i + 211)) * (0.4 + 0.6 * fade), glow))
	return result


## Steam of a fire put out `doused_age` seconds ago: (x, y, radius, alpha).
## Each puff starts a little later and lives half the steam time.
func steam_at(doused_age: float, size: Vector2) -> Array[Vector4]:
	var result: Array[Vector4] = []
	if doused_age < 0.0 or doused_age > steam_seconds:
		return result
	var life := steam_seconds * 0.5
	for i in maxi(steam_puffs, 1):
		var start := (steam_seconds - life) * float(i) / float(maxi(steam_puffs, 1))
		var a := (doused_age - start) / life
		if a < 0.0 or a > 1.0:
			continue
		var x := size.x * (_hash(i + 251) - 0.5) + sin(a * 4.0 + i) * 8.0
		var y := -size.y / 2.0 - steam_rise_px * a
		result.append(Vector4(x, y, steam_radius_px * (0.5 + a), 0.5 * sin(PI * minf(a * 1.5, 1.0)) * (1.0 - a * 0.6)))
	return result


## Everything the look shows at world tick `clock` for a zone in `state`
## (`phase`, `burn`, `doused`, `burnt`), for the tests and the drawing.
func snapshot(clock: int, state: Dictionary, burn_ticks: int, size: Vector2) -> Dictionary:
	var t := float(clock) / per_second
	var phase := int(state.get("phase", 0))
	var strength := flame_strength(phase, int(state.get("burn", 0)), burn_ticks)
	var burnt_age := age(clock, int(state.get("burnt", -1))) if phase == WoodBurn.Phase.BURNT else -1.0
	var char := 1.0 if phase == WoodBurn.Phase.BURNT else (float(state.get("burn", 0)) / float(maxi(burn_ticks, 1)) if phase == WoodBurn.Phase.BURNING else 0.0)
	return {
		"time": t,
		"strength": strength,
		"char": char,
		"sparks": sparks_at(t, size, strength),
		"smoke": smoke_at(t, size, strength, burnt_age),
		"ash": ash_at(burnt_age, size),
		"steam": steam_at(age(clock, int(state.get("doused", -1))), size),
	}


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 78.233) * 43758.5453, 1.0)
