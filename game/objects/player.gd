class_name Player
extends CharacterBody2D
## The player: reads input, applies PlayerMotion, follows the room with the camera.
## The player is not a temporal object: it is never recorded and does not
## listen to the direction of world time. In water the player sinks and holds
## the breath (`Breath`); out of air, `drowned` tells the room to reset. In
## the flames of a burning wood zone the heat grows (`Scorch`); after
## `fire_seconds`, `burned` tells the room to reset.

## The air ran out under water: the room resets.
signal drowned
## The player stood in fire too long: the room resets.
signal burned

var _motion: PlayerMotion
var _breath: Breath
var _scorch: Scorch
var _in_fire := false
var _facing := 1.0
var _size := Vector2(44, 92)
var _head_px := 28.0
var _head_under := false
var _bubbles: CPUParticles2D
## Ticks left of the walk-in at the start of a level (`begin_intro`): the hero
## fades in and walks right on his own, the keys are ignored.
var _intro_left := 0
var _intro_total := 0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: PlayerCamera = $Camera2D
## The look: the heroine's doll (task Д5); the hitbox stays 44x92.
@onready var _rig: HeroineRig = $Heroine


func _ready() -> void:
	# Live, never `temporal`: the look of water finds the player by this group.
	add_to_group("player")
	var params := Content.player()
	_motion = PlayerMotion.new(params)
	_breath = Breath.new(params)
	_scorch = Scorch.new(params)
	_head_px = float(params.get("head_px", 28))
	# Stairs are slopes (D120): she keeps to a slope going down and walks it
	# at her own speed both ways.
	floor_snap_length = float(params.get("floor_snap_px", 1))
	floor_max_angle = deg_to_rad(float(params.get("floor_max_angle_deg", 45)))
	floor_constant_speed = true
	_size = (_shape.shape as RectangleShape2D).size
	_bubbles = _make_bubbles()
	add_child(_bubbles)


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump := Input.is_action_just_pressed("jump")
	if _intro_left > 0:
		axis = 1.0
		jump = false
		_intro_left -= 1
		modulate.a = minf(1.0, 2.0 * (1.0 - float(_intro_left) / float(_intro_total)))
	var water := water_contact()
	velocity = _motion.step(velocity, axis, jump, is_on_floor(), delta, water)
	move_and_slide()
	_rig.set_exit(float(_intro_left) / float(_intro_total) if _intro_left > 0 else 0.0)
	# Her gait reads her own speed: a platform carrying her is not her walk (D120).
	var own := get_real_velocity()
	if is_on_floor():
		own -= get_platform_velocity()
	_rig.step(own, is_on_floor(), delta, _footing())
	if axis != 0.0 and signf(axis) != _facing:
		_facing = signf(axis)
		_rig.set_facing(_facing)
	_head_under = bool(water.get("head_under", false))
	_bubbles.emitting = _head_under
	_bubbles.position.x = 8.0 * _facing
	if _breath.step(_head_under, delta):
		drowned.emit()
	_in_fire = is_in_fire()
	if _scorch.step(_in_fire, delta):
		burned.emit()
	if Input.is_action_just_pressed("interact"):
		_rig.play("press")
		_try_interact()


## The flight of stairs under her feet for the doll (D120): the top of the
## tread under a rig x, in her own pixels, and where she is in the room;
## empty away from stairs.
func _footing() -> Dictionary:
	if not is_inside_tree():
		return {}
	var at := global_position
	for node in get_tree().get_nodes_in_group("stairs"):
		var stairs := node as Stairs
		var flight := stairs.rect_px() if stairs != null else Rect2()
		# The feet reach about half a hitbox beyond her middle.
		if stairs == null or at.x < flight.position.x - _size.x or at.x > flight.end.x + _size.x \
				or at.y < flight.position.y - _size.y or at.y > flight.end.y + _size.y:
			continue
		var origin := stairs.global_position
		return {
			"ground": func(x: float) -> float: return origin.y + stairs.tread_y(at.x + x - origin.x) - at.y,
			"tread_px": stairs.tread_px(),
			"tread_x": origin.x + flight.position.x - at.x,
			"at": at,
			"slope": origin.y + stairs.surface_y(at.x - origin.x) - at.y,
		}
	return {}


