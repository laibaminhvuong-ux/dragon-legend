class_name WorldTerrain
extends RefCounted
# Terrain for one world, sampled from Codex's RuleZone: chunked meshes (64 m) on a regular grid, ground-type
# weights per vertex for the splat shader, void cells left out (paths and floating worlds), and collision built
# from the very same triangles so the player stands exactly on what is drawn.
#   COLOR = (grass, dirt, rock, sand)   UV2 = (snow/white, forest floor)

const CHUNK := 64.0
const CELL := {"low": 4.0, "medium": 3.0, "high": 2.0}
const SHADER := preload("res://world/shaders/terrain.gdshader")

## Bump when the grid format or the splat weights change: old caches/bakes are then ignored.
const GRID_VERSION := 3   # 3: travel pads keep the town/site flattening they sit in (RuleZone._tp_base)
const BAKED_DIR := "res://world/baked"
static var cache_dir := "user://cache/terrain"

static func build(zone: RefCounted, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var grid := grid_for(zone, quality)
	root.set_meta("grid", grid)
	var mat := material(zone)
	if zone.def.terrain.has("path"):  # a narrow road over the void: a ribbon that follows its curve
		_path_ribbon(root, zone, mat)
		return root
	var n: int = grid.n
	var cell: float = grid.cell
	var per := int(CHUNK / cell)
	var floor_y: float = float(zone.kill_y) if zone.kill_y != null else -100.0
	for cj in range(0, n, per):
		for ci in range(0, n, per):
			var mesh := _chunk(grid, ci, cj, mini(per, n - ci), mini(per, n - cj), floor_y)
			if mesh == null:
				continue
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.name = "Chunk_%d_%d" % [ci / per, cj / per]
			root.add_child(mi)
			var body := StaticBody3D.new()
			body.name = mi.name + "_Body"
			var shape := CollisionShape3D.new()
			shape.shape = mesh.create_trimesh_shape()
			body.add_child(shape)
			root.add_child(body)
	return root

## The sampled grid for a world: from the game's baked files, else this PC's cache, else sampled from the
## rules (slow: several seconds) and cached. { n, cell, half, h, col, extra, from_cache }
static func grid_for(zone: RefCounted, quality: String) -> Dictionary:
	var key := cache_key(zone, quality)
	for path in ["%s/%s.grid" % [BAKED_DIR, key], "%s/%s.grid" % [cache_dir, key]]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
			if f != null:
				var g: Variant = f.get_var()
				f.close()
				if g is Dictionary and g.get("key") == key:
					g.from_cache = true
					return g
	var grid := sample_grid(zone, quality)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	save_grid(grid, "%s/%s.grid" % [cache_dir, key])
	return grid

static func save_grid(grid: Dictionary, path: String) -> void:
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f != null:
		var g := grid.duplicate()
		g.erase("from_cache")
		f.store_var(g)
		f.close()

## world + quality + a hash of the world's recipe and the grid version: any change misses the cache.
static func cache_key(zone: RefCounted, quality: String) -> String:
	return "%s_%s_%08x" % [zone.id, quality, hash(JSON.stringify(zone.def, "", true) + str(GRID_VERSION)) & 0xffffffff]

## Samples heights and ground weights from the rules on a regular grid.
static func sample_grid(zone: RefCounted, quality: String) -> Dictionary:
	var cell: float = CELL.get(quality, 2.0)
	var half: float = zone.size / 2.0
	var n := int(ceil(zone.size / cell))
	var h := PackedFloat32Array(); h.resize((n + 1) * (n + 1))
	var col := PackedColorArray(); col.resize(h.size())
	var extra := PackedVector2Array(); extra.resize(h.size())
	if not zone.def.terrain.has("path"):  # path worlds are a ribbon; their grid stays flat (no grass anyway)
		for j in n + 1:
			for i in n + 1:
				var x := -half + i * cell
				var z := -half + j * cell
				var k := j * (n + 1) + i
				h[k] = zone.height_at(x, z)
				var w := _weights(zone, x, z)
				col[k] = w[0]
				extra[k] = w[1]
	return {"key": cache_key(zone, quality), "n": n, "cell": cell, "half": half, "h": h, "col": col, "extra": extra}

## Height and ground weights at (x, z) from a terrain grid (bilinear): { y, grass, dirt, rock, sand, snow, forest }.
static func sample(grid: Dictionary, x: float, z: float) -> Dictionary:
	var n: int = grid.n
	var cell: float = grid.cell
	var fx := clampf((x + float(grid.half)) / cell, 0.0, n - 0.001)
	var fz := clampf((z + float(grid.half)) / cell, 0.0, n - 0.001)
	var i := int(fx); var j := int(fz)
	var u := fx - i; var v := fz - j
	var k := j * (n + 1) + i
	var hh: PackedFloat32Array = grid.h
	var cc: PackedColorArray = grid.col
	var ee: PackedVector2Array = grid.extra
	var y := lerpf(lerpf(hh[k], hh[k + 1], u), lerpf(hh[k + n + 1], hh[k + n + 2], u), v)
	var c := cc[k].lerp(cc[k + 1], u).lerp(cc[k + n + 1].lerp(cc[k + n + 2], u), v)
	var e := ee[k].lerp(ee[k + 1], u).lerp(ee[k + n + 1].lerp(ee[k + n + 2], u), v)
	return {"y": y, "grass": c.r, "dirt": c.g, "rock": c.b, "sand": c.a, "snow": e.x, "forest": e.y}

static func _weights(zone: RefCounted, x: float, z: float) -> Array:
	var s: String = zone.surface_at(x, z)
	var c := Color(0, 0, 0, 0)
	var e := Vector2.ZERO
	match s:
		"grass": c.r = 1.0
		"dirt": c.g = 1.0
		"rock": c.b = 1.0
		"sand", "water", "stone": c.a = 1.0  # stone floors use the fine sand scan, tinted pale (see material)
		"snow", "white": e.x = 1.0
		_: c.b = 1.0
	if s == "grass":
		e.y = clampf((zone.forest_at(x, z) - 0.05) * 3.0, 0.0, 1.0)
	return [c, e]

## One chunk as an indexed mesh straight from the grid (much faster than SurfaceTool). Void quads are skipped.
static func _chunk(grid: Dictionary, ci: int, cj: int, w: int, d: int, floor_y: float) -> ArrayMesh:
	var n: int = grid.n
	var cell: float = grid.cell
	var half: float = grid.half
	var h: PackedFloat32Array = grid.h
	var col: PackedColorArray = grid.col
	var extra: PackedVector2Array = grid.extra
	var verts := PackedVector3Array(); var norms := PackedVector3Array()
	var cols := PackedColorArray(); var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var stride := w + 1
	for j in range(cj, cj + d + 1):
		for i in range(ci, ci + w + 1):
			var k := j * (n + 1) + i
			verts.append(Vector3(-half + i * cell, h[k], -half + j * cell))
			norms.append(_normal(h, n, i, j, cell))
			cols.append(col[k])
			uv2.append(extra[k])
	for j in d:
		for i in w:
			var a := j * stride + i
			var gk := (cj + j) * (n + 1) + ci + i
			if h[gk] <= floor_y or h[gk + 1] <= floor_y or h[gk + n + 1] <= floor_y or h[gk + n + 2] <= floor_y:
				continue  # void: nothing to stand on here
			idx.append_array(PackedInt32Array([a, a + 1, a + stride + 1, a, a + stride + 1, a + stride]))
	if idx.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

## Path worlds (Serpent Road): the road surface plus stone edges dropping away on both sides, in 64 m pieces,
## each with collision from the same triangles.
static func _path_ribbon(root: Node3D, zone: RefCounted, mat: Material) -> void:
	var p: Dictionary = zone.def.terrain.path
	if p.get("serpent", false):   # B3 opt-in: the road is the serpent's back (default off)
		_serpent_road(root, zone, p)
		return
	var half_w: float = float(p.width) / 2.0
	var z0: float = float(p.get("from", -zone.size / 2.0))
	var z1: float = float(p.get("to", zone.size / 2.0))
	var piece := 0
	var z := z0
	while z < z1:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var zz := z
		while zz < minf(z + CHUNK, z1):
			var a := _road_edge(zone, zz, half_w)
			var b := _road_edge(zone, minf(zz + 1.0, z1), half_w)
			# road surface (dirt/grass weights from the rules)
			for q in [[a.l, a.r, b.r], [a.l, b.r, b.l]]:
				for v: Vector3 in q:
					var w := _weights(zone, zone.path_centre(v.z), v.z)
					st.set_color(w[0]); st.set_uv2(w[1]); st.set_normal(Vector3.UP); st.add_vertex(v)
			# stone edges: 1.6 m sides going down
			for side in [[a.l, b.l, -1.0], [a.r, b.r, 1.0]]:
				var top0: Vector3 = side[0]; var top1: Vector3 = side[1]
				var down := Vector3(0, -1.6, 0)
				var n := (top1 - top0).cross(Vector3.UP).normalized() * -float(side[2])
				for v in [top0, top1, top1 + down, top0, top1 + down, top0 + down]:
					st.set_color(Color(0, 0, 1, 0)); st.set_uv2(Vector2.ZERO); st.set_normal(n); st.add_vertex(v)
			zz += 1.0
		var mesh := st.commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Road_%d" % piece
		root.add_child(mi)
		var body := StaticBody3D.new()
		body.name = mi.name + "_Body"
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		root.add_child(body)
		piece += 1
		z += CHUNK

## Serpent Road as the snake's body (terrain.path.serpent: true; B3, audit 106): lilac stone paving on top, a scaled
## round belly under it, saw-tooth dorsal fins along one edge (path.spikes: "right" (default) | "left" | "both" |
## "none"). Same 64 m pieces and road collision as the plain ribbon; materials from LandmarksDivine.
static func _serpent_road(root: Node3D, zone: RefCounted, p: Dictionary) -> void:
	var half_w: float = float(p.width) / 2.0
	var z0: float = float(p.get("from", -zone.size / 2.0))
	var z1: float = float(p.get("to", zone.size / 2.0))
	var spikes: String = str(p.get("spikes", "right"))
	var paving: ShaderMaterial = LandmarksDivine.serpent_paving()
	paving.set_shader_parameter("half_w", half_w)
	var th0 := 0.95                                   # belly arc starts this far (rad) from straight up
	var rb := half_w / sin(th0)
	var drop := rb * cos(th0) + 0.05
	var ring := 14
	var along := 0.0
	var piece := 0
	var z := z0
	while z < z1:
		var top := SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES)
		var belly := SurfaceTool.new(); belly.begin(Mesh.PRIMITIVE_TRIANGLES)
		var fins := SurfaceTool.new(); fins.begin(Mesh.PRIMITIVE_TRIANGLES)
		var zz := z
		while zz < minf(z + CHUNK, z1):
			var zb := minf(zz + 1.0, z1)
			var a := _road_edge(zone, zz, half_w)
			var b := _road_edge(zone, zb, half_w)
			var ca: Vector3 = (a.l + a.r) * 0.5; var cb: Vector3 = (b.l + b.r) * 0.5
			var step := ca.distance_to(cb)
			for q in [[a.l, a.r, b.r], [a.l, b.r, b.l]]:
				for v: Vector3 in q:
					var on_b: bool = v == b.l or v == b.r
					var across: float = -half_w if (v == a.l or v == b.l) else half_w
					top.set_normal(Vector3.UP); top.set_uv(Vector2(across, along + (step if on_b else 0.0))); top.add_vertex(v)
			var xa: Vector3 = (a.r - a.l).normalized(); var xb: Vector3 = (b.r - b.l).normalized()
			if zz == z0:
				_serpent_cap(belly, ca, xa, rb, drop, th0, ring, cb - ca)
			if zb >= z1:
				_serpent_cap(belly, cb, xb, rb, drop, th0, ring, cb - ca)
			for k in ring:
				var t0 := th0 + (TAU - 2.0 * th0) * float(k) / ring
				var t1 := th0 + (TAU - 2.0 * th0) * float(k + 1) / ring
				var quad := []
				for e in [[ca, xa, t0, 0.0], [ca, xa, t1, 0.0], [cb, xb, t1, step], [cb, xb, t0, step]]:
					var c: Vector3 = e[0]; var x: Vector3 = e[1]; var t: float = e[2]
					var n: Vector3 = x * sin(t) + Vector3.UP * cos(t)
					quad.append([c + Vector3(0, -drop, 0) + n * rb, n, Vector2(along + float(e[3]), t * rb)])
				for i in [0, 1, 2, 0, 2, 3]:
					var vq: Array = quad[i]
					belly.set_normal(vq[1]); belly.set_uv(vq[2]); belly.add_vertex(vq[0])
			if spikes != "none" and fmod(zz - z0, 2.0) < 0.5:
				for side in ([1.0, -1.0] if spikes == "both" else ([-1.0] if spikes == "left" else [1.0])):
					var ea: Vector3 = a.r if side > 0 else a.l
					var eb: Vector3 = b.r if side > 0 else b.l
					var out: Vector3 = (xa + xb).normalized() * float(side)
					var tip: Vector3 = (ea + eb) * 0.5 + out * 0.55 + Vector3(0, 0.9, 0) + (eb - ea) * 0.35
					var fn: Vector3 = (eb - ea).cross(tip - ea).normalized()
					for v in [ea + Vector3(0, -0.15, 0), eb + Vector3(0, -0.15, 0), tip]:
						fins.set_normal(fn); fins.add_vertex(v)
			along += step
			zz += 1.0
		var mesh := top.commit()
		mesh.surface_set_material(0, paving)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Road_%d" % piece
		root.add_child(mi)
		var bm := belly.commit()
		bm.surface_set_material(0, LandmarksDivine.serpent_scales())
		var bi := MeshInstance3D.new()
		bi.mesh = bm
		bi.name = "Belly_%d" % piece
		root.add_child(bi)
		if spikes != "none":
			var fm := fins.commit()
			if fm.get_surface_count() > 0:
				fm.surface_set_material(0, LandmarksDivine.serpent_spike())
				var fi := MeshInstance3D.new()
				fi.mesh = fm
				fi.name = "Fins_%d" % piece
				root.add_child(fi)
		var body := StaticBody3D.new()
		body.name = mi.name + "_Body"
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		root.add_child(body)
		piece += 1
		z += CHUNK

