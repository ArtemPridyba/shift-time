class_name TimeThreads
extends RefCounted
## Threads "wind into the glove" (D85, Д5.1, 20.11.2026): under Shift soft pale
## lines come in from beyond the edge of the screen into the gauntlet. They
## replace the glow and the streaks along the screen edges.
##
## Each trip starts from its own point just beyond the screen edge, spread
## evenly round the whole edge by the golden ratio, wherever the heroine
## stands, and fixed on the screen for the whole trip; it flies straight at
## the gauntlet and hooks in only at the very end (D85.3, Boris 20.11: no
## turns on the way, as many from the right as from the left).
##
## They build up while Shift is held: none for `start_seconds`, then `first`
## threads, then one more every `every_seconds`, never more than `max`. Each
## thread is thicker at the screen edge (`edge_scale`) and thins to its normal
## width near the gauntlet. Every number is in `light.threads` of
## data/heroine.json. Plain math in screen pixels, no nodes: the rig draws what
## this returns.

## Spreads the threads' phases and starting points evenly however many there
## are (the golden ratio).
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
## on the way in (`along`, 0 at the screen edge, 1 in the gauntlet; -1 while
## it rests between two trips) and where round the screen edge this trip
## starts (`edge`, 0..1 along the edge clockwise from the top left corner).
static func trip(spec: Dictionary, index: int, t: float) -> Dictionary:
	var period := maxf(float(spec.get("period_seconds", 3.0)), 0.001)
	var travel := clampf(float(spec.get("travel_seconds", 2.4)), 0.001, period)
	var u := t / period + fposmod(float(index) * GOLDEN_RATIO, 1.0)
	var cycle := int(floor(u))
	var local := (u - float(cycle)) * period
	# Every trip of every thread takes the next place round the edge.
	var edge := fposmod(float(spec.get("start_edge", 0.13)) + GOLDEN_RATIO * float(index * 7 + cycle * 61), 1.0)
	return {"along": local / travel if local <= travel else -1.0, "edge": edge}


## The point `edge` (0..1) round the edge of `screen`, clockwise from the top
## left corner by the length of the edge, pushed `margin` pixels outside it.
static func start_point(screen: Rect2, edge: float, margin: float) -> Vector2:
	var w := screen.size.x
	var h := screen.size.y
	var s := fposmod(edge, 1.0) * 2.0 * (w + h)
	if s < w:
		return screen.position + Vector2(s, -margin)
	s -= w
	if s < h:
		return screen.position + Vector2(w + margin, s)
	s -= h
	if s < w:
		return screen.position + Vector2(w - s, h + margin)
	s -= w
	return screen.position + Vector2(-margin, h - s)


## Where a thread is at `along` (0..1) as an offset from the gauntlet, when its
## trip starts at offset `start`: straight in, lingering at the edge and
## rushing in at the end (`pull` below 1), turning by `swirl` radians only at
## the very end (`curl`: the higher, the later).
static func offset(spec: Dictionary, start: Vector2, along: float) -> Vector2:
	var k := clampf(along, 0.0, 1.0)
	var closer := start * pow(1.0 - k, float(spec.get("pull", 0.6)))
	return closer.rotated(float(spec.get("swirl", 0.0)) * pow(k, float(spec.get("curl", 4.0))))


## Width of a thread at `along` as a multiple of its normal width: `edge_scale`
## at the screen edge, easing down to 1 by `shrink_until`.
static func width_scale(spec: Dictionary, along: float) -> float:
	var big := float(spec.get("edge_scale", 3.0))
	var shrink := smoothstep(0.0, maxf(float(spec.get("shrink_until", 0.75)), 0.001), along)
	return lerpf(big, 1.0, shrink)


## The trail of a thread whose head is at `head`: points from the tail to the
## head as offsets from the gauntlet, each with its `along` and `trail` (0 at
## the tail, 1 at the head).
static func trail(spec: Dictionary, start: Vector2, head: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var segments := maxi(int(spec.get("segments", 20)), 1)
	var length := float(spec.get("trail", 0.4))
	for i in segments + 1:
		var k := float(i) / float(segments)
		var along := maxf(head - length * (1.0 - k), 0.0)
		points.append({"offset": offset(spec, start, along), "along": along, "trail": k})
	return points


## How bright a thread is at a point of its trail that is `along` its way:
## nearly clear at the screen edge (`edge_alpha` of full), full near the
## gauntlet, fading toward the tail, gone as its head enters the gauntlet.
static func alpha(spec: Dictionary, along: float, head: float, trail_k: float) -> float:
	var gone := 1.0 - smoothstep(0.86, 1.0, head)
	var near := lerpf(float(spec.get("edge_alpha", 0.3)), 1.0, sharpness(spec, along))
	return float(spec.get("alpha", 0.7)) * trail_k * near * gone


## How sharp a thread is `along` its way: 0 at the screen edge (only a soft
## wide glow), 1 by `sharp_at` (a bright thin core).
static func sharpness(spec: Dictionary, along: float) -> float:
	return smoothstep(0.0, maxf(float(spec.get("sharp_at", 0.8)), 0.001), along)
