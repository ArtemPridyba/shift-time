class_name HeroineRig
extends Node2D
## The heroine as a cutout doll (task Д5, D77): a tree of `Node2D` joints, one
## picture per part, every number from `data/heroine.json`. The rig's origin is
## between her feet; `set_facing(-1)` mirrors her. The indicator strip on the
## gauntlet is drawn by code in the time colour (D76), the cable from the
## battery to the gauntlet is a `Line2D` that sags.

var _data: Dictionary = {}
## Joint node of each part: rotates the part around its pivot.
var _joints: Dictionary = {}
var _sprites: Dictionary = {}
var _body: Node2D
var _cable: Line2D
var _strip: HeroineStrip
var _pose := ""


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
		joint.add_child(sprite)
		_joints[name] = joint
		_sprites[name] = sprite
	# Drawing order: z of each part relative to the rig, whatever its depth.
	for name: String in _sprites:
		(_sprites[name] as Sprite2D).z_index = int((parts[name] as Dictionary).get("z", 0))
	_build_strip(data)
	_build_cable(data)
	_pose = ""
	set_pose("idle")


func set_facing(facing: float) -> void:
	_body.scale.x = absf(_body.scale.y) * (-1.0 if facing < 0.0 else 1.0)
	_update_cable()


func set_pose(pose: String) -> void:
	_pose = pose
	var angles := HeroineData.pose_angles(_data, pose)
	for name: String in _joints:
		(_joints[name] as Node2D).rotation_degrees = float(angles.get(name, 0.0))
	var parts: Dictionary = _data.get("parts", {})
	for name: String in parts:
		if String((parts[name] as Dictionary).get("parent", "")) == "":
			(_joints[name] as Node2D).position = _vec((parts[name] as Dictionary).get("at")) - Vector2(0, HeroineData.pose_lift(_data, pose))
	_update_cable()


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
## game, so it is drawn back at sheet scale and shows 1:1 on screen.
func _picture(dir: String, texture: String, pivot: Vector2, bakes: Dictionary) -> Sprite2D:
	var bake := float(bakes.get(texture, 1.0))
	var sprite := Sprite2D.new()
	sprite.texture = load("%s/%s.png" % [dir, texture])
	sprite.centered = false
	sprite.offset = -pivot * bake
	sprite.scale = Vector2.ONE / bake
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
