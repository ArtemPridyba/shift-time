extends SceneTree
## Screenshots of a level played by its recorded inputs (task Д0, 17.11.2026).
## Claude's eyes for the design tasks: it plays a solution file from
## `game/tests/solutions/` (or one held input) in the real renderer and saves
## PNG frames, so a session can look at a level in normal time and under Shift
## without a person at the keyboard.
##
## Needs a display: in a cloud session run it through `tools/shots.sh`, which
## starts a virtual screen (xvfb), passes `--fixed-fps 60` so every rendered
## frame is exactly one physics tick, and glues the frames into a contact sheet
## and an optional video. Direct call, from the repository root:
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game \
##     --rendering-driver opengl3 --fixed-fps 60 --script $PWD/tools/shots.gd -- \
##     --solution level_01 --every 60 --out $PWD/build/shots/level_01
##
## Arguments after `--`:
##   --solution NAME   a file in tests/solutions (`level_01` or `level_01.json`)
##   --level ID        instead of a solution: this level from levels.json ...
##   --scene NAME      ... or this scene of `game/levels/` or `game/tests/rooms/`
##                     that is no level (`mech_test`), played without a solution ...
##   --ticks N         ... for N ticks ...
##   --hold A,B        ... holding these input actions (for example `rewind`)
##   --plan P          ... or by segments instead of --ticks/--hold:
##                     `60:;30:interact;60:;120:rewind` — ticks, a colon,
##                     the actions held (comma-separated), segments by `;`
##   --every N         save a frame every N ticks (default 60; 1 for a video)
##   --at T1,T2        also save these ticks
##   --from T --to T   only save frames in this range of ticks
##   --past N          keep playing N ticks after the exit is reached (default 30)
##   --scale F         scale the saved frames (default 1.0; 0.5 saves tokens)
##   --follow W,H      crop every frame to W x H screen pixels around the
##                     player (group `player`), before --scale: for close
##                     looks at the heroine's animations (`--follow 240,160 --scale 3`)
##   --out DIR         absolute folder for the frames (default build/shots/NAME)
##
## Frame names: `t00120_fwd.png` / `t00120_rev.png` — the tick and the
## direction of world time at that tick. Nothing here changes the game.

const Solutions := preload("res://tests/test_solutions.gd")
const SETTLE_TICKS := 2

var _args := {}


func _initialize() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	_run.call_deferred()


