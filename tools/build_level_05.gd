extends SceneTree
## Builds level 05 `levels/level_05.tscn` «Crane» (card docs/levels/05.md,
## D176, D215): one screen of 30x17 cells in the Night shop, a puzzle that
## starts from its effect.
##
## Before she comes in, the empty crane has ridden down its rail from the
## ledge at the upper left, where the exit door in the back wall is shut by a
## slab on two chains, to the lower right. On the way the explosion tore the
## slab's left chain and it swung aside: the door is open, high up and out of
## reach. Chunks of the ceiling fell behind the crane, two into
## the pit, one onto the floor by the entrance. The crane hangs at the end of
## its rail over that floor, out of reach.
##
## Under Shift everything goes back: the chunks rise, the crane rides back up,
## the slab shuts the door. The chunk by the entrance lifts her; from it she
## climbs over the two that come back up out of the pit; she lets go, the
## crane rides down again and passes under the last one, she drops into it.
## Shift carries the crane back up to its ledge; she steps off and lets go:
## the crane rides away, the explosion comes again, the slab swings aside and
## she walks in. The crane has no brake here (`crane.pedal` false, D215).
##
## The pit is open to the bottom: a fall is death. Timing: `collapse` of the
## level's entry in data/levels.json.
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
	"#............................#",
	"######.......................#",
	"######.......................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#............................#",
	"#...........................S#",
	"#...................##########",
	"#...................##########"
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(28, 13, 1, 2)
## The chunks of the ceiling in the order of `collapse.pieces` (cells: x and
## row where it hangs, width, height; row where it lies, below the room for
## the two lost in the pit). The first hangs over the rail higher than she
## can jump from the crane, with room for her to ride under it: she drops
## from it into the crane. The second is the step to it, the third the lift
## from the floor; the crane passes over the third only while it lies.
const PIECES: Array[Dictionary] = [
	{"x": 15.0, "row": 5.3, "width": 2.0, "height": 0.8, "rest_row": 18.0, "lost": true},
	{"x": 18.5, "row": 5.6, "width": 2.0, "height": 0.8, "rest_row": 18.0, "lost": true},
	{"x": 22.3, "row": 6.0, "width": 2.0, "height": 0.6, "rest_row": 14.4},
]
## The crane's load where it waits by the ledge (cells: x, top row, width,
## height), how far it rides down the rail, the rail above its top, and how
## far it falls at the end (it never does here). Its end is higher over the
## floor than she can jump, and over the fallen chunk too: the only way in is
## a drop from a chunk under Shift, which is the pedal (D176).
const CRANE := Rect2(6.0, 6.0, 3.0, 0.4)
const CRANE_TRAVEL := Vector2(19.0, 5.5)
const SLING_CELLS := 2.0
const CRANE_FALL_CELLS := 0.0
## The exit door in the back wall of the crane's ledge (cells), its sill the
## ledge's floor. The slab hangs over it on two chains; the exit zone is the
## lower part of the doorway, where her body is when she stands in it.
const DOOR := Rect2(2.3, 4.1, 1.4, 1.9)
const GATE := Rect2(1.9, 3.8, 2.6, 2.4)
const EXIT := Rect2(2.3, 4.6, 1.4, 1.4)


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
