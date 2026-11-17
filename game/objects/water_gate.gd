class_name WaterGate
extends Door
## A gate that keeps a passage shut while a tank stands high and opens by
## itself once the tank has run low (level 02: the tunnel off the well). It is
## a door whose `powered` comes from the water, not from a button: every tick
## at the head it reads the watched tank's level, and the door runs as usual,
## so its frames are recorded and it closes again, smoothly, when Shift lifts
## the water back (rule «A»).
##
## A level may set `open_level` through `objects` of its entry in
## `data/levels.json`, besides the door's own seconds.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const GATE_COLOR := Color("#5a6068")

## The `object_id` of the tank the gate watches, found among the room's objects.
@export var watch_id := "well"
## The gate opens when the watched tank's level is at or under this
## (0 … `Water.LEVEL_MAX`); above it the gate closes.
@export_range(0, 10000) var open_level := 500


func apply_settings(settings: Dictionary) -> void:
	open_level = int(settings.get("open_level", open_level))
	super.apply_settings(settings)


func simulate_tick(tick: int) -> void:
	var tank := _watched()
	if tank != null:
		powered = tank.level <= open_level
	super.simulate_tick(tick)


## The tank this gate watches; null when it is not in the room.
func _watched() -> Water:
	var room := get_parent()
	if room == null:
		return null
	for child in room.get_children():
		var tank := child as Water
		if tank != null and tank.object_id == watch_id:
			return tank
	return null


## A plain slab: no cyan accent and no gauge, it is a water gate, not a
## mechanism of time.
func _draw() -> void:
	var size := _size()
	draw_rect(Rect2(-size / 2.0, size), GATE_COLOR)
	for i in 3:
		var y := -size.y / 2.0 + size.y * (i + 1) / 4.0
		draw_line(Vector2(-size.x / 2.0, y), Vector2(size.x / 2.0, y), BODY_COLOR.darkened(0.4), 2.0)
