class_name WorldTerrain
extends RefCounted
# Terrain for one world, sampled from Codex's RuleZone: chunked meshes (64 m) on a regular grid, ground-type
# weights per vertex for the splat shader, void cells left out (paths and floating worlds), and collision built
# from the very same triangles so the player stands exactly on what is drawn.
#   COLOR = (grass, dirt, rock, sand)   UV2 = (snow/white, forest floor)

const CHUNK := 64.0
const CELL := {"low": 4.0, "medium": 3.0, "high": 2.0}
const SHADER := preload("res://world/shaders/terrain.gdshader")

static func build(zone: RefCounted, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var cell: float = CELL.get(quality, 2.0)
	var half: float = zone.size / 2.0
	var n := int(ceil(zone.size / cell))
	var floor_y: float = float(zone.kill_y) if zone.kill_y != null else -100.0
	# sample the grid once: heights, splat weights
	var h := PackedFloat32Array(); h.resize((n + 1) * (n + 1))
	var col := PackedColorArray(); col.resize(h.size())
	var extra := PackedVector2Array(); extra.resize(h.size())
	for j in n + 1:
		for i in n + 1:
			var x := -half + i * cell
			var z := -half + j * cell
			var k := j * (n + 1) + i
			h[k] = zone.height_at(x, z)
			var w := _weights(zone, x, z)
			col[k] = w[0]
			extra[k] = w[1]
	# keep the sampled grid: grass and other placement read heights/weights from it instead of re-running the rules
	root.set_meta("grid", {"n": n, "cell": cell, "half": half, "h": h, "col": col, "extra": extra})
	var mat := material(zone)
	var per := int(CHUNK / cell)
	for cj in range(0, n, per):
		for ci in range(0, n, per):
			var mesh := _chunk(h, col, extra, n, ci, cj, mini(per, n - ci), mini(per, n - cj), cell, half, floor_y)
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
		"rock", "stone": c.b = 1.0
		"sand", "water": c.a = 1.0
		"snow", "white": e.x = 1.0
		_: c.b = 1.0
	if s == "grass":
		e.y = clampf((zone.forest_at(x, z) - 0.05) * 3.0, 0.0, 1.0)
	return [c, e]

static func _chunk(h: PackedFloat32Array, col: PackedColorArray, extra: PackedVector2Array, n: int, ci: int, cj: int, w: int, d: int, cell: float, half: float, floor_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := 0
	for j in range(cj, cj + d):
		for i in range(ci, ci + w):
			var k00 := j * (n + 1) + i
			var k10 := k00 + 1
			var k01 := k00 + n + 1
			var k11 := k01 + 1
			if h[k00] <= floor_y or h[k10] <= floor_y or h[k01] <= floor_y or h[k11] <= floor_y:
				continue  # void: nothing to stand on here
			for k in [k00, k10, k11, k00, k11, k01]:
				var gi: int = k % (n + 1)
				var gj: int = k / (n + 1)
				st.set_color(col[k])
				st.set_uv2(extra[k])
				st.set_normal(_normal(h, n, gi, gj, cell))
				st.add_vertex(Vector3(-half + gi * cell, h[k], -half + gj * cell))
			tris += 2
	if tris == 0:
		return null
	return st.commit()

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
	if zone.ground == "white":
		m.set_shader_parameter("snow_color", Color(0.96, 0.96, 0.94))
	return m
