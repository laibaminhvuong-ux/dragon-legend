class_name WorldProps
extends RefCounted
# Trees, rocks, bushes and stones from Codex's zone.props() (JS-shaped Dictionaries: x, y, z, scale, rot / rx ry rz,
# variant). Rocks, shrubs and dead trees are CC0 scans (Poly Haven) shown as MeshInstances so Godot's automatic
# LODs apply; living trees (broadleaf, pine, palm, Nameck ajisa, crystal) are built here as low-poly meshes with a
# wind-swaying foliage shader and drawn as MultiMeshes; small stones are instanced.

const MODELS := "res://assets/models"
const FOLIAGE := preload("res://world/shaders/foliage.gdshader")
const ROCK_IDS := ["boulder_01", "namaqualand_boulder_04", "rock_moss_set_01"]

static func build(zone: RefCounted, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "Props"
	var p: RefCounted = zone.props()
	var kind: String = str(zone.biome.get("trees", "broadleaf"))
	var far := 700.0 if quality == "high" else 400.0
	_trees(root, p.trees, kind, far)
	_scanned(root, p.rocks, _rock_meshes(), far * 0.7, true)
	_scanned(root, p.bushes, _model_meshes("shrub_03"), far * 0.5, false)
	if zone.ground != "stone":  # pebbles look wrong on polished tile floors (they're decoration only)
		_stones(root, p.stones)
	return root

# --- trees ---------------------------------------------------------------------------------------------------
static func _trees(root: Node3D, trees: Array, kind: String, far: float) -> void:
	if trees.is_empty() or kind == "none":
		return
	if kind == "dead":
		_scanned(root, trees, _model_meshes("dead_tree_trunk"), far, false, 6.0)
		return
	var variants: Array[ArrayMesh] = []
	for v in 3:
		variants.append(tree_mesh(kind, v))
	var by_variant: Array = [[], [], []]
	for t: Dictionary in trees:
		by_variant[int(t.get("variant", 0)) % 3].append(t)
	for v in 3:
		var tiles := _tiles(by_variant[v], TILE)
		for key: Vector2i in tiles:
			var tile: Array = tiles[key]
			var xfs: Array[Transform3D] = []
			for t: Dictionary in tile:
				var b := Basis(Vector3.UP, float(t.get("rot", 0.0))).scaled(Vector3.ONE * float(t.get("scale", 1.0)))
				xfs.append(Transform3D(b, Vector3(t.x, t.y, t.z)))
			root.add_child(_multi("Trees_%s_%d_%d_%d" % [kind, v, key.x, key.y], variants[v], xfs, far, true))

## Props in square tiles (so tiles out of range are not drawn at all): Vector2i -> Array of items.
const TILE := 256.0
static func _tiles(items: Array, size: float) -> Dictionary:
	var out := {}
	for it: Dictionary in items:
		var key := Vector2i(floori(float(it.x) / size), floori(float(it.z) / size))
		if not out.has(key):
			out[key] = []
		out[key].append(it)
	return out

static func _multi(node_name: String, mesh: Mesh, xfs: Array[Transform3D], far: float, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.visibility_range_end = far
	mmi.visibility_range_end_margin = 40.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## A low-poly tree: bark then foliage surfaces (crystals: foliage only).
static func tree_mesh(kind: String, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 101
	var bark := SurfaceTool.new(); bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := SurfaceTool.new(); leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_col := Color(0.24, 0.45, 0.16)
	match kind:
		"pine":
			var h := rng.randf_range(7.0, 10.0)
			_cylinder(bark, Vector3.ZERO, Vector3(0, h * 0.85, 0), 0.32, 0.08, 7)
			for i in 5:
				var y := h * (0.25 + i * 0.14)
				_cone(leaf, Vector3(0, y, 0), h * 0.32, (2.6 - i * 0.42) * rng.randf_range(0.9, 1.1), 9, rng)
			leaf_col = Color(0.12, 0.3, 0.14)
		"palm":
			var h := rng.randf_range(6.0, 8.5)
			var lean := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			var prev := Vector3.ZERO
			for s in 6:
				var t := float(s + 1) / 6.0
				var p := Vector3(0, h * t, 0) + lean * t * t
				_cylinder(bark, prev, p, 0.26 - t * 0.08, 0.24 - t * 0.08, 7)
				prev = p
			for f in 8:
				_frond(leaf, prev, f * TAU / 8.0 + rng.randf() * 0.3, rng)
			leaf_col = Color(0.26, 0.5, 0.16)
		"ajisa":  # Nameck: a thin pale trunk and one big round blue-green puff
			var h := rng.randf_range(5.5, 7.5)
			_cylinder(bark, Vector3.ZERO, Vector3(0, h, 0), 0.18, 0.12, 7)
			_puff(leaf, Vector3(0, h + 1.4, 0), 2.4 * rng.randf_range(0.9, 1.15), rng, 0.18)
			leaf_col = Color(0.33, 0.66, 0.63)
		"crystal":
			for c in 4:
				var a := rng.randf() * TAU
				var tilt := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.5)
				_prism(leaf, Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.8), (Vector3.UP + tilt).normalized(), rng.randf_range(2.0, 5.0), rng.randf_range(0.3, 0.6))
			leaf_col = Color(0.55, 0.75, 0.95)
		_:  # broadleaf
			var h := rng.randf_range(3.5, 5.0)
			_cylinder(bark, Vector3.ZERO, Vector3(0, h, 0), 0.34, 0.2, 8)
			for b in 3:
				var a := rng.randf() * TAU
				_cylinder(bark, Vector3(0, h * 0.7, 0), Vector3(cos(a) * 1.2, h + 0.6, sin(a) * 1.2), 0.14, 0.06, 6)
			for puff in 6:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.6, 1.6)
				_puff(leaf, Vector3(cos(a) * r, h + 0.8 + rng.randf_range(-0.4, 1.2), sin(a) * r), rng.randf_range(1.3, 2.0), rng, 0.28)
	var mesh := ArrayMesh.new()
	if kind != "crystal":  # crystals are all "foliage": no bark surface
		bark.commit(mesh)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.32, 0.24, 0.17) if kind != "ajisa" else Color(0.62, 0.6, 0.48)
		bm.roughness = 0.95
		mesh.surface_set_material(mesh.get_surface_count() - 1, bm)
	leaf.commit(mesh)
	var lm := ShaderMaterial.new()
	lm.shader = FOLIAGE
	lm.set_shader_parameter("leaf_color", leaf_col)
	lm.set_shader_parameter("glow", 0.8 if kind == "crystal" else 0.0)
	mesh.surface_set_material(mesh.get_surface_count() - 1, lm)
	return mesh

