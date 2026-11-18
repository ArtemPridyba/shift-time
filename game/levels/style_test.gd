extends Node2D
## The style showcase (task Д1): one room of samples drawn in the colours of
## the current palette. P switches the palettes of `art.json` right in the
## game, Shift runs the showcase's own time backwards (the gear, the rack, the
## flames and the motes of the wrist device turn back). Not a level: it is not
## in `levels.json`, records nothing and leaves the palette as it found it.
##
## The shapes are placeholders to show colour and the shared material, not
## design: the slab, the gear and the hero get their real shapes in later steps
## of Д1. Solid things are StyleShape nodes (the shared material); light, water,
## flames and the hero are still flat drawing on the front layer.

const ACTION_NEXT := "next_palette"
const SWATCH := Vector2(60, 26)
const ROW := 32.0
const FLOOR_Y := 900.0
const GEAR_CENTER := Vector2(980, 600)
const GEAR_RADIUS := 90.0
const GEAR_TEETH := 12
## Turns of the gear per second of showcase time.
const GEAR_TURNS := 0.15

## Showcase time: grows forward, falls under Shift, never below zero.
var tau := 0.0

var _font: Font
## Where the flat drawing goes now: this node (back) or the front layer.
var _c: CanvasItem
var _front: Node2D
var _gear: StyleShape
var _rack: StyleShape
var _rack_top := 0.0
var _tank: StyleBlock


func _ready() -> void:
	_font = ThemeDB.fallback_font
	Art.palette_changed.connect(_on_palette_changed)
	_build_samples()
	_front = Node2D.new()
	_front.name = "Front"
	add_child(_front)
	_front.draw.connect(_draw_front)


func _exit_tree() -> void:
	Art.reset()


func _physics_process(delta: float) -> void:
	# Polled on the tick, not read from events: shots and tests press actions
	# with `Input.action_press`, which sends no events.
	if Input.is_action_just_pressed(ACTION_NEXT):
		Art.cycle()
	tau = maxf(0.0, tau + TimeManager.direction * delta)
	var angle := tau * GEAR_TURNS * TAU
	_gear.rotation = angle
	# The rack moves by the arc the gear turns: no slipping.
	_rack.position.y = _rack_top + fposmod(angle * GEAR_RADIUS, _pitch())
	queue_redraw()
	_front.queue_redraw()


func _on_palette_changed(_palette: ArtPalette) -> void:
	queue_redraw()
	if _front != null:
		_front.queue_redraw()


func _draw() -> void:
	_c = self
	var p: ArtPalette = Art.palette
	_c.draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), p.shade("background"))
	_draw_back(p)
	_draw_swatches(p)


func _draw_front() -> void:
	_c = _front
	var p: ArtPalette = Art.palette
	_draw_lamp(p)
	_draw_hero(p)
	_draw_water(p)
	_draw_fire(p)
	_draw_caption(p)


# --- the swatch column ------------------------------------------------------

func _draw_swatches(p: ArtPalette) -> void:
	var panel := Rect2(24, 96, 540, ROW * (Content.ART_ROLES.size() + 1) + 24)
	_c.draw_rect(panel, p.shade("background", 1))
	var y := panel.position.y + 16
	for role in Content.ART_ROLES:
		_text(role, Vector2(40, y + 20), p.shade("background", 4), 18)
		for i in Content.ART_RAMP_SIZE:
			var rect := Rect2(Vector2(190 + i * (SWATCH.x + 6), y), SWATCH)
			_c.draw_rect(rect, p.shade(role, i))
			if i == ArtPalette.BASE:
				_c.draw_rect(rect, p.shade("background", 4), false, 2.0)
		y += ROW
	_text("skin", Vector2(40, y + 20), p.shade("background", 4), 18)
	_c.draw_rect(Rect2(Vector2(190, y), SWATCH), p.skin)


# --- the samples ------------------------------------------------------------

func _draw_back(p: ArtPalette) -> void:
	# A hint of the warehouse: far shelves darker and quieter than the front.
	for i in 6:
		var x := 720.0 + i * 200.0
		_c.draw_rect(Rect2(x, 340, 150, FLOOR_Y - 340), p.shade("background", 1))
		for shelf in 4:
			_c.draw_rect(Rect2(x - 6, 400 + shelf * 130, 162, 10), p.shade("background", 3).lerp(p.shade("background"), 0.6))


