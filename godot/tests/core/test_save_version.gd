extends TestCase
# SaveStore writes the real schema version, and an older-version file is migrated once on load.

var path := "user://test_version_%d.json" % Time.get_ticks_usec()

func _cleanup() -> void:
	for p in [path, path + ".tmp", path + ".bad"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func test_writes_schema_version() -> void:
	var s: Node = load("res://core/save_store.gd").new()
	s.path = path
	s.save_slot(0, {"race": "Saiyan", "level": 5})
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	eq(int(data.version), int(load("res://rules/schema.gd").SCHEMA_VERSION), "file version = schema version")
	s.free(); _cleanup()

func test_old_file_is_migrated_once() -> void:
	var schema: Object = load("res://rules/schema.gd").new()
	var old: Dictionary = schema.new_profile()
	old.version = 3
	var look: Dictionary = schema.default_look("Saiyan")
	var slot: Dictionary = schema.new_slot(look)
	slot.level = 10
	old.slots[0] = slot
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var s: Node = load("res://core/save_store.gd").new()
	s.path = path
	var loaded: Dictionary = s.load_slot(0)
	var expected: Dictionary = schema.migrate(old.duplicate(true))
	eq(int(loaded.level), int(expected.slots[0].level), "v3 levels scaled once, as the rules migrate them")
	s.save_slot(0, loaded)
	var again: Node = load("res://core/save_store.gd").new()
	again.path = path
	eq(int(again.load_slot(0).level), int(expected.slots[0].level), "not scaled a second time")
	s.free(); again.free(); _cleanup()
