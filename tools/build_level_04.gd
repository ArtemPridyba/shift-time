extends SceneTree
## Builds level 04 `levels/level_04.tscn` (task 3.8, D118; card
## docs/levels/04.md): time plates. A room of 38x17 cells in two tiers sized to
## the heroine (D112). Upper tier: a low corridor (two cells high, no jumping
## over a plate) with plate A and its open shutter A, then plate B and its
## shutter B, closed from the start. A shaft drops to the lower tier: plate C,
## a pit of four cells under hatch C, then wall C and the exit. Plate C drives
## both the hatch and the wall. Which shutter starts open is data:
## `objects` of the level's entry in data/levels.json.
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
	"######################################",
	"######################################",
	"######################################",
	"######################################",
	"######################################",
	"#......................###############",
	"#S.....................###############",
	"#####################..###############",
	"#####################..###############",
	"#####################..###############",
	"#####################..###############",
	"#####################..............EE#",
	"#####################..............EE#",
	"############################....######",
	"#############################...######",
	"######################################",
	"######################################",
]

## The doorway the hero walks out of (decoration only), in cells.
const ENTRANCE_CELLS := Rect2i(1, 5, 1, 2)

## Plates: the first cell and the width in cells, on the floor row whose top
## they lie on. Three cells: wider than a jump under the low ceiling.
const PLATE_CELLS := 3
const PLATES := [
	{"id": "plate_a", "label": "A", "cell": Vector2i(5, 7), "targets": ["shutter_a"]},
	{"id": "plate_b", "label": "B", "cell": Vector2i(13, 7), "targets": ["shutter_b"]},
	{"id": "plate_c", "label": "C", "cell": Vector2i(24, 13), "targets": ["hatch_c", "wall_c"]},
]

## Shutters: the cells they close and where they go to open, in cells. Walls
## rise into the ceiling; the hatch slides right into the floor and a half
## cell down, so the heroine standing there never touches it.
const SHUTTERS := [
	{"id": "shutter_a", "label": "A", "cells": Rect2(11, 5, 0.5, 2), "travel": Vector2(0, -2)},
	{"id": "shutter_b", "label": "B", "cells": Rect2(18, 5, 0.5, 2), "travel": Vector2(0, -2)},
	{"id": "hatch_c", "label": "C", "cells": Rect2(28, 13, 4, 0.5), "travel": Vector2(4, 0.5)},
	{"id": "wall_c", "label": "C", "cells": Rect2(34, 11, 0.5, 2), "travel": Vector2(0, -2)},
]


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
