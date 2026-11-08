extends RefCounted
## Tests of `TimeWorld`, the rules of section 2 of docs/architecture.md:
## rewind restores frames, the start pins the world, releasing Shift replays
## the recorded future (rule «A») without simulating, an interference cuts the
## future, the world waits instead of crushing the player. Run by test_runner.gd.

const BACK := TimeWorld.BACKWARD
const FWD := TimeWorld.FORWARD
const PLAYER := Rect2(0, 0, 44, 92)

var failures: Array[String] = []


func _init(_tree: SceneTree) -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## A fake recorded object: a counter that grows by one per simulated tick.
class Counter extends RefCounted:
	var object_id := "counter"
	var value := 0
	var simulated := 0
	## The value at which the object would crush the player; -1 never.
	var crush_at := -1

	func capture_state() -> Dictionary:
		return {"value": value}

	func restore_state(state: Dictionary) -> void:
		value = int(state["value"])

	func simulate_tick(_tick: int) -> void:
		value += 1
		simulated += 1

	func on_time_direction_changed(_direction: int) -> void:
		pass

	func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
		return player_rect.has_area() and int(state["value"]) == crush_at


func _world() -> TimeWorld:
	return TimeWorld.new(Timeline.new(1200))


func _run(world: TimeWorld, objects: Array, direction: int, ticks: int, player := Rect2()) -> Array:
	var steps := []
	for i in ticks:
		steps.append(world.tick(direction, objects, player))
	return steps


func test_rewind_goes_back_frame_by_frame_and_pins_at_start() -> void:
	var world := _world()
	var counter := Counter.new()
	var objects := [counter]
	check(world.tick(FWD, objects) == TimeWorld.Step.STARTED, "the first tick must record frame 0")
	_run(world, objects, FWD, 10)
	check(counter.value == 10, "10 forward ticks must give 10, got %d" % counter.value)
	for expected in range(9, -1, -1):
		check(world.tick(BACK, objects) == TimeWorld.Step.REWOUND, "a back tick above the start must rewind")
		check(counter.value == expected, "rewind must show %d, got %d" % [expected, counter.value])
	var pinned := _run(world, objects, BACK, 30)
	check(pinned.all(func(s: int) -> bool: return s == TimeWorld.Step.PINNED), "at frame 0 the world must stand still")
	check(counter.value == 0 and world.timeline.cursor() == 0, "pinned world must stay at frame 0")
	check(world.timeline.head() == 10, "rewinding must not erase the future")


func test_release_replays_the_recorded_future_without_simulating() -> void:
	var world := _world()
	var counter := Counter.new()
	var objects := [counter]
	_run(world, objects, FWD, 21)
	var simulated := counter.simulated
	_run(world, objects, BACK, 8)
	check(counter.value == 12, "8 back ticks from 20 must show 12, got %d" % counter.value)
	var steps := _run(world, objects, FWD, 8)
	check(steps.all(func(s: int) -> bool: return s == TimeWorld.Step.REPLAYED), "forward left of the head must replay")
	check(counter.value == 20, "replay must bring back the recorded 20, got %d" % counter.value)
	check(counter.simulated == simulated, "replay must not simulate")
	check(world.tick(FWD, objects) == TimeWorld.Step.RECORDED, "at the head the world simulates again")
	check(counter.value == 21, "simulation must continue from the head")


func test_back_and_forth_twice_changes_nothing() -> void:
	var world := _world()
	var counter := Counter.new()
	var objects := [counter]
	_run(world, objects, FWD, 61)
	var before := _history(world)
	for pass_number in 2:
		_run(world, objects, BACK, 80)
		_run(world, objects, FWD, 60)
	check(_history(world) == before, "two rewinds and replays without interference must leave the history as it was")
	check(counter.value == 60 and world.timeline.at_head(), "the world must end at the head with the same state")


