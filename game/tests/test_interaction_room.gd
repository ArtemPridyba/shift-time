extends RefCounted
## The real objects wired in the room `test_room_buttons.tscn`: the player
## presses the button, the door opens and stays open, Shift rewinds it, the
## lever toggles it. Unlike test_interaction.gd this uses the real Door,
## PushButton, Lever and RoomTime, not fakes. Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room_buttons.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_button_opens_the_door_and_shift_rewinds_it() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var button: PushButton = room.get_node("PushButton")
	var player: Player = room.get_node("Player")
	await _ticks(10)
	check(door.open == 0 and not button.pressed, "the door must start closed and the button unpressed")
	player.respawn(button.global_position + Vector2(0, 12))
	time.player_interact(player.global_position)
	await _ticks(60)
	check(button.pressed, "pressing the button must press it")
	check(door.powered and door.open > 0, "the pressed button must power and open the door")
	var opened := door.open
	await _ticks(120)
	check(door.open >= opened, "the door must stay open, not cycle shut by itself")
	Input.action_press("rewind")
	await _ticks(200)
	check(time.last_step == TimeWorld.Step.PINNED or time.last_step == TimeWorld.Step.REWOUND, "Shift must rewind the room")
	check(door.open == 0 and not button.pressed, "rewound to before the press the door is closed and the button unpressed")
	Input.action_release("rewind")
	await _ticks(60)
	check(button.pressed and door.open > 0, "releasing Shift must replay the press (rule A)")
	await _free_room(room)


func test_lever_toggles_the_door() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var lever: Lever = room.get_node("Lever")
	var player: Player = room.get_node("Player")
	await _ticks(5)
	player.respawn(lever.global_position)
	time.player_interact(player.global_position)
	await _ticks(90)
	check(lever.on and door.powered and door.open > 0, "the lever on must open the door")
	time.player_interact(player.global_position)
	await _ticks(200)
	check(not lever.on and not door.powered and door.open == 0, "the lever off must close the door")
	await _free_room(room)


func test_interaction_during_rewind_cuts_the_future() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var button: PushButton = room.get_node("PushButton")
	var player: Player = room.get_node("Player")
	await _ticks(120)
	var head := time.world.timeline.head()
	player.respawn(button.global_position + Vector2(0, 12))
	Input.action_press("rewind")
	await _ticks(60)
	time.player_interact(player.global_position)
	Input.action_release("rewind")
	await _ticks(2)
	check(time.world.timeline.head() < head, "pressing in the past must cut the recorded future")
	await _ticks(90)
	check(button.pressed and door.open > 0, "the press made in the past must stay and open the door")
	await _free_room(room)


## Rule «A» on the real lever and door: rewind to before the lever was pulled,
## release Shift without touching anything, and the room replays the recorded
## future frame by frame: the lever flips on by itself, the door opens again.
func test_release_without_interference_replays_the_lever_and_the_door() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var lever: Lever = room.get_node("Lever")
	var player: Player = room.get_node("Player")
	await _ticks(5)
	player.respawn(lever.global_position)
	time.player_interact(player.global_position)
	var recorded := {}
	await _sample(time, 120, recorded)
	var head := time.world.timeline.head()
	Input.action_press("rewind")
	await _ticks(200)
	check(time.world.timeline.at_start(), "200 ticks of Shift must rewind the room to its first frame")
	check(not lever.on and door.open == 0, "rewound to before the pull the lever is off and the door closed")
	Input.action_release("rewind")
	var replayed := {}
	await _sample(time, 130, replayed)
	check(time.world.timeline.head() >= head, "without interference nothing of the recorded future is cut")
	var common := 0
	for k: int in recorded:
		if replayed.has(k):
			common += 1
			if replayed[k] != recorded[k]:
				check(false, "frame %d must replay exactly as it was recorded: %s, then %s" % [k, recorded[k], replayed[k]])
				break
	check(common >= 100, "the replay must go over the recorded frames (got %d)" % common)
	check(lever.on and door.powered and door.open > 0, "the lever must flip on by itself and the door open again")
	await _free_room(room)


