class_name Geo
extends RefCounted
# A small mesh kit: appends transformed primitives into one surface (one draw call per piece set).
# Used for hair, outfit extras and race features; results are cached by the callers.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _i := PackedInt32Array()

## Appends mesh arrays (vertex, normal, index) through a transform.
func add_arrays(arr: Array, xf := Transform3D.IDENTITY) -> void:
	var nb := xf.basis.inverse().transposed()
	var base := _v.size()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for k in verts.size():
		_v.append(xf * verts[k])
		_n.append((nb * norms[k]).normalized())
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for k in idx.size():
		_i.append(base + idx[k])

func add_primitive(m: PrimitiveMesh, xf := Transform3D.IDENTITY) -> void:
	add_arrays(m.get_mesh_arrays(), xf)

func sphere(xf: Transform3D, r: float, rings := 12, segs := 18) -> void:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.rings = rings; s.radial_segments = segs
	add_primitive(s, xf)

func cylinder(xf: Transform3D, r_top: float, r_bot: float, h: float, segs := 18) -> void:
	var c := CylinderMesh.new(); c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = segs; c.rings = 1
	add_primitive(c, xf)

func torus(xf: Transform3D, ring_r: float, tube_r: float, segs := 28, sides := 10) -> void:
	var t := TorusMesh.new(); t.inner_radius = ring_r - tube_r; t.outer_radius = ring_r + tube_r; t.rings = segs; t.ring_segments = sides
	add_primitive(t, xf)

func box(xf: Transform3D, size: Vector3) -> void:
	var b := BoxMesh.new(); b.size = size
	add_primitive(b, xf)

## A sphere cap from the top (polar angle 0) down to theta_max(azimuth); azimuth 0 faces +Z.
func cap(xf: Transform3D, r: float, theta_front: float, theta_back: float, rings := 12, segs := 28) -> void:
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	for ri in rings + 1:
		for si in segs + 1:
			var a := TAU * float(si) / segs
			var tmax := lerpf(theta_back, theta_front, (cos(a) + 1.0) * 0.5)
			var th := tmax * float(ri) / rings
			var d := Vector3(sin(th) * sin(a), cos(th), sin(th) * cos(a))
			_v.append(xf * (d * r)); _n.append((nb * d).normalized())
	for ri in rings:
		for si in segs:
			var a0 := base + ri * (segs + 1) + si
			var b0 := a0 + segs + 1
			_i.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])

## One spike of anime hair (port of the JS spike): a flattened, slightly curved cone from base along dir.
func spike(base: Vector3, length: float, rad: float, dir: Vector3, up := 0.0) -> void:
	var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = rad; c.height = length; c.radial_segments = 7; c.rings = 4; c.cap_top = false
	var arr := c.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		var p := verts[k]; p.y += length * 0.5
		var t := p.y / length
		verts[k] = Vector3(p.x * 1.25, p.y, p.z * 0.75 + t * t * up * length)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = _normals(verts, arr[Mesh.ARRAY_INDEX])
	var q := Quaternion(Vector3.UP, dir.normalized()) if dir.normalized().dot(Vector3.UP) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	add_arrays(arr, Transform3D(Basis(q), base))

## A tapered tube along a Catmull-Rom curve (tails, antennae).
func tube(points: PackedVector3Array, r0: float, r1: float, seg := 24, sides := 10, xf := Transform3D.IDENTITY) -> void:
	var curve := Curve3D.new()
	for k in points.size():
		var p := points[k]
		var prev := points[maxi(k - 1, 0)]; var next := points[mini(k + 1, points.size() - 1)]
		var tan := (next - prev) / 6.0
		curve.add_point(p, -tan, tan)
	var length := curve.get_baked_length()
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	var normal_ref := Vector3.FORWARD
	for i in seg + 1:
		var t := float(i) / seg
		var c := curve.sample_baked(t * length, true)
		var ahead := curve.sample_baked(minf(t * length + 0.01, length), true) - curve.sample_baked(maxf(t * length - 0.01, 0.0), true)
		var tan := ahead.normalized() if ahead.length() > 1e-6 else Vector3.UP
		var side := tan.cross(normal_ref)
		if side.length() < 1e-4: side = tan.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tan).normalized()
		normal_ref = up
		var r := lerpf(r0, r1, t)
		for s in sides + 1:
			var a := TAU * float(s) / sides
			var d := side * cos(a) + up * sin(a)
			_v.append(xf * (c + d * r)); _n.append((nb * d).normalized())
	for i in seg:
		for s in sides:
			var a0 := base + i * (sides + 1) + s
			var b0 := a0 + sides + 1
			_i.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
	# close the tip
	var tip_c := _v.size()
	_v.append(xf * curve.sample_baked(length)); _n.append((nb * (points[points.size() - 1] - points[points.size() - 2])).normalized())
	var last := base + seg * (sides + 1)
	for s in sides:
		_i.append_array([last + s, last + s + 1, tip_c])

## A gently curved, double-sided sheet hanging down from its top edge (capes).
func sheet(xf: Transform3D, width: float, height: float, cols := 6, rows := 10) -> void:
	for side in [1.0, -1.0]:
		var base := _v.size()
		for r in rows + 1:
			for c in cols + 1:
				var x := (float(c) / cols - 0.5) * width
				var y := -float(r) / rows * height
				var z := -absf(x) * 0.25 - (-y) * 0.08
				_v.append(xf * Vector3(x, y, z))
				_n.append((xf.basis * Vector3(0, 0, side)).normalized())
		for r in rows:
			for c in cols:
				var a0 := base + r * (cols + 1) + c
				var b0 := a0 + cols + 1
				if side > 0: _i.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
				else: _i.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])

func is_empty() -> bool:
	return _v.is_empty()

func mesh() -> ArrayMesh:
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v; arr[Mesh.ARRAY_NORMAL] = _n; arr[Mesh.ARRAY_INDEX] = _i
	var m := ArrayMesh.new()
	if not _v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func _normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array(); n.resize(verts.size())
	for k in range(0, idx.size(), 3):
		var a := verts[idx[k]]; var b := verts[idx[k + 1]]; var c := verts[idx[k + 2]]
		var f := (b - a).cross(c - a)
		n[idx[k]] += f; n[idx[k + 1]] += f; n[idx[k + 2]] += f
	for k in n.size():
		n[k] = n[k].normalized() if n[k].length() > 1e-9 else Vector3.UP
	return n
