extends SceneTree
## Builds level 05 `levels/level_05.tscn` «Crane» (card docs/levels/05.md,
## D144): a room of 66x22 cells in the Night shop, sized to the heroine like
## level 01 (D112), played left to right in three quakes (`Collapse`).
##
## Act 1: she walks out on the floor at the left. The hall shakes; three
## platforms hanging over the pit fall one by one onto their stubs, each
## followed by its lamp; the third breaks and soon crumbles into the pit. From
## the second she holds Shift: the third comes back whole on its stub, she
## jumps onto it, and holding Shift it rises with her to the crane's ledge.
## Act 2: on the ledge the crane hangs from a rail sloping down to the right.
## Her step onto it shakes the hall again; it breaks loose and rides down the
## rail over the pit while the lamps over it fall.
## Act 3: at the end of the rail the third quake. The crane sags; the ceiling
## ahead comes down in chunks, two lamps fall among them, and the world slows
## down: she climbs the falling chunks to the exit ledge high on the right.
## Shift lifts a chunk she stands on when she is late.
##
## The pit is open to the bottom: a fall is death. Timing: `collapse` of the
## level's entry in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_05.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_05.tscn"
const LEVEL_ID := "level_05"

const MAP := [
	"##################################################################",
	"##################################################################",
	"##################################################################",
	"##################################################################",
	"#................................................................#",
	"#................................................................#",
	"#................................................................#",
	"#............................................................EE..#",
	"#............................................................EE..#",
	"#.......................................................##########",
	"#.......................................................##########",
	"#..................######...............................##########",
	"#..................######...............................##########",
	"#....................#..................................##########",
	"#....................#..................................##########",
	"#....................#..................................##########",
	"#S...................#..................................##########",
	"#######.#...#....#...#..................................##########",
	"#######.#...#....#...#..................................##########",
	"#######.#...#....#...#..................................##########",
	"#######.#...#....#...#..................................##########",
	"#######.#...#....#...#..................................##########"
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 15, 1, 2)
## The falling pieces in the order of `collapse.pieces` (cells: x and row where
## it hangs, width, height; x and row where it lies). Act 1: three platforms
## onto their stubs (the third breaks and crumbles). Act 3: five chunks of the
## ceiling, each its own size, lost to the bottom of the pit.
const PIECES: Array[Dictionary] = [
	{"x": 7.0, "row": 12.0, "width": 3.0, "height": 0.5, "rest_row": 16.5},
	{"x": 10.8, "row": 12.0, "width": 3.0, "height": 0.5, "rest_row": 16.5},
	{"x": 15.2, "row": 11.0, "width": 3.8, "height": 0.5, "rest_row": 16.5},
	{"x": 43.8, "row": 4.2, "width": 1.6, "height": 0.8, "rest_row": 23.0, "lost": true},
	{"x": 46.1, "row": 4.0, "width": 1.3, "height": 0.7, "rest_row": 23.0, "lost": true},
	{"x": 48.2, "row": 4.4, "width": 2.0, "height": 1.0, "rest_row": 23.0, "lost": true},
	{"x": 51.0, "row": 4.1, "width": 1.4, "height": 0.7, "rest_row": 23.0, "lost": true},
	{"x": 53.3, "row": 4.0, "width": 1.8, "height": 0.9, "rest_row": 23.0, "lost": true},
]
## The crane's load where it waits by the ledge (cells: x, top row, width,
## height), how far it rides down the rail, the rail above its top, and how
## far it falls at the end.
const CRANE := Rect2(25.0, 11.0, 3.0, 0.4)
const CRANE_TRAVEL := Vector2(15.0, 3.0)
const SLING_CELLS := 4.0
const CRANE_FALL_CELLS := 12.0
## The beacon sits on the wall by the exit door's upper left corner (as in 01).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level05"
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
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					blocks.set_cell(cell, 0, Vector2i.ZERO)
				"S":
					spawn.position = Vector2((x + 0.5) * CELL, (y + 1) * CELL)
				"E":
					exit_cells = Rect2i(cell, Vector2i.ONE) if exit_cells.size == Vector2i.ZERO else exit_cells.expand(cell + Vector2i.ONE)

	# The Night shop world (task Д3) as in level 01: the blockout tiles stay
	# the collision and are hidden; the look is data, world in levels.json.
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

	# The collapse of three quakes (D144): pieces, the crane and its rail.
	var collapse := Collapse.new()
	collapse.name = "Collapse"
	var hangs: Array[Rect2] = []
	var rests: Array[Rect2] = []
	var lost := PackedInt32Array()
	for k in PIECES.size():
		var p: Dictionary = PIECES[k]
		var size := Vector2(float(p["width"]), float(p["height"])) * CELL
		hangs.append(Rect2(Vector2(float(p["x"]), float(p["row"])) * CELL, size))
		rests.append(Rect2(Vector2(float(p["x"]), float(p["rest_row"])) * CELL, size))
		if bool(p.get("lost", false)):
			lost.append(k)
	collapse.pieces = hangs
	collapse.rests = rests
	collapse.lost = lost
	collapse.crane_rect = Rect2(CRANE.position * CELL, CRANE.size * CELL)
	collapse.crane_travel = CRANE_TRAVEL * CELL
	collapse.sling_px = SLING_CELLS * CELL
	collapse.crane_fall_px = CRANE_FALL_CELLS * CELL
	_own(root, collapse)

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


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
