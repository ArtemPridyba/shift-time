extends SceneTree
## Builds level 05 `levels/level_05.tscn` «Crane» (card docs/levels/05.md,
## D176, D215): one screen of 30x17 cells in the Night shop, a puzzle about
## the order of events.
##
## She walks out on a ledge at the upper left where the crane hangs from a
## rail sloping down to the right. The way out is a door in the back wall by
## the rail, shut by a heavy slab on two chains. Her step onto the crane sets
## it riding down; it passes the door, and a little further an explosion
## tears the slab's left chain: the door is open, but the crane is already
## below it. Chunks of the ceiling hang over the rail and fall behind the
## crane, which comes to rest at the bottom by the floor.
##
## Holding Shift on the crane carries her back past the door before the
## explosion: shut. She steps onto a fallen chunk, holds Shift: the chunk
## rises and the empty crane rides back up; she drops into it from the chunk
## (the pedal), Shift carries it to the door, she lets go: the crane is on its
## brake, the world runs on, the explosion comes again, the slab swings aside.
##
## No pit: the floor is solid, every try can be repeated. Timing: `collapse`
## of the level's entry in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_05.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_05.tscn"
const LEVEL_ID := "level_05"

const MAP := [
	"##############################",
	"##############################",
	"#............................#",
	"#............................#",
	"#............................#",
	"#S...........................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"######.......................#",
	"##############################",
	"##############################"
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 4, 1, 2)
## The chunks of the ceiling in the order of `collapse.pieces` (cells: x and
## row where it hangs, width, height; row where it lies on the floor). Each
## hangs over the rail higher than she can jump from the crane, with room for
## her to ride under it, and falls after the crane has passed under it.
const PIECES: Array[Dictionary] = [
	{"x": 15.0, "row": 5.4, "width": 2.0, "height": 0.8, "rest_row": 14.2},
	{"x": 18.5, "row": 6.5, "width": 2.0, "height": 0.8, "rest_row": 14.2},
	{"x": 22.0, "row": 7.5, "width": 2.0, "height": 0.6, "rest_row": 14.4},
]
## The crane's load where it waits by the ledge (cells: x, top row, width,
## height), how far it rides down the rail, the rail above its top, and how
## far it falls at the end (it never does here). Its end is higher over the
## floor than she can jump, and over a fallen chunk too: once off, the only
## way back in is from a chunk rising under Shift, which is the pedal (D176).
const CRANE := Rect2(6.0, 6.0, 3.0, 0.4)
const CRANE_TRAVEL := Vector2(19.0, 6.0)
const SLING_CELLS := 2.0
const CRANE_FALL_CELLS := 0.0
## The exit door in the back wall by the rail (cells): the crane's floor is
## at its sill a fifth of the way down. The slab hangs over it on two chains;
## the exit zone is the lower part of the doorway, where her body is when she
## stands on the crane there.
const DOOR := Rect2(10.2, 5.3, 1.4, 1.9)
const GATE := Rect2(9.8, 5.0, 2.8, 2.4)
const EXIT := Rect2(10.2, 6.3, 1.4, 0.9)


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

	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					blocks.set_cell(cell, 0, Vector2i.ZERO)
				"S":
					spawn.position = Vector2((x + 0.5) * CELL, (y + 1) * CELL)

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

	# The collapse (D144, D176): chunks, the crane and its rail, the gate.
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
	collapse.door_rect = Rect2(DOOR.position * CELL, DOOR.size * CELL)
	collapse.gate_rect = Rect2(GATE.position * CELL, GATE.size * CELL)
	collapse.exit_path = NodePath("../Exit")
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
	exit.size = EXIT.size * CELL
	exit.position = EXIT.get_center() * CELL
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
