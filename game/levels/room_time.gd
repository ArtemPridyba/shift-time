class_name RoomTime
extends Node
## The node that runs `TimeWorld` in a room. Every physics tick it reads the
## direction from TimeManager, collects the room's nodes of the group
## `temporal` and lets the world rewind, replay or record them. It forwards
## direction changes to the objects and is the door for interference
## (`player_action`, `live_action`) and for the level reset.
##
## Put it as a direct child of the room, next to the player and the objects:
## the player's rect and the objects' positions are both in the room's
## coordinates.

## The player, for the crush check; empty means no player in the room.
@export var player_path: NodePath
## Seconds the room runs without the player before it starts (section 2.2).
@export var prelude_seconds := 0.0

var world: TimeWorld
## What the last tick did: a `TimeWorld.Step`.
var last_step := TimeWorld.Step.STARTED

var _recorder := TemporalRecorder.new()
var _initial := {}
var _prelude_ticks := 0


func _init() -> void:
	# After TimeManager (-100), before the player (0): the player moves against
	# the world of this tick.
	process_physics_priority = -50


func _ready() -> void:
	world = TimeWorld.from_config(Content.time())
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.direction_changed.connect(_on_direction_changed)
	var objects := temporal_objects()
	for problem in _recorder.validate(objects):
		push_error("RoomTime: " + problem)
	_initial = _recorder.capture(objects)
	world.start(objects)
	_prelude_ticks = int(round(prelude_seconds * float(Content.time().get("physics_ticks_per_second", 60))))
	world.run_prelude(objects, _prelude_ticks)


func _physics_process(_delta: float) -> void:
	var manager := get_node_or_null("/root/TimeManager")
	var direction: int = manager.direction if manager != null else TimeWorld.FORWARD
	last_step = world.tick(direction, temporal_objects(), _player_rect())
	_tell_world_clock()


## Decoration that is drawn from world time (the look of water, task 2.3А)
## joins the group `world_clock` and gets the cursor every tick, and whether
## this tick was recorded at the head. Nothing in that group is recorded.
func _tell_world_clock() -> void:
	var room := get_parent()
	if room == null:
		return
	var recorded := last_step == TimeWorld.Step.RECORDED
	for node in get_tree().get_nodes_in_group("world_clock"):
		if room.is_ancestor_of(node) and node.has_method("on_world_tick"):
			node.call("on_world_tick", world.timeline.cursor(), recorded)


## The recorded objects of this room, in tree order.
func temporal_objects() -> Array:
	var room := get_parent()
	if room == null or not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group("temporal").filter(
		func(node: Node) -> bool: return room.is_ancestor_of(node))


func player_action(object_id: String, new_state: Dictionary) -> bool:
	return world.player_action(temporal_objects(), object_id, new_state)


func live_action(object_id: String, new_state: Dictionary) -> bool:
	return world.live_action(temporal_objects(), object_id, new_state)


## Returns interaction candidates from buttons and levers in this room.
## Each entry: { "id": String, "position": Vector2, "radius": float, "node": Node }
func interaction_candidates() -> Array:
	var result: Array = []
	var room := get_parent()
	if room == null or not is_inside_tree():
		return result
	for node: Variant in get_tree().get_nodes_in_group("temporal"):
		if not room.is_ancestor_of(node as Node):
			continue
		if (node as Node).has_method("interaction_candidate"):
			var c: Dictionary = (node as Node).call("interaction_candidate")
			c["node"] = node
			result.append(c)
	return result


## The player calls this when pressing `interact`. Finds the nearest
## interaction point and applies all its state changes via player_action.
func player_interact(player_pos: Vector2) -> void:
	var candidates := interaction_candidates()
	var nearest_id := InteractionSystem.get_nearest(player_pos, candidates)
	if nearest_id == "":
		return
	var objects := temporal_objects()
	var interactor: Node = null
	for c: Variant in candidates:
		var cd := c as Dictionary
		if str(cd.get("id", "")) == nearest_id:
			interactor = cd.get("node") as Node
			break
	if interactor == null or not interactor.has_method("get_interaction_change"):
		return
	var changes: Array = interactor.call("get_interaction_change", objects)
	for change: Variant in changes:
		var ch := change as Dictionary
		var id := str(ch.get("id", ""))
		var state := (ch.get("state", {}) as Dictionary).duplicate(true)
		for obj: Variant in objects:
			if obj is Object and (obj as Object).has_method("capture_state") and str((obj as Object).get("object_id")) == id:
				var full_state: Dictionary = ((obj as Object).call("capture_state") as Dictionary).duplicate(true)
				full_state.merge(state, true)
				state = full_state
				break
		player_action(id, state)


## Back to the room as it was loaded, with a fresh history and its prelude
## run again: the player comes back into the same past.
func reset() -> void:
	var objects := temporal_objects()
	_recorder.restore(_initial, objects)
	world.start(objects)
	world.run_prelude(objects, _prelude_ticks)


func _player_rect() -> Rect2:
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("body_rect"):
		return player.call("body_rect")
	return Rect2()


func _on_direction_changed(direction: int) -> void:
	for object in temporal_objects():
		if object.has_method("on_time_direction_changed"):
			object.call("on_time_direction_changed", direction)
