extends SceneTree
## Builds level 08 `levels/level_08.tscn` «Crane» on one screen (card
## docs/levels/08.md, D210): the collapse of level 05 as a puzzle of 30x17
## cells in the Night shop, sized to the heroine like level 01 (D112).
##
## She walks out on a ledge at the left. Over the pit hangs a bridge of two
## slabs on chains, level with a yellow platform by the exit tower; the
## platform hangs on a chain over two pulleys against a heavy slab under the
## roof. The hall shakes (`Collapse`, act 1): the bridge falls onto two stubs
## low in the pit, the heavy slab sinks and pulls the platform up flush with
## the tower, out of reach. Under Shift it all goes back up, but she is not on
## it. The crane by her ledge rides down its rail over the pit once she steps
## onto it (act 2) and falls at its end (act 3, no chunks, no slow part): she
## steps off onto a fallen slab, holds Shift (the crane flies back first, then
## her slab rises), walks over the mended bridge onto the platform while the
## world stands at its start, lets Shift go, and the replayed fall of the
## heavy slab lifts her to the exit (rule «A»).
##
## The pit is open to the bottom: a fall is death. Timing: `collapse` of the
## level's entry in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_08.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_08.tscn"
const LEVEL_ID := "level_08"

const MAP := [
	"##############################",
	"##############################",
	"#............................#",
	"#.........................EE.#",
	"#.........................EE.#",
	"#........................#####",
	"#........................#####",
	"#........................#####",
	"#S.......................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..........#..#....#####",
	"#######..........#..#....#####",
	"#######..........#..#....#####"
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 7, 1, 2)
## The falling pieces in the order of `collapse.pieces` (cells: x and row where
## it hangs, width, height; row where it lies): the bridge's slabs A and B,
## which fall onto their stubs; the heavy slab under the roof, which sinks
## three rows on its chain; the yellow platform it hangs against, which rises
## as far, from the bridge's height to the top of the exit tower.
const PIECES: Array[Dictionary] = [
	{"x": 16.4, "row": 8.0, "width": 3.0, "height": 0.5, "rest_row": 13.5},
	{"x": 19.45, "row": 8.0, "width": 3.0, "height": 0.5, "rest_row": 13.5},
	{"x": 20.2, "row": 3.0, "width": 1.6, "height": 1.2, "rest_row": 6.0},
	{"x": 22.5, "row": 8.0, "width": 2.5, "height": 0.4, "rest_row": 5.0},
]
## The crane's load where it waits by the ledge (cells: x, top row, width,
## height), how far it rides down the rail, the rail above its top, and how
## far it falls at the end.
const CRANE := Rect2(7.0, 9.0, 2.6, 0.4)
const CRANE_TRAVEL := Vector2(6.5, 2.5)
const SLING_CELLS := 1.6
const CRANE_FALL_CELLS := 8.0
## The beacon sits on the wall by the exit door's upper left corner (as in 01).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level08"
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

	# The collapse (D210): the bridge, the counterweight, the crane and its rail.
	var collapse := Collapse.new()
	collapse.name = "Collapse"
	var hangs: Array[Rect2] = []
	var rests: Array[Rect2] = []
	var lost := PackedInt32Array()
	for k in PIECES.size():
		var p: Dictionary = PIECES[k]
		var size := Vector2(float(p["width"]), float(p["height"])) * CELL
		hangs.append(Rect2(Vector2(float(p["x"]), float(p["row"])) * CELL, size))
		rests.append(Rect2(Vector2(float(p.get("rest_x", p["x"])), float(p["rest_row"])) * CELL, size))
		if bool(p.get("lost", false)):
			lost.append(k)
	collapse.pieces = hangs
	collapse.rests = rests
	collapse.lost = lost
	collapse.crane_rect = Rect2(CRANE.position * CELL, CRANE.size * CELL)
	collapse.crane_travel = CRANE_TRAVEL * CELL
	collapse.sling_px = SLING_CELLS * CELL
	collapse.crane_fall_px = CRANE_FALL_CELLS * CELL
	_own(root, collapse)

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
