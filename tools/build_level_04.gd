extends SceneTree
## Builds level 04 «Interference» `levels/level_04.tscn` (task 3.3, card
## docs/levels/04.md, D104): a room of 44x17 cells. The hero walks out of a
## doorway into a hall; ahead a wooden bridge burns over a bottomless pit and
## falls apart; at its far end a wooden barricade burns in the exit corridor.
##
## Both were lit before the hero came (they start burning at frame 0). The
## bridge burns out first, the barricade a little later, so the recorded
## history never has a whole bridge and an open passage together. A lever on
## the landing by the bridge opens a sprinkler pipe over the bridge (not over
## the barricade): thrown now it rains into the empty pit; thrown under Shift
## while the bridge still burns it puts the fire out in a new branch, and the
## barricade burns through on its own. Burn times live in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_04.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells). The bridge, the barricade, the
## lever and the pipe are placed by the constants below. The pit columns are
## open to the bottom, so a fall brings the hero back to the spawn point.

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_04.tscn"

const MAP := [
	"############################################",
	"#...........................################",
	"#...........................################",
	"#...........................################",
	"#...........................################",
	"#...........................################",
	"#...........................################",
	"#..........................................#",
	"#.......................................EE.#",
	"#.......................................EE.#",
	"#...........##...............###############",
	"#.........####...............###############",
	"#.......######...............###############",
	"#.S...########...............###############",
	"##############...............###############",
	"##############...............###############",
	"##############...............###############",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 12, 1, 2)

## The bridge spans the pit (columns 14-28) with its top on the landing's
## level, row 10, and runs under the barricade to the corridor floor: there is
## no floor before the barricade, so nobody waits there for it to burn through.
const BRIDGE_HEIGHT := 32.0
const BRIDGE_CELLS := Rect2i(14, 10, 15, 1)
## The barricade closes the corridor (rows 7-9) in column 28.
const BARRICADE_CELLS := Rect2i(28, 7, 1, 3)
## The lever stands on the landing by the bridge: cell (12, 9).
const LEVER_CELL := Vector2i(12, 9)
## The sprinkler pipe hangs under the ceiling over the pit only, its rain falls
## to the bridge; it stops short of the barricade.
const PIPE_Y := 192.0
const PIPE_LEFT := 14 * 64
const PIPE_RIGHT := 27 * 64 + 32
## The cistern the pipe draws from (decoration), in cells.
const CISTERN_CELLS := Rect2i(9, 2, 3, 2)


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

	var exit_cells := Rect2i()
	for y in MAP.size():
		var row: String = MAP[y]
		assert(row.length() == 44, "row %d is %d cells" % [y, row.length()])
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

	# Decoration: the cistern under the ceiling and the feed pipe to the
	# sprinkler. Nothing here is recorded.
	var cistern := ColorRect.new()
	cistern.name = "Cistern"
	cistern.color = Color("#4a5058")
	cistern.position = Vector2(CISTERN_CELLS.position * CELL)
	cistern.size = Vector2(CISTERN_CELLS.size * CELL)
	_own(root, cistern)
	var feed := ColorRect.new()
	feed.name = "FeedPipe"
	feed.color = Sprinkler.PIPE_COLOR
	feed.position = Vector2(CISTERN_CELLS.end.x * CELL, PIPE_Y - 10.0)
	feed.size = Vector2(PIPE_LEFT - CISTERN_CELLS.end.x * CELL, 12.0)
	_own(root, feed)
	var rod := ColorRect.new()
	rod.name = "LeverRod"
	rod.color = Sprinkler.PIPE_COLOR
	rod.position = Vector2((LEVER_CELL.x + 0.5) * CELL - 3.0, CISTERN_CELLS.end.y * CELL)
	rod.size = Vector2(6.0, (LEVER_CELL.y + 1) * CELL - 64.0 - CISTERN_CELLS.end.y * CELL)
	_own(root, rod)

	# Both wood zones are burning when the room starts: the fire was lit before
	# the hero came. Their burn times are per level (data/levels.json).
	var bridge := _wood("bridge", Rect2(Vector2(BRIDGE_CELLS.position * CELL), Vector2(BRIDGE_CELLS.size.x * CELL, BRIDGE_HEIGHT)))
	bridge.name = "Bridge"
	_own(root, bridge)
	var barricade := _wood("barricade", Rect2(Vector2(BARRICADE_CELLS.position * CELL), Vector2(BARRICADE_CELLS.size * CELL)))
	barricade.name = "Barricade"
	_own(root, barricade)

	var sprinkler := Sprinkler.new()
	sprinkler.name = "Sprinkler"
	sprinkler.object_id = "sprinkler"
	var bridge_top := float(BRIDGE_CELLS.position.y * CELL)
	sprinkler.size = Vector2(PIPE_RIGHT - PIPE_LEFT, bridge_top + BRIDGE_HEIGHT / 2.0 - PIPE_Y)
	sprinkler.position = Vector2((PIPE_LEFT + PIPE_RIGHT) / 2.0, PIPE_Y)
	_own(root, sprinkler)

	var lever: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	lever.object_id = "lever"
	lever.name = "Lever"
	lever.target_id = "sprinkler"
	lever.position = Vector2((LEVER_CELL.x + 0.5) * CELL, (LEVER_CELL.y + 1) * CELL)
	_own(root, lever)

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


## A wood zone over `rect` (pixels), burning from the start.
func _wood(id: String, rect: Rect2) -> WoodZone:
	var zone: WoodZone = (load("res://objects/wood_zone.tscn") as PackedScene).instantiate()
	zone.object_id = id
	zone.size = rect.size
	zone.position = rect.get_center()
	zone.start_phase = WoodBurn.Phase.BURNING
	return zone


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
