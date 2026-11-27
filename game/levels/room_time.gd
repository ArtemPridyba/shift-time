class_name RoomTime
extends Node
## The node that runs `TimeWorld` in a room. Every physics tick it reads the
## direction from TimeManager, collects the room's nodes of the group
## `temporal` and lets the world rewind, replay or record them. It forwards
## direction changes to the objects, lets the live sources (group `live`) act
## after every tick and is the door for interference (`player_action`,
## `live_action`) and for the level reset.
##
## Put it as a direct child of the room, next to the player and the objects:
## the player's rect and the objects' positions are both in the room's
## coordinates.

## Sent after `reset`: the room jumped back to its start, which is no event
## (the sound forgets what it heard, D206).
signal was_reset

## The player, for the crush check; empty means no player in the room.
@export var player_path: NodePath
## Seconds the room runs without the player before it starts (section 2.2):
## from the room's entry in `data/levels.json` (found by the room's scene),
## else `default_prelude_seconds` of `data/time.json`.
var prelude_seconds := 0.0

var world: TimeWorld
## What the last tick did: a `TimeWorld.Step`.
var last_step := TimeWorld.Step.STARTED

var _recorder := TemporalRecorder.new()
var _world_ticks_per_second := 0.0
var _initial := {}
var _prelude_ticks := 0
## The prelude's scripted events from the same entry, in ticks.
var _prelude_events: Array = []
## Per-level object settings from the same entry: `object_id -> settings`.
var _object_settings := {}


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
	_read_prelude()
	_apply_object_settings(objects)
	_initial = _recorder.capture(objects)
	world.start(objects)
	world.run_prelude(objects, _prelude_ticks, _prelude_events)
	# The key hints over interaction points and the wall stencils (task 4.3).
	if not player_path.is_empty():
		var hints := KeyHints.new()
		hints.name = "KeyHints"
		add_child(hints)


## The world time the room shows, in world seconds (D96): the world tick
## (`world_tick`, the still ticks at the head included, D56), so it runs on
## while the room stands. It runs back under Shift and stands at frame 0; the
## clock, the beacon and the WORLD timer read it (task Д4). 0 before the first tick.
func world_seconds() -> float:
	if world == null or world.timeline.cursor() < 0:
		return 0.0
	var tick := world.timeline.world_tick()
	if _world_ticks_per_second <= 0.0:
		_world_ticks_per_second = Content.world_ticks_per_second(Content.time())
	return maxf(float(tick), 0.0) / _world_ticks_per_second


func _physics_process(_delta: float) -> void:
	var manager := get_node_or_null("/root/TimeManager")
	var direction: int = manager.direction if manager != null else TimeWorld.FORWARD
	# A long hold of Shift rewinds several frames a tick (D62).
	var frames: int = manager.rewind_frames if manager != null else 1
	last_step = world.tick(direction, temporal_objects(), _player_rect(), frames)
	_tell_plates(direction)
	_tell_live_sources(direction)
	_tell_world_clock()


## Time plates (group `plate`, level 04) feel the player's step and the
## wheels of a minecart (group `minecart`, D168) after the world moved, by the
## direction of this tick, and change their shutters through `apply_change`.
func _tell_plates(direction: int) -> void:
	var room := get_parent()
	if room == null:
		return
	var rect := _player_rect()
	var wheels: Array = []
	for cart in get_tree().get_nodes_in_group("minecart"):
		if room.is_ancestor_of(cart) and cart.has_method("wheel_rect"):
			wheels.append(cart.call("wheel_rect"))
	for node in get_tree().get_nodes_in_group("plate"):
		if not room.is_ancestor_of(node) or not node.has_method("sense"):
			continue
		if node is TimePlate:
			node.call("sense", self, direction, rect, wheels)
		else:
			node.call("sense", self, direction, rect)


## Live sources (group `live`, reverse items) act after the world moved, by
## the direction of this tick (docs/architecture.md, section 2.5). They get
## this node as an argument and keep no reference to it.
func _tell_live_sources(direction: int) -> void:
	var room := get_parent()
	if room == null:
		return
	for node in get_tree().get_nodes_in_group("live"):
		if room.is_ancestor_of(node) and node.has_method("act"):
			node.call("act", self, direction)


## The frame the world shows now.
func cursor() -> int:
	return world.timeline.cursor()


## The world tick the room shows now: frames plus the still ticks between them
## (D56). The clock of decoration and of the ticks stored in states.
func world_tick() -> int:
	return world.timeline.world_tick()


