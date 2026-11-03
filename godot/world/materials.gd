class_name WorldMaterials
extends RefCounted
# Ground materials for the terrain splat. CC0 photo-scanned textures (Poly Haven, fetched by
# tools/fetch_assets.sh into res://assets/textures/<kind>/) when present; flat colours otherwise.

const DIR := "res://assets/textures"
const COLORS := {
	"grass": Color(0.30, 0.48, 0.20), "forest": Color(0.26, 0.33, 0.17), "dirt": Color(0.45, 0.36, 0.25),
	"rock": Color(0.48, 0.46, 0.43), "sand": Color(0.82, 0.74, 0.55), "snow": Color(0.92, 0.94, 0.97),
	"white": Color(0.92, 0.92, 0.9),
}
static var _cache: Dictionary = {}

## { albedo, normal, rough: Texture2D or null, color: Color } for a ground kind.
static func ground(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var tex_kind := "snow" if kind == "white" else kind
	var out := {
		"albedo": _tex("%s/%s/albedo.jpg" % [DIR, tex_kind]),
		"normal": _tex("%s/%s/normal.jpg" % [DIR, tex_kind]),
		"rough": _tex("%s/%s/rough.jpg" % [DIR, tex_kind]),
		"color": COLORS.get(kind, Color(0.5, 0.5, 0.5)),
	}
	_cache[kind] = out
	return out

static func has_textures() -> bool:
	return ResourceLoader.exists("%s/grass/albedo.jpg" % DIR)

static func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
