class_name LevelProgress
extends RefCounted
## Which levels the player has passed, and which of them the menu opens
## (tasks 4.2, 4.3). Plain data: LevelLoader keeps one, saves it and asks it.
## `order` is the list of level ids in the order of play (`levels.json`).

## Passed level ids (the values are always true).
var passed: Dictionary = {}


func mark_passed(id: String) -> void:
	if not id.is_empty():
		passed[id] = true


func is_passed(id: String) -> bool:
	return passed.has(id)


func clear() -> void:
	passed.clear()


## True when the menu may start this level. Without `in_order` every level is
## open (playtests); with it the first level, every passed one and the one
## right after a passed one are open.
func is_open(id: String, order: Array, in_order: bool) -> bool:
	var at := order.find(id)
	if at < 0:
		return false
	if not in_order or at == 0 or is_passed(id):
		return true
	return is_passed(str(order[at - 1]))


## The level «Start» goes to: the first one in the order not passed yet, or
## the first level when all are passed (or the list is empty: "").
func first_unpassed(order: Array) -> String:
	for id: Variant in order:
		if not is_passed(str(id)):
			return str(id)
	return str(order[0]) if not order.is_empty() else ""


## The level after `id` in the order, or "" after the last one.
static func next_after(id: String, order: Array) -> String:
	var at := order.find(id)
	if at < 0 or at + 1 >= order.size():
		return ""
	return str(order[at + 1])


func to_dict() -> Dictionary:
	return {"passed": passed.keys()}


func from_dict(data: Variant) -> void:
	passed.clear()
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("passed", [])
	if list is Array:
		for id: Variant in list:
			mark_passed(str(id))
