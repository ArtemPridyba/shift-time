class_name InteractionSystem
extends RefCounted
## Pure-logic interaction helper (no nodes). Given a list of candidates with
## their world position and interaction radius, `get_nearest` returns the id
## of the closest one that is within reach of the player.
##
## Usage (player.gd):
##   var items := room_time.interaction_candidates()  # [{id, position, radius}]
##   var id := InteractionSystem.get_nearest(player_position, items)
##   if id != "":
##       room_time.player_interact(id)


## Returns the id of the closest candidate whose radius covers `player_pos`,
## or "" if none qualify. `candidates` is an Array of Dictionaries with
## keys "id" (String), "position" (Vector2), "radius" (float).
## A candidate with `"fallback": true` (the item in the player's hands, which
## E drops) counts only when no other candidate is within reach.
static func get_nearest(player_pos: Vector2, candidates: Array) -> String:
	var best_id := ""
	var best_dist := INF
	var fallback_id := ""
	for item: Variant in candidates:
		var d: Variant = item
		if not d is Dictionary:
			continue
		var pos: Vector2 = (d as Dictionary).get("position", Vector2.ZERO)
		var radius: float = float((d as Dictionary).get("radius", 0))
		var dist := player_pos.distance_to(pos)
		if dist > radius:
			continue
		if bool((d as Dictionary).get("fallback", false)):
			if fallback_id == "":
				fallback_id = str((d as Dictionary).get("id", ""))
			continue
		if dist < best_dist:
			best_dist = dist
			best_id = str((d as Dictionary).get("id", ""))
	return best_id if best_id != "" else fallback_id


## The targets of a control: `target_ids` plus the older single `target_id`,
## without empty names and duplicates, in order.
static func target_list(target_id: String, target_ids: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for id in [target_id] + Array(target_ids):
		if str(id) != "" and not result.has(str(id)):
			result.append(str(id))
	return result


## The changes that set `powered` on every target found among `objects`, each
## merged into the target's current state. Unknown targets are skipped.
static func power_changes(targets: PackedStringArray, objects: Array, powered: bool) -> Array:
	var changes: Array = []
	for id in targets:
		for obj: Variant in objects:
			if obj is Object and (obj as Object).has_method("capture_state") and str((obj as Object).get("object_id")) == id:
				var state := ((obj as Object).call("capture_state") as Dictionary).duplicate(true)
				state["powered"] = powered
				changes.append({"id": id, "state": state})
				break
	return changes


## The interaction point a key hint shows (task 4.3): the closest candidate
## in reach that is no fallback (the drop of an item in the hands is not shown;
## E puts it down anywhere), or {} when none is in reach.
static func hint_target(player_pos: Vector2, candidates: Array) -> Dictionary:
	var best := {}
	var best_dist := INF
	for item: Variant in candidates:
		if not item is Dictionary or bool((item as Dictionary).get("fallback", false)):
			continue
		var d := item as Dictionary
		var dist := player_pos.distance_to(d.get("position", Vector2.ZERO) as Vector2)
		if dist <= float(d.get("radius", 0)) and dist < best_dist:
			best_dist = dist
			best = d
	return best


## The key alpha a hint moves to this frame: towards 1 while shown, towards 0
## while hidden, in `fade_in` / `fade_out` seconds for the whole way.
static func fade(alpha: float, shown: bool, delta: float, fade_in: float, fade_out: float) -> float:
	var seconds := fade_in if shown else fade_out
	var step := delta / seconds if seconds > 0.0 else 1.0
	return move_toward(alpha, 1.0 if shown else 0.0, step)
