extends TestCase
# Ground materials: CC0 textures when fetched, flat colours (null textures) when not, never a crash.

func test_every_kind_resolves() -> void:
	var M: GDScript = load("res://world/materials.gd")
	for kind in ["grass", "dirt", "rock", "sand", "snow", "forest", "white"]:
		var g: Dictionary = M.ground(kind)
		ok(g.has("albedo") and g.has("normal") and g.has("rough") and g.has("color"), "%s has all fields" % kind)
		ok(g.color is Color, "%s has a fallback colour" % kind)
		if M.has_textures():
			ok(g.albedo is Texture2D, "%s albedo loaded" % kind)

func test_unknown_kind_falls_back() -> void:
	var M: GDScript = load("res://world/materials.gd")
	var g: Dictionary = M.ground("lava")
	ok(g.color is Color, "unknown kind still gets a colour")
