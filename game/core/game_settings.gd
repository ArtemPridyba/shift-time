class_name GameSettings
extends RefCounted
## The player's settings kept between runs (task 4.3): for now only the
## volume of the Master bus, 0..1. Plain data: LevelLoader keeps one, saves it
## in `user://` (works in the browser too) and gives the volume to the bus.

var volume := 0.8


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)


## The bus volume in decibels for a slider value; silence below the
## smallest step.
static func volume_db(value: float) -> float:
	return linear_to_db(value) if value > 0.001 else -80.0


func to_dict() -> Dictionary:
	return {"volume": volume}


func from_dict(data: Variant, default_volume: float) -> void:
	set_volume(default_volume)
	if data is Dictionary and Content._is_number((data as Dictionary).get("volume")):
		set_volume(float((data as Dictionary)["volume"]))
