extends Node2D
## Showcase of the heroine's doll (task Д5): the doll at game size next to the
## 44x92 hitbox, facing right and left, and with the strip in the other
## candidate time colour of D70; and up close from the parts at sheet size, to
## check the joints:
## `tools/shots.sh --scene heroine_test --ticks 2`.

const RIG := preload("res://objects/heroine/heroine_rig.gd")
const FLOOR_Y := 760.0
const BACKDROP := Color("#2a2220")
const FLOOR := Color("#151212")
const HITBOX := Color(0.5, 0.9, 1.0, 0.8)
## The other candidate of D70, to compare with the colour in time_hud.json.
const OTHER_TIME_COLOUR := Color("#7FE8FF")


func _ready() -> void:
	_add(Vector2(100, FLOOR_Y), 1.0, true, Color(0, 0, 0, 0))
	_add(Vector2(200, FLOOR_Y), -1.0, true, Color(0, 0, 0, 0))
	_add(Vector2(300, FLOOR_Y), 1.0, false, Color(0, 0, 0, 0))
	_add(Vector2(400, FLOOR_Y), 1.0, false, OTHER_TIME_COLOUR)
	# Up close, from the parts at sheet size: half a sheet pixel per screen pixel.
	var big: HeroineRig = RIG.new()
	big.full_size = true
	big.position = Vector2(900, FLOOR_Y)
	var zoom := 0.5 / float(HeroineData.load_data().get("scale", 1.0))
	big.scale = Vector2(zoom, zoom)
	add_child(big)


func _add(at: Vector2, facing: float, hitbox: bool, strip: Color) -> void:
	var rig: HeroineRig = RIG.new()
	rig.position = at
	add_child(rig)
	rig.set_facing(facing)
	if strip.a > 0.0:
		rig.strip().color = strip
	if hitbox:
		var box := HitboxOutline.new()
		box.position = at
		box.z_index = 50
		add_child(box)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), BACKDROP)
	draw_rect(Rect2(0, FLOOR_Y, 1920, 1080 - FLOOR_Y), FLOOR)


class HitboxOutline extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-22, -92, 44, 92), HITBOX, false, 1.0)
