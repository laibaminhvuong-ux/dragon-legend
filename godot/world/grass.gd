class_name WorldGrass
extends Node3D
# Grass blades streamed around a target (the camera or the player): 16 m chunks of MultiMesh clumps within a
# radius, placed on grass/forest ground from the terrain grid, swaying in the wind and shrinking away with
# distance (no popping). Density comes from the quality preset and the world's biome.grass (default 1).

const CHUNK := 16.0
const PRESET := {"low": {"density": 1.0, "radius": 40.0}, "medium": {"density": 2.2, "radius": 60.0}, "high": {"density": 3.6, "radius": 75.0}}
const SHADER := preload("res://world/shaders/grass.gdshader")

var target: Node3D
var _grid: Dictionary
var _density := 1.0
var _radius := 60.0
var _chunks: Dictionary = {}  # Vector2i -> MultiMeshInstance3D
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _timer := 0.0

static func create(terrain: Node3D, zone: RefCounted, quality := "high") -> WorldGrass:
	var g := WorldGrass.new()
	g.name = "Grass"
	var p: Dictionary = PRESET.get(quality, PRESET.high)
	g._grid = terrain.get_meta("grid")
	g._density = float(p.density) * float(zone.biome.get("grass", 1.0))
	g._radius = p.radius
	g._mesh = _clump_mesh()
	g._material = ShaderMaterial.new()
	g._material.shader = SHADER
	g._material.set_shader_parameter("fade_end", g._radius)
	var tints: Dictionary = zone.biome.get("tints", {})
	if tints.get("grass") is Array:
		var t: Array = tints.grass
		g._material.set_shader_parameter("tint", Color(float(t[0]), float(t[1]), float(t[2])))
	return g

func _process(delta: float) -> void:
	if target == null or _density <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	update_around(target.global_position)

## Builds chunks near `p` and frees far ones (also callable directly, e.g. in tests).
func update_around(p: Vector3) -> void:
	var r := int(ceil(_radius / CHUNK))
	var c := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	var want: Dictionary = {}
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var k := c + Vector2i(i, j)
			var centre := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
			if centre.distance_to(Vector2(p.x, p.z)) <= _radius + CHUNK:
				want[k] = true
	for k: Vector2i in _chunks.keys():
		if not want.has(k):
			if _chunks[k] != null:  # bare-ground chunks are kept as null
				_chunks[k].queue_free()
			_chunks.erase(k)
	for k: Vector2i in want:
		if not _chunks.has(k):
			var mmi := _build_chunk(k)
			_chunks[k] = mmi
			if mmi != null:
				add_child(mmi)

func instance_count() -> int:
	var n := 0
	for m in _chunks.values():
		if m != null:
			n += m.multimesh.instance_count
	return n

func _build_chunk(k: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k) + 12345
	var tries := int(CHUNK * CHUNK * _density)
	var xforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	var half: float = _grid.half
	for t in tries:
		var x := (k.x + rng.randf()) * CHUNK
		var z := (k.y + rng.randf()) * CHUNK
		if absf(x) > half - 1.0 or absf(z) > half - 1.0:
			continue
		var s := WorldTerrain.sample(_grid, x, z)
		var green: float = s.grass * (1.0 - s.snow)
		if rng.randf() > green:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.35))
		xforms.append(Transform3D(b, Vector3(x, s.y - 0.02, z)))
		colours.append(Color(rng.randf(), s.forest, rng.randf(), 1.0))
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_custom_data(i, colours[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## One clump: 14 curved, tapered blades (UV.y = 0 at the root, 1 at the tip).
static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in 14:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var root := dir * rng.randf_range(0.0, 0.22)
		var height := rng.randf_range(0.22, 0.55)
		var bend := rng.randf_range(0.05, 0.25)
		var width := rng.randf_range(0.02, 0.035)
		var segs := 4
		for s in segs:
			var v0 := float(s) / segs
			var v1 := float(s + 1) / segs
			var p0 := root + Vector3.UP * height * v0 + dir * bend * v0 * v0
			var p1 := root + Vector3.UP * height * v1 + dir * bend * v1 * v1
			var w0 := width * (1.0 - v0)
			var w1 := width * (1.0 - v1)
			var quad := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
			var uvs := [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[idx])
				st.add_vertex(quad[idx])
	return st.commit()
