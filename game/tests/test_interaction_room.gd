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
