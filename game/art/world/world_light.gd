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
## recorded or collides. In a level with quakes (`Quakes`, a sibling node, D127)
## the lamps swing while the room shakes and a falling lamp drops to the floor,
## goes dark and breaks; all of it is read from the recorded quake.

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
## Where falls of lamps come from: `Quakes` (level 01) or `Crane` (level 05),
## a sibling with `lamp_fall(i)` and `swing(i)`.
var _quakes: Node
## Per lamp: {"drop", "light", "shatter", "to_row"} while one falls (Quakes.lamp_fall).
var _falls: Array[Dictionary] = []
var _swings: Array[float] = []
var _bases: Array[Vector2] = []
## The flight a falling lamp's shards may land on (a sibling `Stairs`), or null.
var _stairs: Stairs


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
	# A level may be darker than the kit (level 05: the dark is the difficulty).
	if layout.get("darkness") is String:
		dark.color = Color.from_string(str(layout["darkness"]), dark.color)
	add_child(dark)
	var disc := KitTextures.soft_disc()
	var radius := float(_lamp.get("radius_px", 300))
	for i in _lamps.size():
		var at := WorldData.lamp_at(_lamps[i], _ceiling)
		var light := PointLight2D.new()
		light.name = "Light%d" % (i + 1)
		light.texture = disc
		# A lamp may light a wider island than the kit's (level 05: the pillar by the crane).
		var own_radius := float(_lamps[i].get("radius_px", radius)) if _lamps[i] is Dictionary else radius
		light.texture_scale = own_radius * 2.0 / float(disc.get_width())
		light.color = Color.from_string(str(_lamp.get("color", "#ffb066")), Color.ORANGE)
		light.position = at + Vector2(0, float(_lamp.get("below_px", 150)))
		add_child(light)
		lights.append(light)
		_bases.append(light.position)
		_shine.append(1.0)
		_falls.append({})
		_swings.append(0.0)
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
	_stairs = get_node_or_null("../Stairs") as Stairs
	_quakes = get_node_or_null("../Quakes")
	if _quakes == null:
		_quakes = get_node_or_null("../Crane")
	show_at(0.0)
	_light_heroine.call_deferred()


## How bright lamp `i` is now against its full light, about 0..1: flicker,
## fall and the flash of its breaking (the painted room's cones follow it).
func shine(i: int) -> float:
	return _shine[i] if i >= 0 and i < _shine.size() else 0.0


## The room's clock (`RoomTime`, group `world_clock`).
func on_world_tick(tick: int, _recorded: bool) -> void:
	_read_quakes()
	show_at(float(tick) * _seconds_per_frame)


## The lamps as they are at world second `seconds`.
func show_at(seconds: float) -> void:
	var energy := maxf(float(_lamp.get("energy", 1.0)), 0.001)
	for i in lights.size():
		var e := WorldData.lamp_energy(_lamp, i, seconds)
		var fall := _falls[i]
		if not fall.is_empty():
			# The light dies on the way down; the impact flashes once on the floor.
			var shatter := float(fall["shatter"])
			var flash := 0.9 * (1.0 - shatter) * (1.0 - shatter) if shatter > 0.0 else 0.0
			e *= maxf(float(fall["light"]), flash)
			lights[i].position = _bases[i] + Vector2(0, _drop_px(i))
		lights[i].energy = e
		_shine[i] = e / energy
	if _glow != null:
		_glow.queue_redraw()


## The quake's part: swings and falls of the lamps now (`Quakes`, D127).
func _read_quakes() -> void:
	if _quakes == null:
		return
	var changed := false
	for i in _lamps.size():
		var fall: Dictionary = _quakes.call("lamp_fall", i)
		var swing := float(_quakes.call("swing", i))
		if fall != _falls[i] or swing != _swings[i]:
			changed = true
		_falls[i] = fall
		_swings[i] = swing
	if changed:
		queue_redraw()


## How far lamp `i` has fallen now, in pixels.
func _drop_px(i: int) -> float:
	var fall := _falls[i]
	if fall.is_empty():
		return 0.0
	var at := WorldData.lamp_at(_lamps[i], _ceiling)
	var bottom := float(fall["to_row"]) * WorldData.CELL - 10.0
	return maxf(bottom - at.y, 0.0) * float(fall["drop"])


