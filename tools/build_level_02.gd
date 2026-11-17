extends SceneTree
## Builds level 02 `levels/level_02.tscn` (task 3.1, 17.11.2026; card
## docs/levels/02.md): a room of 41x20 cells, about 1.3 screens wide, the camera
## follows the hero. He walks out of a doorway onto a ledge at mid height.
## Right of it is a deep well with a float and a grate on its floor, the button
## lies at the end of a tunnel that leaves the well floor to the right, under
## the pool,
## beyond that a wall as high as the full water line, behind the wall a shallow
## pool with a door in front of the exit. Both waters are full at the start of
## the history and drain; the timing (prelude, walk-in, drain times) lives in
## data/levels.json, the water line is the same height over everything.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_02.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'D' the doorway of the pool door (the door stands in these cells), 'E' the
## exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_02.tscn"

const MAP := [
	"#########################################",
	"#.................................#######",
	"#.................................#######",
	"#.................................#######",
	"#.................................#######",
	"#.................................#######",
	"#...............##................#######",
	"#...............##................#######",
	"#...............##................#######",
	"#...............##................#######",
	"#S..............##................D.....#",
	"#####...........##................D..EE.#",
	"#####...........##................D..EE.#",
	"#####...........#########################",
	"#####...........#########################",
	"#####...........#########################",
	"#####.....................###############",
	"#####.....................###############",
	"#########################################",
	"#########################################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 8, 1, 3)

## The full water line: the top of the wall, row 6. Everything else is measured
## from it: the hero's ledge is 5 cells under it (row 11), the well floor 12
## (row 18), the pool floor 7 (row 13).
const LINE_ROW := 6
## The well tank covers the ledge too (columns 1-15, so the ledge is under water
## when the water is full) down to the well floor.
const WELL_COLUMNS := Vector2i(1, 16)
const WELL_FLOOR_ROW := 18
## The pool tank: columns 18-33 down to the pool floor.
const POOL_COLUMNS := Vector2i(18, 34)
const POOL_FLOOR_ROW := 13

## The float lies on the well floor, centred on this column (cells, from the
## left): a jump from its edge to the wall is 3 cells, a hero's jump is 4.
const FLOAT_CENTRE_COLUMN := 11.5
## The button lies at the end of a tunnel that leaves the foot of the well wall
## to the right, under the pool (rows 16-17, columns 16-25). The hero has to wait
## until the well is empty, walk in, press it and come back to the float.
const BUTTON_FLOOR_ROW := 18
const BUTTON_COLUMN := 24.5
const BUTTON_HEIGHT := 24.0


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level02"
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

	var entrance := Node2D.new()
	entrance.set_script(load("res://objects/entrance_frame.gd"))
	entrance.name = "Entrance"
	entrance.set("size", Vector2(ENTRANCE_CELLS.size * CELL))
	entrance.position = Vector2(ENTRANCE_CELLS.position * CELL)
	_own(root, entrance)

	# Both tanks start full and drain from the first tick (`powered`): the well
	# through its grate, the pool the same, each at its own pace from levels.json.
	var well := _add_water(root, "well", WELL_COLUMNS, WELL_FLOOR_ROW)
	var float_body: WaterFloat = (load("res://objects/water_float.tscn") as PackedScene).instantiate()
	float_body.name = "Float"
	float_body.position = Vector2(FLOAT_CENTRE_COLUMN * CELL - well.position.x, 0.0)
	well.add_child(float_body)
	float_body.owner = root
	_add_water(root, "pool", POOL_COLUMNS, POOL_FLOOR_ROW)

	var button: PushButton = (load("res://objects/push_button.tscn") as PackedScene).instantiate()
	button.object_id = "button"
	button.target_ids = PackedStringArray(["door"])
	button.position = Vector2(BUTTON_COLUMN * CELL, BUTTON_FLOOR_ROW * CELL - BUTTON_HEIGHT / 2.0)
	_own(root, button)
	var sparks := ButtonSparks.new()
	sparks.name = "ButtonSparks"
	sparks.button_path = NodePath("../PushButton")
	sparks.position = button.position + Vector2(0.0, -BUTTON_HEIGHT / 2.0)
	_own(root, sparks)

	var door: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	door.object_id = "door"
	door.linked_id = "button"
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


## A tank from the full water line down to `floor_row`, over the columns
## `[from, to)`: full, draining, its node at the bottom centre.
func _add_water(root: Node, id: String, columns: Vector2i, floor_row: int) -> Water:
	var water: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	water.name = id.to_pascal_case()
	water.object_id = id
	var left := float(columns.x * CELL)
	var right := float(columns.y * CELL)
	var top := float(LINE_ROW * CELL)
	var bottom := float(floor_row * CELL)
	water.position = Vector2((left + right) / 2.0, bottom)
	water.size = Vector2(right - left, bottom - top)
	water.level = Water.LEVEL_MAX
	water.powered = true
	water.open_flow = -1
	water.outlet_side = -1
	_own(root, water)
	return water


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