## An interference in the past: while the door is opening, rewind a little,
## pull the lever off under Shift. The future is cut at the cursor, the old
## sequence (the door opening fully) never plays again, and the new branch is
## recorded without a gap from the point of interference.
func test_lever_pulled_in_the_past_drops_the_old_future() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var lever: Lever = room.get_node("Lever")
	var player: Player = room.get_node("Player")
	var timeline := time.world.timeline
	await _ticks(5)
	player.respawn(lever.global_position)
	time.player_interact(player.global_position)
	var old_future := {}
	await _sample(time, 240, old_future)
	check(door.open == Door.OPEN_MAX, "the lever on must open the door fully")
	Input.action_press("rewind")
	await _ticks(120)
	check(lever.on and door.open > 0 and door.open < Door.OPEN_MAX, "rewound into the opening: the lever is on, the door half open")
	var cut := timeline.cursor()
	time.player_interact(player.global_position)
	Input.action_release("rewind")
	check(timeline.head() == cut and timeline.at_head(), "pulling the lever in the past must cut the future at the cursor")
	var present := timeline.current()
	check(not bool(present["lever"]["on"]) and not bool(present["door"]["powered"]),
		"the frame at the cursor must hold the lever off and the door unpowered")
	var branch := {cut: present}
	await _sample(time, 240, branch)
	check(not lever.on and door.open == 0, "the new branch must close the door")
	var step := _door_step()
	for k in range(cut, timeline.head()):
		if not branch.has(k) or not branch.has(k + 1):
			check(false, "the new branch must be recorded without a gap (frame %d missing)" % (k if not branch.has(k) else k + 1))
			break
		var jump := absi(int(branch[k + 1]["door"]["open"]) - int(branch[k]["door"]["open"]))
		if jump > step:
			check(false, "the door must move at most %d per tick, jumped %d at frame %d" % [step, jump, k])
			break
	for k: int in branch:
		if k > cut and old_future.has(k):
			var old_frame: Dictionary = old_future[k]
			var new_frame: Dictionary = branch[k]
			if old_frame["lever"] == new_frame["lever"] or old_frame["door"] == new_frame["door"]:
				check(false, "frame %d must not replay the old future" % k)
				break
	await _free_room(room)


## The team's answer (13.11.2026, rule «A»): a press made under Shift becomes
## part of the past. Keep holding Shift and the room rewinds over it, the button
## pops up again; release and the replay presses it at the same frame, then the
## door opens at the head.
func test_press_under_shift_then_keep_rewinding_replays_the_press() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var button: PushButton = room.get_node("PushButton")
	var player: Player = room.get_node("Player")
	await _ticks(120)
	player.respawn(button.global_position + Vector2(0, 12))
	Input.action_press("rewind")
	await _ticks(60)
	var pressed_at := time.world.timeline.cursor()
	time.player_interact(player.global_position)
	check(button.pressed and door.powered, "the press under Shift must press the button at once")
	await _ticks(30)
	check(time.world.timeline.cursor() < pressed_at, "holding Shift must keep rewinding past the press")
	check(not button.pressed and door.open == 0, "rewound past the press the button is up again")
	Input.action_release("rewind")
	await _ticks(90)
	check(time.world.timeline.head() > pressed_at, "the room must go on recording after the replayed press")
	check(button.pressed and door.open > 0, "the replay must press the button again and open the door")
	await _free_room(room)


## An interference at frame 0, where the world stands pinned under Shift,
## drops the whole recorded future: the room goes on from the new state.
func test_press_at_frame_zero_drops_the_whole_future() -> void:
	var room := await _load_room()
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node("Door")
	var button: PushButton = room.get_node("PushButton")
	var player: Player = room.get_node("Player")
	var timeline := time.world.timeline
	await _ticks(60)
	player.respawn(button.global_position + Vector2(0, 12))
	Input.action_press("rewind")
	await _ticks(100)
	check(timeline.at_start() and time.last_step == TimeWorld.Step.PINNED, "the world must stand pinned at frame 0")
	time.player_interact(player.global_position)
	check(timeline.head() == timeline.first() and timeline.size() == 1, "a press at frame 0 must leave one frame of history")
	Input.action_release("rewind")
	await _ticks(60)
	check(button.pressed and door.open > 0, "the room must go on from the press: the door opens")
	await _free_room(room)


## After every tick records what the objects show, by the cursor's frame number.
func _sample(time: RoomTime, count: int, into: Dictionary) -> void:
	var recorder := TemporalRecorder.new()
	for i in count:
		await _tree.physics_frame
		into[time.world.timeline.cursor()] = recorder.capture(time.temporal_objects())


## How far a powered door moves in one tick, from the same data the door reads.
func _door_step() -> int:
	var ticks := float(Content.time().get("physics_ticks_per_second", 60))
	var open_ticks := maxi(int(round(float(Content.objects().get("door", {}).get("open_seconds", 3)) * ticks)), 1)
	return int(round(float(Door.OPEN_MAX) / float(open_ticks)))


func _load_room() -> Node:
	Input.action_release("rewind")
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free_room(room: Node) -> void:
	Input.action_release("rewind")
	room.queue_free()
	await _tree.process_frame


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
