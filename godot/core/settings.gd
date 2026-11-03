extends Node
# Autoload "Settings": player settings saved apart from characters (port of web/src/core/settings.js).
# UI writes with set_value(); systems read with get_value() and listen to `changed`.

signal changed(key: String, value: Variant)

const PATH := "user://settings.json"
const SCHEMA := {
	"quality": {"default": "medium", "options": ["low", "medium", "high"]},
	"masterVolume": {"default": 0.8, "min": 0.0, "max": 1.0},
	"musicVolume": {"default": 0.6, "min": 0.0, "max": 1.0},
	"sfxVolume": {"default": 0.8, "min": 0.0, "max": 1.0},
	"voiceVolume": {"default": 0.9, "min": 0.0, "max": 1.0},
	"mouseSensitivity": {"default": 1.0, "min": 0.1, "max": 3.0},
	"invertY": {"default": false, "type": "bool"},
	"showFps": {"default": false, "type": "bool"},
	"voices": {"default": true, "type": "bool"},
	"fullscreen": {"default": false, "type": "bool"},
}
var path := PATH
var _values: Dictionary = {}

func _ready() -> void:
	load_file()

func load_file() -> void:
	var saved: Variant = null
	if FileAccess.file_exists(path):
		saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	var d: Dictionary = saved if saved is Dictionary else {}
	for k: String in SCHEMA:
		_values[k] = sanitize(k, d[k]) if d.has(k) else SCHEMA[k].default

static func sanitize(key: String, value: Variant) -> Variant:
	var s: Dictionary = SCHEMA.get(key, {})
	if s.is_empty():
		return null
	if s.has("options"):
		return value if (s.options as Array).has(value) else s.default
	if s.get("type", "") == "bool":
		return value if value is bool else s.default
	if value is float or value is int:
		return clampf(float(value), float(s.min), float(s.max))
	return s.default

func get_value(key: String) -> Variant:
	if _values.is_empty():
		load_file()   # read before _ready (headless tools/tests)
	return _values.get(key)

func set_value(key: String, value: Variant) -> Variant:
	if not SCHEMA.has(key):
		push_error("Settings: unknown setting '%s'" % key)
		return null
	_values[key] = sanitize(key, value)
	_save()
	changed.emit(key, _values[key])
	return _values[key]

func reset() -> void:
	for k: String in SCHEMA:
		_values[k] = SCHEMA[k].default
		changed.emit(k, _values[k])
	_save()

func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_values, "\t"))
