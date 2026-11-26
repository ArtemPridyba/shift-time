extends SceneTree
## Builds level 03 «Нить» `levels/level_03.tscn` (card docs/levels/03.md,
## D177): one screen, 30x17 cells.
##
## The hero walks out of a doorway onto the left floor. Beyond it a pit too
## wide to jump; a board on a hinge at its edge, raised and lowered by a winch
## under the roof: lying, it is a bridge to the lower floor on the right;
## sloped, it leads up to the mezzanine over that floor; upright, it closes the
## way. The winch's brake hangs on a rope by the entrance (rope 1): burnt, the
## board stays where it is. On the lower floor right of the pit the torch burns
## on its stand. Over the mezzanine the sprinklers rain at the start and stop a
## few seconds later. At the end of the mezzanine the cage waits at the bottom
## of the shaft, tied down by its stop rope (rope 2), whose end lies on the
## mezzanine; the counterweight pulls it up to the gallery and the exit once
## the rope has burnt through.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_03.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells). The pit is open to the bottom: a
## fall is death (D135). The board, the mezzanine, the ropes, the torch, the
## sprinkler and the cage are placed by the constants below.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_03.tscn"
const LEVEL_ID := "level_03"

const MAP := [
	"##############################",
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#..........................EE#",
	"#..........................EE#",
	"#........................#####",
	"#........................#####",
	"#........................#####",
	"#........................#####",
	"#........................#####",
	"#S.......................#####",
	"#########.....#########..#####",
	"#########.....################",
	"#########.....################",
	"#########.....################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 11, 1, 2)
## The board's hinge: the left edge of the pit on the floor (column 9, row 13).
const HINGE := Vector2(9 * 64, 13 * 64)
## The mezzanine: its top on row 10 from the pit's right edge to the shaft.
const MEZZANINE := Rect2(14 * 64, 10 * 64, 9 * 64, 24)
## The winch under the roof: the chain's pulley over the pit and the drum
## over the entrance floor.
const PULLEY := Vector2(11.25 * 64, 2.6 * 64)
const DRUM := Vector2(4.5 * 64, 6 * 64)
## Rope 1 (the brake) hangs from the drum's pawl down to hand height.
const BRAKE_ROPE := [Vector2(4.5 * 64, 11.9 * 64), Vector2(4.5 * 64, 6.6 * 64)]
## Rope 2 (the cage's stop): from its cleat on the mezzanine over the edge down
## to the cage's floor.
const STOP_ROPE := [Vector2(20.5 * 64, 8.75 * 64), Vector2(22.4 * 64, 9.4 * 64),
	Vector2(22.9 * 64, 10.0 * 64), Vector2(23.35 * 64, 12.9 * 64)]
## The torch's stand on the lower floor right of the pit; the torch's foot
## stands this high over the floor.
const STAND_X := 15.5 * 64
const STAND_PX := 56.0
## The sprinklers over the mezzanine: the pipe's height and its span.
const PIPE_Y := 4.7 * 64
## The cage: the middle of the shaft (columns 23-24), its floor on row 13, up
## to the gallery's floor on row 7.
const CAGE_AT := Vector2(24 * 64, 13 * 64)
const CAGE_TRAVEL := 6 * 64
## The beacon over the exit door, from the door's foot (as in level 02).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)
const MEZZANINE_COLOR := Color("#3a3f46")
const MEZZANINE_EDGE := Color("#5a616b")
const STAND_COLOR := Color("#4a5058")


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level03"
	root.set_script(load("res://levels/level_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	_own(root, blocks)
	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	_own(root, spawn)

	var exit_cells := Rect2i()
	for y in MAP.size():
		var row: String = MAP[y]
		assert(row.length() == 30, "row %d is %d cells" % [y, row.length()])
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					blocks.set_cell(cell, 0, Vector2i.ZERO)
				"S":
					spawn.position = Vector2((x + 0.5) * CELL, (y + 1) * CELL)
				"E":
					exit_cells = Rect2i(cell, Vector2i.ONE) if exit_cells.size == Vector2i.ZERO else exit_cells.expand(cell + Vector2i.ONE)

	# The Night shop world as in level 01: the blockout tiles stay the
	# collision and are hidden; the look is data, `world` in levels.json.
	blocks.visible = false
	var back := WorldBack.new()
	back.name = "WorldBack"
	back.level_id = LEVEL_ID
	_own(root, back)

	var entrance := Node2D.new()
	entrance.set_script(load("res://objects/entrance_frame.gd"))
	entrance.name = "Entrance"
	entrance.set("size", Vector2(ENTRANCE_CELLS.size * CELL))
	entrance.position = Vector2(ENTRANCE_CELLS.position * CELL)
	_own(root, entrance)

	# The mezzanine: a steel deck on the wall, solid, the sprinklers over it.
	var deck := StaticBody2D.new()
	deck.name = "Mezzanine"
	deck.position = MEZZANINE.get_center()
	var deck_shape := CollisionShape2D.new()
	var deck_box := RectangleShape2D.new()
	deck_box.size = MEZZANINE.size
	deck_shape.shape = deck_box
	deck.add_child(deck_shape)
	_own(root, deck)
	deck_shape.owner = root
	_box(root, "MezzanineLook", MEZZANINE, MEZZANINE_COLOR)
	_box(root, "MezzanineEdge", Rect2(MEZZANINE.position, Vector2(MEZZANINE.size.x, 4.0)), MEZZANINE_EDGE)

	# Ropes go before what they hold: the board and the cage read them in the
	# same tick.
	var brake := FireRope.new()
	brake.name = "BrakeRope"
	brake.object_id = "brake"
	brake.points = PackedVector2Array(BRAKE_ROPE)
	_own(root, brake)
	var stop := FireRope.new()
	stop.name = "StopRope"
	stop.object_id = "stop_rope"
	stop.points = PackedVector2Array(STOP_ROPE)
	_own(root, stop)

	var top := Vector2(MEZZANINE.position)
	var ramp := WinchRamp.new()
	ramp.name = "Ramp"
	ramp.object_id = "ramp"
	ramp.brake_id = "brake"
	ramp.position = HINGE
	ramp.length_px = HINGE.distance_to(top)
	ramp.slope_deg = rad_to_deg(atan2(HINGE.y - top.y, top.x - HINGE.x))
	ramp.pulley = PULLEY
	ramp.drum = DRUM
	_own(root, ramp)

	var floor_y := 13.0 * CELL
	_box(root, "Stand", Rect2(STAND_X - 3.0, floor_y - STAND_PX, 6.0, STAND_PX), STAND_COLOR)
	var torch := Torch.new()
	torch.name = "Torch"
	torch.object_id = "torch"
	torch.mounted = true
	torch.lit = true
	torch.position = Vector2(STAND_X, floor_y - STAND_PX)
	torch.floor_offset_px = STAND_PX
	_own(root, torch)

	var sprinkler := Sprinkler.new()
	sprinkler.name = "Sprinkler"
	sprinkler.object_id = "sprinkler"
	sprinkler.powered = true
	sprinkler.start_full = true
	sprinkler.size = Vector2(MEZZANINE.size.x, MEZZANINE.position.y - PIPE_Y)
	sprinkler.position = Vector2(MEZZANINE.get_center().x, PIPE_Y)
	_own(root, sprinkler)

	var cage := CounterweightCage.new()
	cage.name = "Cage"
	cage.object_id = "cage"
	cage.rope_id = "stop_rope"
	cage.position = CAGE_AT
	cage.travel_px = CAGE_TRAVEL
	cage.pulley_from_floor = Vector2(0.0, 2.6 * CELL - CAGE_AT.y)
	_own(root, cage)

	var ground := WorldGround.new()
	ground.name = "WorldGround"
	ground.level_id = LEVEL_ID
	_own(root, ground)
	var light := WorldLight.new()
	light.name = "WorldLight"
	light.level_id = LEVEL_ID
	_own(root, light)

	var exit: ExitZone = (load("res://objects/exit_zone.tscn") as PackedScene).instantiate()
	exit.size = Vector2(exit_cells.size * CELL)
	exit.position = (Vector2(exit_cells.position) + Vector2(exit_cells.size) / 2.0) * CELL
	_own(root, exit)
	var exit_door := ExitDoor.new()
	exit_door.name = "ExitDoor"
	exit_door.position = Vector2(0.0, exit.size.y / 2.0)
	exit.add_child(exit_door)
	exit_door.owner = root
	var beacon := Beacon.new()
	beacon.name = "Beacon"
	beacon.position = exit_door.position + BEACON_FROM_DOOR
	exit.add_child(beacon)
	beacon.owner = root

	var player: Node2D = (load("res://objects/player.tscn") as PackedScene).instantiate()
	_own(root, player)
	var room_time := RoomTime.new()
	room_time.name = "RoomTime"
	room_time.player_path = NodePath("../Player")
	_own(root, room_time)

	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, SCENE_PATH) == OK)
	root.free()
	print("wrote ", SCENE_PATH)
	quit()


## Decoration: a plain rectangle, never recorded.
func _box(root: Node, node_name: String, rect: Rect2, color: Color) -> void:
	var box := ColorRect.new()
	box.name = node_name
	box.color = color
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(root, box)


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
