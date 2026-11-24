extends SceneTree
## Builds level 09 `levels/level_09.tscn` «Crane» (card docs/levels/09.md): a
## room of 32x17 cells in the Night shop, sized to the heroine like level 01
## (D112): the hall is 6 cells high under the dark roof. A runaway overhead
## crane rode right in the prelude and its hook struck the three lamps one by
## one, so she walks out into the dark. Under Shift the crane rides back and
## the light returns; at the start of history its load hangs by the pillar
## over the lower hall. She stands on it, lets Shift go, and the crane carries
## her across the hall to the exit ledge, striking the lamps on the way.
##
## Left to right: the start floor (row 12), a gap of two cells, pillar A (two
## cells), one cell to the load's start (one cell higher, row 11); under them
## the lower hall (row 14), three cells down, with a step block back up to the
## start. The load rides 14 cells right and stops flush with the exit ledge
## (row 11), three cells above the lower hall floor: out of reach without the
## crane. Timing and the strikes: `crane` and `objects` of the level's entry in
## data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_09.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_09.tscn"
const LEVEL_ID := "level_09"

const MAP := [
	"################################",
	"################################",
	"################################",
	"################################",
	"################################",
	"################################",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#...........................EE.#",
	"#...........................EE.#",
	"#S........................######",
	"#####..##.................######",
	"######.##.................######",
	"################################",
	"################################",
	"################################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 10, 1, 2)
## The crane's load: where its top edge meets the grid at the start of history
## (the middle in x, the top surface at the row), how far it rides, in cells.
const LOAD_CENTRE := Vector2(11.0, 11.0)
const LOAD_TRAVEL := Vector2(14.0, 0.0)
const LOAD_WIDTH_CELLS := 2
const LOAD_HEIGHT := 32.0
## The beacon sits on the wall by the exit door's upper left corner (as in 01).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level09"
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

	# The crane before its load: the slings are drawn behind the plank.
	var crane := Crane.new()
	crane.name = "Crane"
	_own(root, crane)
	var load_platform: MovingPlatform = (load("res://objects/platform.tscn") as PackedScene).instantiate()
	load_platform.object_id = "crane_load"
	load_platform.name = "CraneLoad"
	load_platform.travel = LOAD_TRAVEL * CELL
	load_platform.width = float(LOAD_WIDTH_CELLS * CELL)
	load_platform.position = Vector2(LOAD_CENTRE.x * CELL, LOAD_CENTRE.y * CELL + LOAD_HEIGHT / 2.0)
	_own(root, load_platform)

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
