extends RefCounted
## Tests of `Timeline` and `TemporalRecorder`: record, rewind to the start and
## replay give the same frames (determinism), the start of the history holds,
## the ring drops the oldest frames, a branch cuts the future. Run by
## test_runner.gd.

var failures: Array[String] = []


func _init(_tree: SceneTree) -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## A fake temporal object: only what the recorder needs.
class FakeObject extends RefCounted:
	var object_id := ""
	var value := 0

	func _init(id: String, start: int) -> void:
		object_id = id
		value = start

	func capture_state() -> Dictionary:
		return {"value": value}

	func restore_state(state: Dictionary) -> void:
		value = int(state["value"])


## An object with an id but without the methods.
class HalfObject extends RefCounted:
	var object_id := "half"


func _frame(i: int) -> Dictionary:
	return {"door": {"open": i * 3, "locked": i % 2 == 0}, "platform": {"position": Vector2(i, 2 * i), "phase": i}}


func _filled(count: int, capacity: int = 1200) -> Timeline:
	var timeline := Timeline.new(capacity)
	for i in count:
		timeline.record(_frame(i))
	return timeline


func test_capacity_comes_from_time_json() -> void:
	var timeline := Timeline.from_config(Content.time())
	check(timeline.capacity() == 1200, "20 s at 60 ticks must hold 1200 frames, got %d" % timeline.capacity())
	check(Timeline.capacity_for({"history_seconds": 20, "physics_ticks_per_second": 60, "snapshot_every_ticks": 4}) == 300,
		"every 4th tick must hold 300 frames")
	check(Timeline.capacity_for({"history_seconds": 30, "physics_ticks_per_second": 60, "snapshot_every_ticks": 1}) == 1800,
		"changing history_seconds must change the capacity")
	check(Timeline.capacity_for({}) >= Timeline.MIN_CAPACITY, "empty data must still give a usable capacity")


func test_record_rewind_replay_is_deterministic() -> void:
	var count := 300
	var timeline := _filled(count)
	check(timeline.size() == count and timeline.at_head(), "after %d records the cursor must be at the head" % count)
	for round_number in 2:
		var back: Array[Dictionary] = [timeline.current()]
		while timeline.step_back():
			back.append(timeline.current())
		check(back.size() == count, "round %d: rewinding must visit %d frames, got %d" % [round_number, count, back.size()])
		check(timeline.at_start(), "round %d: after rewinding the cursor must be at the start" % round_number)
		for i in back.size():
			var expected := _frame(count - 1 - i)
			if back[i] != expected:
				failures.append("round %d: rewound frame %d differs from the recorded one" % [round_number, count - 1 - i])
				break
		var forward: Array[Dictionary] = [timeline.current()]
		while timeline.step_forward():
			forward.append(timeline.current())
		check(forward.size() == count, "round %d: replay must visit %d frames, got %d" % [round_number, count, forward.size()])
		check(timeline.at_head(), "round %d: after replay the cursor must be at the head" % round_number)
		for i in forward.size():
			if forward[i] != _frame(i):
				failures.append("round %d: replayed frame %d differs from the recorded one" % [round_number, i])
				break


func test_start_of_history_holds_the_first_frame() -> void:
	var empty := Timeline.new(10)
	check(not empty.step_back(), "step_back on an empty history must return false")
	check(not empty.step_forward(), "step_forward on an empty history must return false")
	check(empty.current() == {}, "an empty history must give an empty frame")
	check(empty.at_head() and empty.at_start() and empty.is_empty(), "an empty history is at its head and its start")
	var timeline := _filled(5)
	while timeline.step_back():
		pass
	for i in 10:
		check(not timeline.step_back(), "step_back at the start must return false")
	check(timeline.cursor() == timeline.first(), "the cursor must stay on the first frame")
	check(timeline.current() == _frame(0), "the world must stay on the first frame past the start")


func test_overflow_drops_the_oldest_frames() -> void:
	var timeline := _filled(25, 10)
	check(timeline.size() == 10, "a full ring must hold exactly its capacity, got %d" % timeline.size())
	check(timeline.first() == 15 and timeline.head() == 24, "the ring must keep frames 15..24, got %d..%d" % [timeline.first(), timeline.head()])
	var visited := 1
	var oldest := timeline.current()
	while timeline.step_back():
		visited += 1
		oldest = timeline.current()
	check(visited == 10, "rewinding must visit 10 frames, got %d" % visited)
	check(oldest == _frame(15), "the oldest kept frame must be frame 15")
	check(timeline.cursor() == 15, "the cursor must not go left of the oldest kept frame")
	var newest := _filled(25, 10)
	check(newest.current() == _frame(24), "the newest frame must be frame 24")


