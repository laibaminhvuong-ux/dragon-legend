class_name MeshMerge
extends RefCounted
# Combines every static MeshInstance3D under a node into one mesh per material, so a whole town costs a handful
# of draw calls instead of thousands. Pieces under a node marked with meta "spin" (moving parts) are left alone.

static func merge(root: Node3D, visibility_end := 0.0) -> int:
	var groups := {}   # material -> [verts, normals, indices]
	var done: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or _moving(mi, root):
			continue
		var xf := _relative(mi, root)
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.material_override if mi.material_override != null else _surface_material(mi.mesh, s)
			if not groups.has(m):
				groups[m] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
			_append(groups[m], mi.mesh, s, xf)
		done.append(mi)
	for mi in done:
		mi.get_parent().remove_child(mi)
		mi.free()
	var count := 0
	for m: Material in groups:
		var g: Array = groups[m]
		if (g[0] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g[0]
		arrays[Mesh.ARRAY_NORMAL] = g[1]
		arrays[Mesh.ARRAY_INDEX] = g[2]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out := MeshInstance3D.new()
		out.name = "Merged_%d" % count
		out.mesh = mesh
		out.material_override = m
		if visibility_end > 0.0:
			out.visibility_range_end = visibility_end
		root.add_child(out)
		count += 1
	return count

static func _surface_material(mesh: Mesh, s: int) -> Material:
	if mesh is PrimitiveMesh:
		return (mesh as PrimitiveMesh).material
	return mesh.surface_get_material(s)

## Shape cache (perf, 2026-11-05): reading a primitive's arrays back from the renderer is slow (a GPU round trip each,
## thousands per town), so each primitive is reduced to a unit shape read once and scaled by the transform instead.
static var _shapes: Dictionary = {}
static var _lock := Mutex.new()

static func _unit(key: String, make: Callable) -> Array:
	_lock.lock()
	var hit: Variant = _shapes.get(key)
	_lock.unlock()
	if hit != null:
		return hit
	var pm: PrimitiveMesh = make.call()
	var a: Array = pm.get_mesh_arrays()
	if a.is_empty() or a[Mesh.ARRAY_VERTEX] == null:
		push_error("empty unit shape " + key)
		return [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
	var shape := [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX]]
	_lock.lock()
	_shapes[key] = shape
	_lock.unlock()
	return shape

## The mesh's triangles as [verts, normals, indices] for a unit shape plus the scale that restores its size.
static func _shape(mesh: Mesh, s: int) -> Array:
	if mesh is BoxMesh:
		var bm := mesh as BoxMesh
		var key := "box:%d:%d:%d" % [bm.subdivide_width, bm.subdivide_height, bm.subdivide_depth]
		return [_unit(key, func() -> PrimitiveMesh:
			var u := BoxMesh.new(); u.subdivide_width = bm.subdivide_width; u.subdivide_height = bm.subdivide_height
			u.subdivide_depth = bm.subdivide_depth; return u), bm.size, true]
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		var r := maxf(c.top_radius, c.bottom_radius)
		if r <= 0.0 or c.height <= 0.0:
			return [[PackedVector3Array(), PackedVector3Array(), PackedInt32Array()], Vector3.ONE, false]
		var tr := snappedf(c.top_radius / r, 0.01); var br := snappedf(c.bottom_radius / r, 0.01)
		var key := "cyl:%.2f:%.2f:%d:%d:%s:%s" % [tr, br, c.radial_segments, c.rings, c.cap_top, c.cap_bottom]
		return [_unit(key, func() -> PrimitiveMesh:
			var u := CylinderMesh.new(); u.top_radius = tr; u.bottom_radius = br; u.height = 1.0
			u.radial_segments = c.radial_segments; u.rings = c.rings; u.cap_top = c.cap_top; u.cap_bottom = c.cap_bottom
			return u), Vector3(r, c.height, r), false]
	if mesh is SphereMesh:
		var sp := mesh as SphereMesh
		if sp.radius <= 0.0:
			return [[PackedVector3Array(), PackedVector3Array(), PackedInt32Array()], Vector3.ONE, false]
		var hk := snappedf(sp.height / sp.radius, 0.01)
		var key := "sph:%.2f:%d:%d:%s" % [hk, sp.radial_segments, sp.rings, sp.is_hemisphere]
		return [_unit(key, func() -> PrimitiveMesh:
			var u := SphereMesh.new(); u.radius = 1.0; u.height = hk; u.radial_segments = sp.radial_segments
			u.rings = sp.rings; u.is_hemisphere = sp.is_hemisphere; return u), Vector3(sp.radius, sp.radius, sp.radius), false]
	var a: Array = mesh.surface_get_arrays(s)
	return [[a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX]], Vector3.ONE, false]

static func _append(g: Array, mesh: Mesh, s: int, xf: Transform3D) -> void:
	var sh := _shape(mesh, s)
	var unit: Array = sh[0]
	var verts: PackedVector3Array = unit[0]
	if verts.is_empty():
		return
	var scale: Vector3 = sh[1]
	var full := xf * Transform3D(Basis.from_scale(scale), Vector3.ZERO)
	# packed arrays copy on write: modify locals, then store them back
	var gv: PackedVector3Array = g[0]
	var gn: PackedVector3Array = g[1]
	var out: PackedInt32Array = g[2]
	g[0] = PackedVector3Array(); g[1] = PackedVector3Array(); g[2] = PackedInt32Array()   # drop the shared ref (no copy)
	var base: int = gv.size()
	gv.append_array(full * verts)
	g[0] = gv
	var normals: PackedVector3Array = unit[1]
	var rot := Transform3D(full.basis.orthonormalized(), Vector3.ZERO)
	var nb := full.basis.get_scale()
	var uniform := is_equal_approx(nb.x, nb.y) and is_equal_approx(nb.y, nb.z)
	if bool(sh[2]) or uniform:
		gn.append_array(rot * normals)   # box faces / uniform scale: rotation is exact
	else:
		var nn := Transform3D(full.basis.inverse().transposed(), Vector3.ZERO) * normals
		for k in nn.size():
			nn[k] = nn[k].normalized()
		gn.append_array(nn)
	g[1] = gn
	var idx: PackedInt32Array = unit[2]
	var start := out.size()
	if idx.is_empty():
		out.resize(start + verts.size())
		for k in verts.size():
			out[start + k] = base + k
	else:
		out.resize(start + idx.size())
		for k in idx.size():
			out[start + k] = base + idx[k]
	g[2] = out

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
