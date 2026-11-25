extends SceneTree
## Builds level 04 `levels/level_04.tscn` (card docs/levels/04.md, D168): time
## plates, then the minecart that rides through time. A room of 60x17 cells,
## two screens wide, sized to the heroine (D112).
##
## Upper tier: the low corridor of the lesson (plate A and its open shutter A,
## plate B and shutter B, closed from the start), then the open walkway over
## the hall with plate 2 and plate 1, each right above its rail switch, and
## the shaft at its right end where the cart waits at the top of the ramp.
## Lower tier: the rails on trestles over a pit open to the bottom (a fall is
## death, so the rails are walked only in the cart): the ramp down to switch 1
## (its side way: dead end 1), switch 2 (dead end 2), and the main line into
## the tunnel on the left, where the cart stops at the station and the exit
## is a jump away. The hoist runs under the walkway back to the shaft.
##
## Session 1 of the card: the bunker, shutter Z with plate K and the bricked
## wall come in session 2 (the tunnel stands open until then).
##
## Run from the repository root after build_blockout.gd made the tile set:
##   godot --headless --path game --script $PWD/tools/build_level_04.gd
##
## Map legend: '#' block, '.' empty, 'S' spawn point (inside the entrance),
## 'E' the exit zone (centred on its cells).

const CELL := 64
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/level_04.tscn"

const MAP := [
	"############################################################",
	"############################################################",
	"#####################......................................#",
	"#####################......................................#",
	"#####################......................................#",
	"#..........................................................#",
	"#S.........................................................#",
	"#########################################################..#",
	"#######....................................................#",
	"#..........................................................#",
	"#..........................................................#",
	"#EE........................................................#",
	"#EE........................................................#",
	"#######....................................................#",
	"#######....................................................#",
	"#######....................................................#",
	"#######....................................................#",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 5, 1, 2)

## Plates: the first cell and the width in cells, on the floor row whose top
## they lie on. Three cells: wider than a jump under the low ceiling.
const PLATE_CELLS := 3
const PLATES := [
	{"id": "plate_a", "label": "A", "cell": Vector2i(5, 7), "targets": ["shutter_a"]},
	{"id": "plate_b", "label": "B", "cell": Vector2i(13, 7), "targets": ["shutter_b"]},
	{"id": "plate_2", "label": "2", "cell": Vector2i(36, 7), "targets": ["switch_2"]},
	{"id": "plate_1", "label": "1", "cell": Vector2i(46, 7), "targets": ["switch_1"]},
]

## Shutters: the cells they close and where they go to open, in cells. They
## rise into the corridor's ceiling.
const SHUTTERS := [
	{"id": "shutter_a", "label": "A", "cells": Rect2(11, 5, 0.5, 2), "travel": Vector2(0, -2)},
	{"id": "shutter_b", "label": "B", "cells": Rect2(18, 5, 0.5, 2), "travel": Vector2(0, -2)},
]

## The rails, in cells: the main line lies on the top of row 13, the dead
## ends dip to row 15, the park is in the shaft just below the walkway.
const MAIN_Y := 13.0
const SPUR_Y := 15.0
const PARK := Vector2(56.875, 8.375)
const SEGMENTS := [
	{"id": "ramp", "points": [PARK, Vector2(55.625, 8.375), Vector2(50.0, MAIN_Y), Vector2(47.5, MAIN_Y)],
		"end": {"kind": "switch", "switch": "switch_1", "main": "main_1", "side": "spur_1"}},
	{"id": "spur_1", "points": [Vector2(47.5, MAIN_Y), Vector2(44.5, SPUR_Y), Vector2(42.5, SPUR_Y)],
		"end": {"kind": "stop", "stop": "dead_end"}},
	{"id": "main_1", "points": [Vector2(47.5, MAIN_Y), Vector2(37.5, MAIN_Y)],
		"end": {"kind": "switch", "switch": "switch_2", "main": "main_2", "side": "spur_2"}},
	{"id": "spur_2", "points": [Vector2(37.5, MAIN_Y), Vector2(34.5, SPUR_Y), Vector2(32.5, SPUR_Y)],
		"end": {"kind": "stop", "stop": "dead_end"}},
	{"id": "main_2", "points": [Vector2(37.5, MAIN_Y), Vector2(5.0, MAIN_Y)],
		"end": {"kind": "stop", "stop": "station"}},
]

## Switches under their plates: which way leads to the main line (card table).
const SWITCHES := [
	{"id": "switch_1", "label": "1", "at": Vector2(47.5, MAIN_Y), "main_when": "down", "side": Vector2(-3, 2)},
	{"id": "switch_2", "label": "2", "at": Vector2(37.5, MAIN_Y), "main_when": "up", "side": Vector2(-3, 2)},
]
## The walkway's top, where the tie rods meet the plates, in cells.
const WALKWAY_Y := 7.0
## The hoist: the hooked cart's wheels ride at HOIST_Y, the hoist's own rail
## hangs under the walkway at HOIST_RAIL_Y, from HOIST_FROM_X to the shaft.
const HOIST_Y := 10.625
const HOIST_RAIL_Y := 8.125
const HOIST_FROM_X := 7.0


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

	for one: Dictionary in SWITCHES:
		var switch := RailSwitch.new()
		switch.object_id = one["id"]
		switch.name = str(one["id"]).to_pascal_case()
		switch.label = one["label"]
		switch.main_when = one["main_when"]
		switch.main_direction = Vector2.LEFT
		switch.side_direction = (one["side"] as Vector2).normalized()
		var at: Vector2 = one["at"]
		switch.position = at * CELL
		switch.rod_top = Vector2(0, (WALKWAY_Y - at.y) * CELL)
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
		var cell: Vector2i = one["cell"]
		plate.position = Vector2((cell.x + PLATE_CELLS / 2.0) * CELL, cell.y * CELL)
		_own(root, plate)

	var cart := Minecart.new()
	cart.name = "Minecart"
	cart.rails_path = NodePath("../Rails")
	cart.park_segment = "ramp"
	cart.position = PARK * CELL
	_own(root, cart)

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
