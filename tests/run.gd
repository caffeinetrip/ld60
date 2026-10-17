extends SceneTree
## godot --headless --path . --fixed-fps 60 -s res://tests/run.gd [-- name]
## Runs tests/*_test.gd, `name` keeps only suites or tests containing it. Exit code 1 = red.

class Errors extends Logger:
	var lines := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, type: int, _trace: Array) -> void:
		var kind := "WARNING" if type == ERROR_TYPE_WARNING else "ERROR"
		_mutex.lock()
		lines.append("%s %s (%s:%d %s)" % [kind, rationale if rationale else code, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := lines.duplicate()
		lines.clear()
		_mutex.unlock()
		return out


var _errors := Errors.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	if not OS.get_cmdline_user_args().is_empty():
		only = OS.get_cmdline_user_args()[0]
	OS.add_logger(_errors)
	var game := root.get_node("Game")
	var passed := 0
	var failed := PackedStringArray()
	for path in _suites():
		var suite = load(path).new()
		suite.tree = self
		var suite_name := path.get_file().get_basename()
		for m in suite.get_script().get_script_method_list():
			var test: String = m.name
			if not test.begins_with("test_"):
				continue
			if only and not suite_name.contains(only) and not test.contains(only):
				continue
			Engine.time_scale = 1.0
			game.new_run()
			suite.failures.clear()
			_errors.take()
			await suite.before_each()
			await suite.call(test)
			await suite.after_each()
			suite.drop_listeners()
			await process_frame
			var problems: PackedStringArray = suite.failures.duplicate()
			problems.append_array(_errors.take())
			if problems.is_empty():
				passed += 1
				print("  ok    %s.%s" % [suite_name, test])
			else:
				failed.append("%s.%s" % [suite_name, test])
				print("  FAIL  %s.%s" % [suite_name, test])
				for p in problems:
					print("        " + p)
	OS.remove_logger(_errors)
	print("\n%d passed, %d failed" % [passed, failed.size()])
	for f in failed:
		print("  red: " + f)
	quit(1 if failed or passed == 0 else 0)


func _suites() -> PackedStringArray:
	var out := PackedStringArray()
	for file in ResourceLoader.list_directory("res://tests"):
		if file.ends_with("_test.gd"):
			out.append("res://tests/" + file)
	out.sort()
	return out