func _run() -> void:
	var data := _load_input()
	if data.is_empty():
		quit(1)
		return
	var out_dir := str(_args.get("out", _default_out(data)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	for old in DirAccess.get_files_at(out_dir):
		if old.ends_with(".png"):
			DirAccess.remove_absolute(out_dir.path_join(old))
	var every := maxi(1, int(_args.get("every", "60")))
	var at := {}
	for t in str(_args.get("at", "")).split(",", false):
		at[int(t)] = true
	var from_tick := int(_args.get("from", "0"))
	var to_tick := int(_args.get("to", "1000000000"))
	var past := int(_args.get("past", "30"))
	var scale := float(_args.get("scale", "1.0"))

	var all_actions := Solutions._all_actions(data)
	var manager := root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	var scene_path := str(data.get("scene", Solutions._level_scene(str(data.get("level", "")))))
	var room: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(room)
	for i in SETTLE_TICKS:
		await physics_frame

	var tick := 0
	var saved := 0
	var exit_tick := -1
	for segment: Variant in data["segments"]:
		for action: Variant in all_actions:
			if action in (segment["actions"] as Array):
				Input.action_press(action)
			else:
				Input.action_release(action)
		for i in int(segment["ticks"]):
			await physics_frame
			tick += 1
			if (tick % every == 0 or at.has(tick)) and tick >= from_tick and tick <= to_tick:
				await RenderingServer.frame_post_draw
				_save(out_dir, tick, manager, scale)
				saved += 1
			if exit_tick < 0 and room.get("is_completed") == true:
				exit_tick = tick
			if exit_tick >= 0 and tick - exit_tick >= past:
				break
		if exit_tick >= 0 and tick - exit_tick >= past:
			break
	for action: Variant in all_actions:
		Input.action_release(action)
	var ending := "exit reached at tick %d" % exit_tick if exit_tick >= 0 else "no exit"
	print("SHOTS %d frames, %d ticks, %s -> %s" % [saved, tick, ending, out_dir])
	quit(0)


func _save(out_dir: String, tick: int, manager: Node, scale: float) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if _args.has("follow"):
		image = _follow(image)
	if not is_equal_approx(scale, 1.0):
		image.resize(int(image.get_width() * scale), int(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	var reverse := manager != null and bool(manager.call("is_rewinding"))
	image.save_png(out_dir.path_join("t%05d_%s.png" % [tick, "rev" if reverse else "fwd"]))


## The part of the frame around the player, kept inside the frame.
func _follow(image: Image) -> Image:
	var size := str(_args["follow"]).split(",")
	var crop := Vector2i(int(size[0]), int(size[1]) if size.size() > 1 else int(size[0]))
	var player := get_first_node_in_group("player") as Node2D
	if player == null:
		return image
	var screen := player.get_global_transform_with_canvas() * Vector2(0, -46)
	var corner := Vector2i(screen) - crop / 2
	corner.x = clampi(corner.x, 0, maxi(0, image.get_width() - crop.x))
	corner.y = clampi(corner.y, 0, maxi(0, image.get_height() - crop.y))
	return image.get_region(Rect2i(corner, crop))


func _load_input() -> Dictionary:
	if _args.has("solution"):
		var file := str(_args["solution"])
		if not file.ends_with(".json"):
			file += ".json"
		var data: Variant = Content.load_json(Solutions.SOLUTIONS_DIR.path_join(file))
		var problems := Solutions.solution_problems(data)
		if not problems.is_empty():
			printerr("shots: %s: %s" % [file, ", ".join(problems)])
			return {}
		return data
	if _args.has("level") or _args.has("scene"):
		var segments := _segments()
		if segments.is_empty():
			printerr("shots: --plan must look like 60:;30:rewind (ticks:actions;...)")
			return {}
		if _args.has("scene"):
			var scene_name := str(_args["scene"]).trim_suffix(".tscn")
			var path := "res://levels/%s.tscn" % scene_name
			if not ResourceLoader.exists(path):
				path = "res://tests/rooms/%s.tscn" % scene_name
			if not ResourceLoader.exists(path):
				printerr("shots: no scene %s" % path)
				return {}
			return {"scene": path, "segments": segments}
		var data := {"level": str(_args["level"]), "expect": Solutions.EXPECT_EXIT, "segments": segments}
		var problems := Solutions.solution_problems(data)
		if not problems.is_empty():
			printerr("shots: %s" % ", ".join(problems))
			return {}
		return data
	printerr("shots: give --solution NAME, --level ID or --scene NAME (see tools/shots.gd)")
	return {}


## The segments of --plan, or one segment of --ticks with --hold; empty when
## --plan is malformed.
func _segments() -> Array:
	if not _args.has("plan"):
		return [{"actions": Array(str(_args.get("hold", "")).split(",", false)), "ticks": int(_args.get("ticks", "300"))}]
	var segments := []
	for part in str(_args["plan"]).split(";", false):
		var fields := part.split(":")
		if fields.size() != 2 or not fields[0].is_valid_int() or int(fields[0]) <= 0:
			return []
		segments.append({"actions": Array(fields[1].split(",", false)), "ticks": int(fields[0])})
	return segments


func _default_out(data: Dictionary) -> String:
	var name := str(_args.get("solution", _args.get("scene", data.get("level", "")))).trim_suffix(".json")
	return ProjectSettings.globalize_path("res://").path_join("../build/shots").path_join(name).simplify_path()


static func _parse(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	var i := 0
	while i < args.size():
		var key := args[i]
		if key.begins_with("--") and i + 1 < args.size():
			parsed[key.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return parsed
