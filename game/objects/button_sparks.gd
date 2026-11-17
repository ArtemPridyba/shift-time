class_name ButtonSparks
extends Node2D
## Decoration over a button that has not been pressed yet: a few sparks jump up
## and fall back, so the player notices it (level 02). It records nothing and
## changes nothing. Where each spark is comes from the world tick alone (group
## `world_clock`, `RoomTime` tells it), so under Shift the sparks play the other
## way, and they stop once the button is pressed.

const SPARK_COLOR := Color("#ffd27a")
const COUNT := 5
## Seconds one spark takes to jump and fall.
const PERIOD_SECONDS := 0.9
const HEIGHT_PX := 46.0
const SPREAD_PX := 26.0

## The button these sparks sit on, found by path from the room.
@export var button_path: NodePath

var _world_tick := 0
var _ticks := 60.0


func _ready() -> void:
	add_to_group("world_clock")
	_ticks = float(Content.time().get("physics_ticks_per_second", 60))


func on_world_tick(tick: int, _recorded: bool) -> void:
	_world_tick = tick
	queue_redraw()


## Where spark `index` is at world tick `tick`, relative to the node: x across,
## y up as negative. A pure function of the tick, so it plays backwards.
static func spark_at(index: int, tick: int, ticks_per_second: float) -> Vector2:
	var phase := _phase(index, tick, ticks_per_second)
	var side := -1.0 if index % 2 == 0 else 1.0
	var x := side * SPREAD_PX * (0.35 + 0.65 * float((index * 7) % COUNT) / COUNT) * phase
	var y := -HEIGHT_PX * 4.0 * phase * (1.0 - phase)
	return Vector2(x, y)


static func _phase(index: int, tick: int, ticks_per_second: float) -> float:
	return fposmod(float(tick) / (PERIOD_SECONDS * ticks_per_second) + float(index) / COUNT, 1.0)


func is_lit() -> bool:
	var button := get_node_or_null(button_path) as PushButton
	return button == null or not button.pressed


func _draw() -> void:
	if not is_lit():
		return
	for i in COUNT:
		var fade := 1.0 - absf(_phase(i, _world_tick, _ticks) * 2.0 - 1.0) * 0.4
		draw_circle(spark_at(i, _world_tick, _ticks), 2.5, Color(SPARK_COLOR, fade))