func test_interference_cuts_the_future() -> void:
	var world := _world()
	var counter := Counter.new()
	var objects := [counter]
	_run(world, objects, FWD, 11)
	_run(world, objects, BACK, 4)
	check(counter.value == 6, "4 back ticks from 10 must show 6")
	check(world.player_action(objects, "counter", {"value": 100}), "an action on a known object must apply")
	check(world.timeline.head() == 6 and world.timeline.at_head(), "the cursor must become the head")
	check(world.timeline.current() == {"counter": {"value": 100}}, "the new state must be written at the cursor")
	world.tick(BACK, objects)
	check(counter.value == 5, "rewinding further must obey the frames on the left, got %d" % counter.value)
	world.tick(FWD, objects)
	check(counter.value == 100, "forward again must show the changed present, got %d" % counter.value)
	var seen := []
	for i in 10:
		world.tick(FWD, objects)
		seen.append(counter.value)
	check(seen == [101, 102, 103, 104, 105, 106, 107, 108, 109, 110], "the new branch must simulate from the change, got %s" % [seen])
	check(not world.player_action(objects, "nobody", {"value": 1}), "an action on an unknown object must do nothing")


func test_interference_at_the_head_is_ordinary_recording() -> void:
	var world := _world()
	var counter := Counter.new()
	var objects := [counter]
	_run(world, objects, FWD, 6)
	world.live_action(objects, "counter", {"value": 50})
	check(world.timeline.head() == 5 and world.timeline.size() == 6, "an action at the head must not add or cut frames")
	world.tick(FWD, objects)
	check(counter.value == 51 and world.timeline.head() == 6, "recording must continue from the changed state")


func test_world_waits_instead_of_crushing_the_player() -> void:
	var world := _world()
	var counter := Counter.new()
	counter.crush_at = 3
	var objects := [counter]
	_run(world, objects, FWD, 3, PLAYER)
	var steps := _run(world, objects, FWD, 5, PLAYER)
	check(steps.all(func(s: int) -> bool: return s == TimeWorld.Step.WAITED), "the world must wait while the next frame would crush")
	check(counter.value == 2 and world.timeline.head() == 2, "waiting must keep the last safe frame, got %d" % counter.value)
	_run(world, objects, FWD, 3)
	check(counter.value == 5, "without the player in the way the world goes on, got %d" % counter.value)
	steps = _run(world, objects, BACK, 3, PLAYER)
	check(steps == [TimeWorld.Step.REWOUND, TimeWorld.Step.WAITED, TimeWorld.Step.WAITED],
		"rewinding must stop before the crushing frame, got %s" % [steps])
	check(counter.value == 4 and world.timeline.cursor() == 4, "the cursor must wait on the safe frame")
	_run(world, objects, BACK, 2)
	_run(world, objects, FWD, 2, PLAYER)
	check(counter.value == 2, "replay must wait before the crushing frame too, got %d" % counter.value)


func test_prelude_records_without_the_player() -> void:
	var world := _world()
	var counter := Counter.new()
	counter.crush_at = 3
	world.run_prelude([counter], 120)
	check(world.timeline.head() == 119 and counter.value == 119, "a 120-tick prelude must record 120 frames")
	_run(world, [counter], BACK, 200)
	check(counter.value == 0, "the prelude must be rewindable to its first frame")


func test_replace_current_only_at_the_head() -> void:
	var timeline := Timeline.new(10)
	check(not timeline.replace_current({"a": 1}), "an empty history has nothing to replace")
	for i in 4:
		timeline.record({"a": i})
	timeline.step_back()
	check(not timeline.replace_current({"a": 9}), "left of the head the past is changed only after branch()")
	timeline.branch()
	check(timeline.replace_current({"a": 9}) and timeline.current() == {"a": 9}, "after branch() the cursor frame is rewritten")


func _history(world: TimeWorld) -> Array:
	var cursor := world.timeline.cursor()
	var frames := []
	while world.timeline.step_back():
		pass
	frames.append(world.timeline.current())
	while world.timeline.step_forward():
		frames.append(world.timeline.current())
	while world.timeline.cursor() > cursor:
		world.timeline.step_back()
	return frames
