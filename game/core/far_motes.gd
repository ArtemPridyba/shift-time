class_name FarMotes
extends RefCounted
## Far motes (D85.6, a trial, 20.11.2026): besides the motes near her, tiny
## dots come in from the screen edge and whirl clockwise into the gauntlet,
## like the threads but as dots: big, soft and faint at the edge (`edge_scale`
## times their size), shrinking and getting brighter on the way. Every number
## is in `light.far_motes` of data/heroine.json; `"enabled": false` turns them
## off, and this whole trial is one commit, so reverting it removes them.

const GOLDEN_RATIO := 0.618034


## The motes, the same every run (`seed`): each with its own phase and size.
static func list(spec: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 91))
	var motes: Array[Dictionary] = []
	for i in int(spec.get("count", 0)):
		motes.append({
			"phase": rng.randf(),
			"size": lerpf(float(spec.get("size_min_px", 0.5)), float(spec.get("size_max_px", 1.0)), rng.randf()),
		})
	return motes


## Mote `index` at her time `t`: how far along its way it is (0 at the screen
## edge, 1 in the gauntlet's centre), where round the screen edge this trip
## starts (0..1) and which trip it is.
static func trip(spec: Dictionary, index: int, mote: Dictionary, t: float) -> Dictionary:
	var u := t * float(spec.get("hz", 0.3)) + float(mote["phase"])
	var cycle := int(floor(u))
	var edge := fposmod(0.37 + GOLDEN_RATIO * float(index * 11 + cycle * 53), 1.0)
	return {"along": u - float(cycle), "edge": edge, "cycle": cycle}


## The size of a mote at `along`, in screen pixels: `edge_scale` times its
## size at the screen edge, its own size by `shrink_until`.
static func size_px(spec: Dictionary, mote: Dictionary, along: float) -> float:
	var shrink := smoothstep(0.0, maxf(float(spec.get("shrink_until", 0.85)), 0.001), along)
	return float(mote["size"]) * lerpf(float(spec.get("edge_scale", 30.0)), 1.0, shrink)


## How bright a mote is at `along`: faint at the edge (`edge_alpha` of full),
## full near the gauntlet, gone only in its centre.
static func alpha(spec: Dictionary, along: float) -> float:
	var near := lerpf(float(spec.get("edge_alpha", 0.15)), 1.0, smoothstep(0.0, 0.8, along))
	return float(spec.get("alpha", 0.7)) * near * (1.0 - smoothstep(0.96, 1.0, along))
