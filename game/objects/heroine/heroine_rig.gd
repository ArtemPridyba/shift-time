class_name HeroineRig
extends Node2D
## The heroine as a cutout doll (task Д5, D77): a tree of `Node2D` joints, one
## picture per part, every number from `data/heroine.json`. The rig's origin is
## between her feet; `set_facing(-1)` mirrors her. The indicator strip on the
## gauntlet is drawn by code in the time colour (D76), the cable from the
## battery to the gauntlet is a `Line2D` that sags.
##
## Motion: on the floor she stands or runs (the run by the distance walked), in
## the air she blends from the rise to the fall pose by her vertical speed;
## short overlays (press, land) turn only the parts they name; the walk out of
## the doorway bows her and brings her out of the dark. The gauntlet lights only
## her own body (`heroine_light.gdshader`): weak forward, stronger under Shift,
## with waves that run over her into the gauntlet. She never reads world time
## herself: the time device tells her through `set_time_light`.

const LIGHT_SHADER := preload("res://objects/heroine/heroine_light.gdshader")

var _data: Dictionary = {}
## Joint node of each part: rotates the part around its pivot.
var _joints: Dictionary = {}
var _sprites: Dictionary = {}
var _body: Node2D
var _cable: Line2D
var _strip: HeroineStrip
var _pose := ""
## The angles and lift she has now, blending towards the pose she takes.
var _angles: Dictionary = {}
var _lift := 0.0
var _distance := 0.0
## 1 while the lowest sole stands on the floor, 0 while the pelvis keeps its
## idle height in the air; blends like the angles.
var _ground := 1.0
## The lowest sole in the idle pose with the pelvis at its joint: the height the
## pelvis keeps in the air.
var _idle_sole := 0.0
var _was_on_floor := true
var _air_speed := 0.0
## The overlay that plays now ("" for none), how long it has played, and a
## weight that pins it for showcases (negative: by the clock).
var _overlay := ""
var _overlay_time := 0.0
var _overlay_pin := -1.0
var _exit := 0.0
var _material: ShaderMaterial
var _accent := Color("#7FE8FF")
var _glow := 1.0
var _rewind := 0.0
var _wave_phase := 0.0


## The showcase sets this before adding the rig: the parts at sheet size from
## `parts_dir/full`, sharp when the doll is drawn large.
var full_size := false


func _ready() -> void:
	if _body == null:
		build(HeroineData.load_data())


