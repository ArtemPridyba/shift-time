extends SceneTree
## Builds the fire test room `levels/test_room_fire.tscn` (task 2.7), left to
## right: the spawn, a pit with a wooden bridge that the prelude burns (6 s and
## the event that lights it at 1 s live in data/levels.json), a basin with a
## wooden post standing on its bottom and the valve right of it (light the
## post, open the valve: the rising water puts it out with steam), the reverse
## flamethrower on the floor and a wooden wall before the exit.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_fire_room.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point, 'V' the valve, 'T' the
## flamethrower (each on the cell bottom). The wood zones, in cells, are below.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/test_room_fire.tscn"
## The bridge over the pit: columns 6-9, the top of row 12, 32 px thick.
const BRIDGE := Rect2(6 * CELL, 12 * CELL, 4 * CELL, 32)
## The basin: columns 12-15, rows 12-13; the post stands on its bottom in the
## middle and rises one cell above the floor, so the jet reaches it.
const BASIN := Rect2i(12, 12, 4, 2)
const POST := Rect2(14 * CELL - 16, 11 * CELL, 32, 3 * CELL)
## The wall before the exit: column 23, rows 8-11, 48 px wide.
const WALL := Rect2(23 * CELL + 8, 8 * CELL, 48, 4 * CELL)

const MAP := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#.S..............V..T........#",
	"######....##....##############",
	"######....##....##############",
	"######....####################",
	"######....####################",
	"######....####################",
]


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "TestRoomFire"
	root.set_script(load("res://levels/test_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	_own(root, blocks)
	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	_own(root, spawn)
	var valve: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	valve.name = "Valve"
	valve.object_id = "valve"
	valve.target_ids = PackedStringArray(["basin"])
	valve.look = 1
	var thrower: ReverseFlamethrower = (load("res://objects/reverse_flamethrower.tscn") as PackedScene).instantiate()
	thrower.name = "Flamethrower"
	thrower.object_id = "flamethrower"

	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var feet := Vector2(x * CELL + CELL / 2.0, (y + 1) * CELL)
			match row[x]:
				"#":
					blocks.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
				"S":
					spawn.position = feet
				"V":
					valve.position = feet
				"T":
					thrower.position = feet

	_own(root, _wood("bridge", BRIDGE))
	var water: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	water.name = "Basin"
	water.object_id = "basin"
	var basin := Rect2(BASIN.position * CELL, BASIN.size * CELL)
	water.position = Vector2(basin.get_center().x, basin.end.y)
	water.size = basin.size
	water.level = 0
	water.open_flow = 1
	_own(root, water)
	_own(root, _wood("post", POST))
	_own(root, valve)
	_own(root, _wood("wall", WALL))
	_own(root, thrower)

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


func _wood(id: String, rect: Rect2) -> WoodZone:
	var zone: WoodZone = (load("res://objects/wood_zone.tscn") as PackedScene).instantiate()
	zone.name = id.capitalize()
	zone.object_id = id
	zone.size = rect.size
	zone.position = rect.get_center()
	return zone


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
