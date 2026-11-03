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
var _schema: Object = null

func _ready() -> void:
	if ResourceLoader.exists("res://rules/schema.gd"):
		_schema = load("res://rules/schema.gd").new()

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
	if s is Dictionary and _schema != null and _schema.has_method("normalize"):
		return _schema.normalize(s.duplicate(true))
	return s.duplicate(true) if s is Dictionary else null

func save_slot(i: int, slot: Dictionary) -> bool:
	if not _valid(i):
		return false
	_ensure_loaded()
	return _change(i, slot.duplicate(true))

func create_slot(i: int, look: Dictionary) -> bool:
	var slot: Dictionary = _schema.new_slot(look) if _schema != null and _schema.has_method("new_slot") else {"appearance": look}
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
	f.store_string(JSON.stringify({"version": 1, "slots": _slots}, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return err == OK
