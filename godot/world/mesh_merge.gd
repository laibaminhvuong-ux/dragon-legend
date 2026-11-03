class_name MeshMerge
extends RefCounted
# Combines every static MeshInstance3D under a node into one mesh per material, so a whole town costs a handful
# of draw calls instead of thousands. Pieces under a node marked with meta "spin" (moving parts) are left alone.

static func merge(root: Node3D, visibility_end := 0.0) -> int:
	var groups := {}   # material -> SurfaceTool
	var done: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or _moving(mi, root):
			continue
		var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		var xf := _relative(mi, root)
		for s in mi.mesh.get_surface_count():
			var m: Material = mat if mi.material_override != null else mi.mesh.surface_get_material(s)
			if not groups.has(m):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[m] = st
			(groups[m] as SurfaceTool).append_from(mi.mesh, s, xf)
		done.append(mi)
	for mi in done:
		mi.get_parent().remove_child(mi)
		mi.free()
	var count := 0
	for m: Material in groups:
		var st: SurfaceTool = groups[m]
		var out := MeshInstance3D.new()
		out.name = "Merged_%d" % count
		out.mesh = st.commit()
		out.material_override = m
		if visibility_end > 0.0:
			out.visibility_range_end = visibility_end
		root.add_child(out)
		count += 1
	return count

static func _moving(n: Node, root: Node) -> bool:
	var c := n
	while c != null and c != root:
		if c.has_meta("spin"):
			return true
		c = c.get_parent()
	return false

static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
