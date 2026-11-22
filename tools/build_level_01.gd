extends SceneTree
## Builds level 01 `levels/level_01.tscn` (task 2.5, merged with the platform
## level 03 on 16.11.2026, widened the same day, rebuilt to the heroine's size
## on 22.11.2026, D112; card docs/levels/01.md): a room of 32x17 cells, a tall
## hall a little wider than the screen, the camera follows the hero. Everything
## she uses is sized to her (92 px tall): the door and the platforms are two
## cells, the pit is a little over four jumps wide. She walks
## out of a doorway on the left, then comes a door that is closing, a long pit,
## platform 1 that has already left and rides across it once, and platform 2
## that sinks beside the exit pillar. The timing (door, platforms, prelude, the
## hero's walk-in) lives in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_01.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'D' the doorway (the door stands in these cells), 'E' the exit zone (centred
## on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_01.tscn"
const LEVEL_ID := "level_01"

const MAP := [
	"################################",
	"#.......#......................#",
	"#.......#......................#",
	"#.......#......................#",
	"#.......#......................#",
	"#.......#......................#",
	"#.......#......................#",
	"#.......#..................EE..#",
	"#.......#..................EE..#",
	"#.......#...............########",
	"#.......D...............########",
	"#S......D...............########",
	"##############..........########",
	"###############.........########",
	"################........########",
	"################################",
	"################################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 10, 1, 2)

## Platform 1 starts flush with the left ground (columns 14-15, top at row 12)
## and rides 6 cells right. Platform 2 starts flush with the exit ledge
## (columns 22-23, top at row 9) and sinks 5 cells to just above the pit floor;
## on its way it passes the level of platform 1's end (row 12) at the moment
## platform 1 arrives there (the delays are in data/levels.json, checked by a
## test). Centres, in cells. Both are two cells wide (D112).
const PLATFORM_HEIGHT := 32.0
const PLATFORM_WIDTH_CELLS := 2
const PLATFORM_1_CENTRE := Vector2(15.0, 12.0)
const PLATFORM_1_TRAVEL := Vector2(6.0, 0.0)
const PLATFORM_2_CENTRE := Vector2(23.0, 9.0)
const PLATFORM_2_TRAVEL := Vector2(0.0, 5.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level01"
	root.set_script(load("res://levels/level_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	_own(root, blocks)
	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	_own(root, spawn)

	var door_cells := Rect2i()
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
				"D":
					door_cells = Rect2i(cell, Vector2i.ONE) if door_cells.size == Vector2i.ZERO else door_cells.expand(cell + Vector2i.ONE)
				"E":
					exit_cells = Rect2i(cell, Vector2i.ONE) if exit_cells.size == Vector2i.ZERO else exit_cells.expand(cell + Vector2i.ONE)

	# The Night shop world (task Д3): the back wall behind everything, the
	# ground after the doors and platforms, the light; the blockout tiles stay
	# the collision and are hidden. The look is data: world in levels.json.
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

	var door: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	door.object_id = "door"
	door.travel = float(door_cells.size.y * CELL)
	door.height = float(door_cells.size.y * CELL)
	door.position = (Vector2(door_cells.position) + Vector2(door_cells.size) / 2.0) * CELL
	_own(root, door)

	_add_platform(root, "platform_1", PLATFORM_1_CENTRE, PLATFORM_1_TRAVEL)
	_add_platform(root, "platform_2", PLATFORM_2_CENTRE, PLATFORM_2_TRAVEL)

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


## `centre` is where the platform's top edge meets the cell grid: the middle of
## the platform in x and the top surface at the given row.
func _add_platform(root: Node, id: String, centre: Vector2, travel_cells: Vector2) -> void:
	var platform: MovingPlatform = (load("res://objects/platform.tscn") as PackedScene).instantiate()
	platform.object_id = id
	platform.name = id.to_pascal_case()
	platform.travel = travel_cells * CELL
	platform.width = float(PLATFORM_WIDTH_CELLS * CELL)
	platform.position = Vector2(centre.x * CELL, centre.y * CELL + PLATFORM_HEIGHT / 2.0)
	_own(root, platform)


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
