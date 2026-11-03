extends Node
# Autoload "SaveStore": the player's 3 save slots in one file (user://profile.json by default).
# File: { "version": 1, "slots": [slot|null, slot|null, slot|null] }; a slot is the same Dictionary as the
# JS game's schema v6. Writes are atomic (write .tmp, then rename). A file that can't be read is copied to
# <path>.bad and the game starts with empty slots; the corrupt file is only replaced by the next real save.
# When Codex's res://rules/schema.gd exists, slots go through its normalize() / new_slot().

const SLOTS := 3

var path := "user://profile.json":
	set(value):
		path = value
		_slots = []

var _slots: Array = []  # loaded lazily
var _readonly := false  # set when a corrupt file couldn't be backed up: never overwrite it
var _pending_rewrite := false  # migrated on load: write the current version on the next save
## Off only in tests of the raw file handling; the game always goes through Codex's schema.
var use_schema := true
var _schema: Object = null

var _schema_checked := false

func _ready() -> void:
	_get_schema()  # load the rules' schema up front at start-up (it's also loaded lazily when needed)

## Codex's rules/schema.gd when present (loaded lazily, so fresh instances in tests use it too).
func _get_schema() -> Object:
	if not use_schema:
		return null
	if not _schema_checked:
		_schema_checked = true
		if ResourceLoader.exists("res://rules/schema.gd"):
			_schema = load("res://rules/schema.gd").new()
	return _schema

func _version() -> int:
	var sc := _get_schema()
	return int(sc.get_script().get("SCHEMA_VERSION")) if sc != null and sc.get_script().get("SCHEMA_VERSION") != null else 1

func list_slots() -> Array:
	_ensure_loaded()
	var out: Array = []
	for s in _slots:
		out.append(_summary(s) if s is Dictionary else null)
	return out

func load_slot(i: int) -> Variant:
	if not _valid(i):
		return null
	_ensure_loaded()
	var s: Variant = _slots[i]
	var sc := _get_schema()
	if s is Dictionary and sc != null and sc.has_method("normalize"):
		return sc.normalize(s.duplicate(true))
	return s.duplicate(true) if s is Dictionary else null

func save_slot(i: int, slot: Dictionary) -> bool:
	if not _valid(i):
		return false
	_ensure_loaded()
	return _change(i, slot.duplicate(true))

func create_slot(i: int, look: Dictionary) -> bool:
	var sc := _get_schema()
	var slot: Dictionary = sc.new_slot(look) if sc != null and sc.has_method("new_slot") else {"appearance": look}
	return save_slot(i, slot)

func delete_slot(i: int) -> bool:
	if not _valid(i):
		return false
	_ensure_loaded()
	return _change(i, null)

## Changes one slot and writes; if the write fails, memory goes back to what is on disk.
func _change(i: int, value: Variant) -> bool:
	var before: Variant = _slots[i]
	_slots[i] = value
	if _write():
		return true
	_slots[i] = before
	return false

## The whole profile ({version, slots}) for a save code.
func export_profile() -> Dictionary:
	_ensure_loaded()
	return {"version": _version(), "slots": _slots.duplicate(true)}

func export_code() -> String:
	var sc := _get_schema()
	return sc.export_code(export_profile()) if sc != null else ""

## Replaces all three slots from a save code. Returns {ok, error}.
func import_code(code: String) -> Dictionary:
	var sc := _get_schema()
	if sc == null:
		return {"ok": false, "error": "Save codes are unavailable"}
	var r: Dictionary = sc.import_code(code)
	if not r.get("ok", false):
		return r
	var slots: Array = r.profile.get("slots", [])
	var before := _slots.duplicate(true)
	for i in SLOTS:
		_slots[i] = slots[i] if i < slots.size() and slots[i] is Dictionary else null
	if not _write():
		_slots = before
		return {"ok": false, "error": "Couldn't write the save file"}
	return {"ok": true}

func _valid(i: int) -> bool:
	return i >= 0 and i < SLOTS

func _summary(s: Dictionary) -> Dictionary:
	var out := {}
	for k in ["race", "level", "zone", "playedAt", "playTime", "appearance"]:
		if s.has(k):
			out[k] = s[k]
	return out

func _ensure_loaded() -> void:
	if _slots.size() == SLOTS:
		return
	_slots = [null, null, null]
	var main: Variant = _read(path) if FileAccess.file_exists(path) else null
	if main == null and FileAccess.file_exists(path):
		_keep_bad()
	if main == null:
		# a save interrupted between writing .tmp and the rename: finish it
		var tmp: Variant = _read(path + ".tmp") if FileAccess.file_exists(path + ".tmp") else null
		if tmp == null:
			return
		main = tmp
		_fill(main)
		if not _readonly:
			_write()
		return
	_fill(main)

func _read(p: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return null
	if not (json.data is Dictionary and json.data.get("slots") is Array):
		return null
	return json.data

func _fill(data: Dictionary) -> void:
	# a file from an older save version goes through the rules' migration exactly once (it's rewritten as current)
	var sc := _get_schema()
	if sc != null and sc.has_method("migrate") and int(data.get("version", 1)) < _version():
		data = sc.migrate(data.duplicate(true))
		_pending_rewrite = true
	var slots: Array = data["slots"]
	for i in mini(SLOTS, slots.size()):
		_slots[i] = slots[i] if slots[i] is Dictionary else null

## Keeps the unreadable file's exact bytes as <path>.bad. If that fails, the store goes read-only so the
## corrupt original is never overwritten.
func _keep_bad() -> void:
	var raw := FileAccess.get_file_as_bytes(path)
	var bad := FileAccess.open(path + ".bad", FileAccess.WRITE)
	if bad != null:
		bad.store_buffer(raw)
		bad.close()
	if bad == null or FileAccess.get_file_as_bytes(path + ".bad") != raw:
		_readonly = true
		push_warning("SaveStore: %s could not be read or backed up; not writing to it" % path)
		return
	push_warning("SaveStore: %s could not be read; kept a copy as %s.bad and started with empty slots" % [path, path])

func _write() -> bool:
	if _readonly:
		return false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveStore: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify({"version": _version(), "slots": _slots}, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return err == OK