## Flat end cap closing the serpent body at a road end (centre c, across x, facing along dir).
static func _serpent_cap(st: SurfaceTool, c: Vector3, x: Vector3, rb: float, drop: float, th0: float, ring: int, dir: Vector3) -> void:
	var mid := c + Vector3(0, -drop, 0)
	var n := dir.normalized()
	var pts: Array[Vector3] = []
	for k in ring + 1:
		var t := th0 + (TAU - 2.0 * th0) * float(k) / ring
		pts.append(mid + (x * sin(t) + Vector3.UP * cos(t)) * rb)
	pts.append(pts[0])
	for k in pts.size() - 1:
		for v: Vector3 in [mid, pts[k], pts[k + 1]]:
			st.set_normal(n); st.set_uv(Vector2((v - mid).x, (v - mid).y)); st.add_vertex(v)

static func _road_edge(zone: RefCounted, z: float, half_w: float) -> Dictionary:
	var c: float = zone.path_centre(z)
	var dc: float = zone.path_centre(z + 0.5) - zone.path_centre(z - 0.5)
	var n := Vector2(1.0, -dc).normalized()  # across the road
	var y: float = zone.height_at(c, z)
	return {"l": Vector3(c - n.x * half_w, y, z - n.y * half_w), "r": Vector3(c + n.x * half_w, y, z + n.y * half_w)}

