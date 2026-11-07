class_name TemporalRecorder
extends RefCounted
## Turns the states of temporal objects into one frame and back.
##
## A temporal object is found by duck typing (the door is an AnimatableBody2D,
## the button an Area2D, so there is no common base class). It needs a unique
## `object_id`, `capture_state() -> Dictionary` and `restore_state(state)`.
## The recorder keeps no reference to the objects: they come as an argument.

const REQUIRED_METHODS: Array[String] = ["capture_state", "restore_state"]


## One frame: `object_id -> capture_state()` for every valid object.
func capture(objects: Array) -> Dictionary:
	var frame := {}
	for object in objects:
		if not _is_valid(object):
			continue
		frame[str(object.get("object_id"))] = (object.call("capture_state") as Dictionary).duplicate(true)
	return frame


## Gives every object its state from the frame. An object that is not in the
## frame (it appeared later) is left as it is.
func restore(frame: Dictionary, objects: Array) -> void:
	for object in objects:
		if not _is_valid(object):
			continue
		var id := str(object.get("object_id"))
		if frame.has(id):
			object.call("restore_state", (frame[id] as Dictionary).duplicate(true))


## Problems that would make recording unsafe: a missing method, an empty or a
## repeated `object_id`. An empty list means the objects are fine.
func validate(objects: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for object in objects:
		if not object is Object:
			errors.append("temporal object is not an Object")
			continue
		for method in REQUIRED_METHODS:
			if not object.has_method(method):
				errors.append("temporal object has no %s()" % method)
		var id := str(object.get("object_id")) if object.get("object_id") != null else ""
		if id.is_empty():
			errors.append("temporal object has an empty object_id")
		elif seen.has(id):
			errors.append("object_id '%s' is used twice" % id)
		else:
			seen[id] = true
	return errors


func _is_valid(object: Variant) -> bool:
	if not object is Object:
		return false
	for method in REQUIRED_METHODS:
		if not object.has_method(method):
			return false
	var id: Variant = object.get("object_id")
	return id != null and not str(id).is_empty()
