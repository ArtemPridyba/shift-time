extends Node2D
## Showcase of the heroine's doll (task Д5): every pose and animation in one
## frame. Left: up close from the parts at sheet size, with the time device.
## Two rows of poses, twice as large and at game size next to the 44x92
## hitbox: idle, four phases of the run, the jump, the top of the jump, the
## fall, the landing, the press, the walk out of the doorway (start and
## halfway). Bottom: the time device on the gauntlet three times as large and
## 1:1, facing right and left (the arrows are never mirrored), and the strip in
## the other candidate time colour of D70. Under Shift every doll shows the
## stronger light, the even glow and the motes of time (D80.1):
## `tools/shots.sh --scene heroine_test --plan '60:;90:rewind' --at 60,150`.

const RIG := preload("res://objects/heroine/heroine_rig.gd")
const HUD := preload("res://ui/time_hud.gd")
const TOP_FLOOR_Y := 400.0
const MID_FLOOR_Y := 640.0
const BOTTOM_FLOOR_Y := 1050.0
const ROW_X := 660.0
const ROW_STEP := 105.0
const BACKDROP := Color("#2a2220")
const FLOOR := Color("#151212")
const HITBOX := Color(0.5, 0.9, 1.0, 0.8)
const LABEL := Color(0.85, 0.8, 0.75)
## The other candidate of D70, to compare with the colour in time_hud.json.
const OTHER_TIME_COLOUR := Color("#7FE8FF")
## What each column shows: a label and how to pose the doll.
const POSES: Array[Array] = [
	["idle", "idle"], ["run 0", "run:0"], ["run 1/4", "run:0.25"], ["run 1/2", "run:0.5"],
	["run 3/4", "run:0.75"], ["jump", "air:-800"], ["top", "air:0"], ["fall", "air:800"],
	["land", "overlay:land"], ["press", "overlay:press"], ["exit", "exit:1"], ["exit 1/2", "exit:0.5"],
]

## The device that drives the light of every doll without one of its own.
var _main_hud: TimeHud
var _lit: Array[HeroineRig] = []
var _labels: Array[Array] = []


func _ready() -> void:
	# Up close, from the parts at sheet size: half a sheet pixel per screen pixel.
	var zoom := 0.5 / float(HeroineData.load_data().get("scale", 1.0))
	var big := _holder(Vector2(330, BOTTOM_FLOOR_Y), zoom, 1.0, true)
	_main_hud = big.hud
	_label(Vector2(80, 60), "left: sheet size, with the time device on the gauntlet")
	for i in POSES.size():
		var x := ROW_X + i * ROW_STEP
		_posed(Vector2(x, TOP_FLOOR_Y), 2.0, String(POSES[i][1]))
		_posed(Vector2(x, MID_FLOOR_Y), 1.0, String(POSES[i][1]))
		var box := HitboxOutline.new()
		box.position = Vector2(x, MID_FLOOR_Y)
		box.z_index = 50
		add_child(box)
		_label(Vector2(x - 30, MID_FLOOR_Y + 22), String(POSES[i][0]))
	_holder(Vector2(760, BOTTOM_FLOOR_Y), 3.0, 1.0, false)
	_holder(Vector2(960, BOTTOM_FLOOR_Y), 3.0, -1.0, false)
	_label(Vector2(700, BOTTOM_FLOOR_Y - 300), "device x3, right and left")
	_holder(Vector2(1120, BOTTOM_FLOOR_Y), 1.0, 1.0, false)
	_holder(Vector2(1180, BOTTOM_FLOOR_Y), 1.0, -1.0, false)
	var other := _posed(Vector2(1260, BOTTOM_FLOOR_Y), 1.0, "idle")
	other.set_time_colours(OTHER_TIME_COLOUR)
	_label(Vector2(1100, BOTTOM_FLOOR_Y - 110), "1:1, and D70 cyan")


func _process(_delta: float) -> void:
	for rig in _lit:
		rig.set_time_light(_main_hud.state.glow(), _main_hud.state.edge_amount)


func _posed(at: Vector2, zoom: float, how: String) -> HeroineRig:
	var rig: HeroineRig = RIG.new()
	rig.position = at
	rig.scale = Vector2(zoom, zoom)
	add_child(rig)
	var parts := how.split(":")
	var value := float(parts[1]) if parts.size() > 1 else 0.0
	match parts[0]:
		"run":
			rig.set_run_phase(value)
		"air":
			rig.set_air(value)
		"overlay":
			rig.set_overlay(parts[1], 1.0)
		"exit":
			rig.set_run_phase(0.25)
			rig.set_exit(value)
		_:
			rig.set_pose(parts[0])
	_lit.append(rig)
	return rig


## A doll with its own time device, as on the player.
func _holder(at: Vector2, zoom: float, facing: float, sheet_size: bool) -> Holder:
	var holder := Holder.new()
	holder.position = at
	holder.scale = Vector2(zoom, zoom)
	holder.rig = RIG.new()
	holder.rig.full_size = sheet_size
	holder.add_child(holder.rig)
	holder.rig.set_facing(facing)
	holder.hud = HUD.new()
	holder.add_child(holder.hud)
	add_child(holder)
	# One set of glowing screen edges is enough.
	if _main_hud != null:
		(holder.hud.get_node("Edges") as CanvasLayer).visible = false
	return holder


func _label(at: Vector2, text: String) -> void:
	_labels.append([at, text])
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), BACKDROP)
	draw_rect(Rect2(0, BOTTOM_FLOOR_Y, 1920, 1080 - BOTTOM_FLOOR_Y), FLOOR)
	draw_rect(Rect2(ROW_X - 60, TOP_FLOOR_Y, 1920, 6), FLOOR)
	draw_rect(Rect2(ROW_X - 60, MID_FLOOR_Y, 1920, 6), FLOOR)
	for label: Array in _labels:
		draw_string(ThemeDB.fallback_font, label[0], String(label[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LABEL)


## Stands in for the player: tells the device where the strip is and passes
## its light on to the doll.
class Holder extends Node2D:
	var rig: HeroineRig
	var hud: TimeHud

	func device_point() -> Vector2:
		return rig.transform * rig.device_point()

	func facing() -> float:
		return 1.0

	func show_time_light(glow: float, rewind: float) -> void:
		rig.set_time_light(glow, rewind)


class HitboxOutline extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-22, -92, 44, 92), HITBOX, false, 1.0)
