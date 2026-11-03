extends SceneTree
# Headless test runner: godot --headless --path godot -s res://tests/run_all.gd -- [filter]
# Runs every res://tests/**/test_*.gd; a filter keeps tests whose "file::method" contains it.
# Prints "ok ..." / "FAIL ...: msg" lines and "N passed, M failed"; exits 1 if anything failed.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := args[0] if args.size() > 0 else ""
	var passed := 0
	var failed := 0
	for path in _find("res://tests"):
		var script: GDScript = load(path)
		if script == null:
			print("FAIL %s: does not load" % path)
			failed += 1
			continue
		var rel := path.trim_prefix("res://tests/")
		var probe: Object = script.new()
		var opt: Dictionary = probe.opt_in() if probe.has_method("opt_in") else {}
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
			var t: Object = script.new()
			t.call(name)
			var fails: Array = t.get("failures")
			if fails.is_empty():
				print("ok %s" % id)
				passed += 1
			else:
				print("FAIL %s: %s" % [id, "; ".join(fails)])
				failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _find(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_find(dir.path_join(sub)))
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append(dir.path_join(f))
	out.sort()
	return out
