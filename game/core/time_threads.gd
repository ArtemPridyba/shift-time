class_name TimeThreads
extends RefCounted
## Threads "wind into the glove" (D85, Д5.1, 20.11.2026): under Shift soft pale
## lines come in from beyond the edge of the screen into the gauntlet. They
## replace the glow and the streaks along the screen edges. Unlike the motes
## they do not circle: each comes nearly straight in from the dark at the edge
## and curls only as it reaches the gauntlet (`offset`, D85.2), so they read
## as coming out from behind the screen, not flying round it.
##
## They build up while Shift is held (Boris, 20.11): none for `start_seconds`,
## then `first` threads, then one more every `every_seconds`, never more than
## `max`. Each thread is three times as thick at the screen edge
## (`edge_scale`) and thins to its normal width as it nears the gauntlet.
## Every number is in `light.threads` of data/heroine.json. Plain math, no
## nodes: the rig draws what this returns.

## Each next thread and each next trip turns by the golden angle, so no two
## trips come from the same place.
const GOLDEN_ANGLE := 2.399963
## Spreads the threads' phases evenly however many there are (the golden ratio).
const GOLDEN_RATIO := 0.618034


## How many threads are out after Shift has been held for `held` seconds.
static func count(spec: Dictionary, held: float) -> int:
	var start := float(spec.get("start_seconds", 1.0))
	if held < start:
		return 0
	var every := maxf(float(spec.get("every_seconds", 0.5)), 0.001)
	var n := int(spec.get("first", 1)) + int(floor((held - start) / every))
	return clampi(n, 0, int(spec.get("max", 0)))


## How far thread `index` has faded in (0..1): it comes in softly when the
## count grows to it, never all at once.
static func fade_in(spec: Dictionary, index: int, held: float) -> float:
	var first := int(spec.get("first", 1))
	var since := float(spec.get("start_seconds", 1.0)) + float(maxi(index - first + 1, 0)) * float(spec.get("every_seconds", 0.5))
	return clampf((held - since) / maxf(float(spec.get("fade_in_seconds", 0.3)), 0.001), 0.0, 1.0)


## Thread `index` at her time `t` (seconds, always forward): where its head is
## on the way in (`along`, 0 at the screen edge, 1 in the gauntlet) and the
## angle it starts from. Between two trips it rests (`along` is -1).
static func trip(spec: Dictionary, index: int, t: float) -> Dictionary:
	var period := maxf(float(spec.get("period_seconds", 3.0)), 0.001)
	var travel := clampf(float(spec.get("travel_seconds", 2.4)), 0.001, period)
	var u := t / period + fposmod(float(index) * GOLDEN_RATIO, 1.0)
	var cycle := int(floor(u))
	var local := (u - float(cycle)) * period
	var angle := float(spec.get("start_angle", 0.6)) + GOLDEN_ANGLE * float(index + cycle * 97)
	if local > travel:
		return {"along": -1.0, "angle": angle}
	return {"along": local / travel, "angle": angle}


## How far from the gauntlet a thread at `angle` must start to come from
## beyond the edge of `view` (both in the same pixels as `origin`), plus
## `margin`. The way in is flattened like the motes' spiral.
static func start_distance(origin: Vector2, angle: float, flatten: float, view: Rect2, margin: float) -> float:
	var dir := Vector2(cos(angle), sin(angle) * flatten)
	var reach := INF
	if dir.x > 0.0001:
		reach = minf(reach, (view.end.x - origin.x) / dir.x)
	elif dir.x < -0.0001:
		reach = minf(reach, (view.position.x - origin.x) / dir.x)
	if dir.y > 0.0001:
		reach = minf(reach, (view.end.y - origin.y) / dir.y)
	elif dir.y < -0.0001:
		reach = minf(reach, (view.position.y - origin.y) / dir.y)
	if reach == INF:
		reach = 0.0
	return maxf(reach, 0.0) + margin


## Width of a thread at `along` as a multiple of its normal width: `edge_scale`
## at the screen edge, easing down to 1 by `shrink_until`.
static func width_scale(spec: Dictionary, along: float) -> float:
	var big := float(spec.get("edge_scale", 3.0))
	var shrink := sm(0.0, maxf(float(spec.get("shrink_until", 0.75)), 0.001), along)
	return lerpf(big, 1.0, shrink)


## The trail of a thread whose head is at `head`: points from the tail to the
## head as offsets from the gauntlet, each with its `along` and `trail` (0 at
## the tail, 1 at the head).
static func trail(spec: Dictionary, flatten: float, angle: float, from: float, head: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var segments := maxi(int(spec.get("segments", 20)), 1)
	var length := float(spec.get("trail", 0.2))
	for i in segments + 1:
		var k := float(i) / float(segments)
		var along := maxf(head - length * (1.0 - k), 0.0)
		points.append({"offset": offset(spec, flatten, angle, from, along), "along": along, "trail": k})
	return points


## Where a thread is at `along` (0..1) as an offset from the gauntlet: from
## `from` away at `angle`, closing in by `pull` (below 1: it lingers at the edge
## and rushes in at the end) and turning by `swirl` only near the end
## (`curl`: the higher, the later it turns), flattened in height by `flatten`.
static func offset(spec: Dictionary, flatten: float, angle: float, from: float, along: float) -> Vector2:
	var k := clampf(along, 0.0, 1.0)
	var distance := from * pow(1.0 - k, float(spec.get("pull", 0.6)))
	var turned := angle + float(spec.get("swirl", 1.2)) * pow(k, float(spec.get("curl", 3.0)))
	return Vector2(cos(turned) * distance, sin(turned) * distance * flatten)


## How bright a thread is at a point of its trail: fading toward the tail,
## pale far away, gone as it enters the gauntlet.
static func alpha(spec: Dictionary, head: float, trail_k: float) -> float:
	var gone := 1.0 - sm(0.86, 1.0, head)
	return float(spec.get("alpha", 0.7)) * trail_k * (0.55 + 0.45 * head) * gone


static func sm(from: float, to: float, x: float) -> float:
	return smoothstep(from, to, x)
