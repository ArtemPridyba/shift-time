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
## The look (task 2.7А) is decoration from `FireLook`, drawn from world time
## (the group `world_clock`) and the recorded state: a wood shader that chars
## from the top with an ember edge, a flame shader, a warm glow, sparks, smoke,
## the ash of a zone that burns out and the steam of a fire put out. Under
## Shift it all plays backwards: the tongues flow down, sparks fall back, the
## ash flies back up into the plank; at frame 0 the fire stands still. The
## glow does not light dark rooms (D55).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const CHAR_COLOR := Color("#1f1a18")
const ASH_COLOR := Color("#5a5450")
const EMBER_COLOR := Color("#ff8a3d")
const SPARK_COLOR := Color("#ffc46b")
const SMOKE_COLOR := Color("#3b3837")
const STEAM_COLOR := Color("#e4eaee")
const GLOW_COLOR := Color("#ff7a2a")
const WOOD_SHADER := preload("res://objects/wood.gdshader")
const FLAME_SHADER := preload("res://objects/wood_flame.gdshader")

@export var object_id := "wood"
## The zone's size in pixels; the node is its centre.
@export var size := Vector2(256, 32)
@export_enum("Whole:0", "Burning:1", "Burnt:2") var start_phase := 0

var burn: WoodBurn
## The frame on which the fire was last put out, for the steam; -1 never.
var doused := -1
## The frame on which the zone burnt out, for the ash and the last smoke; -1
## when it never burnt out at the head (set burnt in the scene).
var burnt := -1
## +1 or -1, from TimeManager through RoomTime; for looks later.
var time_direction := 1
## The bottom of the player's body this deep inside the zone is standing on
## it, not being crushed (`carry_margin_px`, as for the door).
var carry_margin := 8.0

var look := FireLook.new()
var _flame_px := 40.0
var _flame_side_px := 12.0
var _flame_rise_px := 90.0
var _glow_radius_px := 150.0
var _glow_alpha := 0.35
var _per_second := 60.0
var _wood: ColorRect
var _flames: ColorRect
var _glow: Sprite2D
var _behind: Node2D
var _front: Node2D
## The world tick the look is drawn at.
var _clock := 0


func _init() -> void:
	var data := Content.objects()
	var time_data := Content.time()
	burn = WoodBurn.new(data.get("wood", {}), time_data)
	var wood: Dictionary = data.get("wood", {})
	_flame_px = float(wood.get("flame_px", 40))
	_flame_side_px = float(wood.get("flame_side_px", 12))
	var fire_look: Dictionary = data.get("fire_look", {})
	_flame_rise_px = float(fire_look.get("flame_rise_px", 90))
	_glow_radius_px = float(fire_look.get("glow_radius_px", 150))
	_glow_alpha = float(fire_look.get("glow_alpha", 0.35))
	look.configure(data, time_data)
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
	_build_look()
	_apply()


func capture_state() -> Dictionary:
	return {"phase": int(burn.phase), "burn": burn.burn, "doused": doused, "burnt": burnt}


func restore_state(state: Dictionary) -> void:
	burn.phase = clampi(int(state["phase"]), WoodBurn.Phase.WHOLE, WoodBurn.Phase.BURNT) as WoodBurn.Phase
	burn.burn = int(state["burn"])
	doused = int(state["doused"])
	burnt = int(state.get("burnt", -1))
	_apply()


func simulate_tick(tick: int) -> void:
	match burn.tick(is_wet()):
		WoodBurn.Event.DOUSED:
			doused = tick
		WoodBurn.Event.BURNT_OUT:
			burnt = tick
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
		_update_look()


## The state a live source writes to light the zone; empty when it cannot burn.
func ignite_change() -> Dictionary:
	if burn.phase != WoodBurn.Phase.WHOLE:
		return {}
	return {"phase": WoodBurn.Phase.BURNING, "burn": 0, "doused": doused, "burnt": burnt}


## The state a live source writes to put the fire out on frame `at_tick`;
## empty when nothing burns.
func douse_change(at_tick: int) -> Dictionary:
	if burn.phase != WoodBurn.Phase.BURNING:
		return {}
	return {"phase": WoodBurn.Phase.WHOLE, "burn": 0, "doused": at_tick, "burnt": burnt}


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
	return look.age(_clock, doused)


## What the look shows now, for the tests: the same at the same world tick
## going forward and rewinding.
func look_snapshot() -> Dictionary:
	var shot := look.snapshot(_clock, capture_state(), burn.burn_ticks, size)
	shot["tick"] = _clock
	return shot


func _apply() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not burn.is_solid()
	_update_look()


