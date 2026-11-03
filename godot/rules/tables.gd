class_name RuleTables
extends RefCounted
# Data-only access for both autoload-backed play and fresh headless rule instances.
static var _cache: Dictionary = {}

static func table(key: String, data: Object = null) -> Variant:
	if data != null:
		return data.table(key)
	if not _cache.has(key):
		var file := "res://data/%s.json" % key
		if not FileAccess.file_exists(file):
			push_error("Missing exported game table: " + file)
			return null
		_cache[key] = JSON.parse_string(FileAccess.get_file_as_string(file))
	return _cache[key]
