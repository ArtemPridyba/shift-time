extends SceneTree
## Builds level 02 `levels/level_02.tscn` «Поток», rebuilt 24.11.2026 after
## Artem's sketch (D150, card docs/levels/02.md): the height and the look of
## level 01 (17 rows, the roof on rows 0-1, the Night shop kit), longer than one
## screen; the camera follows the heroine.
##
## Left: the start floor with button 1, pool 1 (full) with its float by the far
## wall, the wall between the pools with a sluice at the bottom of pool 1, and
## the deep pool 2 (empty) with its float by the far wall. Button 1 opens the
## sluice: pool 1 runs into pool 2 until both stand on one line (pool 1's floor
## is the full line of pool 2). Right: the floor with button 2 and a tunnel that
## dips under the rock between two gates; its water stands to the brim. Button 2
## starts the tunnel's drain; the pump fails before the tunnel is dry and fills
## it to the brim again; only then the near gate opens. The far gate is opened
## by a lever behind bars under the start floor, which only the jet out of the
## sluice reaches, under Shift, when the heroine is not in its way (D161).
## The heroine crosses with Shift held. The numbers live in data/levels.json.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_02.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_02.tscn"
const LEVEL_ID := "level_02"

const MAP := [
	"#######################################################",
	"#######################################################",
	"#.....................................................#",
	"#.....................................................#",
	"#.....................................................#",
	"#.....................................................#",
	"#.....................................................#",
	"#.....................................................#",
	"#S....................................................#",
	"#####.........##..............####################....#",
	"#####.........##.................##############....EE.#",
	"#####.........##.................##############....EE.#",
	"################..........#####..................######",
	"################..........######................#######",
	"################..........#############################",
	"#######################################################",
	"#######################################################",
]

