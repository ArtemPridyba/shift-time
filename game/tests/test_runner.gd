extends SceneTree
## Rule tests. Runs every `test_*` method of the suites below, prints PASS or
## FAIL for each and `N tests, M failed` at the end. Exit code 1 on failure.
##
##   godot --headless --path game --script res://tests/test_runner.gd

const SUITES: Array[String] = [
	"res://tests/test_core.gd",
	"res://tests/test_time_manager.gd",
	"res://tests/test_timeline.gd",
	"res://tests/test_time_world.gd",
	"res://tests/test_objects.gd",
	"res://tests/test_interaction.gd",
	"res://tests/test_interaction_room.gd",
	"res://tests/test_level_loader.gd",
	"res://tests/test_lamp.gd",
]

var _errors := ScriptErrors.new()
var _tests := 0
var _failed := 0


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _run() -> void:
	for path in SUITES:
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
			_errors.reset()
			suite.failures.clear()
			await suite.call(method)
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
	print("%d tests, %d failed" % [_tests, _failed])
	quit(1 if _failed > 0 else 0)