static func _cylinder(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP).normalized()
	var fwd := up.cross(side)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + fwd * sin(a0)
		var d1 := side * cos(a1) + fwd * sin(a1)
		var q := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		var n := [d0, d1, d1, d0]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n[k]); st.set_color(Color(0, 0, 0)); st.add_vertex(q[k])

static func _cone(st: SurfaceTool, base: Vector3, h: float, r: float, sides: int, rng: RandomNumberGenerator) -> void:
	var tip := base + Vector3(0, h, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0), -0.3 * rng.randf(), sin(a0)) * r
		var p1 := base + Vector3(cos(a1), -0.3 * rng.randf(), sin(a1)) * r
		var n := (p0 - tip).cross(p1 - tip).normalized() * -1.0
		for v in [tip, p1, p0]:
			st.set_normal((n + Vector3.UP * 0.4).normalized()); st.set_color(Color(1, 0, 0)); st.add_vertex(v)

static func _puff(st: SurfaceTool, centre: Vector3, r: float, rng: RandomNumberGenerator, bump: float) -> void:
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 1.7; s.radial_segments = 14; s.rings = 8
	var arr := s.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var seed_off := rng.randf() * 10.0
	for k in idx:
		var v: Vector3 = verts[k]
		var d := 1.0 + bump * sin(v.x * 3.1 + seed_off) * sin(v.y * 2.7) * sin(v.z * 3.3 + seed_off)
		st.set_normal(norms[k]); st.set_color(Color(1, 0, 0)); st.add_vertex(centre + v * d)

static func _frond(st: SurfaceTool, top: Vector3, a: float, rng: RandomNumberGenerator) -> void:
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x)
	var length := rng.randf_range(2.6, 3.6)
	var prev_c := top
	for s in 5:
		var t := float(s + 1) / 5.0
		var c := top + dir * length * t + Vector3(0, 0.5 * t - 1.6 * t * t, 0)
		var w0 := 0.45 * (1.0 - float(s) / 5.0) + 0.05
		var w1 := 0.45 * (1.0 - t) + 0.05
		var q := [prev_c - side * w0, prev_c + side * w0, c + side * w1, c - side * w1]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP); st.set_color(Color(1, 0, 0)); st.add_vertex(q[k])
		prev_c = c