static func _normal(h: PackedFloat32Array, n: int, i: int, j: int, cell: float) -> Vector3:
	var l := h[j * (n + 1) + maxi(i - 1, 0)]
	var r := h[j * (n + 1) + mini(i + 1, n)]
	var u := h[maxi(j - 1, 0) * (n + 1) + i]
	var dn := h[mini(j + 1, n) * (n + 1) + i]
	return Vector3(l - r, 2.0 * cell, u - dn).normalized()

## The splat material for a world: CC0 textures (or flat colours) tinted by the world's biome.
static func material(zone: RefCounted) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var M: GDScript = load("res://world/materials.gd")
	var kinds := ["grass", "dirt", "rock", "sand", "snow", "forest"]
	m.set_shader_parameter("has_textures", M.has_textures())
	for kind in kinds:
		var g: Dictionary = M.ground(kind)
		m.set_shader_parameter("%s_albedo" % kind, g.albedo)
		m.set_shader_parameter("%s_normal" % kind, g.normal)
		m.set_shader_parameter("%s_color" % kind, g.color)
	# the leafy CC0 lawn scan is autumn-ish: lean it towards a lush green field, then apply the world's own tint
	var base := {"grass": Color(0.84, 1.02, 0.7), "dirt": Color(1, 1, 1), "rock": Color(1, 1, 1), "sand": Color(1, 1, 1)}
	var tints: Dictionary = zone.biome.get("tints", {})
	for kind: String in base:
		var c: Color = base[kind]
		if tints.get(kind) is Array and tints[kind].size() >= 3:
			var t: Array = tints[kind]
			c = Color(c.r * float(t[0]), c.g * float(t[1]), c.b * float(t[2]))
		m.set_shader_parameter("%s_tint" % kind, c)
	if zone.ground == "stone":  # palace platforms and arenas: polished pale tiles drawn by the shader
		m.set_shader_parameter("tiled_floor", true)
	if zone.ground == "white":
		m.set_shader_parameter("snow_color", Color(0.96, 0.96, 0.94))
	return m
