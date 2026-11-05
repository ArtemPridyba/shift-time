class_name ScriptErrors
extends Logger
## Counts script errors (the "SCRIPT ERROR" lines). A test that triggers one
## fails. `push_error` is only printed and is not counted.

var count := 0
var messages := PackedStringArray()
var _mutex := Mutex.new()


func _log_error(
	function: String, file: String, line: int, code: String, rationale: String,
	_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	count += 1
	messages.append("%s:%d in %s: %s %s" % [file, line, function, code, rationale])
	_mutex.unlock()


func reset() -> void:
	_mutex.lock()
	count = 0
	messages.clear()
	_mutex.unlock()
