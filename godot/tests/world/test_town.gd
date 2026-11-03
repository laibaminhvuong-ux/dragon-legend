extends TestCase
# Open-world towns: the same layout every time, nothing built on the roads or where you arrive, solid buildings,
# and every style draws.
const TOWNS := ["amber_city", "pepper_village", "snowpeak_village", "harbor_town"]

func _town(zone: RuleZone) -> Dictionary:
	return zone.landmarks.filter(func(l: Dictionary) -> bool: return l.type == "town")[0]

func test_layouts_are_stable_and_leave_roads_and_arrival_clear() -> void:
	for id: String in TOWNS:
		var zone := RuleZone.new(id)
		var l := _town(zone)
		var a: Dictionary = RuleTown.layout(l)
		RuleTown._cache.clear()
		eq(RuleTown.layout(l), a, id + " same layout from its seed")
		ok(a.buildings.size() >= 8, "%s has %d buildings" % [id, a.buildings.size()])
		for b: Dictionary in a.buildings:
			if str(b.kind) in ["lighthouse", "windmill"]:
				continue
			ok(not RuleTown._on_road(a, float(b.x), float(b.z), minf(float(b.w), float(b.d)) * 0.5), "%s: %s at %.0f,%.0f is off the road" % [id, b.kind, b.x, b.z])
		var spawn := Vector3(zone.spawn.x, zone.height_at(zone.spawn.x, zone.spawn.z), zone.spawn.z)
		eq(zone.free_position({"x": zone.spawn.x, "z": zone.spawn.z}), spawn, id + " arrival point is free")

func test_buildings_are_solid() -> void:
	var zone := RuleZone.new("amber_city")
	var b: Dictionary = RuleTown.layout(_town(zone)).buildings[0]
	ok(not zone.props().near(float(b.x), float(b.z), 1.0).is_empty(), "a collider at the first building")

func test_every_style_draws() -> void:
	for id: String in TOWNS:
		var zone := RuleZone.new(id)
		var root := WorldLandmarks.build(zone)
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		ok(meshes.size() >= 4 and meshes.size() < 60, "%s merged into %d meshes" % [id, meshes.size()])
		var verts := 0
		for m in meshes:
			verts += (m as MeshInstance3D).mesh.get_faces().size()
		ok(verts > 3000, "%s still has its buildings (%d triangle corners)" % [id, verts])
		root.free()
