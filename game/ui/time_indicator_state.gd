class_name TimeIndicatorState
extends RefCounted
## What the wrist device shows, as numbers: no nodes, no drawing, so a test can
## drive it tick by tick. `TimeHud` reads it and draws.
##
## The direction of time never reads from color alone: forward and rewind
## differ by the arrows (`>>` or `<<`), by the sweep of light along them, by
## the flicker and by the way the motes fly (outwards or inwards).

const FORWARD := 1
const BACKWARD := -1
const GLYPH_FORWARD := ">>"
const GLYPH_REWIND := "<<"
const GOLDEN_ANGLE := 2.399963

## +1 while time runs forward, -1 while the world is rewound.
var direction := FORWARD
## 0 in forward time, 1 in rewind; eases over `edges.fade_seconds`.
## The view scales it by `edges.strength`.
var edge_amount := 0.0
## Phase of the motes, in cycles: grows in forward time and shrinks in rewind,
## so every mote flies the same path the other way.
var particle_phase := 0.0
## Phase of the sweep along the arrows and of the flicker, in cycles. They run
## only in rewind; forward time is a steady glow.
var sweep_phase := 0.0
var flicker_phase := 0.0

var _cycle_seconds := 1.2
var _fade_seconds := 0.25
var _sweep_hz := 1.6
var _flicker_hz := 9.0
var _flicker_depth := 0.45
var _count := 7


func _init(config: Dictionary = {}) -> void:
	var particles := config.get("particles", {}) as Dictionary
	var edges := config.get("edges", {}) as Dictionary
	var rewind := config.get("rewind", {}) as Dictionary
	_cycle_seconds = maxf(float(particles.get("cycle_seconds", _cycle_seconds)), 0.01)
	_count = maxi(int(particles.get("count", _count)), 0)
	_fade_seconds = maxf(float(edges.get("fade_seconds", _fade_seconds)), 0.01)
	_sweep_hz = float(rewind.get("sweep_hz", _sweep_hz))
	_flicker_hz = float(rewind.get("flicker_hz", _flicker_hz))
	_flicker_depth = clampf(float(rewind.get("flicker_depth", _flicker_depth)), 0.0, 1.0)


func set_direction(new_direction: int) -> void:
	direction = BACKWARD if new_direction < 0 else FORWARD


func is_rewinding() -> bool:
	return direction == BACKWARD


## The arrows on the plate.
func glyph() -> String:
	return GLYPH_REWIND if direction == BACKWARD else GLYPH_FORWARD


func step(delta: float) -> void:
	particle_phase += float(direction) * delta / _cycle_seconds
	if direction == BACKWARD:
		sweep_phase += delta * _sweep_hz
		flicker_phase += delta * _flicker_hz
	edge_amount = move_toward(edge_amount, 1.0 if direction == BACKWARD else 0.0, delta / _fade_seconds)


## Brightness of the device, 0 to 1: steady in forward time, flickering in rewind.
func glow() -> float:
	if direction != BACKWARD:
		return 1.0
	return 1.0 - _flicker_depth * (0.5 + 0.5 * sin(TAU * flicker_phase))


## Where the sweep of light is along the arrows: 0 is the left end and 1 the
## right end. In rewind it runs from right to left; in forward time there is
## none (-1).
func sweep_position() -> float:
	if direction != BACKWARD:
		return -1.0
	return 1.0 - fposmod(sweep_phase, 1.0)


## One mote: `progress` from 0 (at the plate) to 1 (far away), the direction of
## its flight as an angle and its opacity. In forward time the motes drift out
## and fade; in rewind the same motes come back and brighten.
func mote(index: int) -> Dictionary:
	var progress := fposmod(particle_phase + float(index) / float(maxi(_count, 1)), 1.0)
	return {
		"progress": progress,
		"angle": float(index) * GOLDEN_ANGLE,
		"alpha": 1.0 - progress,
	}


func mote_count() -> int:
	return _count
