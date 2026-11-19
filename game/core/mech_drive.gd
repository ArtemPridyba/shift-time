class_name MechDrive
extends RefCounted
## How a mechanism turns (task Д2). A mechanism keeps no history: its angle or
## the offset of its links follows from the recorded value of the object it
## drives (how far a door or a platform has moved), so under Shift it turns
## back exactly as the object goes back, and the same frame of history gives
## the same angle.


## A gear or a roller rolling without slipping along a rack, a rail or a chain
## that moved `travel_px`: the angle in radians.
static func rolling_angle(travel_px: float, radius_px: float) -> float:
	if radius_px <= 0.0:
		return 0.0
	return travel_px / radius_px


## A gear meshed with one at `angle` turns the other way, slower by the ratio
## of the radii.
static func meshed_angle(angle: float, from_radius: float, to_radius: float) -> float:
	if to_radius <= 0.0:
		return 0.0
	return -angle * from_radius / to_radius


## Where the links of a chain or the teeth of a moving rack stand along their
## path, wrapped by one pitch: 0 ≤ offset < pitch.
static func link_offset(travel_px: float, pitch_px: float) -> float:
	if pitch_px <= 0.0:
		return 0.0
	return fposmod(travel_px, pitch_px)


## A valve wheel that makes `turns` turns while the object goes from closed
## (`fraction` 0) to open (1).
static func wheel_angle(fraction: float, turns: float) -> float:
	return TAU * turns * clampf(fraction, 0.0, 1.0)


## How far a recorded object has moved, read from it: `mech_travel()` in
## pixels and `mech_fraction()` from 0 to 1 (door, platform). An object
## without them gives 0, so a mechanism on it stands still.
static func travel_of(driven: Object) -> float:
	if driven != null and driven.has_method("mech_travel"):
		return float(driven.call("mech_travel"))
	return 0.0


static func fraction_of(driven: Object) -> float:
	if driven != null and driven.has_method("mech_fraction"):
		return float(driven.call("mech_fraction"))
	return 0.0
