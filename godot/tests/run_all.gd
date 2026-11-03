extends SceneTree
# Headless test runner: godot --headless --path godot -s res://tests/run_all.gd -- [filter] [--dir=res://...]
# Runs every res://tests/**/test_*.gd (tests/fixtures is skipped unless --dir points into it); a filter keeps
# tests whose "file::method" contains it. Prints "ok ..." / "FAIL ...: msg" and "N passed, M failed";
# exits 1 if anything failed.
# It can't hang: a file that doesn't load or isn't a TestCase is a FAIL, a test that hits an engine/script error
# is a FAIL (a Logger counts errors while each test runs), and if a broken file still aborts the run, the first
# frame's watchdog prints why and exits 2.

class ErrorCounter extends Logger:
	var count := 0
	var first := ""
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return  # warnings are allowed (e.g. Data reporting a broken file)
		count += 1
		if first == "":
			first = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]

var _finished := false
var _current := ""
var _errors := ErrorCounter.new()

func _initialize() -> void:
	OS.add_logger(_errors)
	var filter := ""
	var root := "res://tests"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			root = a.substr(6)
		else:
			filter = a
	var passed := 0
	var failed := 0
	for path in _find(root, root == "res://tests"):
		var rel := path.trim_prefix(root + "/")
		_current = rel
		_errors.count = 0
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s: does not load (%s)" % [rel, _errors.first if _errors.first != "" else "parse error"])
			failed += 1
			continue
		var probe: Object = script.new()
		if not (probe is TestCase):
			print("FAIL %s: does not extend TestCase" % rel)
			failed += 1
			if probe is Node:
				probe.free()
			continue
		var opt: Dictionary = probe.opt_in()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var id := "%s::%s" % [rel, name]
			if opt.has(name):
				if filter != opt[name]:
					continue
			elif filter != "" and not id.contains(filter):
				continue
			_current = id
			_errors.count = 0
			_errors.first = ""
			var t: TestCase = script.new()
			t.call(name)
			var fails: Array = t.failures.duplicate()
			if _errors.count > 0:
				fails.append("%d engine error(s), first: %s" % [_errors.count, _errors.first])
			if fails.is_empty():
				print("ok %s" % id)
				passed += 1
			else:
				print("FAIL %s: %s" % [id, "; ".join(fails)])
				failed += 1
	print("%d passed, %d failed" % [passed, failed])
	_finished = true
	OS.remove_logger(_errors)
	quit(1 if failed > 0 else 0)

func _process(_delta: float) -> bool:
	if not _finished:
		print("FAIL %s: the test run was aborted by a script error (%s)" % [_current, _errors.first])
		OS.remove_logger(_errors)
		quit(2)
	return false

func _find(dir: String, skip_fixtures: bool) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		if skip_fixtures and sub == "fixtures":
			continue
		out.append_array(_find(dir.path_join(sub), skip_fixtures))
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append(dir.path_join(f))
	out.sort()
	return out
