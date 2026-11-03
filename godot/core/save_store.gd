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
	_slots[i] = slot.duplicate(true)
	return _write()

func create_slot(i: int, look: Dictionary) -> bool:
	var slot: Dictionary = _schema.new_slot(look) if _schema != null and _schema.has_method("new_slot") else {"appearance": look}
	return save_slot(i, slot)

func delete_slot(i: int) -> bool:
	if not _valid(i):
		return false
	_ensure_loaded()
	_slots[i] = null
	return _write()

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
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var good: bool = json.parse(text) == OK and json.data is Dictionary and json.data.get("slots") is Array
	if not good:
		_keep_bad(text)
		return
	var slots: Array = json.data["slots"]
	for i in mini(SLOTS, slots.size()):
		_slots[i] = slots[i] if slots[i] is Dictionary else null

func _keep_bad(text: String) -> void:
	var bad := FileAccess.open(path + ".bad", FileAccess.WRITE)
	if bad != null:
		bad.store_string(text)
		bad.close()
	push_warning("SaveStore: %s could not be read; kept a copy as %s.bad and started with empty slots" % [path, path])

func _write() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveStore: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify({"version": 1, "slots": _slots}, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return err == OK
