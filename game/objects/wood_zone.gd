class_name WoodZone
extends StaticBody2D
## A recorded wood zone (task 2.7): a bridge, a wall, a plank. Whole → burning
## → burnt by `WoodBurn`; solid while whole or burning, a gap once burnt. Only
## `simulate_tick` burns it on, so fire is never reversed: under Shift the
## frames bring a burnt zone back through burning to whole, and a zone lit
## under Shift burns out only after Shift is released. Water over the zone and
## the reverse flamethrower in normal time put the fire out, and steam rises.
## The player standing in the flames burns (`burns_rect`, `Scorch`).
##
## Flames, sparks and steam are decoration drawn from world time (the group
## `world_clock`): under Shift the sparks fall back into the wood and the steam
## sinks back into it. Grey-blockout look until the art; the look of fire is a
## separate task.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const WOOD_COLOR := Color("#7d6a55")
const PLANK_COLOR := Color("#655544")
const CHAR_COLOR := Color("#2a2523")
const ASH_COLOR := Color("#4a4643")
const FLAME_COLOR := Color("#ff8c33")
const FLAME_CORE_COLOR := Color("#ffd56b")
const SPARK_COLOR := Color("#ffb347")
const STEAM_COLOR := Color("#e4eaee")

@export var object_id := "wood"
## The zone's size in pixels; the node is its centre.
@export var size := Vector2(256, 32)
@export_enum("Whole:0", "Burning:1", "Burnt:2") var start_phase := 0

var burn: WoodBurn
## The frame on which the fire was last put out, for the steam; -1 never.
var doused := -1
## +1 or -1, from TimeManager through RoomTime; for looks later.
var time_direction := 1
## The bottom of the player's body this deep inside the zone is standing on
## it, not being crushed (`carry_margin_px`, as for the door).
var carry_margin := 8.0

var _flame_px := 40.0
var _flame_side_px := 12.0
var _flames_per_cell := 2
var _sparks := 10
var _steam := {}
var _per_second := 60.0
## The world tick the look is drawn at.
var _clock := 0


func _init() -> void:
	var data := Content.objects()
	var time_data := Content.time()
	burn = WoodBurn.new(data.get("wood", {}), time_data)
	var wood: Dictionary = data.get("wood", {})
	_flame_px = float(wood.get("flame_px", 40))
	_flame_side_px = float(wood.get("flame_side_px", 12))
	_flames_per_cell = maxi(int(wood.get("flames_per_cell", 2)), 1)
	_sparks = maxi(int(wood.get("sparks", 10)), 0)
	_steam = data.get("steam", {})
	carry_margin = float(data.get("carry_margin_px", 8))
	_per_second = float(time_data.get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("flammable")
	add_to_group("fire")
	add_to_group("world_clock")
	burn.phase = clampi(start_phase, WoodBurn.Phase.WHOLE, WoodBurn.Phase.BURNT) as WoodBurn.Phase
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape.shape = rect_shape
	_apply()


func capture_state() -> Dictionary:
	return {"phase": int(burn.phase), "burn": burn.burn, "doused": doused}


func restore_state(state: Dictionary) -> void:
	burn.phase = clampi(int(state["phase"]), WoodBurn.Phase.WHOLE, WoodBurn.Phase.BURNT) as WoodBurn.Phase
	burn.burn = int(state["burn"])
	doused = int(state["doused"])
	_apply()


func simulate_tick(tick: int) -> void:
	if burn.tick(is_wet()) == WoodBurn.Event.DOUSED:
		doused = tick
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## A burnt zone is a gap; a whole or burning one coming back where the player
## stands would crush, so the world waits (section 2.3).
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area() or int(state["phase"]) == WoodBurn.Phase.BURNT:
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, carry_margin))
	return Rect2(position - size / 2.0, size).intersects(body)


func on_world_tick(tick: int, _recorded: bool) -> void:
	if tick != _clock:
		_clock = tick
		queue_redraw()


## The state a live source writes to light the zone; empty when it cannot burn.
func ignite_change() -> Dictionary:
	if burn.phase != WoodBurn.Phase.WHOLE:
		return {}
	return {"phase": WoodBurn.Phase.BURNING, "burn": 0, "doused": doused}


