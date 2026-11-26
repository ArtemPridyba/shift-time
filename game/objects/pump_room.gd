class_name PumpRoom
extends Node2D
## The pump room on the slab over the tunnel of level 02 (25.11 notes): the
## motor and the pump that drain the tunnel, the pipes from it, and the
## electric panel whose cable runs down to button 2. Decoration drawn by code:
## it records nothing and nothing collides; the heroine never gets up here.
## The fan of the motor turns while the pump runs, from the tank's recorded
## counter (`Water.run`), so it turns back under Shift and stops when the pump
## fails; then the panel's lamp goes red. The sparks, the smoke and the
## blinking lamps of the failure are `FaultFx` nodes the builder puts here.
## Positions are room pixels from the builder (cells in tools/build_level_02.gd).

const IRON := Color("#3c3a3e")
const IRON_LIGHT := Color("#66636a")
const IRON_DARK := Color("#232227")
const RUST := Color("#6e4130")
const PAINT := Color("#4a5a52")
const PAINT_DARK := Color("#2f3a35")
const CABLE := Color("#1d1a18")
const GREEN := Color("#7fd46a")
const RED := Color("#e0503a")
## Turns of the fan per second of the running pump.
const FAN_TURNS := 3.0

@export var tunnel_path: NodePath
## The top of the slab the machines stand on.
@export var floor_y := 576.0
## The motor's middle on the slab; the pump stands right of it.
@export var motor_x := 3300.0
## The panel's top-left corner on the back wall.
@export var panel_at := Vector2(2970, 380)
## The cable from the panel down to button 2.
@export var cable := PackedVector2Array()
## The discharge pipe from the pump up and away, after the pump's outlet.
@export var discharge := PackedVector2Array()

var _world_tick := 0


func _ready() -> void:
	add_to_group("world_clock")


func on_world_tick(tick: int, _recorded: bool) -> void:
	_world_tick = tick
	queue_redraw()


func _tunnel() -> Water:
	return get_node_or_null(tunnel_path) as Water if not tunnel_path.is_empty() else null


## The fan's angle: it turns while the pump runs and stands where the failure
## stopped it.
func fan_angle() -> float:
	var tunnel := _tunnel()
	if tunnel == null or tunnel.turn_after_ticks < 0:
		return 0.0
	var ticks := float(mini(tunnel.run, tunnel.turn_after_ticks))
	return ticks / 60.0 * FAN_TURNS * TAU


func running() -> bool:
	var tunnel := _tunnel()
	return tunnel != null and tunnel.powered and not tunnel.turned()


func failed() -> bool:
	var tunnel := _tunnel()
	return tunnel != null and tunnel.turned()


## The pump's outlet on its top, where the discharge pipe starts.
func pump_outlet() -> Vector2:
	return Vector2(motor_x + 118.0, floor_y - 86.0)


func _draw() -> void:
	_draw_cable()
	_draw_panel()
	_draw_pipes()
	_draw_motor()
	_draw_pump()


func _draw_cable() -> void:
	if cable.size() >= 2:
		draw_polyline(cable, CABLE, 4.0, true)
		for p in cable:
			draw_circle(p, 3.0, IRON)


func _draw_panel() -> void:
	var size := Vector2(64, 92)
	var r := Rect2(panel_at, size)
	draw_rect(r.grow(3.0), IRON_DARK)
	draw_rect(r, PAINT)
	draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(size.x - 12, 22)), PAINT_DARK)
	# Louvres, a handle, a warning plate.
	for k in 4:
		draw_line(r.position + Vector2(12, 40 + k * 9), r.position + Vector2(size.x - 12, 40 + k * 9), PAINT_DARK, 3.0)
	draw_rect(Rect2(r.position + Vector2(size.x - 10, 44), Vector2(4, 18)), IRON_LIGHT)
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(20, 82), r.position + Vector2(32, 70), r.position + Vector2(44, 82)]), Color("#c9a227"))
	# Two lamps: green while the pump runs, red after it failed.
	var green := Color(GREEN, 1.0 if running() else 0.18)
	var red := Color(RED, 0.2)
	if failed():
		red = Color(RED, 1.0 if (_world_tick / 8) % 2 == 0 else 0.35)
	draw_circle(r.position + Vector2(20, 17), 5.0, green)
	draw_circle(r.position + Vector2(44, 17), 5.0, red)


