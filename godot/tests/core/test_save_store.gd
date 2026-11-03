extends TestCase
# SaveStore: 3 slots in one JSON file, atomic writes, a corrupt file is kept as .bad instead of being lost.

var path := "user://test_profile_%d.json" % Time.get_ticks_usec()

func _store() -> Node:
	var s: Node = load("res://core/save_store.gd").new()
	s.path = path
	s.use_schema = false  # raw file handling; schema normalization has its own tests
	return s

func _cleanup() -> void:
	for p in [path, path + ".bad", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func test_round_trip() -> void:
	var a := _store()
	ok(a.save_slot(1, {"race": "Saiyan", "level": 5.0, "zone": "earth_plains"}), "save")
	var b := _store()
	eq(b.load_slot(1), {"race": "Saiyan", "level": 5.0, "zone": "earth_plains"}, "reloaded by a new instance")
	eq(b.load_slot(0), null, "other slots stay empty")
	eq(b.list_slots()[1]["level"], 5.0, "summary")
	a.free(); b.free(); _cleanup()

func test_three_slots_only() -> void:
	var s := _store()
	eq(s.save_slot(3, {}), false, "slot 3 refused")
	eq(s.save_slot(-1, {}), false, "slot -1 refused")
	eq(s.load_slot(-1), null)
	eq(s.delete_slot(7), false)
	s.save_slot(2, {"race": "Human"})
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	eq(data["slots"].size(), 3, "file always has 3 slots")
	s.free(); _cleanup()

func test_corrupt_file_kept_as_bad() -> void:
	var broken := "{\"slots\": ["
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(broken)
	f.close()
	var s := _store()
	eq(s.list_slots(), [null, null, null], "starts empty")
	ok(FileAccess.file_exists(path + ".bad"), ".bad copy exists")
	eq(FileAccess.get_file_as_string(path + ".bad"), broken, ".bad keeps the original bytes")
	eq(FileAccess.get_file_as_string(path), broken, "original untouched until the next save")
	ok(s.save_slot(0, {"race": "Majin"}), "saving works afterwards")
	eq(s.load_slot(0), {"race": "Majin"})
	s.free(); _cleanup()

func test_delete() -> void:
	var s := _store()
	s.save_slot(0, {"race": "Namekian"})
	ok(s.delete_slot(0), "delete")
	eq(s.load_slot(0), null)
	var again := _store()
	eq(again.load_slot(0), null, "deleted on disk too")
	again.free(); s.free(); _cleanup()
