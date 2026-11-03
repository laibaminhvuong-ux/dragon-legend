extends TestCase
# Streaming LOD terrain for big maps (open world, docs/superpowers/specs/2026-11-03-open-world-design.md):
# chunks near the viewer are full detail, far ones coarser, every vertex lies on the grid's heights, and
# moving the viewer swaps detail without leaving holes or leaking chunks.
const Zone = preload("res://rules/zone.gd")

func _stream() -> TerrainStream:
	var zone := Zone.new("htc")
	var grid := WorldTerrain.grid_for(zone, "low")
	return TerrainStream.create(zone, grid)

func test_lod_by_distance_and_vertices_on_the_grid() -> void:
	var s := _stream()
	s.update_around(Vector3.ZERO, true)
	ok(s.chunk_count() > 0, "chunks built")
	eq(s.lod_of(Vector2i(s.chunk_of(Vector3.ZERO))), 1, "full detail under the viewer")
	var far := Vector3(s.grid.half - 10.0, 0, s.grid.half - 10.0)
	ok(s.lod_of(s.chunk_of(far)) > 1, "coarser far away")
	var mi := s.mesh_at(Vector3.ZERO)
	ok(mi != null, "a mesh under the viewer")
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var checked := 0
	for v in verts:
		var y: float = WorldTerrain.sample(s.grid, v.x, v.z).y
		if absf(v.y - y) < 0.001:
			checked += 1
	ok(checked > verts.size() * 0.6, "surface vertices on the grid (skirts hang below): %d/%d" % [checked, verts.size()])
	s.free()

func test_moving_swaps_detail_and_keeps_one_mesh_per_chunk() -> void:
	var s := _stream()
	s.update_around(Vector3.ZERO, true)
	var before := s.chunk_count()
	var corner := Vector3(s.grid.half - 20.0, 0, s.grid.half - 20.0)
	s.update_around(corner, true)
	eq(s.lod_of(s.chunk_of(corner)), 1, "detail follows the viewer")
	ok(s.lod_of(s.chunk_of(Vector3(-s.grid.half + 20.0, 0, -s.grid.half + 20.0))) > 1, "old spot is coarse now")
	eq(s.chunk_count(), before, "same chunks, no leaks")
	var meshes := 0
	for c in s.get_children():
		if c is MeshInstance3D: meshes += 1
	eq(meshes, s.chunk_count(), "one mesh per chunk")
	s.free()
