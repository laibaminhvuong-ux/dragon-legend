extends TestCase
# The terrain grid cache returns exactly what sampling the rules returns, and a changed recipe misses the cache.

func test_cached_grid_equals_sampled() -> void:
	var T: GDScript = load("res://world/terrain.gd")
	var zone: RefCounted = load("res://rules/zone.gd").new("king_kai")
	T.cache_dir = "user://test_terrain_cache_%d" % Time.get_ticks_usec()
	var fresh: Dictionary = T.sample_grid(zone, "low")
	var first: Dictionary = T.grid_for(zone, "low")   # samples and writes the cache
	var second: Dictionary = T.grid_for(zone, "low")  # reads it
	eq(second.get("from_cache", false), true, "second call is a cache hit")
	ok(second.h == fresh.h and second.col == fresh.col and second.extra == fresh.extra, "cached grid == sampled grid")
	eq(int(second.n), int(fresh.n), "grid size")
	# a different recipe (another world, same id key) must not hit
	ok(T.cache_key(zone, "low") != T.cache_key(load("res://rules/zone.gd").new("lookout"), "low"), "keys differ per recipe")
	for f in DirAccess.get_files_at(T.cache_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(T.cache_dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(T.cache_dir))
	T.cache_dir = "user://cache/terrain"

func test_mesh_from_cached_grid_matches_rules() -> void:
	var zone: RefCounted = load("res://rules/zone.gd").new("earth_plains")
	var t: Node3D = load("res://world/terrain.gd").build(zone, "low")
	var worst := 0.0
	for c in t.get_children():
		if c is MeshInstance3D:
			var v: PackedVector3Array = c.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i in range(0, v.size(), 97):
				worst = maxf(worst, absf(v[i].y - zone.height_at(v[i].x, v[i].z)))
	near(worst, 0.0, 1e-3, "drawn height == rule height")
	t.free()
