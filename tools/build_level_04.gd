extends SceneTree
## Builds level 04 «Interference» `levels/level_04.tscn` (task 3.3, card
## docs/levels/04.md, D57): a room of 30x15 cells. The hero walks out of a
## doorway onto a ledge; a bottomless pit; across it the exit gate stands right
## at the end of where the bridge was, with no ledge in front of it.
##
## The bridge and the gate are one safety sequence: first the bridge slides
## back into its slot under the ledge, then the gate opens. Recorded history
## never has both the bridge out and the gate open. A latch (a lever) at the
## edge of the ledge can only hold the bridge in its slot-out position; thrown
## in the past, it keeps the bridge out in the new branch while the gate opens
## on its own. Timing (bridge, gate, prelude) lives in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_04.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'D' the gate (the door stands in these cells), 'E' the exit zone (centred on
## its cells). Row 10 under the ledge is the bridge's slot; the pit columns are
## open to the bottom, so a fall brings the hero back to the spawn point.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_04.tscn"

const MAP := [
	"##############################",
	"#.....................########",
	"#.....................########",
	"#.....................########",
	"#.....................########",
	"#.....................########",
	"#.....................########",
	"#.....................########",
	"#S....................D...EE.#",
	"#############.........D...EE.#",
	"###....................#######",
	"#############..........#######",
	"#############..........#######",
	"#############..........#######",
	"#############..........#######",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 7, 1, 2)

## The bridge spans the pit (columns 13-22) with its top at row 10, one cell
## below the ledge, and slides 10 cells left into the slot under the ledge. It
## runs under the gate (column 22) to the floor of the exit corridor: there is
## no floor under the gate, so nobody waits there for it to open.
const BRIDGE_HEIGHT := 32.0
const BRIDGE_CELLS := Rect2i(13, 10, 10, 1)
const BRIDGE_TRAVEL := Vector2(-10.0, 0.0)

## The latch stands on the ledge by its edge, over the slot: cell (11, 8).
const LATCH_CELL := Vector2i(11, 8)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level04"
	root.set_script(load("res://levels/level_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	_own(root, blocks)
	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	_own(root, spawn)

	var gate_cells := Rect2i()
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
				"D":
					gate_cells = Rect2i(cell, Vector2i.ONE) if gate_cells.size == Vector2i.ZERO else gate_cells.expand(cell + Vector2i.ONE)
				"E":
					exit_cells = Rect2i(cell, Vector2i.ONE) if exit_cells.size == Vector2i.ZERO else exit_cells.expand(cell + Vector2i.ONE)

	var entrance := Node2D.new()
	entrance.set_script(load("res://objects/entrance_frame.gd"))
	entrance.name = "Entrance"
	entrance.set("size", Vector2(ENTRANCE_CELLS.size * CELL))
	entrance.position = Vector2(ENTRANCE_CELLS.position * CELL)
	_own(root, entrance)

	# The gate runs its own timer, "cycle": "opens_once" (data/levels.json), so
	# a new branch of history opens it again on time.
	var gate: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	gate.object_id = "gate"
	gate.name = "Gate"
	gate.travel = float(gate_cells.size.y * CELL)
	gate.height = float(gate_cells.size.y * CELL)
	gate.position = (Vector2(gate_cells.position) + Vector2(gate_cells.size) / 2.0) * CELL
	_own(root, gate)

	var bridge: MovingPlatform = (load("res://objects/platform.tscn") as PackedScene).instantiate()
	bridge.object_id = "bridge"
	bridge.name = "Bridge"
	bridge.holdable = true
	bridge.travel = BRIDGE_TRAVEL * CELL
	var width := float(BRIDGE_CELLS.size.x * CELL)
	bridge.position = Vector2((BRIDGE_CELLS.position.x * CELL) + width / 2.0, BRIDGE_CELLS.position.y * CELL + BRIDGE_HEIGHT / 2.0)
	bridge.width = width
	_own(root, bridge)

	var latch: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	latch.object_id = "latch"
	latch.name = "Latch"
	latch.target_id = "bridge"
	latch.position = Vector2((LATCH_CELL.x + 0.5) * CELL, (LATCH_CELL.y + 1) * CELL)
	_own(root, latch)

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
