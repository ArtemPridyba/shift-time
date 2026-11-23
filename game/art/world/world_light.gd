class_name WorldLight
extends Node2D
## Darkness and islands of light (task Д3, D65): the room is multiplied by the
## dark colour of `world.colors.darkness` (CanvasModulate), and every lamp of
## `world.lamps` in the level's entry hangs from the ceiling and casts a soft
## warm island (`PointLight2D`) on what the player uses. A lamp flickers a
## little by a formula of world time (`WorldData.lamp_energy`), so under Shift
## the flicker plays backwards; dust drifts in its light (`TimeParticles`,
## Д2, the light preset `lamp_dust`: five lamps on a screen) and is seen only
## there. A weak light of her own lights only the heroine
## (light mask 2), so she reads between the islands (D76). Nothing here is
## recorded or collides.

const HEROINE_MASK := 2

@export var level_id := ""
@export var player_path := NodePath("../Player")

var lights: Array[PointLight2D] = []
var _lamps: Array = []
## The row the lamp cables hang from (`ceiling` of the layout).
var _ceiling := 1.0
var _lamp: Dictionary
var _world: Dictionary
var _glow: Node2D
var _shine: Array[float] = []
var _seconds_per_frame := 1.0 / 60.0


func _ready() -> void:
	add_to_group("world_clock")
	# The chain picture repeats down to the lamp.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_world = WorldData.look()
	_lamp = _world.get("lamp", {})
	var layout := WorldData.layout(WorldData.entry(level_id))
	_lamps = layout.get("lamps", [])
	_ceiling = WorldData.ceiling(layout)
	var time_data := Content.time()
	_seconds_per_frame = float(time_data.get("snapshot_every_ticks", 1)) \
		/ maxf(float(time_data.get("physics_ticks_per_second", 60)), 1.0)
	var dark := CanvasModulate.new()
	dark.name = "Darkness"
	dark.color = WorldData.color(_world, "darkness")
	add_child(dark)
	var disc := KitTextures.soft_disc()
	var radius := float(_lamp.get("radius_px", 300))
	for i in _lamps.size():
		var at := WorldData.lamp_at(_lamps[i], _ceiling)
		var light := PointLight2D.new()
		light.name = "Light%d" % (i + 1)
		light.texture = disc
		light.texture_scale = radius * 2.0 / float(disc.get_width())
		light.color = Color.from_string(str(_lamp.get("color", "#ffb066")), Color.ORANGE)
		light.position = at + Vector2(0, float(_lamp.get("below_px", 150)))
		add_child(light)
		lights.append(light)
		_shine.append(1.0)
		var dust := TimeParticles.new()
		dust.name = "Dust%d" % (i + 1)
		dust.preset = "lamp_dust"
		dust.noise_seed = 17 + i * 5
		dust.position = at + Vector2(0, 12)
		add_child(dust)
	# The bulbs and their halo glow by themselves: the dark does not dim them.
	_glow = Node2D.new()
	_glow.name = "Glow"
	var glow_material := CanvasItemMaterial.new()
	glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_material
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	show_at(0.0)
	_light_heroine.call_deferred()


## The room's clock (`RoomTime`, group `world_clock`).
func on_world_tick(tick: int, _recorded: bool) -> void:
	show_at(float(tick) * _seconds_per_frame)


## The lamps as they are at world second `seconds`.
func show_at(seconds: float) -> void:
	var energy := maxf(float(_lamp.get("energy", 1.0)), 0.001)
	for i in lights.size():
		var e := WorldData.lamp_energy(_lamp, i, seconds)
		lights[i].energy = e
		_shine[i] = e / energy
	if _glow != null:
		_glow.queue_redraw()


## Chains and caged lamps: lit by the lamps like everything else.
func _draw() -> void:
	var picture := KitTextures.piece("lamp")
	var chain := KitTextures.piece("lamp_chain")
	for lamp: Dictionary in _lamps:
		var at := WorldData.lamp_at(lamp, _ceiling)
		# The lamp picture at its own size, the bulb where the glow is.
		var size := Vector2(picture.get_size()) / KitTextures.texel("lamp") if picture != null else Vector2.ZERO
		var top := at.y + 7.0 - size.y * float(_lamp.get("picture_bulb", 0.66)) if picture != null else at.y - 14.0
		# The chain it hangs on.
		if chain != null:
			var width := float(chain.get_width()) / KitTextures.texel("lamp_chain")
			KitTextures.draw_down(self, chain, Rect2(at.x - width / 2.0, _ceiling * WorldData.CELL, width, top + 2.0 - _ceiling * WorldData.CELL))
		else:
			var link := Vector2(at.x, _ceiling * WorldData.CELL)
			while link.y < top:
				draw_rect(Rect2(link - Vector2(1.5, 0), Vector2(3, 5)), WorldData.color(_world, "iron").lightened(0.1), false, 1.0)
				link.y += 6.0
		if picture != null:
			draw_texture_rect(picture, Rect2(at.x - size.x / 2.0, top, size.x, size.y), false)
			continue
		# A caged lamp (D115): a small rusty cap, a wire cage round the bulb.
		var rust := WorldData.color(_world, "rust").darkened(0.35)
		var wire := WorldData.color(_world, "iron").lightened(0.15)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-11, -1), at + Vector2(-6, -12),
			at + Vector2(6, -12), at + Vector2(11, -1)]), rust)
		draw_line(at + Vector2(-11, -1), at + Vector2(11, -1), rust.lightened(0.25), 2.0)
		draw_arc(at + Vector2(0, 8), 9.0, 0.0, PI, 10, wire, 1.5)
		for x in [-9.0, -3.0, 3.0, 9.0]:
			draw_line(at + Vector2(x, -1), at + Vector2(x * 0.7, 8.0 + sqrt(maxf(81.0 - x * x, 0.0)) * 0.9), wire, 1.2)
		draw_line(at + Vector2(-9, 8), at + Vector2(9, 8), wire, 1.2)


func _draw_glow() -> void:
	var bulb := WorldData.color(_world, "bulb")
	var halo_px := float(_lamp.get("halo_px", 40))
	var halo_alpha := float(_lamp.get("halo_alpha", 0.5))
	var disc := KitTextures.soft_disc()
	var light_color := Color.from_string(str(_lamp.get("color", "#ffb066")), Color.ORANGE)
	for i in _lamps.size():
		var at := WorldData.lamp_at(_lamps[i], _ceiling) + Vector2(0, 7)
		var halo := light_color
		halo.a = halo_alpha * _shine[i]
		_glow.draw_texture_rect(disc, Rect2(at - Vector2(halo_px, halo_px), Vector2(halo_px, halo_px) * 2.0), false, halo)
		_glow.draw_circle(at, 6.0, bulb * Color(1, 1, 1, clampf(_shine[i], 0.0, 1.0)))


## Her own weak light: it lights only what carries light mask 2, her body.
func _light_heroine() -> void:
	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return
	var own_data: Dictionary = _world.get("heroine_light", {})
	var disc := KitTextures.soft_disc()
	var own := PointLight2D.new()
	own.name = "OwnLight"
	own.texture = disc
	own.texture_scale = float(own_data.get("radius_px", 110)) * 2.0 / float(disc.get_width())
	own.energy = float(own_data.get("energy", 0.45))
	own.range_item_cull_mask = HEROINE_MASK
	own.position = Vector2(0, -46)
	player.add_child(own)
	_mask(player)


func _mask(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask |= HEROINE_MASK
	for child in node.get_children():
		_mask(child)
