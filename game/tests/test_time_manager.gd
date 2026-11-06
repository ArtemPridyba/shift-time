extends RefCounted
## Tests of `TimeManager`: the direction follows the rewind action (Shift),
## the signal fires once per change, a reset brings forward time back, and the
## player is not subscribed to time. Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room.tscn"
const ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "interact", "rewind", "reset_level", "pause",
]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_time_manager_is_an_autoload_in_forward_time() -> void:
	var registered := str(ProjectSettings.get_setting("autoload/TimeManager", ""))
	check(registered == "*res://autoload/time_manager.gd", "TimeManager must be an autoload of time_manager.gd, got '%s'" % registered)
	var manager := _manager()
	check(manager != null, "no /root/TimeManager node")
	if manager == null:
		return
	await _settle()
	check(manager.direction == 1, "time must start forward, got %d" % manager.direction)
	check(not manager.is_rewinding(), "is_rewinding() must be false at the start")


func test_direction_follows_shift_and_comes_back() -> void:
	var manager := _manager()
	await _settle()
	Input.action_press("rewind")
	await _ticks(3)
	check(manager.direction == -1, "holding rewind must give direction -1, got %d" % manager.direction)
	check(manager.is_rewinding(), "is_rewinding() must be true while rewind is held")
	Input.action_release("rewind")
	await _ticks(3)
	check(manager.direction == 1, "releasing rewind must bring direction back to +1, got %d" % manager.direction)
	check(not manager.is_rewinding(), "is_rewinding() must be false after the release")


func test_signal_fires_once_per_change() -> void:
	var manager := _manager()
	await _settle()
	var seen: Array[int] = []
	var listener := func(direction: int) -> void: seen.append(direction)
	manager.direction_changed.connect(listener)
	Input.action_press("rewind")
	await _ticks(10)
	check(seen == [-1], "holding rewind must emit exactly one -1, got %s" % [seen])
	Input.action_release("rewind")
	await _ticks(10)
	check(seen == [-1, 1], "releasing rewind must emit exactly one +1 more, got %s" % [seen])
	manager.direction_changed.disconnect(listener)


func test_reset_returns_to_forward_and_waits_for_a_new_press() -> void:
	var manager := _manager()
	await _settle()
	var seen: Array[int] = []
	var listener := func(direction: int) -> void: seen.append(direction)
	manager.direction_changed.connect(listener)

	manager.reset()
	check(seen.is_empty(), "a reset in forward time must emit nothing, got %s" % [seen])

	Input.action_press("rewind")
	await _ticks(3)
	check(manager.direction == -1, "rewinding must work before the reset")
	manager.reset()
	check(manager.direction == 1, "reset() must bring direction back to +1 at once")
	await _ticks(10)
	check(manager.direction == 1, "a Shift that is still held must not rewind again after a reset")
	check(seen == [-1, 1], "the held Shift must not flip the direction back, got %s" % [seen])

	Input.action_release("rewind")
	await _ticks(3)
	Input.action_press("rewind")
	await _ticks(3)
	check(manager.direction == -1, "a new press after the release must rewind again")
	Input.action_release("rewind")
	await _ticks(3)
	manager.direction_changed.disconnect(listener)


func test_player_is_not_subscribed_to_time() -> void:
	var manager := _manager()
	await _settle()
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var player: Node = room.get_node("Player")
	var subscribed := false
	for connection in manager.direction_changed.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == player:
			subscribed = true
	check(not subscribed, "the player must not be connected to TimeManager.direction_changed")
	check(not player.is_in_group("temporal"), "the player must not be a temporal object")
	room.queue_free()
	await _tree.process_frame


# --- helpers ----------------------------------------------------------------

func _manager() -> Node:
	return _tree.root.get_node_or_null("TimeManager")


## Releases every action and waits until time runs forward again.
func _settle() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	await _ticks(3)


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
