extends SceneTree
## Builds level 01 `levels/level_01.tscn` (task 2.5, card docs/levels/01.md):
## one screen, a flat floor, the spawn on the left, a wall with a doorway
## 20 cells to the right, the door in it and the exit behind it. The door's
## timing (open 1 s, closes in 5 s, once) and the prelude live in
## data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_01.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point, 'D' the doorway (the
## door stands in these cells), 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_01.tscn"

const MAP := [
	"##############################",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................#......#",
	"#.....................D...EE.#",
	"#.....................D...EE.#",
	"#.S...................D...EE.#",
	"##############################",
	"##############################",
]


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

	var door: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	door.object_id = "door"
	door.travel = float(door_cells.size.y * CELL)
	door.position = (Vector2(door_cells.position) + Vector2(door_cells.size) / 2.0) * CELL
	_own(root, door)

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


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
