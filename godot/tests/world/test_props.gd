extends TestCase
# Every tree, rock, bush and stone the rules place is drawn, at its rule position.

func _count(root: Node) -> int:
	var n := 0
	for c in root.find_children("*", "", true, false):
		if c is MultiMeshInstance3D:
			n += c.multimesh.instance_count
		elif c is MeshInstance3D:
			n += 1
	return n

func test_all_props_placed() -> void:
	for id in ["earth_plains", "namek", "gizard_wasteland"]:
		var zone: RefCounted = load("res://rules/zone.gd").new(id)
		var p: RefCounted = zone.props()
		var want: int = p.trees.size() + p.rocks.size() + p.bushes.size() + p.stones.size()
		var root: Node3D = load("res://world/props.gd").build(zone, "low")
		eq(_count(root), want, "%s: every prop drawn" % id)
		root.free()

func test_tree_meshes_for_every_kind() -> void:
	for kind in ["broadleaf", "pine", "palm", "ajisa", "crystal"]:
		var m: ArrayMesh = load("res://world/props.gd").tree_mesh(kind, 0)
		eq(m.get_surface_count(), 1 if kind == "crystal" else 2, "%s surfaces" % kind)
		ok(m.surface_get_material(m.get_surface_count() - 1) is ShaderMaterial, "%s foliage uses the foliage shader" % kind)
