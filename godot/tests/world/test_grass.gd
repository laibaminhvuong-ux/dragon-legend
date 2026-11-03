extends TestCase
# Grass streams around a point, only on grass ground, and frees chunks that fall out of range.

func test_streams_and_respects_ground() -> void:
	var zone: RefCounted = load("res://rules/zone.gd").new("earth_plains")
	var terrain: Node3D = load("res://world/terrain.gd").build(zone, "low")
	var g: Node3D = load("res://world/grass.gd").create(terrain, zone, "low")
	var s: Dictionary = zone.spawn
	g.update_around(Vector3(s.x, 0, s.z))
	var n: int = g.instance_count()
	ok(n > 500, "grass near spawn (%d clumps)" % n)
	var grid: Dictionary = terrain.get_meta("grid")
	var bad := 0
	for c in g.get_children():
		var mm: MultiMesh = c.multimesh
		for i in mini(mm.instance_count, 40):
			var p := mm.get_instance_transform(i).origin
			if WorldTerrain.sample(grid, p.x, p.z).grass < 0.01:
				bad += 1
	eq(bad, 0, "no blades on bare ground")
	g.update_around(Vector3(s.x + 400, 0, s.z + 400))
	g.update_around(Vector3(s.x + 400, 0, s.z + 400))
	ok(g.instance_count() != n, "chunks follow the target")
	g.free(); terrain.free()
