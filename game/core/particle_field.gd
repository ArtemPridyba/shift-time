class_name ParticleField
extends RefCounted
## Particles that run backwards (task Д2): the place of every particle is a
## formula of world time, so the same frame of history always shows the same
## particles, whichever way time went to get there. Nothing is simulated and
## nothing is recorded; Godot's own particles cannot do this.
##
## A particle is born at a known moment: a steady stream (`rate` per second,
## particle `i` is born at `i / rate`, so the room is already dusty at time 0),
## bursts every `burst_every` seconds (the first at `burst_every`), and bursts at moments the owner gives
## (`extra_bursts`, e.g. the lamp shattering). From its birth, its index and
## the noise seed every number of the particle follows by a hash: start point,
## velocity, size, sway, spin. The position at age `a` is
## `p0 + v·a + g·a²/2` plus a sideways sway; with a floor it either stops
## where it lands (`on_floor` "stop", shards) or ends there ("die", drops).
## The numbers come from `particles` in `data/look.json`.

## Floats per particle in `sample()`: x, y, angle, length, width, alpha and
## how far the color went toward `color_end` (0…1).
const STRIDE := 7
const SHAPES: Array[String] = ["dot", "square", "streak", "shard"]
const FLOORS: Array[String] = ["none", "stop", "die"]
const BLENDS: Array[String] = ["mix", "add"]

var shape := "dot"
var rate := 0.0
var lifetime := 1.0
var lifetime_jitter := 0.0
## Spawn area for the stream: a rect, or a light cone pointing down from the
## node (then particles fade toward the cone's edge and end).
var area := Rect2()
var cone_spread := 0.0
var cone_length := 0.0
var velocity := Vector2.ZERO
var velocity_jitter := Vector2.ZERO
var gravity := Vector2.ZERO
var wobble_px := Vector2.ZERO
var wobble_hz := Vector2.ZERO
var size := Vector2(1, 1)
var spin := 0.0
var stretch := 0.0
var alpha := 1.0
var fade_in := 0.0
var fade_out := 0.0
var on_floor := "none"
## The floor counts only once the owner sets it (`set_floor`).
var has_floor := false
var floor_y := 0.0
var burst_count := 0
var burst_every := 0.0
var burst_area := Vector2.ZERO
## Moments (world seconds) of the bursts the owner adds, besides the periodic ones.
var extra_bursts := PackedFloat32Array()
var noise_seed := 1
## True: the stream starts at time 0, nothing was born before it (smoke from
## a breakdown); false: the stream has always run (dust in a lamp's light).
var starts_empty := false


static func from_preset(preset: Dictionary, field_seed: int) -> ParticleField:
	var f := ParticleField.new()
	f.noise_seed = field_seed
	f.shape = str(preset.get("shape", "dot"))
	f.rate = float(preset.get("rate", 0))
	f.lifetime = maxf(float(preset.get("lifetime", 1)), 0.01)
	f.lifetime_jitter = clampf(float(preset.get("lifetime_jitter", 0)), 0.0, 0.95)
	var cone: Variant = preset.get("cone")
	if cone is Dictionary:
		f.cone_spread = float(cone.get("spread", 0))
		f.cone_length = float(cone.get("length_px", 0))
	var a: Variant = preset.get("area", [0, 0, 0, 0])
	if a is Array and a.size() == 4:
		f.area = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	f.velocity = _vec(preset.get("velocity"))
	f.velocity_jitter = _vec(preset.get("velocity_jitter"))
	f.gravity = _vec(preset.get("gravity"))
	f.wobble_px = _vec(preset.get("wobble_px"))
	f.wobble_hz = _vec(preset.get("wobble_hz"))
	f.size = _vec(preset.get("size"), Vector2(1, 1))
	f.spin = float(preset.get("spin", 0))
	f.stretch = float(preset.get("stretch", 0))
	f.alpha = float(preset.get("alpha", 1))
	f.fade_in = float(preset.get("fade_in", 0))
	f.fade_out = float(preset.get("fade_out", 0))
	f.on_floor = str(preset.get("on_floor", "none"))
	f.burst_count = int(preset.get("burst_count", 0))
	f.burst_every = float(preset.get("burst_every", 0))
	f.burst_area = _vec(preset.get("burst_area"))
	return f


## How many particles can be alive at once: the size of the draw buffer.
func capacity() -> int:
	var n := int(ceil(lifetime * rate)) + 1 if rate > 0.0 else 0
	if burst_count > 0 and burst_every > 0.0:
		n += burst_count * (int(ceil(lifetime / burst_every)) + 1)
	n += burst_count * extra_bursts.size()
	return n


## A floor at `y` in the node's coordinates; `on_floor` says what happens there.
func set_floor(y: float) -> void:
	floor_y = y
	has_floor = true
	if on_floor == "none":
		on_floor = "stop"


