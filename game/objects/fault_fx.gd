class_name FaultFx
extends Node2D
## A breakdown that shows (level 02, 25.11 notes): when a tank's pump fails
## (`Water.fault_seconds`), sparks burst out here (the particle preset `sparks`
## of `data/look.json`, as `SparkingWire`), smoke rises (preset `smoke`) and
## the lamps named in `lamps` blink. Decoration: it records nothing and
## changes nothing. Everything is drawn from the seconds since the failure, a
## pure function of the tank's recorded state, so under Shift the smoke sinks
## back, the sparks fly back in and the lamps calm down before the failure.
## Blink numbers: `kit_objects.fault` of `data/look.json`.

## The tank with the failing pump, by path from this node.
@export var water_path: NodePath
@export var sparks := true
@export var smoke := false
## Where the smoke comes out, from this node (sparks come from its origin).
@export var smoke_at := Vector2.ZERO
## The floor below the sparks, from this node: they die there.
@export var floor_y := 64.0
## Indices of the room's lamps (`lamps` of the level's world) that blink.
@export var lamps := PackedInt32Array()
@export var noise_seed := 31

var spark_particles: TimeParticles
var smoke_particles: TimeParticles
var _look := {}


func _ready() -> void:
	add_to_group("world_clock")
	add_to_group("lamp_fault")
	_look = ObjectLook.of("fault")
	if sparks:
		spark_particles = _particles("Sparks", "sparks", Vector2.ZERO)
		spark_particles.has_floor = true
		spark_particles.floor_y = floor_y
		# One burst the moment it fails, then the preset's own bursts.
		spark_particles.bursts_at = PackedFloat32Array([0.02])
		add_child(spark_particles)
	if smoke:
		smoke_particles = _particles("Smoke", "smoke", smoke_at)
		smoke_particles.starts_empty = true
		add_child(smoke_particles)
	_show(-1.0)


func _particles(node_name: String, preset: String, at: Vector2) -> TimeParticles:
	var particles := TimeParticles.new()
	particles.name = node_name
	particles.preset = preset
	particles.own_clock = false
	particles.noise_seed = noise_seed
	particles.position = at
	return particles


## Seconds since the failure, -1 before it.
func fault_seconds() -> float:
	var water := get_node_or_null(water_path) as Water if not water_path.is_empty() else null
	return water.fault_seconds() if water != null else -1.0


func active() -> bool:
	return fault_seconds() >= 0.0


## The room's clock (`RoomTime`, group `world_clock`).
func on_world_tick(_tick: int, _recorded: bool) -> void:
	_show(fault_seconds())


func _show(seconds: float) -> void:
	for particles: TimeParticles in [spark_particles, smoke_particles]:
		if particles == null:
			continue
		particles.visible = seconds >= 0.0
		if seconds >= 0.0:
			particles.show_at(seconds)


## How bright lamp `index` is against its usual light, for `WorldLight`: 1
## unless the lamp is ours and the pump has failed.
func lamp_factor(index: int) -> float:
	if not index in lamps:
		return 1.0
	var seconds := fault_seconds()
	return 1.0 if seconds < 0.0 else blink(seconds, _look, index)


## A stutter of the light: in steps of 1/`blink_hz` seconds the lamp is on or
## down to `blink_dark`, by a hash of the step; about `blink_on_share` of the
## steps are on. A pure function of the seconds.
static func blink(seconds: float, look: Dictionary, index: int) -> float:
	var hz := maxf(float(look.get("blink_hz", 8.0)), 0.1)
	var step := int(floor(seconds * hz))
	var on := ParticleField.rand01(97 + index * 13, step, 3) < float(look.get("blink_on_share", 0.55))
	return 1.0 if on else float(look.get("blink_dark", 0.12))
