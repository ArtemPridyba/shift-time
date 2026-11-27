extends SceneTree
## Rule tests. Runs every `test_*` method of the suites below, prints PASS or
## FAIL for each, the time of every suite, the slowest tests and
## `N tests, M failed` at the end. Exit code 1 on failure.
##
##   godot --headless --fixed-fps 60 --path game --script res://tests/test_runner.gd
##
## `--fixed-fps 60` lets every frame count as exactly 1/60 s without waiting
## for the wall clock: the same ticks, many times faster. Without it the run
## waits in real time and a warning is printed.
##
## Only some suites or tests: name them after `--`, by the file name without
## `test_` and `.gd`, and a test after a colon:
##
##   ... --script res://tests/test_runner.gd -- fire water
##   ... --script res://tests/test_runner.gd -- fire:test_wood_burns_through_burning_to_burnt

const SUITES: Array[String] = [
	"res://tests/test_core.gd",
	"res://tests/test_art.gd",
	"res://tests/test_time_particles.gd",
	"res://tests/test_mech.gd",
	"res://tests/test_time_manager.gd",
	"res://tests/test_timeline.gd",
	"res://tests/test_time_world.gd",
	"res://tests/test_objects.gd",
	"res://tests/test_interaction.gd",
	"res://tests/test_interaction_room.gd",
	"res://tests/test_level_loader.gd",
	"res://tests/test_lamp.gd",
	"res://tests/test_water.gd",
	"res://tests/test_prelude.gd",
	"res://tests/test_fire.gd",
	"res://tests/test_time_hud.gd",
	"res://tests/test_sound.gd",
	"res://tests/test_heroine.gd",
	"res://tests/test_level_01.gd",
	"res://tests/test_world.gd",
	"res://tests/test_level_02.gd",
	"res://tests/test_level_03.gd",
	"res://tests/test_level_04.gd",
	"res://tests/test_level_05.gd",
	"res://tests/test_level_06.gd",
	"res://tests/test_level_07.gd",
	"res://tests/test_solutions.gd",
	"res://tests/test_solution_replay.gd",
	"res://tests/test_monkey.gd",
]

const SLOWEST_SHOWN := 10

var _errors := ScriptErrors.new()
var _tests := 0
var _failed := 0
## [seconds, "suite:test"] of every test that ran.
var _times: Array = []


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


## The engine keeps `--fixed-fps` to itself, so the runner looks at the clock:
## 30 ticks in real time take half a second, with the flag a few milliseconds.
func _warn_without_fixed_fps() -> void:
	var start := Time.get_ticks_msec()
	for i in 30:
		await physics_frame
	if Time.get_ticks_msec() - start > 300:
		print("WARNING: run without --fixed-fps 60, the tests wait in real time")


## Suite name -> the tests asked for in it ([] = every test), from the
## arguments after `--`. An empty result means every suite.
func _filter() -> Dictionary:
	var wanted := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split(":", true, 1)
		var suite := parts[0].trim_prefix("test_").trim_suffix(".gd")
		if not wanted.has(suite):
			wanted[suite] = []
		if parts.size() > 1:
			(wanted[suite] as Array).append(parts[1])
	return wanted


func _run() -> void:
	await _warn_without_fixed_fps()
	var wanted := _filter()
	var start_all := Time.get_ticks_msec()
	for path in SUITES:
		var suite_name := path.get_file().trim_prefix("test_").trim_suffix(".gd")
		if not wanted.is_empty() and not wanted.has(suite_name):
			continue
		var only: Array = wanted.get(suite_name, [])
		var start_suite := Time.get_ticks_msec()
		var count_before := _tests
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			# A suite that does not parse fails, and the run still ends.
			_tests += 1
			_failed += 1
			print("FAIL ", path, " does not load")
			continue
		var suite: RefCounted = script.new(self)
		for info in suite.get_script().get_script_method_list():
			var method: String = info["name"]
			if not method.begins_with("test_"):
				continue
			if not only.is_empty() and not only.has(method):
				continue
			_errors.reset()
			suite.failures.clear()
			var start_test := Time.get_ticks_msec()
			await suite.call(method)
			_times.append([(Time.get_ticks_msec() - start_test) / 1000.0, suite_name + ":" + method])
			_tests += 1
			var problems: Array[String] = []
			problems.append_array(suite.failures)
			for message in _errors.messages:
				problems.append("SCRIPT ERROR " + message)
			if problems.is_empty():
				print("PASS ", method)
			else:
				_failed += 1
				print("FAIL ", method)
				for problem in problems:
					print("  - ", problem)
		print("SUITE %s: %d tests, %.1f s" % [
			suite_name, _tests - count_before, (Time.get_ticks_msec() - start_suite) / 1000.0])
	if not wanted.is_empty() and _tests == 0:
		# A typo in a suite or test name must not look green.
		_failed += 1
		print("FAIL no test matches ", OS.get_cmdline_user_args())
	_times.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("Slowest tests:")
	for i in mini(SLOWEST_SHOWN, _times.size()):
		print("  %.1f s  %s" % [_times[i][0], _times[i][1]])
	print("Total %.1f s" % [(Time.get_ticks_msec() - start_all) / 1000.0])
	print("%d tests, %d failed" % [_tests, _failed])
	_silence()
	quit(1 if _failed > 0 else 0)


## Stops every sound and lets the audio thread drop them before quitting, so no
## playback is left in use at exit (the sound, D183).
func _silence() -> void:
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		for node in root.find_children("*", kind, true, false):
			node.call("stop")
	OS.delay_msec(150)