## Every particle alive at world time `t` (seconds), STRIDE floats each.
func sample(t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if rate > 0.0:
		var first := int(floor((t - lifetime) * rate)) + 1
		if starts_empty:
			first = maxi(first, 0)
		var last := int(floor(t * rate))
		for i in range(first, last + 1):
			_add(out, t, float(i) / rate, noise_seed, i, _stream_origin(noise_seed, i))
	if burst_count > 0 and burst_every > 0.0:
		# The first periodic burst is at `burst_every`, not at 0: the world
		# pinned at frame 0 shows no frozen burst.
		var k_first := maxi(int(floor((t - lifetime) / burst_every)) + 1, 1)
		var k_last := int(floor(t / burst_every))
		for k in range(k_first, k_last + 1):
			_add_burst(out, t, float(k) * burst_every, noise_seed + 7919 * (k + 1))
	for n in extra_bursts.size():
		_add_burst(out, t, extra_bursts[n], noise_seed + 104729 * (n + 1))
	return out


## The same numbers for one particle of the stream, or an empty array if it
## is not alive at `t`: for tests.
func stream_particle(t: float, index: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if rate > 0.0:
		_add(out, t, float(index) / rate, noise_seed, index, _stream_origin(noise_seed, index))
	return out


func _add_burst(out: PackedFloat32Array, t: float, at: float, burst_seed: int) -> void:
	if t < at or t >= at + lifetime:
		return
	for j in burst_count:
		var origin := Vector2(
			(rand01(burst_seed, j, 1) - 0.5) * burst_area.x,
			(rand01(burst_seed, j, 2) - 0.5) * burst_area.y)
		_add(out, t, at, burst_seed, j, origin)


func _stream_origin(s: int, i: int) -> Vector2:
	var u := rand01(s, i, 1)
	var w := rand01(s, i, 2)
	if cone_length > 0.0:
		# Uniform over the cone's area: depth by the square root.
		var depth := sqrt(w) * cone_length
		return Vector2((u * 2.0 - 1.0) * depth * tan(cone_spread), depth)
	return area.position + Vector2(u * area.size.x, w * area.size.y)


func _add(out: PackedFloat32Array, t: float, birth: float, s: int, i: int, p0: Vector2) -> void:
	var life := lifetime * (1.0 - lifetime_jitter * rand01(s, i, 0))
	var age := t - birth
	if age < 0.0 or age >= life:
		return
	var v := velocity + Vector2(
		(rand01(s, i, 3) * 2.0 - 1.0) * velocity_jitter.x,
		(rand01(s, i, 4) * 2.0 - 1.0) * velocity_jitter.y)
	var a := age
	if has_floor and on_floor != "none":
		var land := _landing_age(p0.y, v.y, gravity.y)
		if age >= land:
			if on_floor == "die":
				return
			a = land
	var pos := p0 + v * a + gravity * (0.5 * a * a)
	var amp := lerpf(wobble_px.x, wobble_px.y, rand01(s, i, 8))
	if amp > 0.0:
		var hz := lerpf(wobble_hz.x, wobble_hz.y, rand01(s, i, 9))
		pos.x += sin(TAU * (hz * a + rand01(s, i, 5))) * amp
	var d := lerpf(size.x, size.y, rand01(s, i, 6))
	var angle := rand01(s, i, 7) * TAU + spin * (rand01(s, i, 10) * 2.0 - 1.0) * a
	var length := d
	var width := d
	if shape == "streak":
		var vel := v + gravity * a
		angle = vel.angle()
		length = d * 2.0 + vel.length() * stretch * d
		width = d * 0.6
	var k := clampf(age / life, 0.0, 1.0)
	var fade := 1.0
	if fade_in > 0.0:
		fade *= smoothstep(0.0, fade_in, k)
	if fade_out > 0.0:
		fade *= 1.0 - smoothstep(1.0 - fade_out, 1.0, k)
	if cone_length > 0.0:
		fade *= _cone_light(pos)
	if fade <= 0.001:
		return
	out.append_array(PackedFloat32Array([pos.x, pos.y, angle, length, width, alpha * fade, k]))


## The light of the lamp's cone at `p` (0…1), as in the mock-up: full inside
## 55 % of the spread, none at the edge; weaker with distance.
func _cone_light(p: Vector2) -> float:
	if p.y <= 0.0:
		return 0.0
	var off := absf(atan2(p.x, p.y))
	var side := 1.0 - smoothstep(cone_spread * 0.55, cone_spread, off)
	var dist := clampf(1.0 - p.length() / cone_length, 0.0, 1.0)
	return side * pow(dist, 1.3)


## The age at which a particle starting at height `y0` with vertical speed
## `vy` and gravity `g` reaches `floor_y`; INF if it never does.
func _landing_age(y0: float, vy: float, g: float) -> float:
	var dy := floor_y - y0
	if dy <= 0.0:
		return 0.0
	if absf(g) < 0.0001:
		return dy / vy if vy > 0.0 else INF
	var disc := vy * vy + 2.0 * g * dy
	if disc < 0.0:
		return INF
	return (-vy + sqrt(disc)) / g


## A number in [0, 1) that depends only on the seed, the particle and the channel.
static func rand01(s: int, index: int, channel: int) -> float:
	var h := (s * 374761393 + index * 668265263 + channel * 1274126177) & 0xFFFFFFFF
	# Multipliers below 2^31 keep every product inside 64 bits.
	h = ((h ^ (h >> 16)) * 73244475) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 73244475) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0


static func _vec(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
