extends Node2D
## Test room: a blockout on the 64 px grid, wider than the screen.
## The tiles are built by tools/build_blockout.gd; edit them in the editor
## or change the map in that tool and run it again.

## The player falls this far below the room before returning to the spawn point.
const FALL_MARGIN_CELLS := 4

@onready var _blocks: TileMapLayer = $Blocks
@onready var _spawn: Marker2D = $SpawnPoint
@onready var _player: Player = $Player
@onready var _time: RoomTime = $RoomTime

var _bottom := 0


func _ready() -> void:
	if _blocks == null or _player == null:
		return
	var cell := _blocks.tile_set.tile_size.x
	var rect := _blocks.get_used_rect()
	_bottom = rect.end.y * cell
	_player.set_camera_limits(Rect2i(rect.position * cell, rect.size * cell))
	if _spawn != null:
		_player.respawn(_spawn.global_position)
	_player.drowned.connect(restart)


func _physics_process(_delta: float) -> void:
	if _player == null or _blocks == null:
		return
	var fell := _player.global_position.y > _bottom + FALL_MARGIN_CELLS * _blocks.tile_set.tile_size.y
	if fell:
		if _spawn != null:
			_player.respawn(_spawn.global_position)
	if Input.is_action_just_pressed("reset_level"):
		restart()


## The room as it was loaded and the player back at the spawn: the reset key,
## and drowning.
func restart() -> void:
	if _spawn != null and _player != null:
		_player.respawn(_spawn.global_position)
	if _time != null:
		_time.reset()
