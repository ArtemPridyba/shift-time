class_name RailSwitch
extends Node2D
## A recorded rail switch of level 04 (card docs/levels/04.md, D168), thrown by
## a time plate on the walkway above it, like a shutter: a step in normal time
## sets it down (▼), a step with Shift held sends the throw into the past, so
## it goes up (▲) once time runs forward. Its blade moves between the two over
## `rail_switch.move_seconds` and rewinds with the world, so a cart that passes
## while Shift is held meets the switch as it was in the past.
##
## Which way leads to the main line is the level's choice: `main_when`. The
## cart takes the main segment while the blade is past half way to it.
##
## State recorded: { "blade": int 0…1000 (1000 down), "target": int 0 or 1000 }.
## A level picks the start in `objects` of its entry in data/levels.json:
## `"start": "down"` or `"up"` (the default is down).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const DOWN := 1000
const START_DOWN := "down"
const START_UP := "up"
const RAIL_COLOR := Color("#8a8f96")
const BLADE_COLOR := Color("#d9b400")
const ROD_COLOR := Color("#5a5f66")
const BASE_COLOR := Color("#3c4148")

@export var object_id := "switch"
## The way to the main line: "down" or "up".
@export var main_when := START_DOWN
## The direction of the main and of the side segment from the switch point,
## for the blade's look.
@export var main_direction := Vector2.LEFT
@export var side_direction := Vector2(-0.7, 0.7)
## Where the tie rod meets the plate on the walkway, relative to the switch.
@export var rod_top := Vector2(0, -384)
@export var label := ""

var blade := DOWN
var target := DOWN

var _step := 40


func _init() -> void:
	configure(Content.objects().get("rail_switch", {}), Content.time())


## Seconds of a full throw into a step per world tick (D96).
func configure(switch_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := Content.world_ticks_per_second(time_data)
	var seconds := float(switch_data.get("move_seconds", 0.6))
	_step = maxi(int(ceil(float(DOWN) / maxf(seconds * ticks, 1.0))), 1)


func apply_settings(settings: Dictionary) -> void:
	var start := 0 if str(settings.get("start", START_DOWN)) == START_UP else DOWN
	blade = start
	target = start
	queue_redraw()


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("rail_switch")


func capture_state() -> Dictionary:
	return {"blade": blade, "target": target}


func restore_state(state: Dictionary) -> void:
	blade = int(state["blade"])
	target = int(state["target"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if blade < target:
		blade = mini(blade + _step, target)
	elif blade > target:
		blade = maxi(blade - _step, target)
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## True while the blade is past half way to the main line.
func leads_main() -> bool:
	return (blade >= DOWN / 2) == (main_when == START_DOWN)


## How far the blade is down, 0…1, for mechanisms on it.
func mech_fraction() -> float:
	return float(blade) / float(DOWN)


func _draw() -> void:
	# The tie rod from the plate above: a pull rod that rides up and down with
	# the blade, so the link between plate and switch reads by motion.
	var down := mech_fraction()
	var rod_bottom := Vector2(rod_top.x, -40.0)
	draw_line(rod_top, rod_bottom, ROD_COLOR, 4.0)
	var slider := rod_bottom.lerp(rod_top, 0.12) + Vector2(0.0, 24.0 * down)
	draw_rect(Rect2(slider - Vector2(10, 6), Vector2(20, 12)), BLADE_COLOR)
	# The lever box beside the rails and the blade: it points along the main
	# or the side segment.
	draw_rect(Rect2(Vector2(6, -40), Vector2(28, 28)), BASE_COLOR)
	draw_line(Vector2(20, -26), slider + Vector2(0, 6), ROD_COLOR, 3.0)
	var main_dir := main_direction.normalized()
	var side_dir := side_direction.normalized()
	var to_main := down if main_when == START_DOWN else 1.0 - down
	var dir := side_dir.slerp(main_dir, to_main)
	draw_line(Vector2.ZERO, dir * 80.0, BLADE_COLOR, 6.0)
	draw_circle(Vector2.ZERO, 7.0, BASE_COLOR)
	if label != "":
		draw_string(ThemeDB.fallback_font, Vector2(10, -48), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, BLADE_COLOR)
