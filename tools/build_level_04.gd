extends SceneTree
## Builds level 04 «Interference» `levels/level_04.tscn` (task 3.3, card
## docs/levels/04.md, D104, D105): a room of 44x17 cells. The hero walks out
## of a doorway into a hall; ahead a wooden bridge burns over a bottomless pit
## and falls apart; at its far end a wooden barricade burns in the exit
## corridor, and the hall's fire system rains on it and puts it out, so it
## stays whole and shut.
##
## Part one: a lever high on the left wall (three ledges up) opens a sprinkler
## over the bridge. Thrown now it rains into the empty pit; thrown under Shift
## while the bridge burns it puts the bridge out in a new branch.
## Part two: a valve on the middle ledge shuts the fire system over the
## barricade. It is open from the start and the system starts on its own a
## moment into the history (`start_seconds`); shut under Shift before then, the
## barricade burns through in the new branch. Both are needed, so the recorded
## history never has a whole bridge and an open way. Numbers in levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_04.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells). The bridge, the barricade, the
## levers and the pipes are placed by the constants below. The pit columns are
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
	"###.....................................EE.#",
	"#....##...####...............###############",
	"#........#####...............###############",
	"#.......######...............###############",
	"#.S....#######...............###############",
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
## The lever stands on the lower ledge, level with the landing, one jump from
## it: cell (5, 9). The valve of the fire system stands on the upper ledge by
## the left wall, two jumps from the landing: cell (2, 8) (D106: swapped, so
## the two water lines never cross). The ledges hang over the hall floor, high
## enough to walk under them from the entrance.
const LEVER_CELL := Vector2i(5, 9)
const VALVE_CELL := Vector2i(2, 8)
## The sprinkler pipe hangs under the ceiling over the pit only, its rain falls
## to the bridge; it stops short of the barricade.
const PIPE_Y := 192.0
const PIPE_LEFT := 14 * 64
const PIPE_RIGHT := 27 * 64 + 16
## The cistern the pipe draws from (decoration), in cells, over the lever.
const CISTERN_CELLS := Rect2i(4, 2, 3, 1)
## The fire system: its main rises from the valve by the left wall, runs along
## the ceiling over the cistern to the corridor and down its wall; its nozzle
## hangs over the barricade only. The feed pipe runs under the main, so the
## two lines never cross (D106).
const MAIN_Y := 80.0
const MAIN_X := 27 * 64 + 44
const SYSTEM_Y := 7 * 64 + 12


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

	# Decoration: the cistern under the ceiling and the rod down to the lever.
	# Nothing here is recorded.
	_pipe(root, "Cistern", Rect2(Vector2(CISTERN_CELLS.position * CELL), Vector2(CISTERN_CELLS.size * CELL)), Color("#4a5058"))
	var lever_x := (LEVER_CELL.x + 0.5) * CELL
	_pipe(root, "LeverRod", Rect2(lever_x - 3.0, CISTERN_CELLS.end.y * CELL, 6.0, (LEVER_CELL.y + 1) * CELL - 64.0 - CISTERN_CELLS.end.y * CELL))

	# Both wood zones are burning when the room starts: the fire was lit before
	# the hero came. Their burn times are per level (data/levels.json).
	var bridge := _wood("bridge", Rect2(Vector2(BRIDGE_CELLS.position * CELL), Vector2(BRIDGE_CELLS.size.x * CELL, BRIDGE_HEIGHT)))
	bridge.name = "Bridge"
	_own(root, bridge)
	var barricade := _wood("barricade", Rect2(Vector2(BARRICADE_CELLS.position * CELL), Vector2(BARRICADE_CELLS.size * CELL)))
	barricade.name = "Barricade"
	_own(root, barricade)

	# The two water lines (D106): pipes that show the water running in them.
	# The feed pipe runs from the cistern along the sprinkler's nozzles; the
	# main rises from the valve to the ceiling, over the cistern, down the
	# corridor wall and along the fire system's nozzle.
	var feed_y := PIPE_Y - 4.0
	_water_pipe(root, "FeedPipe", WaterPipe.Kind.FEED, "../Sprinkler", PackedVector2Array([
		Vector2(CISTERN_CELLS.end.x * CELL, feed_y), Vector2(PIPE_RIGHT, feed_y)]))
	var valve_x := (VALVE_CELL.x + 0.5) * CELL
	var system_y := SYSTEM_Y - 4.0
	_water_pipe(root, "FireMain", WaterPipe.Kind.MAIN, "../FireSystem", PackedVector2Array([
		Vector2(valve_x, (VALVE_CELL.y + 1) * CELL - 32.0), Vector2(valve_x, MAIN_Y),
		Vector2(MAIN_X, MAIN_Y), Vector2(MAIN_X, system_y),
		Vector2(BARRICADE_CELLS.end.x * CELL, system_y)]))

	var sprinkler := Sprinkler.new()
	sprinkler.name = "Sprinkler"
	sprinkler.object_id = "sprinkler"
	sprinkler.draw_pipe = false
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

	# The hall's fire system over the barricade: open from the start, it rains
	# on its own after `start_seconds` (levels.json) unless the valve is shut.
	var system := Sprinkler.new()
	system.name = "FireSystem"
	system.object_id = "fire_system"
	system.powered = true
	system.draw_pipe = false
	system.size = Vector2(BARRICADE_CELLS.size.x * CELL, BARRICADE_CELLS.size.y * CELL - 16.0 - (SYSTEM_Y - BARRICADE_CELLS.position.y * CELL))
	system.position = Vector2((BARRICADE_CELLS.position.x + BARRICADE_CELLS.size.x / 2.0) * CELL, SYSTEM_Y)
	_own(root, system)

	var valve: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	valve.object_id = "valve"
	valve.name = "Valve"
	valve.target_id = "fire_system"
	valve.look = 1
	valve.on = true
	valve.position = Vector2((VALVE_CELL.x + 0.5) * CELL, (VALVE_CELL.y + 1) * CELL)
	_own(root, valve)

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


## A water pipe along `path` (pixels) that shows the water of `source`.
func _water_pipe(root: Node, node_name: String, kind: WaterPipe.Kind, source: String, path: PackedVector2Array) -> void:
	var pipe := WaterPipe.new()
	pipe.name = node_name
	pipe.kind = kind
	pipe.source_path = NodePath(source)
	pipe.points = path
	_own(root, pipe)


## A decorative pipe or tank: a plain rectangle, never recorded.
func _pipe(root: Node, node_name: String, rect: Rect2, color: Color = Sprinkler.PIPE_COLOR) -> void:
	var pipe := ColorRect.new()
	pipe.name = node_name
	pipe.color = color
	pipe.position = rect.position
	pipe.size = rect.size
	pipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(root, pipe)


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
