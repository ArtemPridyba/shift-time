extends SceneTree
## Builds level 07 «Plates» `levels/level_07.tscn` (card docs/levels/07.md,
## D190, D191): the time plates of level 04 as a puzzle on one screen, 30x17
## cells, sized to the heroine (D112).
##
## Upper left: the low corridor of the lesson: plate A, then shutter A, closed
## from the start (a step in normal time keeps it closed, a step with Shift
## held opens it once time runs forward). Past it the open walkway over the
## hall to the shaft at its right end, where the minecart waits at the top of
## the ramp behind a barrier that opens only while the cart stands parked.
## Below: the rails on trestles over a pit open to the bottom (a fall is
## death): the ramp down to switch B, its side way into the dead end under the
## main line, where plate B lies under the wheels at the buffer and pulls
## switch B; the main line into the tunnel on the left, the station, and the
## exit a jump away. The hoist runs under the walkway back to the shaft.
##
## At the start the empty cart rides by itself (intro ride, D191): into the
## dead end, its wheels on plate B, the bump, the hoist back to the park.
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_07.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_07.tscn"

const MAP := [
	"##############################",
	"##############################",
	"############................##",
	"############................##",
	"############................##",
	"#...........................##",
	"#S..........................##",
	"##########################..##",
	"#######.....................##",
	"#...........................##",
	"#...........................##",
	"#EE.........................##",
	"#EE.........................##",
	"#######.....................##",
	"#######.....................##",
	"#######.....................##",
	"#######.....................##",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 5, 1, 2)
## Plates: the first cell and the width in cells, on the row whose top they lie
## on. Plate A: three cells, wider than a jump under the low ceiling. Plate B:
## under the wheels at the buffer of the dead end (its top on the spur's rail).
const PLATE_CELLS := 3
const PLATES := [
	{"id": "plate_a", "label": "A", "cell": Vector2(5, 7), "targets": ["shutter_a"]},
	{"id": "plate_b", "label": "B", "cell": Vector2(10, 15), "targets": ["switch_b"]},
]
## Shutter A: the cells it closes and where it goes to open, in cells; it rises
## into the corridor's ceiling.
const SHUTTERS := [
	{"id": "shutter_a", "label": "A", "cells": Rect2(9, 5, 0.5, 2), "travel": Vector2(0, -2)},
]
## The rails, in cells: the main line on the top of row 13, the dead end dips
## to row 15 under it, the park is in the shaft just below the walkway.
const MAIN_Y := 13.0
const SPUR_Y := 15.0
const PARK := Vector2(25.875, 8.375)
const SWITCH_X := 15.0
const SEGMENTS := [
	{"id": "ramp", "points": [PARK, Vector2(24.625, 8.375), Vector2(19.5, MAIN_Y), Vector2(SWITCH_X, MAIN_Y)],
		"end": {"kind": "switch", "switch": "switch_b", "main": "main", "side": "spur"}},
	{"id": "spur", "points": [Vector2(SWITCH_X, MAIN_Y), Vector2(13.0, SPUR_Y), Vector2(9.5, SPUR_Y)],
		"end": {"kind": "stop", "stop": "dead_end"}},
	{"id": "main", "points": [Vector2(SWITCH_X, MAIN_Y), Vector2(5.0, MAIN_Y)],
		"end": {"kind": "stop", "stop": "station"}},
]
## Switch B: up leads to the main line; it starts down, into the dead end
## (`objects` of the level's entry). Its pull rod comes up from plate B.
const SWITCH := {"id": "switch_b", "label": "B", "at": Vector2(SWITCH_X, MAIN_Y), "main_when": "up", "side": Vector2(-1, 1),
	"rod_top": Vector2(-2, 2)}
## The hoist: the hooked cart's wheels ride at HOIST_Y, the hoist's own rail
## hangs under the walkway at HOIST_RAIL_Y, from HOIST_FROM_X to the shaft.
const HOIST_Y := 10.625
const HOIST_RAIL_Y := 8.125
const HOIST_FROM_X := 9.0
## The barrier at the end of the walkway, in cells: a wall while the cart is
## away (D192). Higher than a jump.
const GATE_CELLS := Rect2(25.6, 4.5, 0.4, 2.5)
## The beacon over the exit door, from the door's foot (as in level 02).
const BEACON_FROM_DOOR := Vector2(-66.0, -118.0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level07"
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

	var rails := Rails.new()
	rails.name = "Rails"
	var segments: Array = []
	for one: Dictionary in SEGMENTS:
		var pts := PackedVector2Array()
		for p: Vector2 in one["points"]:
			pts.append(p * CELL)
		segments.append({"id": one["id"], "points": pts, "end": one["end"]})
	rails.segments = segments
	rails.hoist_y = HOIST_Y * CELL
	rails.hoist_rail_y = HOIST_RAIL_Y * CELL
	rails.hoist_from_x = HOIST_FROM_X * CELL
	rails.hoist_to_x = PARK.x * CELL
	rails.ground_y = MAP.size() * CELL
	_own(root, rails)

	var switch := RailSwitch.new()
	switch.object_id = SWITCH["id"]
	switch.name = str(SWITCH["id"]).to_pascal_case()
	switch.label = SWITCH["label"]
	switch.main_when = SWITCH["main_when"]
	switch.main_direction = Vector2.LEFT
	switch.side_direction = (SWITCH["side"] as Vector2).normalized()
	switch.position = (SWITCH["at"] as Vector2) * CELL
	switch.rod_top = (SWITCH["rod_top"] as Vector2) * CELL
	_own(root, switch)

	for one: Dictionary in SHUTTERS:
		var shutter := Shutter.new()
		shutter.object_id = one["id"]
		shutter.name = str(one["id"]).to_pascal_case()
		shutter.label = one["label"]
		var cells: Rect2 = one["cells"]
		shutter.size = cells.size * CELL
		shutter.travel = (one["travel"] as Vector2) * CELL
		shutter.position = (cells.position + cells.size / 2.0) * CELL
		_own(root, shutter)

	for one: Dictionary in PLATES:
		var plate := TimePlate.new()
		plate.object_id = one["id"]
		plate.name = str(one["id"]).to_pascal_case()
		plate.label = one["label"]
		plate.target_ids = PackedStringArray(one["targets"])
		plate.width = float(PLATE_CELLS * CELL)
		var cell: Vector2 = one["cell"]
		plate.position = Vector2((cell.x + PLATE_CELLS / 2.0) * CELL, cell.y * CELL)
		_own(root, plate)

	var cart := Minecart.new()
	cart.name = "Minecart"
	cart.rails_path = NodePath("../Rails")
	cart.park_segment = "ramp"
	cart.position = PARK * CELL
	cart.gate_rect = Rect2(GATE_CELLS.position * CELL, GATE_CELLS.size * CELL)
	_own(root, cart)

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
