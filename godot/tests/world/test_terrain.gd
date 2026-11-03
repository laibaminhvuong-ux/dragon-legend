extends TestCase
# Terrain: drawn heights equal the rules' heights, void is left out, collision is built from the same triangles.

func _build(zone_id: String) -> Array:
	var zone: RefCounted = load("res://rules/zone.gd").new(zone_id)
	var t: Node3D = load("res://world/terrain.gd").build(zone, "low")
	return [zone, t]

func _vertices(t: Node3D) -> PackedVector3Array:
	var all := PackedVector3Array()
	for c in t.get_children():
		if c is MeshInstance3D:
			all.append_array(c.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return all

func test_heights_match_rules() -> void:
	var r := _build("earth_plains")
	var zone: RefCounted = r[0]
	var verts := _vertices(r[1])
	ok(verts.size() > 1000, "terrain has vertices (%d)" % verts.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var worst := 0.0
	for i in 50:
		var v := verts[rng.randi_range(0, verts.size() - 1)]
		worst = maxf(worst, absf(v.y - zone.height_at(v.x, v.z)))
	near(worst, 0.0, 1e-3, "drawn height == rule height")
	r[1].free()

func test_void_is_left_out() -> void:
	var r := _build("snake_way")
	var zone: RefCounted = r[0]
	var floor_y: float = (zone.kill_y if zone.kill_y != null else -100.0)
	var lowest := INF
	for v in _vertices(r[1]):
		lowest = minf(lowest, v.y)
	ok(lowest > floor_y, "no vertex below the kill height (lowest %.1f, kill %.1f)" % [lowest, floor_y])
	r[1].free()

func test_collision_matches_mesh() -> void:
	var r := _build("earth_plains")
	var shapes := 0
	var meshes := 0
	for c in r[1].get_children():
		if c is MeshInstance3D:
			meshes += 1
		if c is StaticBody3D:
			for s in c.get_children():
				if s is CollisionShape3D and s.shape is ConcavePolygonShape3D:
					shapes += 1
	ok(meshes > 0 and shapes == meshes, "one collision shape per mesh chunk (%d meshes, %d shapes)" % [meshes, shapes])
	r[1].free()