func _draw_pipes() -> void:
	# The suction pipe down from the pump through the slab into the tunnel.
	var down := Vector2(motor_x + 150.0, floor_y - 30.0)
	draw_line(down, Vector2(down.x, floor_y + 4.0), IRON, 18.0)
	draw_line(down + Vector2(-5, 0), Vector2(down.x - 5, floor_y + 4.0), IRON_LIGHT, 2.0)
	draw_rect(Rect2(Vector2(down.x - 15, floor_y - 10), Vector2(30, 10)), IRON_DARK)
	if discharge.size() >= 2:
		var line := PackedVector2Array([pump_outlet()])
		line.append_array(discharge)
		draw_polyline(line, IRON, 18.0)
		draw_polyline(line, IRON_LIGHT, 2.5)
		for i in range(1, line.size() - 1):
			draw_rect(Rect2(line[i] - Vector2(13, 13), Vector2(26, 26)), IRON)
		# Rust under the joint where it leaks.
		draw_rect(Rect2(line[1] + Vector2(-6, 13), Vector2(12, 40)), Color(RUST, 0.5))


func _draw_motor() -> void:
	var base := Rect2(Vector2(motor_x - 90.0, floor_y - 12.0), Vector2(260, 12))
	draw_rect(base, IRON_DARK)
	var body := Rect2(Vector2(motor_x - 70.0, floor_y - 74.0), Vector2(120, 60))
	draw_rect(body, PAINT)
	for k in 6:
		var x := body.position.x + 10.0 + k * 18.0
		draw_line(Vector2(x, body.position.y + 4), Vector2(x, body.end.y - 4), PAINT_DARK, 4.0)
	draw_rect(Rect2(body.position + Vector2(30, -14), Vector2(40, 14)), PAINT_DARK)
	# The fan's cover on the left end, the fan turning behind its grille.
	var fan := Vector2(body.position.x - 8.0, body.get_center().y)
	draw_circle(fan, 30.0, IRON_DARK)
	var a := fan_angle()
	for k in 3:
		var b := a + TAU * k / 3.0
		draw_line(fan, fan + Vector2(cos(b), sin(b)) * 25.0, IRON_LIGHT, 7.0)
	draw_circle(fan, 6.0, IRON)
	draw_arc(fan, 30.0, 0.0, TAU, 24, IRON, 3.0)
	for k in 3:
		draw_line(fan + Vector2(-26, -14 + k * 14), fan + Vector2(26, -14 + k * 14), Color(IRON, 0.8), 1.5)
	# The shaft and the coupling to the pump, its bolts turning.
	var shaft := Vector2(body.end.x, body.get_center().y)
	draw_line(shaft, shaft + Vector2(34, 0), IRON_LIGHT, 8.0)
	var c := shaft + Vector2(17, 0)
	draw_rect(Rect2(c - Vector2(8, 16), Vector2(16, 32)), IRON)
	draw_circle(c + Vector2(0, sin(a) * 11.0), 2.5, IRON_LIGHT)


func _draw_pump() -> void:
	var c := Vector2(motor_x + 118.0, floor_y - 44.0)
	draw_rect(Rect2(c + Vector2(-26, 20), Vector2(52, 24)), IRON_DARK)
	draw_circle(c, 34.0, IRON)
	draw_arc(c, 34.0, -PI * 0.2, PI * 1.3, 20, IRON_LIGHT, 3.0)
	draw_circle(c, 12.0, IRON_DARK)
	for k in 6:
		var b := TAU * k / 6.0
		draw_circle(c + Vector2(cos(b), sin(b)) * 25.0, 2.5, IRON_LIGHT)
	# The outlet on top.
	draw_rect(Rect2(pump_outlet() + Vector2(-11, 0), Vector2(22, 20)), IRON)
	draw_rect(Rect2(c + Vector2(20, 4), Vector2(14, 22)), IRON)