func build(data: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_data = data
	_joints.clear()
	_sprites.clear()
	_body = Node2D.new()
	_body.name = "Body"
	var scale_px := float(data.get("scale", 1.0))
	_body.scale = Vector2(scale_px, scale_px)
	add_child(_body)
	var parts: Dictionary = data.get("parts", {})
	var dir := _parts_dir(data)
	var far_tint := Color.from_string(String(data.get("far_tint", "#ffffff")), Color.WHITE)
	var bakes := {} if full_size else HeroineData.bake_factors(data)
	var colors: Dictionary = Content.time_hud().get("colors", {})
	_accent = Color.from_string(String(colors.get("accent", "#7FE8FF")), Color.CYAN)
	_material = ShaderMaterial.new()
	_material.shader = LIGHT_SHADER
	for name in HeroineData.build_order(parts):
		var part: Dictionary = parts[name]
		var parent := String(part.get("parent", ""))
		var joint := Node2D.new()
		joint.name = name
		var at := _vec(part.get("at"))
		if parent == "":
			_body.add_child(joint)
			joint.position = at
		else:
			(_joints[parent] as Node2D).add_child(joint)
			joint.position = at - _vec((parts[parent] as Dictionary).get("pivot"))
		# A part may be drawn larger than on the sheet (the gauntlet reads at 94 px).
		var size := float(part.get("size", 1.0))
		joint.scale = Vector2(size, size)
		var sprite := _picture(dir, String(part.get("texture", "")), _vec(part.get("pivot")), bakes)
		sprite.name = "Picture"
		if bool(part.get("far", false)):
			sprite.modulate = far_tint
		sprite.material = _material
		joint.add_child(sprite)
		_joints[name] = joint
		_sprites[name] = sprite
	# Drawing order: z of each part relative to the rig, whatever its depth.
	for name: String in _sprites:
		(_sprites[name] as Sprite2D).z_index = int((parts[name] as Dictionary).get("z", 0))
	_build_strip(data)
	_build_cable(data)
	_pose = ""
	_overlay = ""
	_exit = 0.0
	_angles = HeroineData.pose_angles(_data, "idle").duplicate()
	_lift = 0.0
	_ground = 1.0
	_apply_angles(_angles)
	_idle_sole = _sole_with_root_at_joint()
	set_pose("idle")
	_update_light(0.0)


func set_facing(facing: float) -> void:
	if _body == null:
		build(HeroineData.load_data())
	_body.scale.x = absf(_body.scale.y) * (-1.0 if facing < 0.0 else 1.0)
	_update_cable()


## Shows a pose at once, without blending: for showcases. The air poses keep
## the pelvis at its idle height, as in a jump.
func set_pose(pose: String) -> void:
	_pose = pose
	_angles = HeroineData.pose_angles(_data, pose).duplicate()
	_lift = HeroineData.pose_lift(_data, pose)
	var air: Dictionary = _data.get("air", {})
	_ground = 0.0 if pose in [String(air.get("rise", "")), String(air.get("fall", ""))] else 1.0
	_apply()


## Moves her by how she moves in the game: `velocity` is her real velocity in
## px/s. Running, the pose follows the distance walked, so the feet do not
## slide; standing she takes the idle pose, in the air the rise or the fall by
## her vertical speed. Poses blend over `run.blend_seconds`. Touching down after
## a fast fall plays the land overlay.
func step(velocity: Vector2, on_floor: bool, delta: float) -> void:
	var run: Dictionary = _data.get("run", {})
	var target_angles: Dictionary
	var target_lift: float
	var target_ground := 1.0
	if on_floor and absf(velocity.x) >= float(run.get("min_speed_px", 1.0)):
		_distance += absf(velocity.x) * delta
		var key := HeroineData.run_pose(_data, _distance / float(run.get("cycle_px", 1.0)))
		target_angles = key["angles"]
		target_lift = float(key["lift"])
		_pose = "run"
	elif on_floor:
		target_angles = HeroineData.pose_angles(_data, "idle")
		target_lift = HeroineData.pose_lift(_data, "idle")
		_pose = "idle"
	else:
		var air := HeroineData.air_pose(_data, velocity.y)
		target_angles = air["angles"]
		target_lift = float(air["lift"])
		target_ground = 0.0
		_pose = "fall" if float(air["fall"]) > 0.5 else "jump"
		_air_speed = velocity.y
	if on_floor and not _was_on_floor:
		var land: Dictionary = (_data.get("overlays", {}) as Dictionary).get("land", {})
		if _air_speed >= float(land.get("min_speed_px", 0.0)):
			play("land")
	_was_on_floor = on_floor
	var blend := float(run.get("blend_seconds", 0.0))
	var k := 1.0 if blend <= 0.0 else 1.0 - exp(-delta / blend)
	_angles = HeroineData.blend_angles(_angles, target_angles, k)
	_lift = lerpf(_lift, target_lift, k)
	_ground = lerpf(_ground, target_ground, k)
	if _overlay != "" and _overlay_pin < 0.0:
		_overlay_time += delta
		if _overlay_time >= float(((_data.get("overlays", {}) as Dictionary).get(_overlay, {}) as Dictionary).get("seconds", 0.0)):
			_overlay = ""
	_apply()


## Starts a short overlay pose from `overlays` (press, land).
func play(overlay: String) -> void:
	if not (_data.get("overlays", {}) as Dictionary).has(overlay):
		return
	_overlay = overlay
	_overlay_time = 0.0
	_overlay_pin = -1.0
	_apply()


## Shows an overlay at a fixed weight (0..1), for showcases; "" clears it.
func set_overlay(overlay: String, weight: float) -> void:
	_overlay = overlay
	_overlay_time = 0.0
	_overlay_pin = weight
	_apply()


## The overlay that plays now, "" for none.
func overlay() -> String:
	return _overlay


## The walk out of the doorway: 1 as she steps out, 0 once she is out. Bows
## her by the exit pose and brings her from the dark tint to her own colours.
func set_exit(amount: float) -> void:
	_exit = clampf(amount, 0.0, 1.0)
	var dark := Color.from_string(String((_data.get("exit", {}) as Dictionary).get("dark", "#000000")), Color.BLACK)
	modulate = Color.WHITE.lerp(dark, smoothstep(0.0, 1.0, _exit))
	_apply()


## The gauntlet's light on her body: `glow` is the device's brightness (it
## flickers in rewind), `rewind` 0 in forward time and 1 under Shift (it fades
## in and out with the edges of the screen).
func set_time_light(glow: float, rewind: float) -> void:
	_glow = glow
	_rewind = clampf(rewind, 0.0, 1.0)


func _process(delta: float) -> void:
	_update_light(delta)


## The light's strength now: between `light.forward` and `light.rewind`.
func light_strength() -> float:
	var light: Dictionary = _data.get("light", {})
	return lerpf(float(light.get("forward", 0.0)), float(light.get("rewind", 0.0)), _rewind) * _glow


## The strength of the waves over her body: 0 in forward time.
func wave_strength() -> float:
	return float((_data.get("light", {}) as Dictionary).get("wave_strength", 0.0)) * _rewind


func _update_light(delta: float) -> void:
	if _material == null:
		return
	var light: Dictionary = _data.get("light", {})
	if _rewind > 0.0:
		_wave_phase = fposmod(_wave_phase + delta * float(light.get("wave_hz", 0.0)), 1.0)
	var to_canvas := get_global_transform() if is_inside_tree() else transform
	var scale_px := absf(to_canvas.get_scale().y)
	_material.set_shader_parameter("light_pos", to_canvas * device_point())
	_material.set_shader_parameter("radius", float(light.get("radius_px", 1.0)) * scale_px)
	_material.set_shader_parameter("light", light_strength())
	_material.set_shader_parameter("accent", _accent)
	_material.set_shader_parameter("waves", wave_strength())
	_material.set_shader_parameter("wave_px", float(light.get("wave_px", 1.0)) * scale_px)
	_material.set_shader_parameter("wave_phase", _wave_phase)
	_material.set_shader_parameter("wave_width", float(light.get("wave_width", 0.25)))


## A shader uniform of the light, for tests.
func light_parameter(parameter: StringName) -> Variant:
	return _material.get_shader_parameter(parameter)


## The center of the gauntlet's strip in the rig's pixels: the time device
## draws its indicator there.
func device_point() -> Vector2:
	var strip_data: Dictionary = _data.get("strip", {})
	var part := String(strip_data.get("part", ""))
	if _body == null or not _joints.has(part):
		return Vector2.ZERO
	return _body.transform * _part_point(part, _vec(strip_data.get("center")))


## Shows the air pose at vertical speed `speed_y` at once: for showcases.
func set_air(speed_y: float) -> void:
	var air := HeroineData.air_pose(_data, speed_y)
	_angles = air["angles"]
	_lift = float(air["lift"])
	_ground = 0.0
	_pose = "fall" if float(air["fall"]) > 0.5 else "jump"
	_apply()


## Shows the run at `phase` (cycles) at once, without blending: for showcases.
func set_run_phase(phase: float) -> void:
	var key := HeroineData.run_pose(_data, phase)
	_angles = key["angles"]
	_lift = float(key["lift"])
	_ground = 1.0
	_pose = "run"
	_apply()


## The distance walked in the run, in game pixels: the phase of the run.
func distance() -> float:
	return _distance


## The lowest point of her soles in the rig's pixels: 0 when she stands.
func sole_y() -> float:
	return _lowest_sole() * absf(_body.scale.y)


func _apply() -> void:
	var angles := _angles
	if _overlay != "":
		var weight := _overlay_pin if _overlay_pin >= 0.0 else HeroineData.overlay_weight(_data, _overlay, _overlay_time)
		var entry: Dictionary = (_data.get("overlays", {}) as Dictionary).get(_overlay, {})
		angles = HeroineData.lay_over(_data, angles, String(entry.get("pose", _overlay)), weight)
	if _exit > 0.0:
		angles = HeroineData.lay_over(_data, angles, String((_data.get("exit", {}) as Dictionary).get("pose", "exit")), _exit)
	_apply_angles(angles)
	# On the floor the lowest sole stands on it, whatever the pose does to the
	# legs; in the air the pelvis keeps its idle height, the legs swing free.
	var sole := _sole_with_root_at_joint()
	if (_data.get("soles", {}) as Dictionary).is_empty():
		sole = 0.0
		_idle_sole = 0.0
	var root_joint := _root_joint()
	root_joint.position.y -= _lift + lerpf(_idle_sole, sole, _ground)
	_update_cable()


func _apply_angles(angles: Dictionary) -> void:
	for name: String in _joints:
		(_joints[name] as Node2D).rotation_degrees = float(angles.get(name, 0.0))


func _root_joint() -> Node2D:
	var parts: Dictionary = _data.get("parts", {})
	for name: String in parts:
		if String((parts[name] as Dictionary).get("parent", "")) == "":
			return _joints[name]
	return null


## The lowest sole with the root part at its joint (no lift): puts the root
## there and measures.
func _sole_with_root_at_joint() -> float:
	var parts: Dictionary = _data.get("parts", {})
	var root_joint := _root_joint()
	root_joint.position = _vec((parts[String(root_joint.name)] as Dictionary).get("at"))
	if (_data.get("soles", {}) as Dictionary).is_empty():
		return 0.0
	return _lowest_sole()


func _lowest_sole() -> float:
	var lowest := -INF
	var soles: Dictionary = _data.get("soles", {})
	for part: String in soles:
		for point: Array in soles[part]:
			lowest = maxf(lowest, _part_point(part, Vector2(float(point[0]), float(point[1]))).y)
	return lowest


func pose() -> String:
	return _pose


func joint(part: String) -> Node2D:
	return _joints.get(part)


func strip() -> HeroineStrip:
	return _strip


## The box around every part's picture, in the rig's own pixels.
func body_rect() -> Rect2:
	var box := Rect2()
	var first := true
	for name: String in _sprites:
		var sprite: Sprite2D = _sprites[name]
		var to_rig := _to_rig(sprite)
		var rect := sprite.get_rect()
		for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
			var point: Vector2 = to_rig * corner
			if first:
				box = Rect2(point, Vector2.ZERO)
				first = false
			else:
				box = box.expand(point)
	return box


func _to_rig(node: Node2D) -> Transform2D:
	var transform_to := Transform2D.IDENTITY
	var walk: Node = node
	while walk != null and walk != self:
		transform_to = (walk as Node2D).transform * transform_to
		walk = walk.get_parent()
	return transform_to


## A part's picture: baked by tools/cut_heroine_parts.py to its size in the
## game, so it is drawn back at sheet scale and shows 1:1 on screen. Nearest
## pixels: at 1:1 linear filtering at a fraction of a pixel blurs the picture
## (the showcase's large doll keeps linear).
func _picture(dir: String, texture: String, pivot: Vector2, bakes: Dictionary) -> Sprite2D:
	var bake := float(bakes.get(texture, 1.0))
	var sprite := Sprite2D.new()
	sprite.texture = load("%s/%s.png" % [dir, texture])
	sprite.centered = false
	sprite.offset = -pivot * bake
	sprite.scale = Vector2.ONE / bake
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if full_size else CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


## The indicator strip: a white mask of the strip cut from the gauntlet, laid
## exactly over the gauntlet's picture and tinted with the time colour.
func _build_strip(data: Dictionary) -> void:
	var strip_data: Dictionary = data.get("strip", {})
	var part := String(strip_data.get("part", ""))
	if not _joints.has(part):
		return
	var under: Sprite2D = _sprites[part]
	_strip = HeroineStrip.new()
	_strip.name = "Strip"
	_strip.texture = load("%s/%s.png" % [_parts_dir(data), String(strip_data.get("texture", ""))])
	_strip.centered = false
	_strip.offset = under.offset
	_strip.scale = under.scale
	_strip.texture_filter = under.texture_filter
	_strip.z_index = under.z_index
	var colors: Dictionary = Content.time_hud().get("colors", {})
	_strip.color = Color.from_string(String(colors.get("accent", "#7FE8FF")), Color.CYAN)
	(_joints[part] as Node2D).add_child(_strip)


func _build_cable(data: Dictionary) -> void:
	var cable: Dictionary = data.get("cable", {})
	if cable.is_empty():
		return
	_cable = Line2D.new()
	_cable.name = "Cable"
	_cable.width = float(cable.get("width", 2.0))
	_cable.default_color = Color.from_string(String(cable.get("color", "#202020")), Color.BLACK)
	_cable.joint_mode = Line2D.LINE_JOINT_ROUND
	_cable.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_cable.end_cap_mode = Line2D.LINE_CAP_ROUND
	_cable.antialiased = true
	_cable.z_index = int(cable.get("z", 0))
	_body.add_child(_cable)


## The cable hangs between its two ends as a parabola `sag` part pixels deep.
func _update_cable() -> void:
	if _cable == null:
		return
	var cable: Dictionary = _data.get("cable", {})
	var from: Array = cable["from"]
	var to: Array = cable["to"]
	var a := _part_point(String(from[0]), Vector2(float(from[1]), float(from[2])))
	var b := _part_point(String(to[0]), Vector2(float(to[1]), float(to[2])))
	var sag := float(cable.get("sag", 0.0))
	var count := int(cable.get("points", 2))
	var points := PackedVector2Array()
	for i in count:
		var k := float(i) / float(count - 1)
		points.append(a.lerp(b, k) + Vector2(0, sag * 4.0 * k * (1.0 - k)))
	_cable.points = points


## A point of a part's picture (sheet pixels) in the body's pixels, before
## scale and facing.
func _part_point(part: String, pixel: Vector2) -> Vector2:
	var to_body := Transform2D.IDENTITY
	var walk: Node = _joints[part]
	while walk != null and walk != _body:
		to_body = (walk as Node2D).transform * to_body
		walk = walk.get_parent()
	var pivot := _vec((_data["parts"][part] as Dictionary).get("pivot"))
	return to_body * (pixel - pivot)


func _parts_dir(data: Dictionary) -> String:
	var dir := String(data.get("parts_dir", ""))
	return dir + "/full" if full_size else dir


static func _vec(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
