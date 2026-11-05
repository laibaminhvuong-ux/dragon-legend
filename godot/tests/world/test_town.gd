extends TestCase
# Open-world towns: the same layout every time, nothing built on the roads or where you arrive, solid buildings,
# and every style draws.
var TOWNS: Array:
	get: return (RuleTables.table("zones") as Dictionary).keys().filter(func(z: String) -> bool: return RuleTables.table("zones")[z].get("kind", "") == "town")

func _town(zone: RuleZone) -> Dictionary:
	return zone.landmarks.filter(func(l: Dictionary) -> bool: return l.type == "town")[0]

func test_layouts_are_stable_and_leave_roads_and_arrival_clear() -> void:
	for id: String in TOWNS:
		var zone := RuleZone.new(id)
		var l := _town(zone)
		var a: Dictionary = RuleTown.layout(l)
		RuleTown._cache.clear()
		eq(RuleTown.layout(l), a, id + " same layout from its seed")
		ok(a.buildings.size() >= (5 if l.get("style") == "garden" else 8), "%s has %d buildings" % [id, a.buildings.size()])
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
		ok(root.has_meta("towns"), "%s: towns stream in like chunks" % id)
		(root.get_meta("towns") as TownStream).update_around(Vector3(zone.spawn.x, 0, zone.spawn.z))   # standing in town builds it
		(root.get_meta("towns") as TownStream).flush()   # far parts build on a worker thread
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		ok(meshes.size() >= 4 and meshes.size() < 60, "%s merged into %d meshes" % [id, meshes.size()])
		var verts := 0
		for m in meshes:
			verts += (m as MeshInstance3D).mesh.get_faces().size()
		ok(verts > 3000, "%s still has its buildings (%d triangle corners)" % [id, verts])
		root.free()

func test_towns_load_near_and_unload_far() -> void:
	var zone := RulePlanet.new("earth")
	var root := WorldLandmarks.build(zone)
	var stream: TownStream = root.get_meta("towns")
	eq(stream.built_count(), 0, "nothing built before the player is placed")
	var far := Vector3(-1500, 0, -1500)
	stream.update_around(far)
	stream.flush()
	var near_far := stream.built_count()
	ok(near_far < stream.towns.size(), "only towns near the player are built (%d of %d)" % [near_far, stream.towns.size()])
	var t: Dictionary = stream.towns[0]
	stream.update_around(Vector3(float(t.x), 0, float(t.z)))
	stream.flush()
	ok(stream.built.has(0), "walking to a town builds it")
	stream.update_around(Vector3(float(t.x) + 400.0, 0, float(t.z)))
	stream.flush()
	stream.update_around(Vector3(float(t.x) + 3000.0, 0, float(t.z) + 3000.0))
	ok(not stream.built.has(0), "walking away frees it")
	# a town further off builds on a worker thread and appears once done
	var before := stream.built_count()
	stream.update_around(Vector3(float(t.x) + 450.0, 0, float(t.z)))
	ok(stream.built_count() == before, "nothing built synchronously in passing")
	stream.flush()
	ok(stream.built.has(0), "the worker thread built it")
	root.free()
