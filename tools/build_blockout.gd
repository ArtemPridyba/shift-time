extends SceneTree
## Builds the gray blockout tiles and the test room scene.
##
## Run from the repository root, in this order (the second step needs the
## imported png):
##   godot --headless --path game --script $PWD/tools/build_blockout.gd -- png
##   godot --headless --path game --import
##   godot --headless --path game --script $PWD/tools/build_blockout.gd -- scene
##
## Map legend: '#' block, '.' empty, 'S' spawn point (feet on the cell bottom).
## Grid is 64 px. Jump height is a little over 2 cells, so every step and
## ledge is at most 2 cells above the surface the player jumps from.

const CELL := 64
const TILE_PNG := "res://levels/blockout/gray_block.png"
const TILESET_RES := "res://levels/blockout/blockout_tileset.tres"
const SCENE_PATH := "res://levels/test_room.tscn"

const MAP := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#................................####..#",
	"#...........................####.......#",
	"#.......##............####.............#",
	"#.S...######........##.................#",
	"################...#####################",
	"########################################",
]


func _initialize() -> void:
	var step := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	match step:
		"png":
			_build_png()
		"scene":
			_build_scene()
		_:
			push_error("usage: -- png | scene")
	quit()


func _build_png() -> void:
	var image := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	image.fill(Color("#3d434b"))
	for i in CELL:
		for edge in [0, CELL - 1]:
			image.set_pixel(i, edge, Color("#59606b"))
			image.set_pixel(edge, i, Color("#59606b"))
	image.save_png(ProjectSettings.globalize_path(TILE_PNG))
	print("wrote ", TILE_PNG)


func _build_scene() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL, CELL)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	var source := TileSetAtlasSource.new()
	source.texture = load(TILE_PNG)
	source.texture_region_size = Vector2i(CELL, CELL)
	source.create_tile(Vector2i.ZERO)
	# The source must belong to the tile set before its tiles get physics
	# data: only then the tile knows about the physics layer.
	tile_set.add_source(source, 0)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	var h := CELL / 2.0
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	]))
	assert(ResourceSaver.save(tile_set, TILESET_RES) == OK)

	var root := Node2D.new()
	root.name = "TestRoom"
	root.set_script(load("res://levels/test_room.gd"))

	var blocks := TileMapLayer.new()
	blocks.name = "Blocks"
	blocks.tile_set = load(TILESET_RES)
	root.add_child(blocks)
	blocks.owner = root

	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	root.add_child(spawn)
	spawn.owner = root

	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			match row[x]:
				"#":
					blocks.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
				"S":
					spawn.position = Vector2(x * CELL + CELL / 2.0, (y + 1) * CELL)

	var player: Node2D = load("res://objects/player.tscn").instantiate()
	root.add_child(player)
	player.owner = root

	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, SCENE_PATH) == OK)
	root.free()
	print("wrote ", SCENE_PATH)
