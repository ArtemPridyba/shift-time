class_name TimeParticles
extends MultiMeshInstance2D
## Particles that run backwards (task Д2): dust in a lamp's light, ash, the
## sparks of a wire, shards, drops. The place of every particle is a formula of
## world time (`ParticleField`), drawn by one MultiMesh. Nothing is recorded:
## the node joins `world_clock` and draws the frame the room shows, so under
## Shift the dust drifts back up, the shards fly back together, the drops climb
## back into the pipe. Decoration only, it affects nothing (D21).
##
## The numbers of each kind are a preset in `particles` of `data/look.json`;
## the scene only places the emitter, picks the preset and, for event bursts
## (a lamp shattering), gives their moments in world seconds.

## A preset name in `particles` of `data/look.json`.
@export var preset := "dust"
## Two emitters with the same preset and seed look the same; give each its own.
@export var noise_seed := 1
## Moments of extra bursts, in world seconds (the shards of a lamp at 14 s).
@export var bursts_at := PackedFloat32Array()
## A floor at this height in the node's coordinates: shards stop there, drops end.
@export var has_floor := false
## False: the node's owner shows the particles at its own seconds (`show_at`),
## the room's clock does not (a breakdown's sparks count from the breakdown).
@export var own_clock := true
## The stream starts at time 0 instead of having always run (`ParticleField`).
@export var starts_empty := false
@export var floor_y := 0.0

var field: ParticleField
## What the last frame drew: ParticleField.STRIDE floats per particle (for tests).
var last_sample := PackedFloat32Array()
var world_seconds := 0.0

var _seconds_per_frame := 1.0 / 60.0
var _color := Color.WHITE
var _color_end := Color.WHITE


func _ready() -> void:
	if own_clock:
		add_to_group("world_clock")
	var data: Variant = Content.look_particles().get(preset)
	if not data is Dictionary:
		push_error("TimeParticles: no preset '%s' in data/look.json" % preset)
		return
	field = ParticleField.from_preset(data, noise_seed)
	field.extra_bursts = bursts_at
	field.starts_empty = starts_empty
	if has_floor:
		field.set_floor(floor_y)
	var time_data := Content.time()
	_seconds_per_frame = float(time_data.get("snapshot_every_ticks", 1)) \
		/ maxf(float(time_data.get("physics_ticks_per_second", 60)), 1.0)
	_color = Color.from_string(str(data.get("color", "#ffffff")), Color.WHITE)
	_color_end = Color.from_string(str(data.get("color_end", data.get("color", "#ffffff"))), _color)
	_build(str(data.get("shape", "dot")), str(data.get("blend", "mix")))
	show_at(0.0)


## The room's clock (`RoomTime`, group `world_clock`): the world tick it shows now.
func on_world_tick(tick: int, _recorded: bool) -> void:
	show_at(float(tick) * _seconds_per_frame)


## Draws the particles of world time `seconds`.
func show_at(seconds: float) -> void:
	if field == null:
		return
	world_seconds = seconds
	last_sample = field.sample(seconds)
	var count := mini(last_sample.size() / ParticleField.STRIDE, multimesh.instance_count)
	for k in count:
		var o := k * ParticleField.STRIDE
		var xf := Transform2D(last_sample[o + 2], Vector2(last_sample[o + 3], last_sample[o + 4]), 0.0,
			Vector2(last_sample[o], last_sample[o + 1]))
		multimesh.set_instance_transform_2d(k, xf)
		var c := _color.lerp(_color_end, last_sample[o + 6])
		c.a = last_sample[o + 5]
		multimesh.set_instance_color(k, c)
	multimesh.visible_instance_count = count


## How many particles are drawn now.
func alive_count() -> int:
	return last_sample.size() / ParticleField.STRIDE


func _build(shape: String, blend: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _mesh(shape)
	mm.instance_count = maxi(field.capacity(), 1)
	mm.visible_instance_count = 0
	multimesh = mm
	if shape == "dot" or shape == "streak":
		texture = _soft_texture()
	if blend == "add":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


## A unit quad, or a unit triangle for shards; the instance transform sizes it.
static func _mesh(shape: String) -> Mesh:
	if shape == "shard":
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.35), Vector2(0.5, -0.1), Vector2(-0.15, 0.5)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0.25), Vector2(0.35, 1)])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return quad


## A soft round spot: white in the middle, clear at the edge.
static func _soft_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