## The solid samples, painted by the shared material (StyleShape).
func _build_samples() -> void:
	var samples := Node2D.new()
	samples.name = "Samples"
	add_child(samples)
	var add := func(shape_name: String, svg: String, at: Vector2, role: String, rust: float = 0.0) -> StyleShape:
		var shape := StyleShape.new()
		shape.name = shape_name
		shape.centered = false
		shape.set_svg(svg)
		shape.position = at
		shape.role = role
		shape.rust = rust
		shape.wear_seed = float(samples.get_child_count()) * 3.7
		samples.add_child(shape)
		return shape
	# Rack and gear first, so that the pipe and the floor cover their ends.
	# Rack: teeth on the side of the gear, one pitch longer than shown so that
	# its moving top stays under the pipe.
	var pitch := _pitch()
	var rack_size := Vector2i(46, int(FLOOR_Y - 330.0 + pitch))
	var rack_body := '<rect x="12" width="34" height="%d" fill="%s"/>' % [rack_size.y, StyleMask.MAIN]
	var y := 0.0
	while y < rack_size.y:
		rack_body += '<path d="%s" fill="%s"/>' % [StyleMask.path(PackedVector2Array([
			Vector2(13, y), Vector2(0, y + pitch * 0.15), Vector2(0, y + pitch * 0.4), Vector2(13, y + pitch * 0.55)])), StyleMask.MAIN]
		y += pitch
	_rack_top = 330.0 - pitch
	_rack = add.call("Rack", StyleMask.svg(rack_size, rack_body), Vector2(GEAR_CENTER.x + GEAR_RADIUS - 10.0, _rack_top), "mechanism")
	# Gear: turns around its centre.
	_gear = add.call("Gear", StyleMask.gear(GEAR_TEETH, GEAR_RADIUS, GEAR_RADIUS - 16.0, 4, 11.0, 26.0), GEAR_CENTER, "mechanism")
	_gear.centered = true
	# Solid things are boxes in the room's perspective (StyleBlock): position and
	# size are the collision rectangle, the middle plane of the box.
	var box := func(box_name: String, rect: Rect2, depth: float, role: String, rust: float = 0.0) -> StyleBlock:
		var shape := StyleBlock.new()
		shape.name = box_name
		shape.size = rect.size
		shape.depth = depth
		shape.role = role
		shape.position = rect.position
		shape.front.rust = rust
		shape.front.wear_seed = float(samples.get_child_count()) * 3.7
		samples.add_child(shape)
		return shape
	var slab := func(slab_name: String, kind: String, rect: Rect2, left: bool = false, right: bool = false) -> StyleSlab:
		var shape := StyleSlab.new()
		shape.name = slab_name
		shape.kind = kind
		shape.size = rect.size
		shape.open_left = left
		shape.open_right = right
		shape.position = rect.position
		shape.role = "steel"
		shape.front.wear_seed = float(samples.get_child_count()) * 3.7
		samples.add_child(shape)
		return shape
	box.call("Pipe", Rect2(720, 250, 1180, 30), 30.0, "steel")
	box.call("Column", Rect2(740, 290, 56, FLOOR_Y - 290), 56.0, "rust", 0.6)
	# A floor with a pit, a ledge over it and a wall standing on the floor.
	slab.call("FloorLeft", "floor", Rect2(0, FLOOR_Y, 576, 1080 - FLOOR_Y), false, true)
	slab.call("Floor", "floor", Rect2(704, FLOOR_Y, 1216, 1080 - FLOOR_Y), true, false)
	slab.call("Ledge", "ledge", Rect2(256, 760, 192, 48), true, true)
	slab.call("Wall", "wall", Rect2(0, 644, 128, FLOOR_Y - 644))
	box.call("Crate", Rect2(1180, FLOOR_Y - 96, 96, 96), 96.0, "wood")
	box.call("Pedestal", Rect2(1440, FLOOR_Y - 70, 40, 70), 40.0, "steel")
	box.call("Button", Rect2(1448, FLOOR_Y - 86, 24, 16), 16.0, "interact")
	box.call("Lamp", Rect2(1316, 300, 48, 22), 22.0, "steel")
	box.call("Wood", Rect2(1720, FLOOR_Y - 60, 160, 60), 64.0, "wood")
	_tank = box.call("Tank", Rect2(1530, FLOOR_Y - 150, 150, 150), 120.0, "steel")


func _pitch() -> float:
	return TAU * GEAR_RADIUS / GEAR_TEETH


func _draw_lamp(p: ArtPalette) -> void:
	var at := Vector2(1340, 300)
	_c.draw_line(Vector2(at.x, 280), at, p.dark(), 3.0)
	var cone := PackedVector2Array([at + Vector2(-18, 20), at + Vector2(18, 20), at + Vector2(150, FLOOR_Y - at.y), at + Vector2(-150, FLOOR_Y - at.y)])
	var light := p.shade("lamp_light", 4)
	_c.draw_colored_polygon(cone, Color(light, 0.14))
	_c.draw_circle(at + Vector2(0, 24), 9.0, p.shade("lamp_light", 4))


