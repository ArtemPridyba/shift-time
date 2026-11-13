extends SceneTree
## Builds the water test room `levels/test_room_water.tscn` (task 2.3): a high
## well with a ledge for the player and the lever on the left, a float on the
## water and the exit ledge at the rim on the right. The well starts full and
## drains through the prelude; under Shift the water rises back to the rim.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_water_room.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (feet on the cell bottom),
## 'L' the lever (on the cell bottom). The tank is `TANK_CELLS` below.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/test_room_water.tscn"
## The cells of the water: from column 1, row 5, twenty wide and ten high.
const TANK_CELLS := Rect2i(1, 5, 20, 10)  # columns 1-20, rows 5-14
## The full surface stands this far above the exit ledge, so water that lifts
## the player brings the feet over the ledge.
const RIM_PX := 16.0
## The float's centre, in cells from the left.
const FLOAT_COLUMN := 13.5
const PRELUDE_SECONDS := 8.0

const MAP := [
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#....................#########",
	"#....................#########",
	"#....................#########",
	"#....................#########",
	"#.S.L................#########",
	"######...............#########",
	"######...............#########",
	"######...............#########",
	"######...............#########",
	"######...............#########",
	"##############################",
	"##############################",
]


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "TestRoomWater"
	root.set_script(load("res://levels/test_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	_own(root, blocks)
	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	_own(root, spawn)
	var lever: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	lever.name = "Lever"
	lever.object_id = "valve"
	lever.target_ids = PackedStringArray(["water"])
	lever.on = true

	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var feet := Vector2(x * CELL + CELL / 2.0, (y + 1) * CELL)
			match row[x]:
				"#":
					blocks.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
				"S":
					spawn.position = feet
				"L":
					lever.position = feet

	var water: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	water.name = "Water"
	water.object_id = "water"
	var left := TANK_CELLS.position.x * CELL
	var right := TANK_CELLS.end.x * CELL
	var bottom := TANK_CELLS.end.y * CELL
	var top := TANK_CELLS.position.y * CELL - RIM_PX
	water.position = Vector2((left + right) / 2.0, bottom)
	water.size = Vector2(right - left, bottom - top)
	water.level = Water.LEVEL_MAX
	water.powered = true
	water.open_flow = -1
	_own(root, water)
	var float_body: WaterFloat = (load("res://objects/water_float.tscn") as PackedScene).instantiate()
	float_body.name = "Float"
	float_body.position = Vector2(FLOAT_COLUMN * CELL - water.position.x, 0.0)
	water.add_child(float_body)
	float_body.owner = root
	_own(root, lever)

	var player: Node2D = (load("res://objects/player.tscn") as PackedScene).instantiate()
	_own(root, player)
	var room_time := RoomTime.new()
	room_time.name = "RoomTime"
	room_time.player_path = NodePath("../Player")
	room_time.prelude_seconds = PRELUDE_SECONDS
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
