extends Node2D
## Showcase of the heroine's doll (task Д5): the doll at game size next to the
## 44x92 hitbox, facing right and left, and four times larger to check joints.
## `tools/shots.sh --scene heroine_test --ticks 2` takes its picture.

const RIG := preload("res://objects/heroine/heroine_rig.gd")
const FLOOR_Y := 900.0
const BACKDROP := Color("#2a2220")
const FLOOR := Color("#151212")
const HITBOX := Color(0.5, 0.9, 1.0, 0.8)


func _ready() -> void:
	_add(Vector2(260, FLOOR_Y), 1.0, 1.0, true)
	_add(Vector2(400, FLOOR_Y), 1.0, -1.0, true)
	_add(Vector2(560, FLOOR_Y), 2.0, 1.0, true)
	_add(Vector2(1100, FLOOR_Y), 7.5, 1.0, false)


func _add(at: Vector2, zoom: float, facing: float, hitbox: bool) -> void:
	var rig: HeroineRig = RIG.new()
	rig.position = at
	rig.scale = Vector2(zoom, zoom)
	add_child(rig)
	rig.set_facing(facing)
	if hitbox:
		var box := HitboxOutline.new()
		box.position = at
		box.scale = Vector2(zoom, zoom)
		box.z_index = 50
		add_child(box)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), BACKDROP)
	draw_rect(Rect2(0, FLOOR_Y, 1920, 1080 - FLOOR_Y), FLOOR)


class HitboxOutline extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-22, -92, 44, 92), HITBOX, false, 1.0)
