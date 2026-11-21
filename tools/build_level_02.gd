extends SceneTree
## Builds level 02 `levels/level_02.tscn` (task 3.1, 17.11.2026; reworked after
## Artem's playtests 21.11.2026, D97, D98 and D99, card docs/levels/02.md): a
## room of 48x17 cells, about 1.6 screens wide, the camera follows the hero. He walks out
## of a doorway onto a ledge at mid height. Right of it is a well with a float and
## a grate on its floor, beyond that a wall as high as the full water line,
## behind the wall a small pool with its own float by the far wall and, beyond
## the pool on the full line, a dry landing and the way out: a passage two cells
## high, shut by a gate the pool holds down while it stands high. The well runs
## through its grate into the pool: at the start of the history the well is full
## and the pool empty, then the well drains and the pool fills. The full pool
## carries the hero up to the landing, the empty pool opens the gate: the same
## water once forward, once back. Right behind the gate the floor drops into a
## flooded sump (D99): full at the start of the history, it drains later, and a
## sluice in its far wall opens only once the sump has run low. Under Shift the
## gate is open but the sump is full: the hero dives in and has to let go of
## Shift, so the sump drains before the air runs out. The events come one after
## another (D99): the well drains, the pipe starts, the gate shuts, the sump
## drains, the sluice opens. The timing (prelude, walk-in, drain and fill times,
## when the pipe and the sump start, the gates' levels) lives in
## data/levels.json, the water line is the same height over everything.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_02.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_02.tscn"

const MAP := [
	"################################################",
	"#...............................################",
	"#...............................################",
	"#...............................################",
	"#.......................................#....EE#",
	"#.......................................#....EE#",
	"#...............##..........#####.......#...####",
	"#...............##..........#####..........#####",
	"#...............##..........#####.........######",
	"#...............##..........####################",
	"#S..............################################",
	"#####...........################################",
	"#####...........################################",
	"#####...........################################",
	"#####...........################################",
	"################################################",
	"################################################",
]

## The doorway the hero walks out of (decoration only), in cells: two cells,
## 128 px, as in level 01 (D82).
const ENTRANCE_CELLS := Rect2i(1, 9, 1, 2)

## The full water line: the top of the wall, row 6. Everything else is measured
## from it: the hero's ledge is 5 cells under it (row 11), the well floor 9
## (row 15), the pool floor 4 (row 10), the landing and the way out are on it.
const LINE_ROW := 6
## The well tank covers the ledge too (columns 1-15, so the ledge is under water
## when the water is full) down to the well floor.
const WELL_COLUMNS := Vector2i(1, 16)
const WELL_FLOOR_ROW := 15
## The pool tank: columns 18-27 down to the pool floor.
const POOL_COLUMNS := Vector2i(18, 28)
const POOL_FLOOR_ROW := 10