static func _prism(st: SurfaceTool, base: Vector3, up: Vector3, h: float, r: float) -> void:
	var side := up.cross(Vector3.RIGHT).normalized()
	var fwd := up.cross(side)
	var tip := base + up * (h + r * 1.5)
	var top := base + up * h
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		var d0 := side * cos(a0) + fwd * sin(a0)
		var d1 := side * cos(a1) + fwd * sin(a1)
		var q := [base + d0 * r, base + d1 * r, top + d1 * r, top + d0 * r]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal((d0 + d1).normalized()); st.set_color(Color(1, 0, 0)); st.add_vertex(q[k])
		for v in [top + d0 * r, top + d1 * r, tip]:
			st.set_normal((d0 + d1 + up).normalized()); st.set_color(Color(1, 0, 0)); st.add_vertex(v)

# --- scanned models ------------------------------------------------------------------------------------------
static func _model_meshes(id: String) -> Array:
	var path := "%s/%s/%s.gltf" % [MODELS, id, id]
	if not ResourceLoader.exists(path):
		return []
	var scene: Node = (load(path) as PackedScene).instantiate()
	var out: Array = []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var aabb := m.get_aabb()
		out.append({"mesh": m, "size": maxf(aabb.size.x, aabb.size.z), "bottom": aabb.position.y})
	scene.free()
	return out

static func _rock_meshes() -> Array:
	var all: Array = []
	for id in ROCK_IDS:
		all.append_array(_model_meshes(id))
	return all

## Rocks and bushes from scanned models, one MultiMesh per model per tile, sized from the prop's scale.
static func _scanned(root: Node3D, items: Array, meshes: Array, far: float, tilt: bool, size := 2.0) -> void:
	if items.is_empty():
		return
	if meshes.is_empty():
		meshes = [{"mesh": _fallback_rock(), "size": 2.0, "bottom": -1.0}]
	var group := Node3D.new()
	group.name = "Scanned"
	root.add_child(group)
	var tiles := _tiles(items, TILE)
	for key: Vector2i in tiles:
		var per_mesh: Array = []
		for i in meshes.size():
			per_mesh.append([] as Array[Transform3D])
		for it: Dictionary in tiles[key]:
			var vi := int(it.get("variant", 0)) % meshes.size()
			var m: Dictionary = meshes[vi]
			var s := float(it.get("scale", 1.0)) * size / maxf(float(m.size), 0.01)
			var b := Basis.from_euler(Vector3(float(it.get("rx", 0.0)) * 0.2 if tilt else 0.0, float(it.get("ry", it.get("rot", 0.0))), float(it.get("rz", 0.0)) * 0.2 if tilt else 0.0))
			(per_mesh[vi] as Array[Transform3D]).append(Transform3D(b.scaled(Vector3.ONE * s), Vector3(it.x, float(it.y) - float(m.bottom) * s * 0.85, it.z)))
		for vi in meshes.size():
			var xfs: Array[Transform3D] = per_mesh[vi]
			if not xfs.is_empty():
				group.add_child(_multi("Scan_%d_%d_%d" % [vi, key.x, key.y], meshes[vi].mesh, xfs, far, tilt))

static func _stones(root: Node3D, stones: Array) -> void:
	if stones.is_empty():
		return
	var mesh := _fallback_rock()
	var tiles := _tiles(stones, 128.0)
	for key: Vector2i in tiles:
		var xfs: Array[Transform3D] = []
		for s: Dictionary in tiles[key]:
			var b := Basis.from_euler(Vector3(s.get("rx", 0.0), s.get("ry", 0.0), s.get("rz", 0.0))).scaled(Vector3.ONE * float(s.get("scale", 0.15)))
			xfs.append(Transform3D(b, Vector3(s.x, s.y, s.z)))
		root.add_child(_multi("Stones_%d_%d" % [key.x, key.y], mesh, xfs, 160.0, false))

static func _fallback_rock() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	_puff(st, Vector3.ZERO, 1.0, rng, 0.35)
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.44, 0.41)
	mat.roughness = 0.95
	m.surface_set_material(0, mat)
	return m