## The state a live source writes to put the fire out on frame `at_tick`;
## empty when nothing burns.
func douse_change(at_tick: int) -> Dictionary:
	if burn.phase != WoodBurn.Phase.BURNING:
		return {}
	return {"phase": WoodBurn.Phase.WHOLE, "burn": 0, "doused": at_tick}


## The zone in global pixels.
func global_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


## True while the zone burns and `rect` (global) is in its flames: the zone
## itself, `flame_px` above it and `flame_side_px` at its sides.
func burns_rect(rect: Rect2) -> bool:
	if not burn.is_burning():
		return false
	var fire := global_rect().grow_individual(_flame_side_px, _flame_px, _flame_side_px, 0.0)
	return fire.intersects(rect)


## True while water covers part of the zone.
func is_wet() -> bool:
	if not is_inside_tree():
		return false
	var zone := global_rect()
	for node in get_tree().get_nodes_in_group("water"):
		if node.has_method("water_global_rect"):
			var water: Rect2 = node.call("water_global_rect")
			if water.has_area() and water.intersects(zone):
				return true
	return false


## Seconds since the fire was put out at the shown frame; negative before.
func steam_age() -> float:
	if doused < 0:
		return -1.0
	return float(_clock - doused) / _per_second


func _apply() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not burn.is_solid()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	if burn.is_solid():
		draw_rect(rect, WOOD_COLOR.lerp(CHAR_COLOR, burn.charred()))
		var plank := 16.0
		var y := rect.position.y + plank
		while y < rect.end.y - 2.0:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), PLANK_COLOR.lerp(CHAR_COLOR, burn.charred()), 2.0)
			y += plank
	else:
		draw_rect(rect, ASH_COLOR, false, 2.0)
		draw_rect(Rect2(rect.position.x, rect.end.y - 4.0, rect.size.x, 4.0), ASH_COLOR)
	if burn.is_burning():
		_draw_fire(rect)
	_draw_steam(rect)


func _draw_fire(rect: Rect2) -> void:
	var t := float(_clock) / _per_second
	var count := maxi(int(ceil(rect.size.x / 64.0)) * _flames_per_cell, 1)
	var width := rect.size.x / count
	for i in count:
		var x := rect.position.x + width * (i + 0.5)
		var flicker := 0.65 + 0.35 * sin(t * 9.0 + i * 1.7)
		var height := _flame_px * flicker
		var base := rect.position.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - width * 0.45, base), Vector2(x + width * 0.45, base),
			Vector2(x + width * 0.1 * sin(t * 5.0 + i), base - height)]), FLAME_COLOR)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - width * 0.22, base), Vector2(x + width * 0.22, base),
			Vector2(x, base - height * 0.55)]), FLAME_CORE_COLOR)
	# Sparks rise with world time, so under Shift they fall back into the wood.
	for i in _sparks:
		var seed := fmod(i * 0.618, 1.0)
		var life := fposmod(t * 0.9 + seed, 1.0)
		var x := rect.position.x + rect.size.x * fmod(seed * 7.3, 1.0) + sin(t * 3.0 + i) * 6.0
		var y := rect.position.y - _flame_px * 0.4 - life * _flame_px * 1.6
		draw_circle(Vector2(x, y), 2.0, Color(SPARK_COLOR, 1.0 - life))


func _draw_steam(rect: Rect2) -> void:
	var age := steam_age()
	var seconds := float(_steam.get("seconds", 2.5))
	if age < 0.0 or age > seconds:
		return
	var puffs := maxi(int(_steam.get("puffs", 10)), 1)
	var rise := float(_steam.get("rise_px", 150))
	var radius := float(_steam.get("radius_px", 18))
	# Each puff starts a little later and lives half the steam time.
	var life := seconds * 0.5
	for i in puffs:
		var start := (seconds - life) * float(i) / float(puffs)
		var a := (age - start) / life
		if a < 0.0 or a > 1.0:
			continue
		var x := rect.position.x + rect.size.x * fmod(i * 0.618 + 0.1, 1.0) + sin(a * 4.0 + i) * 8.0
		var y := rect.position.y - rise * a
		draw_circle(Vector2(x, y), radius * (0.5 + a), Color(STEAM_COLOR, 0.55 * (1.0 - a)))