## The well float lies on the well floor, centred on this column (cells, from
## the left): a jump from its edge to the wall is 3 cells, a hero's jump is 4.
const FLOAT_CENTRE_COLUMN := 11.5
## The pool float stands by the far wall, centred on this column: from its edge
## to the landing is half a cell, from the wall top to it far more than a jump,
## so only a hero who rides it up from the pool floor reaches the landing.
const POOL_FLOAT_CENTRE_COLUMN := 26.0
## The landing beyond the pool is columns 28-31 on the full line; the passage
## to the way out starts at column 32, rows 4-5, and the gate stands in its
## mouth, at the right edge of its column: there is no ground behind it to
## wait on, the next step falls into the sump. The gate watches the pool: open
## while the pool is low, shut while it stands high (its level in levels.json).
const GATE_COLUMN := 32
const GATE_ROWS := Vector2i(4, 6)
const GATE_WIDTH := 32.0
## The sump behind the gate: columns 33-39, its floor 3 cells under the line
## (row 9), more than a jump, so the hero who dropped in cannot climb back. Its
## tank runs from the line to the floor.
const SUMP_COLUMNS := Vector2i(33, 40)
const SUMP_FLOOR_ROW := 9
## The sluice in the sump's far wall: column 40, rows 7-8 (128 px, D82), at
## the bottom of the sump. Behind it steps of one cell climb to the way out.
const SLUICE_COLUMN := 40
const SLUICE_ROWS := Vector2i(7, 9)


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

	var entrance := Node2D.new()
	entrance.set_script(load("res://objects/entrance_frame.gd"))
	entrance.name = "Entrance"
	entrance.set("size", Vector2(ENTRANCE_CELLS.size * CELL))
	entrance.position = Vector2(ENTRANCE_CELLS.position * CELL)
	_own(root, entrance)

	# The well starts full and drains through its grate from the first tick
	# (`powered`); the pool starts empty and still, the pipe in the wall the
	# well runs into starts it a little later, and the sump starts full and still
	# until its grate opens later again: prelude events in levels.json, each
	# water at its own pace from there.
	var well := _add_water(root, "well", WELL_COLUMNS, WELL_FLOOR_ROW, Water.LEVEL_MAX, -1, true)
	_add_float(root, well, "Float", FLOAT_CENTRE_COLUMN)
	var pool := _add_water(root, "pool", POOL_COLUMNS, POOL_FLOOR_ROW, 0, 1, false)
	_add_float(root, pool, "Float", POOL_FLOAT_CENTRE_COLUMN)
	_add_water(root, "sump", SUMP_COLUMNS, SUMP_FLOOR_ROW, Water.LEVEL_MAX, -1, false)

	# The gate in the mouth of the way out: the pool holds it shut while it
	# stands high, so the hero who rode the full pool up has to send the pool
	# back down under Shift to pass.
	_add_gate(root, "Gate", "gate", "pool", GATE_ROWS, GATE_COLUMN * CELL + CELL - GATE_WIDTH / 2.0)
	# The sluice at the bottom of the sump: the sump holds it shut while it
	# stands high, so the hero who dived in under Shift has to let go of it.
	_add_gate(root, "Sluice", "sluice", "sump", SLUICE_ROWS, SLUICE_COLUMN * CELL + GATE_WIDTH / 2.0)

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


## A water gate `id` in a passage of `rows` `[from, to)`, centred on `x`, that
## watches the tank `watch_id`.
func _add_gate(root: Node, node_name: String, id: String, watch_id: String, rows: Vector2i, x: float) -> void:
	var gate: WaterGate = (load("res://objects/water_gate.tscn") as PackedScene).instantiate()
	gate.name = node_name
	gate.object_id = id
	gate.watch_id = watch_id
	gate.linked_id = watch_id
	gate.height = float((rows.y - rows.x) * CELL)
	gate.travel = gate.height
	gate.position = Vector2(x, (rows.x + rows.y) / 2.0 * CELL)
	_own(root, gate)


## A tank from the full water line down to `floor_row`, over the columns
## `[from, to)`, at `level`, running (`flow` -1 drains, +1 fills) from the
## first tick when `powered`; its node at the bottom centre. The grate or pipe
## is on the left.
func _add_water(root: Node, id: String, columns: Vector2i, floor_row: int, level: int, flow: int, powered: bool) -> Water:
	var water: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	water.name = id.to_pascal_case()
	water.object_id = id
	var left := float(columns.x * CELL)
	var right := float(columns.y * CELL)
	var top := float(LINE_ROW * CELL)
	var bottom := float(floor_row * CELL)
	water.position = Vector2((left + right) / 2.0, bottom)
	water.size = Vector2(right - left, bottom - top)
	water.level = level
	water.powered = powered
	water.open_flow = flow
	water.outlet_side = -1
	_own(root, water)
	return water


## A float on `water`, centred on `column`; the water sets its height.
func _add_float(root: Node, water: Water, node_name: String, column: float) -> void:
	var float_body: WaterFloat = (load("res://objects/water_float.tscn") as PackedScene).instantiate()
	float_body.name = node_name
	float_body.position = Vector2(column * CELL - water.position.x, 0.0)
	water.add_child(float_body)
	float_body.owner = root


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
