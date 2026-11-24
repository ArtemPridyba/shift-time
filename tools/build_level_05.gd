extends SceneTree
## Builds level 05 `levels/level_05.tscn` «Crane» (card docs/levels/05.md, D139):
## a room of 48x17 cells in the Night shop, sized to the heroine like level 01
## (D112). A gallery of girders hangs from the crane's rail under the roof, each
## with its lamp. She walks out on the floor at the left; at once the runaway
## crane rides from the far right towards her and its ram knocks the girders off
## one by one, their lamps falling with them: the two on the right land on stubs
## in the pit as a low bridge to the exit, the two in the middle are lost to the
## bottom of the pit, the last one lands on the floor by her. The crane slams
## into its stop; it is dark.
##
## Under Shift the crane rides back and the girder knocked last rises first: she
## rides it up to the gallery, crosses the middle girders as they rise and
## reaches the crane operator's post. There she pulls the stop lever while the
## crane is between the post and the right girders: in the new history the crane
## stands there, the right girders lie as the bridge, the rest hang lit. She lets
## Shift go, drops onto the bridge and walks under the overhang to the exit.
##
## Left to right: the start floor (row 13), the pit (open to the bottom: a fall
## is death), the post on the gallery (row 9) on its pillar, two stubs, the
## overhang that walls the gallery off from the exit, the exit ledge (row 13).
## Timing: `crane` and `objects` of the level's entry in data/levels.json.
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
	"################################################",
	"################################################",
	"################################################",
	"################################################",
	"################################################",
	"################################################",
	"#..............................................#",
	"#..............................................#",
	"#..............................................#",
	"#............####..............................#",
	"#..............#............####################",
	"#..............#............####################",
	"#S.............#...........................EE..#",
	"#########......#........#..................EE..#",
	"#########......#........#..#####################",
	"#########......#........#..#####################",
	"#########......#........#..#####################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 10, 1, 2)
## The crane's ram: where its top edge meets the grid at the start of history
## (the middle in x, the top at the row), how far it rides, in cells. It hangs
## from the hook over the gallery and carries nobody.
const LOAD_CENTRE := Vector2(33.0, 7.0)
const LOAD_TRAVEL := Vector2(-30.5, 0.0)
const LOAD_WIDTH_CELLS := 1
const LOAD_HEIGHT := 32.0
## The girders of the gallery (cells: x where it hangs, width; x and top row
## where it lies), from the left; each hangs on row 9. The bridge girder hangs
## far to the right over the slab and comes down sideways (`CollapsePlan.path`).
const GIRDER_HEIGHT := 0.5
const GIRDERS: Array[Dictionary] = [
	{"x": 5.0, "width": 4.0, "rest_x": 5.0, "rest_row": 12.5},
	{"x": 9.0, "width": 4.0, "rest_x": 9.0, "rest_row": 16.5, "lost": true},
	{"x": 17.0, "width": 4.0, "rest_x": 17.0, "rest_row": 16.5, "lost": true},
	{"x": 27.5, "width": 4.0, "rest_x": 22.0, "rest_row": 12.5},
]
const HANG_ROW := 9.0
## The crane's stop lever on the operator's post (the cell it stands in).
const LEVER_CELL := Vector2i(14, 8)
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
	# The stop lever holds it wherever it is (D139); it rams girders, not her.
	load_platform.holdable = true
	load_platform.brake = true
	load_platform.solid = false
	load_platform.collision_layer = 0
	load_platform.collision_mask = 0
	_own(root, load_platform)

	# The gallery the crane's ram knocks down (D139).
	var collapse := Collapse.new()
	collapse.name = "Collapse"
	var hangs: Array[Rect2] = []
	var rests: Array[Rect2] = []
	var lost := PackedInt32Array()
	for k in GIRDERS.size():
		var g: Dictionary = GIRDERS[k]
		var size := Vector2(float(g["width"]), GIRDER_HEIGHT) * CELL
		hangs.append(Rect2(Vector2(float(g["x"]), HANG_ROW) * CELL, size))
		rests.append(Rect2(Vector2(float(g["rest_x"]), float(g["rest_row"])) * CELL, size))
		if bool(g.get("lost", false)):
			lost.append(k)
	collapse.girders = hangs
	collapse.rests = rests
	collapse.lost = lost
	_own(root, collapse)

	var lever: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	lever.object_id = "crane_stop"
	lever.name = "CraneStop"
	lever.target_id = "crane_load"
	lever.position = Vector2((LEVER_CELL.x + 0.5) * CELL, (LEVER_CELL.y + 1) * CELL)
	_own(root, lever)

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