## Chains and caged lamps: lit by the lamps like everything else.
func _draw() -> void:
	var picture := KitTextures.piece("lamp")
	var chain := KitTextures.piece("lamp_chain")
	for i in _lamps.size():
		var at := WorldData.lamp_at(_lamps[i], _ceiling)
		var top_y := _ceiling * WorldData.CELL
		if not _falls[i].is_empty() and float(_falls[i]["drop"]) > 0.0:
			_draw_fallen(i, at, picture, chain)
			continue
		# While the room shakes the lamp swings on its chain from the ceiling.
		draw_set_transform(Vector2(at.x, top_y), _swings[i])
		at = Vector2(0.0, at.y - top_y)
		# The lamp picture at its own size, the bulb where the glow is.
		var size := Vector2(picture.get_size()) / KitTextures.texel("lamp") if picture != null else Vector2.ZERO
		var top := at.y + 7.0 - size.y * float(_lamp.get("picture_bulb", 0.66)) if picture != null else at.y - 14.0
		# The chain it hangs on.
		if chain != null:
			var width := float(chain.get_width()) / KitTextures.texel("lamp_chain")
			KitTextures.draw_down(self, chain, Rect2(at.x - width / 2.0, 0.0, width, top + 2.0))
		else:
			var link := Vector2(at.x, 0.0)
			while link.y < top:
				draw_rect(Rect2(link - Vector2(1.5, 0), Vector2(3, 5)), WorldData.color(_world, "iron").lightened(0.1), false, 1.0)
				link.y += 6.0
		if picture != null:
			draw_texture_rect(picture, Rect2(at.x - size.x / 2.0, top, size.x, size.y), false)
			draw_set_transform(Vector2.ZERO)
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
		draw_set_transform(Vector2.ZERO)


## A lamp torn loose by a quake: a stub of chain on the ceiling, the lamp on
## its way down; it hits the floor, hops once and rolls onto its side, its
## glass bursts into shards that fly out in arcs and come to rest on the treads
## (`Stairs`) or the floor. All of it is a formula of the recorded fall, so
## under Shift the shards fly back together and the lamp back up.
func _draw_fallen(i: int, at: Vector2, picture: Texture2D, chain: Texture2D) -> void:
	var fall := _falls[i]
	var look := ObjectLook.of("quake")
	var top_y := _ceiling * WorldData.CELL
	if chain != null:
		var width := float(chain.get_width()) / KitTextures.texel("lamp_chain")
		KitTextures.draw_down(self, chain, Rect2(at.x - width / 2.0, top_y, width, minf(at.y - top_y, 40.0)))
	var size := Vector2(picture.get_size()) / KitTextures.texel("lamp") if picture != null else Vector2(22, 30)
	var shatter := float(fall["shatter"])
	# One hop off the floor in the first half of the breaking, then it lies.
	var hop_part := clampf(shatter * 2.0, 0.0, 1.0)
	var hop := ObjectLook.number(look, "lamp_bounce_px", 12.0) * 4.0 * hop_part * (1.0 - hop_part)
	var roll := 1.0 - (1.0 - shatter) * (1.0 - shatter)
	var centre := at + Vector2(10.0 * roll, _drop_px(i) + size.y * 0.1 - hop)
	var turn := 1.5 * roll + 0.25 * float(fall["drop"])
	if picture != null:
		# Without its glass and light the lamp is a dull iron cage.
		var dull := Color(1, 1, 1).lerp(Color(0.72, 0.7, 0.68), shatter)
		ObjectLook.draw_turned(self, picture, centre, size, turn, dull)
	if shatter <= 0.0:
		return
	_draw_shards(self, i, at, WorldData.color(_world, "glass").lightened(0.35), 0.0)


## The glass of fallen lamp `i` on `item`: drawn lit with the room, and once
## more faintly in the glow (`glint` 0..1) so it catches the eye in the dark.
func _draw_shards(item: CanvasItem, i: int, at: Vector2, glass: Color, glint: float) -> void:
	var fall := _falls[i]
	var shatter := float(fall["shatter"])
	if shatter <= 0.0:
		return
	var look := ObjectLook.of("quake")
	var origin := Vector2(at.x, float(fall["to_row"]) * WorldData.CELL - 8.0)
	for k in int(ObjectLook.number(look, "lamp_shards", 14.0)):
		var shard := _shard(i, k, origin, shatter, look)
		var s := float(shard["size"])
		var turned := Transform2D(float(shard["angle"]), shard["at"] as Vector2)
		var points := PackedVector2Array([Vector2(-s, -s * 0.35), Vector2(s * 0.8, -s * 0.5), Vector2(s * 0.4, s * 0.45)])
		var color := glass.darkened(0.25 * float(shard["shade"]))
		if glint > 0.0:
			color.a = glint * (0.5 + 0.5 * float(shard["shade"]))
		item.draw_colored_polygon(turned * points, color)


