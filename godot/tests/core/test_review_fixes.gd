extends TestCase
# Fixes from the Stage 1 final review: Data name safety and shape checks, SaveStore byte-exact .bad,
# recovery from an interrupted save, and in-memory rollback when a write fails.

const DATA_DIR := "user://review_data"
var path := "user://review_profile_%d.json" % Time.get_ticks_usec()

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _data_with(files: Dictionary) -> Node:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var d := DirAccess.open(DATA_DIR)
	for f in d.get_files():
		d.remove(f)
	for name: String in files:
		_write(DATA_DIR.path_join(name), files[name])
	var data: Node = load("res://core/data.gd").new()
	data.load_dir(DATA_DIR)
	return data

func _store() -> Node:
	var s: Node = load("res://core/save_store.gd").new()
	s.path = path
	return s

func _cleanup() -> void:
	for p in [path, path + ".bad", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func test_data_file_named_like_a_node_property_is_harmless() -> void:
	var d := _data_with({"script.json": "{\"a\":1}", "name.json": "[1]", "forms.json": "{\"SSJ\":{}}"})
	ok(d.get_script() != null, "Data keeps its script")
	ok(d.forms.has("SSJ"), "named tables still load")
	eq(d.table("script"), {"a": 1.0}, "the odd file is still reachable by name")
	d.free()

func test_wrong_shape_is_reported() -> void:
	var d := _data_with({"quests.json": "{\"q\":1}", "forms.json": "[1,2]"})
	ok(d.quests.is_empty() and d.forms.is_empty(), "wrong shapes don't load")
	eq(d.errors.size(), 2, "both are reported: %s" % [d.errors])
	d.free()

func test_bad_copy_is_byte_exact() -> void:
	var raw := PackedByteArray([0x7b, 0xff, 0xfe, 0xc3, 0x22, 0x73, 0x6c, 0x00, 0x9f])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	var s := _store()
	eq(s.list_slots(), [null, null, null])
	eq(FileAccess.get_file_as_bytes(path + ".bad"), raw, ".bad has exactly the original bytes")
	s.free(); _cleanup()

func test_recovers_interrupted_save_from_tmp() -> void:
	_write(path + ".tmp", JSON.stringify({"version": 1, "slots": [{"race": "Saiyan"}, null, {"race": "Majin"}]}))
	var s := _store()
	eq(s.load_slot(0), {"race": "Saiyan"}, "slot 0 recovered")
	eq(s.load_slot(2), {"race": "Majin"}, "slot 2 recovered")
	ok(FileAccess.file_exists(path), "the save file is restored")
	s.free(); _cleanup()

func test_failed_write_rolls_back() -> void:
	var s: Node = load("res://core/save_store.gd").new()
	s.path = "user://no_such_dir_%d/profile.json" % Time.get_ticks_usec()
	eq(s.save_slot(0, {"race": "Human"}), false, "write fails")
	eq(s.load_slot(0), null, "memory doesn't claim a save that isn't on disk")
	s.free()
