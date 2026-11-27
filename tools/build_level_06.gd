extends SceneTree
## Builds level 06 «Поток» `levels/level_06.tscn` (card docs/levels/06.md,
## D187): the one-screen puzzle of the water rule, 30x17 cells, in place of
## the long level 02 (which stays as it is until the team decides).
##
## The heroine walks out of a doorway onto the high left floor. Right of it the
## upper tank A, full, its float by the far wall; the wall between the tanks
## with a sluice at the bottom of A; the lower tank B, empty, as deep as A and
## as wide, its float by the far wall; past B the exit floor on B's brim. In
## front of her the sluice opens by itself and A runs into B: the float of A
## sinks to the bottom, the float of B rises to the exit floor. Under Shift the
## same water runs back: the float of A lifts her to the wall, and in the past
## B stands empty, so she can wait on its float for the water to come again.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_06.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells). The tanks, their floats and the
## sluice are placed by the constants below; the numbers (how fast the water
## runs, when the sluice opens) are in data/levels.json.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_06.tscn"
const LEVEL_ID := "level_06"

const MAP := [
	"##############################",
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#S...........................#",
	"######........##.............#",
	"######........##.............#",
	"######........##..........EE.#",
	"######........##..........EE.#",
	"################........######",
	"################........######",
	"################........######",
	"################........######",
	"##############################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 6, 1, 2)
## Tank A: columns [6, 14), water from row 8 to its floor on row 12.
const TANK_A_COLUMNS := Vector2i(6, 14)
const TANK_A_TOP_ROW := 8
const TANK_A_FLOOR_ROW := 12
## Tank B: columns [16, 24), from A's floor line down to its own floor on row
## 16: as wide and as deep as A, so what leaves A fills B to the brim.
const TANK_B_COLUMNS := Vector2i(16, 24)
const TANK_B_TOP_ROW := 12
const TANK_B_FLOOR_ROW := 16
## The floats by the far wall of each tank (centre column; a float is three
## cells wide): A's reaches the wall between the tanks, B's the exit floor.
const FLOAT_A_COLUMN := 12.5
const FLOAT_B_COLUMN := 22.5
## The sluice: on the left face of the wall between the tanks, in A's lowest row.
const SLUICE_CELL := Vector2i(14, 11)
## The beacon over the exit door, from the door's foot (as in level 02).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level06"
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

	# The Night shop world as in levels 01 and 03: the blockout tiles stay the
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

	# Tank A starts full and still, tank B empty; the prelude's events open the
	# sluice and run both at once (prelude_events in levels.json).
	var tank_a := _add_water(root, "tank_a", TANK_A_COLUMNS, TANK_A_TOP_ROW, TANK_A_FLOOR_ROW, Water.LEVEL_MAX, -1, 1)
	_add_float(root, tank_a, FLOAT_A_COLUMN)
	var tank_b := _add_water(root, "tank_b", TANK_B_COLUMNS, TANK_B_TOP_ROW, TANK_B_FLOOR_ROW, 0, 1, -1)
	_add_float(root, tank_b, FLOAT_B_COLUMN)

	var ground := WorldGround.new()
	ground.name = "WorldGround"
	ground.level_id = LEVEL_ID
	_own(root, ground)

	# The sluice is drawn over the wall: it sinks into it to let A out. It is a
	# powered door; nothing in the room drives it but the prelude's event.
	var sluice: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	sluice.name = "Sluice"
	sluice.object_id = "sluice"
	sluice.linked_id = "prelude"
	sluice.height = float(CELL)
	sluice.travel = -float(CELL)
	sluice.position = Vector2(SLUICE_CELL.x * CELL + 16.0, (SLUICE_CELL.y + 0.5) * CELL)
	_own(root, sluice)

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


## A tank over the columns `[from, to)` from `top_row` down to `floor_row`, at
## `level`, running `flow` (-1 drains, +1 fills) once powered; its node at the
## bottom centre, the grate or the pipe on `outlet_side` (as in level 02).
func _add_water(root: Node, id: String, columns: Vector2i, top_row: int, floor_row: int, level: int, flow: int, outlet_side: int) -> Water:
	var water: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	water.name = id.to_pascal_case()
	water.object_id = id
	var left := float(columns.x * CELL)
	var right := float(columns.y * CELL)
	var top := float(top_row * CELL)
	var bottom := float(floor_row * CELL)
	water.position = Vector2((left + right) / 2.0, bottom)
	water.size = Vector2(right - left, bottom - top)
	water.level = level
	water.powered = false
	water.open_flow = flow
	water.outlet_side = outlet_side
	_own(root, water)
	return water


func _add_float(root: Node, water: Water, column: float) -> void:
	var float_body: WaterFloat = (load("res://objects/water_float.tscn") as PackedScene).instantiate()
	float_body.name = "Float"
	float_body.position = Vector2(column * CELL - water.position.x, 0.0)
	water.add_child(float_body)
	float_body.owner = root


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