## Shard `k` of lamp `i` at `shatter` (0..1 of the breaking): it flies from
## `origin` with its own speed under gravity and stops where it meets the
## ground. {"at": Vector2, "angle", "size", "shade"}.
func _shard(i: int, k: int, origin: Vector2, shatter: float, look: Dictionary) -> Dictionary:
	var r1 := _noise(i, k, 1.0)
	var r2 := _noise(i, k, 2.0)
	var r3 := _noise(i, k, 3.0)
	var speed := Vector2((r1 * 2.0 - 1.0) * ObjectLook.number(look, "shard_speed_px", 170.0),
			-(0.35 + 0.65 * r2) * ObjectLook.number(look, "shard_hop_px", 260.0))
	var gravity := ObjectLook.number(look, "gravity_px", 1500.0)
	var seconds := shatter * ObjectLook.number(look, "shatter_seconds", 0.6)
	var spin := (r2 - 0.5) * 24.0
	var step := 1.0 / 60.0
	var t := 0.0
	var at := origin
	# Step the arc until the shard meets the ground, then it lies there.
	while t < seconds:
		var dt := minf(step, seconds - t)
		var next := at + speed * dt + Vector2(0.0, gravity * dt * dt * 0.5)
		speed.y += gravity * dt
		var ground := _ground_y(next.x, origin.y + 8.0) - 1.5
		if next.y > ground and ground < at.y - 0.5:
			# It meets the riser of a higher tread: it bounces back off it.
			speed.x = -speed.x * 0.3
			next.x = at.x
			ground = _ground_y(next.x, origin.y + 8.0) - 1.5
		if speed.y > 0.0 and next.y >= ground:
			at = Vector2(next.x, ground)
			t += dt
			break
		at = next
		t += dt
	return {"at": at, "angle": spin * t, "size": 3.0 + 5.0 * r3, "shade": r1}


## The ground under room x where a fall lies: a tread of the stairs, or the floor.
func _ground_y(x: float, floor_y: float) -> float:
	if _stairs != null:
		var r := _stairs.rect_px()
		if x >= r.position.x and x < r.end.x:
			return _stairs.tread_y(x)
	return floor_y


## A fixed number 0..1 for lamp `i`, piece `k`, channel `c`: the same every time.
static func _noise(i: int, k: int, c: float) -> float:
	return fposmod(sin(float(k) * 12.9898 + float(i) * 78.233 + c * 37.719) * 43758.5453, 1.0)


## Sparks of the breaking lamp: short streaks out of the impact that fade.
func _draw_sparks(i: int, at: Vector2) -> void:
	var fall := _falls[i]
	var look := ObjectLook.of("quake")
	var part := float(fall["shatter"]) * 2.0
	if part <= 0.0 or part >= 1.0:
		return
	var origin := Vector2(at.x, float(fall["to_row"]) * WorldData.CELL - 10.0)
	var reach := ObjectLook.number(look, "spark_px", 46.0)
	var bulb := WorldData.color(_world, "bulb")
	for k in int(ObjectLook.number(look, "sparks", 10.0)):
		var angle := -PI * (0.08 + 0.84 * _noise(i, k, 5.0))
		var dir := Vector2.from_angle(angle)
		var far := reach * (0.5 + 0.5 * _noise(i, k, 6.0)) * part
		var tip := origin + dir * far + Vector2(0.0, 30.0 * part * part)
		var color := bulb
		color.a = 1.0 - part
		_glow.draw_line(tip - dir * 7.0, tip, color, 1.5)


func _draw_glow() -> void:
	var bulb := WorldData.color(_world, "bulb")
	var halo_px := float(_lamp.get("halo_px", 40))
	var halo_alpha := float(_lamp.get("halo_alpha", 0.5))
	var disc := KitTextures.soft_disc()
	var light_color := Color.from_string(str(_lamp.get("color", "#ffb066")), Color.ORANGE)
	for i in _lamps.size():
		var at := WorldData.lamp_at(_lamps[i], _ceiling) + Vector2(0, 7)
		if not _falls[i].is_empty():
			_draw_sparks(i, at)
			_draw_shards(_glow, i, WorldData.lamp_at(_lamps[i], _ceiling), Color("#cfe6ff"),
					ObjectLook.number(ObjectLook.of("quake"), "shard_glint", 0.3))
			at.y += _drop_px(i)
		else:
			# The bulb swings with its lamp.
			var top_y := _ceiling * WorldData.CELL
			at = Vector2(at.x, top_y) + Vector2(0, at.y - top_y).rotated(_swings[i])
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
