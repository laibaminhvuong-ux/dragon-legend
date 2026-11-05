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
	"cameraZoom": {"default": 1.0, "min": 0.35, "max": 2.6},
	"showFps": {"default": false, "type": "bool"},
	"voices": {"default": true, "type": "bool"},
	"fullscreen": {"default": false, "type": "bool"},
	# off by default (perf, 2026-11-05): VSync locks the game to the display's refresh, and the user's display runs at 30 Hz
	"vsync": {"default": false, "type": "bool"},
	# overrides on top of Controls' defaults: { action: [ "key:<physical keycode>" | "mouse:<button>" ] }
	"bindings": {"default": {}, "type": "dict"},
}
var path := PATH
var _values: Dictionary = {}

func _ready() -> void:
	load_file()
	apply_display()

## VSync on: lock to the display. Off: up to 120 fps (keeps laptops cool) — smoother input on a slow display.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var on := bool(get_value("vsync"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if on else 120

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
	if s.get("type", "") == "dict":
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
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
	if key == "vsync":
		apply_display()
	return _values[key]

func reset() -> void:
	for k: String in SCHEMA:
		_values[k] = SCHEMA[k].default.duplicate(true) if SCHEMA[k].default is Dictionary else SCHEMA[k].default
		changed.emit(k, _values[k])
	_save()
	apply_display()

func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_values, "\t"))
