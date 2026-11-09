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
static func get_nearest(player_pos: Vector2, candidates: Array) -> String:
	var best_id := ""
	var best_dist := INF
	for item: Variant in candidates:
		var d: Variant = item
		if not d is Dictionary:
			continue
		var pos: Vector2 = (d as Dictionary).get("position", Vector2.ZERO)
		var radius: float = float((d as Dictionary).get("radius", 0))
		var dist := player_pos.distance_to(pos)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			best_id = str((d as Dictionary).get("id", ""))
	return best_id