## Decoration that is drawn from world time (the look of water, task 2.3А)
## joins the group `world_clock` and gets the world tick every tick (it keeps
## running while the room stands still, D56), and whether this tick ran at the
## head, recorded or still. Nothing in that group is recorded.
func _tell_world_clock() -> void:
	var room := get_parent()
	if room == null:
		return
	var recorded := TimeWorld.at_head_step(last_step)
	for node in get_tree().get_nodes_in_group("world_clock"):
		if room.is_ancestor_of(node) and node.has_method("on_world_tick"):
			node.call("on_world_tick", world.timeline.world_tick(), recorded)


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
		if bool(ch.get("rewrite_all", false)):
			_set_without_branch(id, ch.get("state", {}) as Dictionary)
			continue
		apply_change(id, ch.get("state", {}) as Dictionary)
		if bool(ch.get("rewrite_past", false)):
			world.rewrite_past(temporal_objects(), id)


## A change that is no interference (`rewrite_all`, D175): `partial` is merged
## over the object's present state, and that state is written into all its
## frames, past and future; the room's history is not cut.
func _set_without_branch(id: String, partial: Dictionary) -> void:
	for obj: Variant in temporal_objects():
		if obj is Object and (obj as Object).has_method("capture_state") and str((obj as Object).get("object_id")) == id:
			var state: Dictionary = ((obj as Object).call("capture_state") as Dictionary).duplicate(true)
			state.merge(partial.duplicate(true), true)
			(obj as Object).call("restore_state", state)
			world.rewrite_all(temporal_objects(), id)
			# What depends on the item follows it along the recorded future.
			if (obj as Object).has_method("after_rewrite"):
				(obj as Object).call("after_rewrite", world.timeline)
			return


## A player's change to one object: `partial` is merged over the object's
## present state and goes through `player_action` (interference left of the
## head, ordinary recording at it).
func apply_change(id: String, partial: Dictionary) -> bool:
	var state := partial.duplicate(true)
	for obj: Variant in temporal_objects():
		if obj is Object and (obj as Object).has_method("capture_state") and str((obj as Object).get("object_id")) == id:
			var full_state: Dictionary = ((obj as Object).call("capture_state") as Dictionary).duplicate(true)
			full_state.merge(state, true)
			state = full_state
			break
	return player_action(id, state)


## The frames left of the cursor where `id` had `flag` set take its present
## state (a torch put back on its stand, D177).
func rewrite_past_where(id: String, flag: String) -> bool:
	return world.rewrite_past_where(temporal_objects(), id, flag)


## Back to the room as it was loaded, with a fresh history and its prelude
## run again: the player comes back into the same past.
func reset() -> void:
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("carried"):
		if room != null and room.is_ancestor_of(node) and node.has_method("forget_hands"):
			node.call("forget_hands")
	for node in get_tree().get_nodes_in_group("plate"):
		if room != null and room.is_ancestor_of(node) and node.has_method("forget_step"):
			node.call("forget_step")
	# The minecart is out of time (D168): a reset parks it, nothing rewinds it.
	for node in get_tree().get_nodes_in_group("minecart"):
		if room != null and room.is_ancestor_of(node) and node.has_method("reset_ride"):
			node.call("reset_ride")
	var objects := temporal_objects()
	_recorder.restore(_initial, objects)
	world.start(objects)
	world.run_prelude(objects, _prelude_ticks, _prelude_events)
	was_reset.emit()


## Hands every object its settings from `objects` of the level's entry
## (`object_id -> settings`), before the room's first state is captured.
func _apply_object_settings(objects: Array) -> void:
	for object: Variant in objects:
		var settings: Variant = _object_settings.get(str(object.get("object_id")))
		if settings is Dictionary and object.has_method("apply_settings"):
			object.call("apply_settings", settings)


func _read_prelude() -> void:
	var time_data := Content.time()
	# World seconds (D96): the prelude runs as long as the faster world needs
	# to reach the same picture.
	var per_second := Content.world_ticks_per_second(time_data)
	var room := get_parent()
	var entry := Content.level_for_scene(room.scene_file_path if room != null else "")
	var settings: Variant = entry.get("objects", {})
	_object_settings = settings if settings is Dictionary else {}
	prelude_seconds = float(entry.get("prelude_seconds", time_data.get("default_prelude_seconds", 0)))
	_prelude_ticks = int(round(prelude_seconds * per_second))
	_prelude_events = TimeWorld.prelude_events_from_data(entry.get("prelude_events", []), per_second)


func _player_rect() -> Rect2:
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("body_rect"):
		return player.call("body_rect")
	return Rect2()


func _on_direction_changed(direction: int) -> void:
	for object in temporal_objects():
		if object.has_method("on_time_direction_changed"):
			object.call("on_time_direction_changed", direction)
