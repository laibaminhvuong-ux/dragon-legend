extends TestCase
# Building-by-building audit 2026-11-12 (Snake Way, World of Void, Crimson Ribbon base): regressions.

## King Kae's orb over Serpent Road: its white band stays on the sphere (it used to bend its top ends down to the
## road's ground, a white pillar from the road's end up to the orb) and the house / car / tree touch the curved top.
func test_kaiorb_band_and_top_stay_on_the_sphere() -> void:
	var zone := RuleZone.new("snake_way")
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "kaiorb":
			l = m
	ok(not l.is_empty(), "snake_way has the orb")
	if l.is_empty():
		return
	var g := WorldLandmarks.build_one(zone, l)
	var r := float(l.get("radius", 34.0))
	var worst := 0.0
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("no_collision") or mi.mesh == null:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			worst = maxf(worst, absf(Vector2(v.y, v.z).length() - r))
	ok(worst < 0.5, "band vertices within 0.5 m of the sphere (worst %.2f m)" % worst)
	g.free()

## Grand Zenno's stand is inside the map (fighters are clamped to it), floats over the void and Zenno stands on it.
func test_zeno_stands_on_his_stand_inside_the_map() -> void:
	var zone := RuleZone.new("world_of_void")
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "zenobox":
			l = m
	ok(not l.is_empty() and absf(float(l.z)) < zone.size / 2.0 - 10.0, "stand inside the map")
	var g := WorldLandmarks.build_one(zone, l)
	ok(g.position.y > -10.0, "stand floats near the arena, not in the void (y %.1f)" % g.position.y)
	var zeno: Dictionary = RuleTables.table("npcs").filter(func(n: Dictionary) -> bool: return n.id == "zeno")[0]
	var p := zone.free_position(zone.place_in("world_of_void", float(zeno.x), float(zeno.z)).merged({"y": float(zeno.y)}))
	ok(Vector2(p.x - float(l.x), p.z - float(l.z)).length() < 3.0, "Zenno on the stand, not pushed off it (%s)" % p)
	ok(absf(p.y - (g.position.y + 27.5)) < 7.0, "Zenno at the stand's top height (%.1f vs %.1f)" % [p.y, g.position.y + 27.5])
	g.free()

## Every door of the Crimson Ribbon base is within reach of a fighter standing at the building (door use range 2.6 m).
func test_red_ribbon_hangar_doors_are_at_the_door() -> void:
	var zone := RuleZone.new("red_ribbon")
	var root := WorldLandmarks.build(zone)
	for d: Dictionary in zone.doors():
		if str(d.get("interior", "")) != "interior_hangar":
			continue
		# walk from the door point straight at the building: within 2.6 m you must hit its wall
		var dir := -Vector2(sin(float(d.yaw)), cos(float(d.yaw)))
		var e := {"pos": Vector3(float(d.x), zone.height_at(d.x, d.z), float(d.z)), "vel": Vector3.ZERO, "flying": false, "onGround": true}
		for i in 40:
			var prev: Vector3 = e.pos
			e.pos = prev + Vector3(dir.x, 0, dir.y) * 0.1
			e.pos.y = zone.ground_at(e.pos.x, e.pos.z, prev.y)
			RuleCollision.resolve(e, zone, prev)
		var moved := Vector2(e.pos.x - float(d.x), e.pos.z - float(d.z)).length()
		ok(moved < 2.4, "%s: the wall is %.1f m from its door point" % [d.name, moved])
		ok(not str(d.name).begins_with("Rrhangar"), "door has a proper name (%s)" % d.name)
	root.free()
