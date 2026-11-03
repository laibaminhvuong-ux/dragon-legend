extends TestCase
# Every landmark type in the game has a builder, and each landmark sits where the rules put it.

func test_every_type_has_a_builder() -> void:
	var L: GDScript = load("res://world/landmarks.gd")
	var zones: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones.json"))
	var types := {}
	for z: Dictionary in zones.values():
		for l: Dictionary in z.get("landmarks", []):
			types[l.type] = true
	var missing: Array = []
	for t: String in types:
		if not L.has_builder(t):
			missing.append(t)
	eq(missing, [], "types without a builder")
	ok(types.size() >= 33, "%d landmark types" % types.size())

func test_placed_at_rule_positions() -> void:
	for id in ["earth_plains", "namek", "west_city", "cell_games"]:
		var zone: RefCounted = load("res://rules/zone.gd").new(id)
		var root: Node3D = load("res://world/landmarks.gd").build(zone)
		var groups: Array = root.get_children().filter(func(c: Node) -> bool: return c.has_meta("landmark"))
		eq(groups.size(), zone.landmarks.size(), "%s: one node per landmark" % id)
		for g: Node3D in groups:
			var l: Dictionary = g.get_meta("landmark")
			near(g.position.x, float(l.x), 1e-4, "%s %s x" % [id, l.type])
			near(g.position.z, float(l.z), 1e-4, "%s %s z" % [id, l.type])
			ok(g.get_child_count() > 0, "%s %s has geometry" % [id, l.type])
		root.free()