## The doorway the heroine walks out of (decoration), two cells as in level 01.
const ENTRANCE_CELLS := Rect2i(1, 7, 1, 2)
## The start floor and the wall between the pools stand on this row; it is
## pool 1's full line.
const LINE_ROW := 9
## Pool 1: columns 5-13 down to its floor on row 12, three cells of water;
## its float by the wall between the pools.
const POOL_1_COLUMNS := Vector2i(5, 14)
const POOL_1_FLOOR_ROW := 12
const POOL_1_FLOAT_COLUMN := 12.0
## Pool 2: columns 16-25, full to row 12 (pool 1's floor and the right floor),
## its floor on row 15; its float by the right floor.
const POOL_2_COLUMNS := Vector2i(16, 26)
const POOL_2_TOP_ROW := 12
const POOL_2_FLOOR_ROW := 15
const POOL_2_FLOAT_COLUMN := 24.0
## The sluice: on the face of the wall in the middle of pool 1, one cell high.
## Under Shift the jet flies out of it across pool 1 (D161) while the surface
## is below it.
const SLUICE_CELL := Vector2i(14, 10)
## The niche behind bars under the start floor (columns 3-4, rows 10-11): the
## lever the jet hits stands on its floor; the heroine's reach stops at the bars.
const NICHE_CELLS := Rect2i(3, 10, 2, 2)
const LEVER_COLUMN := 3.6
## The red-green lamps of the lever: in the niche and over the far gate.
const NICHE_LAMP := Vector2(4.35, 10.4)
const GATE_LAMP := Vector2(48.6, 9.5)
## The buttons: on the start floor and on the right floor before the tunnel.
const BUTTON_1_CELL := Vector2i(3, 9)
const BUTTON_2_CELL := Vector2i(28, 12)
## The tunnel: water from the brim (row 12, the floor at the gates) down to the
## floor under the rock (row 14), from the first step to the last.
const TUNNEL_COLUMNS := Vector2i(31, 49)
const TUNNEL_TOP_ROW := 12
const TUNNEL_FLOOR_ROW := 14
## The gates stand in the mouths on the floor (rows 10-11) and sink into it.
const GATE_IN_COLUMN := 30
const GATE_OUT_COLUMN := 49
const GATE_ROWS := Vector2i(10, 12)
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


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

	# The Night shop world (as level 01): the back wall, the ground after the
	# gates (it hides a sunk blade), the light; the tiles stay the collision.
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

	# Pool 1 starts full and still, pool 2 empty; button 1 opens the sluice
	# and runs both. The tunnel starts full; button 2 starts its drain, which
	# turns into a fill (turn_after_seconds in levels.json).
	var pool_1 := _add_water(root, "pool_1", POOL_1_COLUMNS, LINE_ROW, POOL_1_FLOOR_ROW, Water.LEVEL_MAX, -1, 1)
	_add_float(root, pool_1, POOL_1_FLOAT_COLUMN)
	var pool_2 := _add_water(root, "pool_2", POOL_2_COLUMNS, POOL_2_TOP_ROW, POOL_2_FLOOR_ROW, 0, 1, -1)
	_add_float(root, pool_2, POOL_2_FLOAT_COLUMN)
	_add_water(root, "tunnel", TUNNEL_COLUMNS, TUNNEL_TOP_ROW, TUNNEL_FLOOR_ROW, Water.LEVEL_MAX, -1, 1)

	var gate_in: WaterGate = (load("res://objects/water_gate.tscn") as PackedScene).instantiate()
	gate_in.name = "GateIn"
	gate_in.object_id = "gate_in"
	gate_in.watch_id = "tunnel"
	gate_in.opens_after_flood = true
	_place_gate(root, gate_in, GATE_IN_COLUMN)
	var gate_out: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	gate_out.name = "GateOut"
	gate_out.object_id = "gate_out"
	gate_out.linked_id = "lever_jet"
	_place_gate(root, gate_out, GATE_OUT_COLUMN)

	var ground := WorldGround.new()
	ground.name = "WorldGround"
	ground.level_id = LEVEL_ID
	_own(root, ground)

	# The sluice is drawn over the wall: it sinks into it to let pool 1 out.
	var sluice: Door = (load("res://objects/door.tscn") as PackedScene).instantiate()
	sluice.name = "Sluice"
	sluice.object_id = "sluice"
	sluice.linked_id = "button_1"
	sluice.height = float(CELL)
	sluice.travel = -float(CELL)
	sluice.position = Vector2(SLUICE_CELL.x * CELL + 16.0, (SLUICE_CELL.y + 0.5) * CELL)
	_own(root, sluice)

	# The niche, the lever in it, the jet out of the sluice and the lamps that
	# show the lever (D161): the jet hits the lever only when nothing stands in
	# its way; the lever opens the far gate of the tunnel.
	var niche := BarredNiche.new()
	niche.name = "Niche"
	niche.size = Vector2(NICHE_CELLS.size * CELL)
	niche.bars_side = 1
	niche.position = Vector2(NICHE_CELLS.position * CELL)
	_own(root, niche)
	var lever: Lever = (load("res://objects/lever.tscn") as PackedScene).instantiate()
	lever.name = "LeverJet"
	lever.object_id = "lever_jet"
	lever.target_ids = PackedStringArray(["gate_out"])
	lever.position = Vector2(LEVER_COLUMN * CELL, NICHE_CELLS.end.y * CELL)
	_own(root, lever)
	var jet := ReverseJet.new()
	jet.name = "Jet"
	jet.water_path = NodePath("../Pool1")
	jet.lever_path = NodePath("../LeverJet")
	jet.direction = -1
	jet.position = Vector2(SLUICE_CELL.x * CELL, (SLUICE_CELL.y + 0.5) * CELL)
	jet.length_px = float((SLUICE_CELL.x - NICHE_CELLS.end.x) * CELL)
	_own(root, jet)
	for at: Vector2 in [NICHE_LAMP, GATE_LAMP]:
		var lamp := LeverLamp.new()
		lamp.name = "LeverLamp" if at == NICHE_LAMP else "GateLamp"
		lamp.lever_path = NodePath("../LeverJet")
		lamp.position = at * CELL
		_own(root, lamp)

	var button_1 := _add_button(root, "Button1", "button_1", BUTTON_1_CELL, ["sluice", "pool_1", "pool_2"])
	_add_sparks(root, button_1, NodePath())
	var button_2 := _add_button(root, "Button2", "button_2", BUTTON_2_CELL, ["tunnel"])
	_add_sparks(root, button_2, NodePath("../../Tunnel"))

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
## bottom centre, the grate or the pipe on `outlet_side`.
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


## A gate two cells high in the mouth at `column`, standing on the floor; it
## sinks into the floor to open.
func _place_gate(root: Node, gate: Door, column: int) -> void:
	var rows := GATE_ROWS.y - GATE_ROWS.x
	gate.height = float(rows * CELL)
	gate.travel = -float(rows * CELL)
	gate.position = Vector2((column + 0.5) * CELL, (GATE_ROWS.x + rows / 2.0) * CELL)
	_own(root, gate)


func _add_button(root: Node, node_name: String, id: String, cell: Vector2i, targets: Array) -> PushButton:
	var button: PushButton = (load("res://objects/push_button.tscn") as PackedScene).instantiate()
	button.name = node_name
	button.object_id = id
	button.target_ids = PackedStringArray(targets)
	button.position = Vector2((cell.x + 0.5) * CELL, cell.y * CELL - PushButton.SIZE.y / 2.0)
	_own(root, button)
	return button


func _add_sparks(root: Node, button: PushButton, fault_path: NodePath) -> void:
	var sparks := ButtonSparks.new()
	sparks.name = "Sparks"
	sparks.button_path = NodePath("..")
	sparks.fault_water_path = fault_path
	button.add_child(sparks)
	sparks.owner = root


func _own(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
