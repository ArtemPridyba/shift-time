extends Node2D
## Test room: a blockout on the 64 px grid, wider than the screen.
## The tiles are built by tools/build_blockout.gd; edit them in the editor
## or change the map in that tool and run it again.

## The player falls this far below the room before returning to the spawn point.
const FALL_MARGIN_CELLS := 4

@onready var _blocks: TileMapLayer = $Blocks
@onready var _spawn: Marker2D = $SpawnPoint
@onready var _player: Player = $Player

var _bottom := 0


func _ready() -> void:
	var cell := _blocks.tile_set.tile_size.x
	var rect := _blocks.get_used_rect()
	_bottom = rect.end.y * cell
	_player.set_camera_limits(Rect2i(rect.position * cell, rect.size * cell))
	_player.respawn(_spawn.global_position)


func _physics_process(_delta: float) -> void:
	var fell := _player.global_position.y > _bottom + FALL_MARGIN_CELLS * _blocks.tile_set.tile_size.y
	if fell or Input.is_action_just_pressed("reset_level"):
		_player.respawn(_spawn.global_position)
