extends SceneTree
## Builds level 03 «Interference» `levels/level_03.tscn` (card
## docs/levels/03.md, D155), part 1: the first screen, 30x17 cells.
##
## The hero walks out of a doorway straight onto the level of a bridge over a
## pit. The bridge is six wood zones of three cells; the first burns when the
## room starts and the fire runs along them one by one (`spread_from`). Under
## the ceiling a sprinkler pipe runs from the fire alarm handle by the entrance
## over the whole bridge; its fire sensor over the fifth zone opens it when
## the fire gets there, and the rain puts out the rest of the bridge and the
## torch in its holder by the entrance. Behind the bridge a wooden barricade
## closes the doorway of a brick wall.
##
## The way: under Shift, at frame 0, take the burning torch and pull the alarm
## (a branch: the rain runs from the start and the first zone goes out); cross
## the wet bridge and thrust the torch into the barricade. Until part 2 widens
## the level to 60 cells, the exit waits right behind the barricade.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_03.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells). The bridge, the barricade, the
## alarm, the torch and the pipe are placed by the constants below. The pit
## under the bridge is open to the bottom: a fall is death (D135).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_03.tscn"

const MAP := [
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"#..........................###",
	"#..........................###",
	"#..........................###",
	"#..........................###",
	"#...........................E#",
	"#S..........................E#",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
	"#######..................#####",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 8, 1, 2)
## The bridge: six zones of three cells from column 7, top on row 10.
const BRIDGE_LEFT := 7
const BRIDGE_ROW := 10
const ZONES := 6
const ZONE_CELLS := 3
const BRIDGE_HEIGHT := 32.0
## The zone the fire sensor on the pipe watches (1-based).
const SENSOR_ZONE := 5
## The barricade closes the doorway of the brick wall (column 27, rows 8-9).
const BARRICADE_CELLS := Rect2i(27, 8, 1, 2)
## The alarm handle stands at hand height in column 3; the node is on the floor.
const ALARM_CELL := Vector2i(3, 9)
## The torch hangs in its holder in column 5, row 8, under the first nozzle.
const TORCH_CELL := Vector2i(5, 8)
## The sprinkler pipe under the ceiling: from over the torch to the end of the
## bridge (columns 4-24), rain down to the middle of the bridge.
const PIPE_Y := 4 * 64 + 14
const PIPE_LEFT := 4 * 64
const PIPE_RIGHT := 25 * 64


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level03"
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

	var entrance := Node2D.new()
	entrance.set_script(load("res://objects/entrance_frame.gd"))
	entrance.name = "Entrance"
	entrance.set("size", Vector2(ENTRANCE_CELLS.size * CELL))
	entrance.position = Vector2(ENTRANCE_CELLS.position * CELL)
	_own(root, entrance)

	# The bridge: a chain of fire, each zone catches from the one before it.
	for i in ZONES:
		var left := (BRIDGE_LEFT + i * ZONE_CELLS) * CELL
		var zone := _wood("bridge_%d" % (i + 1), Rect2(left, BRIDGE_ROW * CELL, ZONE_CELLS * CELL, BRIDGE_HEIGHT))
		zone.name = "Bridge%d" % (i + 1)
		zone.start_phase = WoodBurn.Phase.BURNING if i == 0 else WoodBurn.Phase.WHOLE
		zone.spread_from = "" if i == 0 else "bridge_%d" % i
		_own(root, zone)
	var barricade := _wood("barricade", Rect2(Vector2(BARRICADE_CELLS.position * CELL), Vector2(BARRICADE_CELLS.size * CELL)))
	barricade.name = "Barricade"
	_own(root, barricade)

	var alarm_x := (ALARM_CELL.x + 0.5) * CELL
	var floor_y := float(BRIDGE_ROW * CELL)
	var alarm := FireAlarm.new()
	alarm.name = "Alarm"
	alarm.object_id = "alarm"
	alarm.target_ids = PackedStringArray(["sprinkler"])
	alarm.position = Vector2(alarm_x, floor_y)
	alarm.box_height_px = floor_y - (ALARM_CELL.y + 0.5) * CELL
	_own(root, alarm)

	# The pipe rises from the alarm to the ceiling and runs along the nozzles.
	_water_pipe(root, "AlarmPipe", "../Sprinkler", PackedVector2Array([
		Vector2(alarm_x, floor_y - alarm.box_height_px - 24.0), Vector2(alarm_x, PIPE_Y - 4.0),
		Vector2(PIPE_RIGHT, PIPE_Y - 4.0)]))
	var sensor_x := (BRIDGE_LEFT + (SENSOR_ZONE - 0.5) * ZONE_CELLS) * CELL
	_box(root, "Sensor", Rect2(sensor_x - 10.0, PIPE_Y + 2.0, 20.0, 14.0), Color("#9a2a22"))

	var sprinkler := Sprinkler.new()
	sprinkler.name = "Sprinkler"
	sprinkler.object_id = "sprinkler"
	sprinkler.draw_pipe = false
	sprinkler.sensor_id = "bridge_%d" % SENSOR_ZONE
	sprinkler.size = Vector2(PIPE_RIGHT - PIPE_LEFT, floor_y + BRIDGE_HEIGHT / 2.0 - PIPE_Y)
	sprinkler.position = Vector2((PIPE_LEFT + PIPE_RIGHT) / 2.0, PIPE_Y)
	_own(root, sprinkler)

	var torch := Torch.new()
	torch.name = "Torch"
	torch.object_id = "torch"
	torch.mounted = true
	torch.lit = true
	torch.position = Vector2((TORCH_CELL.x + 0.5) * CELL, (TORCH_CELL.y + 1) * CELL - 8.0)
	torch.floor_offset_px = floor_y - torch.position.y
	_own(root, torch)

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


## A whole wood zone over `rect` (pixels).
func _wood(id: String, rect: Rect2) -> WoodZone:
	var zone: WoodZone = (load("res://objects/wood_zone.tscn") as PackedScene).instantiate()
	zone.object_id = id
	zone.size = rect.size
	zone.position = rect.get_center()
	return zone


## A water pipe along `path` (pixels) that shows the water of `source`.
func _water_pipe(root: Node, node_name: String, source: String, path: PackedVector2Array) -> void:
	var pipe := WaterPipe.new()
	pipe.name = node_name
	pipe.kind = WaterPipe.Kind.FEED
	pipe.source_path = NodePath(source)
	pipe.points = path
	_own(root, pipe)


## Decoration: a plain rectangle, never recorded.
func _box(root: Node, node_name: String, rect: Rect2, color: Color) -> void:
	var box := ColorRect.new()
	box.name = node_name
	box.color = color
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(root, box)


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