func set_camera_limits(rect: Rect2i) -> void:
	_camera.set_room(Rect2(rect))


## The camera shows the whole room for `seconds` (D83), then comes close.
func show_overview(seconds: float) -> void:
	_camera.show_overview(seconds)


## +1 while the hero faces right, -1 while left; the wrist device follows it.
func facing() -> float:
	return _facing


## Where the time device draws its indicator: the strip of the gauntlet, in
## the player's pixels. It moves with her arm and goes to the other side when
## she turns, but the device itself is never mirrored.
func device_point() -> Vector2:
	return _rig.transform * _rig.device_point()


## The time device lights her body (D76): only her, never the room.
func show_time_light(glow: float, rewind: float) -> void:
	_rig.set_time_light(glow, rewind)


## The heroine's doll, for tests and showcases.
func rig() -> HeroineRig:
	return _rig


## The player's body in the parent's coordinates (the origin is at the feet).
func body_rect() -> Rect2:
	return Rect2(position - Vector2(_size.x / 2.0, _size.y), _size)


## The deepest water the player is in this tick (`PlayerMotion.water_contact`);
## depth 0 on land.
func water_contact() -> Dictionary:
	var best := {"depth": 0.0, "rise": 0.0, "head_under": false}
	if not is_inside_tree():
		return best
	var body := Rect2(global_position - Vector2(_size.x / 2.0, _size.y), _size)
	for node in get_tree().get_nodes_in_group("water"):
		var water := node as Water
		if water == null:
			continue
		var contact := PlayerMotion.water_contact(body, water.tank_global_rect(), water.surface_global_y(), water.rise_px_per_second, _head_px)
		if float(contact["depth"]) > float(best["depth"]):
			best = contact
	return best


## 1 with full lungs, 0 out of air; the vignette reads it.
func breath_fraction() -> float:
	return _breath.fraction() if _breath != null else 1.0


func is_head_under_water() -> bool:
	return _head_under


## 0 when cool, 1 when the fire has burned the player; the vignette reads it.
func heat_fraction() -> float:
	return _scorch.fraction() if _scorch != null else 0.0


## True while the body is in the flames of a burning wood zone (group `fire`).
func is_in_fire() -> bool:
	if not is_inside_tree():
		return false
	var body := Rect2(global_position - Vector2(_size.x / 2.0, _size.y), _size)
	for node in get_tree().get_nodes_in_group("fire"):
		if node.has_method("burns_rect") and bool(node.call("burns_rect", body)):
			return true
	return false


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_intro_left = 0
	modulate.a = 1.0
	_rig.set_exit(0.0)
	_motion.reset()
	if _breath != null:
		_breath.reset()
	if _scorch != null:
		_scorch.reset()
	_camera.reset_smoothing()


## The hero comes in by himself for `ticks` physics ticks: fades in, walks right,
## ignores the keys. Time keeps running, Shift works as usual.
func begin_intro(ticks: int) -> void:
	_intro_total = maxi(ticks, 1)
	_intro_left = ticks
	modulate.a = 0.0 if ticks > 0 else 1.0


func intro_ticks_left() -> int:
	return _intro_left


## Asks the parent RoomTime (if any) to handle an interact press.
func _try_interact() -> void:
	var room_time := _find_room_time()
	if room_time != null and room_time.has_method("player_interact"):
		room_time.call("player_interact", global_position)


func _find_room_time() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is RoomTime:
			return child
	return null


## Bubbles from the mouth while the head is under water: decoration, never
## recorded (the player is live).
func _make_bubbles() -> CPUParticles2D:
	var bubbles := CPUParticles2D.new()
	bubbles.name = "Bubbles"
	bubbles.position = Vector2(8.0, -_size.y + 18.0)
	bubbles.emitting = false
	bubbles.amount = 8
	bubbles.lifetime = 1.4
	bubbles.direction = Vector2.UP
	bubbles.spread = 20.0
	bubbles.gravity = Vector2(0, -40)
	bubbles.initial_velocity_min = 20.0
	bubbles.initial_velocity_max = 45.0
	bubbles.scale_amount_min = 2.0
	bubbles.scale_amount_max = 4.0
	bubbles.color = Color(0.85, 0.95, 1.0, 0.7)
	return bubbles
