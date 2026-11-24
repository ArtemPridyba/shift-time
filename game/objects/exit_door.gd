class_name ExitDoor
extends Node2D
## The way out dressed as a pressure door in the back wall (task Д4): a frame
## in the brick, the leaf with its wheel, a rail above, and behind it a flight
## of stairs up with cold light from the top. Put it as a child of the level's
## ExitZone: it stands on the zone's lower edge and locks the zone until it is
## open, so the heroine walks into an open doorway.
##
## It opens once, when the heroine stands on the floor of the doorway within
## `open_distance_px` of it (on the exit ledge): the wheel turns `wheel_turns`
## times, the leaf comes off the wall (its edge and shadow show) and slides
## right along the rail. It is not a temporal object: like the entrance it
## belongs to the way out, keeps no history and Shift does not touch it.
## Numbers: `kit_objects.exit_door` of `data/look.json`.

## Emitted once, when the leaf has slid fully open.
signal opened

## Seconds since the door began to open; below 0 while it is shut.
var elapsed := -1.0

var _look := {}
var _light: PointLight2D


func _ready() -> void:
	_look = ObjectLook.of("exit_door")
	_light = PointLight2D.new()
	_light.texture = KitTextures.soft_disc()
	_light.color = ObjectLook.color(_look, "light", Color("#9fd0ff"))
	_light.texture_scale = ObjectLook.number(_look, "light_radius_px", 180.0) * 2.0 / float(KitTextures.DISC_SIZE)
	_light.position = opening_rect().get_center()
	_light.energy = 0.0
	add_child(_light)
	var zone := get_parent() as ExitZone
	if zone != null:
		zone.lock_until(self)


func _physics_process(delta: float) -> void:
	if elapsed < 0.0:
		if _player_near():
			elapsed = 0.0
		return
	if is_open():
		return
	elapsed += delta
	_light.energy = ObjectLook.number(_look, "light_energy", 0.9) * clampf(slide_fraction() + out_fraction() * 0.3, 0.0, 1.0)
	queue_redraw()
	if is_open():
		opened.emit()


## The whole opening takes this long: wheel, then off the wall, then the slide.
func open_seconds() -> float:
	return _num("wheel_seconds", 1.0) + _num("out_seconds", 0.3) + _num("slide_seconds", 0.7)


func is_open() -> bool:
	return elapsed >= open_seconds()


## Turns of the wheel so far, 0 … wheel_turns.
func wheel_turns_done() -> float:
	return _num("wheel_turns", 2.5) * _ease(_part(0.0, _num("wheel_seconds", 1.0)))


## 0 … 1: the leaf coming off the wall.
func out_fraction() -> float:
	return _ease(_part(_num("wheel_seconds", 1.0), _num("out_seconds", 0.3)))


## 0 … 1: the leaf sliding right along the rail.
func slide_fraction() -> float:
	return _ease(_part(_num("wheel_seconds", 1.0) + _num("out_seconds", 0.3), _num("slide_seconds", 0.7)))


## The frame's rect: as tall as `height_px`, standing on this node's origin.
func frame_rect() -> Rect2:
	var frame := ObjectLook.picture("exit_frame")
	var h := _num("height_px", 150.0)
	var w := h * 0.7 if frame == null else h * float(frame.get_width()) / float(frame.get_height())
	return Rect2(-w / 2.0, -h, w, h)


## The dark opening inside the frame, where the stairs show.
func opening_rect() -> Rect2:
	var f := frame_rect()
	return Rect2(f.position + f.size * Vector2(0.27, 0.14), f.size * Vector2(0.46, 0.72))


## The leaf at rest: it covers the frame's rim.
func leaf_rect() -> Rect2:
	var f := frame_rect()
	var leaf := ObjectLook.picture("exit_leaf")
	var h := f.size.y * 0.87
	var w := h * 0.6 if leaf == null else h * float(leaf.get_width()) / float(leaf.get_height())
	return Rect2(Vector2(-w / 2.0, f.get_center().y - h / 2.0), Vector2(w, h))


func _draw() -> void:
	var f := frame_rect()
	var open := opening_rect()
	var stairs := ObjectLook.picture("exit_stairs")
	if stairs != null:
		draw_texture_rect(stairs, open, false)
	else:
		draw_rect(open, Color("#15181c"))
	var frame := ObjectLook.picture("exit_frame")
	if frame != null:
		draw_texture_rect(frame, f, false)
	else:
		draw_rect(f, Color("#2a2a30"), false, 6.0)
	var leaf_at := leaf_rect()
	var out := out_fraction() * _num("out_px", 8.0)
	var slide := slide_fraction() * (leaf_at.size.x + 8.0)
	leaf_at.position += Vector2(slide + out * 0.5, -out * 0.25)
	var rail := ObjectLook.picture("exit_rail")
	var rail_h := _num("rail_px", 20.0)
	if rail != null:
		draw_texture_rect(rail, Rect2(Vector2(f.position.x + f.size.x * 0.3, f.position.y - rail_h * 0.6),
				Vector2(leaf_at.size.x + 8.0 + f.size.x * 0.4, rail_h)), false)
	if out > 0.0:
		# Off the wall: a shadow on the wall and the leaf's edge.
		draw_rect(Rect2(leaf_at.position + Vector2(-out, out), leaf_at.size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(leaf_at.position + Vector2(-out, 0.0), Vector2(out, leaf_at.size.y)), Color("#2a2a30"))
	var leaf := ObjectLook.picture("exit_leaf")
	if leaf != null:
		draw_texture_rect(leaf, leaf_at, false)
	else:
		draw_rect(leaf_at, Color("#4c4c53"))
	var wheel := ObjectLook.picture("exit_wheel")
	if wheel != null:
		var px := _num("wheel_px", 30.0)
		ObjectLook.draw_turned(self, wheel, leaf_at.get_center() + Vector2(0.0, leaf_at.size.y * 0.06),
				Vector2(px, px), wheel_turns_done() * TAU)


func _player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return false
	# The player's origin is at the feet.
	var feet := player.global_position
	return absf(feet.y - global_position.y) <= _num("floor_tolerance_px", 10.0) \
			and absf(feet.x - global_position.x) <= _num("open_distance_px", 260.0)


func _part(from: float, length: float) -> float:
	if elapsed < 0.0:
		return 0.0
	return clampf((elapsed - from) / maxf(length, 0.001), 0.0, 1.0)


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _num(key: String, fallback: float) -> float:
	return ObjectLook.number(_look, key, fallback)