func test_record_left_of_the_head_is_refused() -> void:
	var timeline := _filled(10)
	timeline.step_back()
	timeline.step_back()
	var cursor_before := timeline.cursor()
	check(not timeline.record(_frame(99)), "record left of the head must return false")
	check(timeline.cursor() == cursor_before and timeline.head() == 9 and timeline.size() == 10,
		"a refused record must change nothing")
	check(timeline.current() == _frame(7), "the frame at the cursor must stay as recorded")


func test_branch_cuts_the_future() -> void:
	var timeline := _filled(20)
	for i in 5:
		timeline.step_back()
	check(timeline.cursor() == 14, "the cursor must be at frame 14 after five steps back")
	timeline.branch()
	check(timeline.head() == 14 and timeline.at_head(), "branch must make the cursor the head")
	check(timeline.size() == 15, "branch must keep frames 0..14, got %d" % timeline.size())
	check(not timeline.step_forward(), "the cut future must not be replayed")
	check(timeline.record({"door": {"open": -1}}), "recording must continue after a branch")
	check(timeline.head() == 15 and timeline.current() == {"door": {"open": -1}}, "the new frame must follow the cut one")
	timeline.step_back()
	check(timeline.current() == _frame(14), "going back must show the old past")
	timeline.step_forward()
	check(timeline.current() == {"door": {"open": -1}}, "going forward must show the new branch, not the old future")
	timeline.step_back()
	timeline.step_back()
	timeline.step_back()
	for i in 20:
		timeline.step_forward()
	check(timeline.current() == {"door": {"open": -1}}, "the old future must never come back")


func test_branch_at_the_head_and_on_an_empty_history_is_harmless() -> void:
	var timeline := _filled(3)
	timeline.branch()
	check(timeline.size() == 3 and timeline.head() == 2, "branch at the head must change nothing")
	var empty := Timeline.new(5)
	empty.branch()
	check(empty.is_empty(), "branch on an empty history must keep it empty")


func test_frames_are_copies() -> void:
	var timeline := Timeline.new(10)
	var frame := {"door": {"open": 5}}
	timeline.record(frame)
	frame["door"]["open"] = 999
	check(timeline.current() == {"door": {"open": 5}}, "changing the recorded dictionary must not change the history")
	var taken := timeline.current()
	taken["door"]["open"] = 777
	check(timeline.current() == {"door": {"open": 5}}, "changing a returned frame must not change the history")


func test_clear_forgets_everything() -> void:
	var timeline := _filled(8)
	timeline.step_back()
	timeline.clear()
	check(timeline.is_empty() and timeline.head() == -1 and timeline.cursor() == -1, "clear must empty the history")
	check(timeline.record(_frame(0)) and timeline.current() == _frame(0), "recording must work after clear")


func test_recorder_captures_and_restores_a_frame() -> void:
	var recorder := TemporalRecorder.new()
	var door := FakeObject.new("door", 10)
	var platform := FakeObject.new("platform", 20)
	var objects: Array = [door, platform]
	var frame := recorder.capture(objects)
	check(frame == {"door": {"value": 10}, "platform": {"value": 20}}, "capture must key states by object_id, got %s" % [frame])
	door.value = 11
	platform.value = 21
	recorder.restore(frame, objects)
	check(door.value == 10 and platform.value == 20, "restore must bring every object back")
	var late := FakeObject.new("late", 5)
	recorder.restore(frame, [late])
	check(late.value == 5, "an object that is not in the frame must stay as it is")


func test_recorder_with_a_timeline_replays_objects() -> void:
	var recorder := TemporalRecorder.new()
	var timeline := Timeline.new(100)
	var door := FakeObject.new("door", 0)
	var objects: Array = [door]
	for i in 30:
		door.value = i * 2
		timeline.record(recorder.capture(objects))
	for i in 10:
		timeline.step_back()
		recorder.restore(timeline.current(), objects)
	check(door.value == 38, "ten frames back the door must be at 38, got %d" % door.value)
	for i in 10:
		timeline.step_forward()
		recorder.restore(timeline.current(), objects)
	check(door.value == 58, "back at the head the door must be at 58, got %d" % door.value)


func test_recorder_validates_objects() -> void:
	var recorder := TemporalRecorder.new()
	check(recorder.validate([FakeObject.new("a", 0), FakeObject.new("b", 0)]).is_empty(), "good objects must pass")
	check(not recorder.validate([FakeObject.new("a", 0), FakeObject.new("a", 1)]).is_empty(), "a repeated object_id must be reported")
	check(not recorder.validate([FakeObject.new("", 0)]).is_empty(), "an empty object_id must be reported")
	check(not recorder.validate([HalfObject.new()]).is_empty(), "missing methods must be reported")
	var frame := recorder.capture([HalfObject.new(), FakeObject.new("ok", 3)])
	check(frame == {"ok": {"value": 3}}, "capture must skip an invalid object instead of failing, got %s" % [frame])