func _draw_hero(p: ArtPalette) -> void:
	var feet := Vector2(1340, FLOOR_Y)
	_box(Rect2(feet.x - 16, feet.y - 30, 14, 30), "suit", p, 1)
	_box(Rect2(feet.x + 2, feet.y - 30, 14, 30), "suit", p, 1)
	_box(Rect2(feet.x - 22, feet.y - 82, 44, 54), "suit", p)
	_c.draw_rect(Rect2(feet.x - 22, feet.y - 60, 44, 6), p.shade("helmet", 4))
	_c.draw_rect(Rect2(feet.x - 14, feet.y - 104, 28, 22), p.skin)
	_c.draw_rect(Rect2(feet.x - 14, feet.y - 104, 28, 22), p.dark(), false, 2.0)
	var helmet := PackedVector2Array()
	for i in 13:
		var a := PI + i * PI / 12.0
		helmet.append(feet + Vector2(0, -102) + Vector2(cos(a) * 20, sin(a) * 16))
	_c.draw_colored_polygon(helmet, p.shade("helmet"))
	_c.draw_rect(Rect2(feet.x - 24, feet.y - 104, 48, 5), p.shade("helmet", 1))
	_c.draw_rect(Rect2(feet.x - 30, feet.y - 34, 9, 6), p.dark())
	_c.draw_rect(Rect2(feet.x + 21, feet.y - 34, 9, 6), p.dark())
	# Arm with the wrist device; its motes circle forward, backwards under Shift.
	_box(Rect2(feet.x + 22, feet.y - 80, 12, 40), "suit", p, 1)
	var device := Vector2(feet.x + 28, feet.y - 46)
	_c.draw_circle(device, 13.0, Color(p.shade("time", 3), 0.25 + 0.15 * sin(tau * 6.0)))
	_c.draw_rect(Rect2(device - Vector2(8, 5), Vector2(16, 10)), p.shade("time"))
	for i in 5:
		var a := tau * 3.0 + i * TAU / 5.0
		_c.draw_circle(device + Vector2(cos(a), sin(a)) * 22.0, 2.5, p.shade("time", 4 - i % 2))


func _draw_water(p: ArtPalette) -> void:
	# The water fills the front face of the tank box.
	var tank: Rect2 = _tank.front_rect()
	_c.draw_rect(tank, p.shade("steel", 1))
	var level: float = tank.size.y * 0.66 + 10.0 * sin(tau * 1.5)
	var water := Rect2(tank.position.x + 8, tank.end.y - level, tank.size.x - 16, level)
	_c.draw_rect(water, p.shade("water"))
	_c.draw_rect(Rect2(water.position, Vector2(water.size.x, 6)), p.shade("water", 4))
	_c.draw_rect(Rect2(water.position.x, water.end.y - 24, water.size.x, 24), p.shade("water", 1))
	_c.draw_rect(tank, p.dark(), false, 3.0)


func _draw_fire(p: ArtPalette) -> void:
	var wood := Rect2(1720, FLOOR_Y - 60, 160, 60)
	for i in 5:
		var x := wood.position.x + 18 + i * 31.0
		var h := 50.0 + 22.0 * sin(tau * 7.0 + i * 1.7)
		var base := wood.position.y + 2
		_c.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, base), Vector2(x + 14, base), Vector2(x + 3, base - h)]), p.shade("fire"))
		_c.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, base), Vector2(x + 7, base), Vector2(x + 1, base - h * 0.55)]), p.shade("fire", 4))


## The drawing rule, flat (for what has no material yet): dark outline, body in the main colour, a
## light edge on top and a shadow at the bottom (light from the top left).
func _box(rect: Rect2, role: String, p: ArtPalette, base: int = ArtPalette.BASE) -> void:
	_c.draw_rect(rect, p.shade(role, base))
	var edge := minf(5.0, rect.size.y * 0.2)
	_c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, edge)), p.shade(role, base + 1))
	_c.draw_rect(Rect2(rect.position.x, rect.end.y - edge, rect.size.x, edge), p.shade(role, base - 1))
	_c.draw_rect(rect, p.dark(), false, 2.0)


# --- caption ----------------------------------------------------------------

func _draw_caption(p: ArtPalette) -> void:
	var light := p.shade("background", 4)
	_text("Style test — %s (%s)" % [p.title, p.id], Vector2(24, 52), light, 32)
	_text("P: next palette    Shift: rewind", Vector2(24, 84), p.shade("background", 3), 20)
	var reverse := TimeManager.is_rewinding()
	_text(("<< REWIND" if reverse else "FORWARD >>") + "   t = %.2f" % tau, Vector2(1500, 52), p.shade("time") if reverse else light, 28)


func _text(text: String, at: Vector2, color: Color, size: int) -> void:
	_c.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