## The children that draw the zone, back to front: the wood, smoke, flames,
## glow, then sparks, ash and steam.
func _build_look() -> void:
	_wood = _shader_rect("Wood", WOOD_SHADER, Rect2(-size / 2.0, size))
	var mat := _wood.material as ShaderMaterial
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("vertical", 1.0 if size.y > size.x else 0.0)
	_behind = Node2D.new()
	_behind.name = "Smoke"
	_behind.draw.connect(_draw_smoke)
	add_child(_behind)
	var rise := _flame_px * 1.8
	var flame_rect := Rect2(-size.x / 2.0 - _flame_side_px, -size.y / 2.0 - rise, size.x + 2.0 * _flame_side_px, size.y + rise)
	_flames = _shader_rect("Flames", FLAME_SHADER, flame_rect)
	mat = _flames.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", flame_rect.size)
	mat.set_shader_parameter("zone_pos", Vector2(_flame_side_px, rise))
	mat.set_shader_parameter("zone_size", size)
	mat.set_shader_parameter("flame_px", _flame_px)
	mat.set_shader_parameter("rise_px", _flame_rise_px)
	mat.set_shader_parameter("side_px", _flame_side_px)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(GLOW_COLOR, 1.0))
	gradient.set_color(1, Color(GLOW_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_glow.texture = texture
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	var reach := Vector2(size.x + 2.0 * _glow_radius_px, size.y + 2.0 * _glow_radius_px)
	_glow.scale = reach / 128.0
	_glow.position = Vector2(0.0, -_flame_px * 0.5)
	add_child(_glow)
	_front = Node2D.new()
	_front.name = "Sparks"
	_front.draw.connect(_draw_front)
	add_child(_front)


func _shader_rect(node_name: String, shader: Shader, rect: Rect2) -> ColorRect:
	var node := ColorRect.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material = mat
	add_child(node)
	return node


func _update_look() -> void:
	queue_redraw()
	if _wood == null:
		return
	var t := float(_clock) / _per_second
	var strength := look.flame_strength(burn.phase, burn.burn, burn.burn_ticks)
	_wood.visible = burn.is_solid()
	var mat := _wood.material as ShaderMaterial
	mat.set_shader_parameter("charred", burn.charred())
	mat.set_shader_parameter("heat", maxf(strength, 0.35) if burn.is_burning() else 0.0)
	mat.set_shader_parameter("time", t)
	_flames.visible = strength > 0.0
	mat = _flames.material as ShaderMaterial
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("time", t)
	_glow.visible = strength > 0.0
	_glow.modulate = Color(1.0, 1.0, 1.0, _glow_alpha * strength * (0.85 + 0.15 * sin(t * 11.0)))
	_behind.queue_redraw()
	_front.queue_redraw()


## A burnt zone leaves charred stubs at its ends (a bridge) or its foot (a
## wall), so the player sees what was there.
func _draw() -> void:
	if burn.is_solid():
		return
	var rect := Rect2(-size / 2.0, size)
	if size.y > size.x:
		draw_rect(Rect2(rect.position.x, rect.end.y - 10.0, rect.size.x, 10.0), CHAR_COLOR)
		draw_rect(Rect2(rect.position.x + 4.0, rect.end.y - 3.0, rect.size.x - 8.0, 3.0), ASH_COLOR)
	else:
		var stub := minf(rect.size.x * 0.08, 20.0)
		draw_rect(Rect2(rect.position, Vector2(stub, rect.size.y)), CHAR_COLOR)
		draw_rect(Rect2(Vector2(rect.end.x - stub, rect.position.y), Vector2(stub, rect.size.y)), CHAR_COLOR)


func _shot() -> Dictionary:
	return look.snapshot(_clock, capture_state(), burn.burn_ticks, size)


func _draw_smoke() -> void:
	for puff: Vector4 in _shot()["smoke"]:
		_soft_puff(_behind, Vector2(puff.x, puff.y), puff.z, SMOKE_COLOR, puff.w)


func _draw_front() -> void:
	var shot := _shot()
	for spark: Vector3 in shot["sparks"]:
		_front.draw_circle(Vector2(spark.x, spark.y), 2.0, Color(SPARK_COLOR, spark.z))
	for piece: Vector4 in shot["ash"]:
		var color := ASH_COLOR.lerp(EMBER_COLOR, piece.w)
		_front.draw_rect(Rect2(Vector2(piece.x, piece.y) - Vector2.ONE * piece.z / 2.0, Vector2.ONE * piece.z), color)
	for puff: Vector4 in shot["steam"]:
		_soft_puff(_front, Vector2(puff.x, puff.y), puff.z, STEAM_COLOR, puff.w)


## A puff with a soft edge: rings that thicken towards the middle.
func _soft_puff(canvas: Node2D, at: Vector2, radius: float, color: Color, alpha: float) -> void:
	for ring in 4:
		var k := 1.0 - ring * 0.22
		canvas.draw_circle(at, radius * k, Color(color, alpha * 0.28))
