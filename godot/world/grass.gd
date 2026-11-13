class_name WorldGrass
extends Node3D
# Grass blades streamed around a target (the camera or the player): 16 m chunks of MultiMesh clumps within a
# radius, placed on grass/forest ground from the terrain grid, swaying in the wind and shrinking away with
# distance (no popping). Density comes from the quality preset and the world's biome.grass (default 1).
# Wind: WorldWind (world/wind.gd) shader globals; this node applies the zone's wind and advances its clock.
# Optional biome.grassColors {root, tip, dry, forest} (0xRRGGBB) sets the blade colours outright (default: green + tint).

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
var _towns: Array = []   # town landmarks: no grass in a city, nor on village roads
## Landmarks whose ground is covered by low floors or water (tops under the ~0.5 m blades): no grass inside this radius
## (m, landmark-centred, times its scale; a landmark's own "noGrass" overrides). Baaba's moat and arena (top 0.16-0.3 m)
## had blades growing up through the water and the tiles.
const NO_GRASS := {"baabaisle": 60.0, "capsulehq": 28.0, "budokaihall": 34.0}   # Baaba: moat r 54 round local (0, -6); Kapsule HQ: lawn and paths (tops 0.08-0.12); tournament hall: gate walkway (top 0.08, z 20-32)
var _bare: Array = []    # Vector3(x, radius, z)

static func create(terrain: Node3D, zone: RefCounted, quality := "high") -> WorldGrass:
	var g := WorldGrass.new()
	g.name = "Grass"
	WorldWind.apply(zone, quality)   # every world has grass: it sets the map's wind (biome.wind or the biome default)
	var p: Dictionary = PRESET.get(quality, PRESET.high)
	g._grid = terrain.get_meta("grid")
	g._towns = zone.landmarks.filter(func(l: Dictionary) -> bool: return l.get("type") == "town")
	for l: Dictionary in zone.landmarks:
		var r := float(l.get("noGrass", NO_GRASS.get(str(l.get("type", "")), 0.0))) * float(l.get("scale", 1.0))
		if r > 0.0:
			g._bare.append(Vector3(float(l.x), r, float(l.z)))
	g._density = float(p.density) * float(zone.biome.get("grass", 1.0))
	g._radius = p.radius
	g._mesh = _clump_mesh()
	g._material = ShaderMaterial.new()
	g._material.shader = SHADER
	g._material.set_shader_parameter("fade_end", g._radius)
	var tints: Dictionary = zone.biome.get("tints", {})
	var cols: Variant = zone.biome.get("grassColors")
	if cols is Dictionary and not (cols as Dictionary).is_empty():
		# Batch B4: literal blade colours (0xRRGGBB ints; keys root/tip/dry/forest, any subset) for alien grass that a
		# multiplicative tint on green cannot reach (Nameck blue-turquoise, Nameless crimson). Replaces tints.grass.
		for key: String in ["root", "tip", "dry", "forest"]:
			if (cols as Dictionary).has(key):
				g._material.set_shader_parameter(key + "_color", Color.hex((int(cols[key]) << 8) | 0xff))
	elif tints.get("grass") is Array:
		var t: Array = tints.grass
		g._material.set_shader_parameter("tint", Color(float(t[0]), float(t[1]), float(t[2])))
	return g

func _process(delta: float) -> void:
	WorldWind.advance(delta)   # the one place the wind clock moves
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
	var towns: Array = _towns.filter(func(l: Dictionary) -> bool:
		return Vector2((k.x + 0.5) * CHUNK - float(l.x), (k.y + 0.5) * CHUNK - float(l.z)).length() < float(l.radius) + CHUNK)
	var bare: Array = _bare.filter(func(b: Vector3) -> bool:
		return Vector2((k.x + 0.5) * CHUNK - b.x, (k.y + 0.5) * CHUNK - b.z).length() < b.y + CHUNK)
	for t in tries:
		var x := (k.x + rng.randf()) * CHUNK
		var z := (k.y + rng.randf()) * CHUNK
		if absf(x) > half - 1.0 or absf(z) > half - 1.0:
			continue
		if not towns.is_empty() and _paved(towns, x, z):
			continue
		if not bare.is_empty() and _bare_at(bare, x, z):
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

static func _bare_at(bare: Array, x: float, z: float) -> bool:
	for b: Vector3 in bare:
		if (x - b.x) * (x - b.x) + (z - b.z) * (z - b.z) < b.y * b.y:
			return true
	return false

static func _paved(towns: Array, x: float, z: float) -> bool:
	for l: Dictionary in towns:
		var lx := x - float(l.x)
		var lz := z - float(l.z)
		var d := Vector2(lx, lz).length()
		if d > float(l.radius):
			continue
		if str(l.get("style", "")) == "city":
			return true
		# town-local frame (hamlets are rotated, as RuleTown.surface_at)
		var lr := float(l.get("rot", 0.0))
		var tx := lx * cos(lr) - lz * sin(lr)
		var tz := lx * sin(lr) + lz * cos(lr)
		var lay := RuleTown.layout(l)
		if RuleTown._on_road(lay, tx, tz, 0.6):
			return true
		for e: Dictionary in lay.extras:   # building audit: grass grew through the village plazas and crop fields
			match str(e.get("kind", "")):
				"plaza":
					if Vector2(tx - float(e.x), tz - float(e.z)).length() < float(e.r) + 0.3:
						return true
				"field":
					var fr := float(e.rot)
					var fx := tx - float(e.x); var fz := tz - float(e.z)
					if absf(fx * cos(fr) - fz * sin(fr)) < float(e.w) * 0.5 + 0.2 and absf(fx * sin(fr) + fz * cos(fr)) < float(e.d) * 0.5 + 0.2:
						return true
		if not RuleTown.inside(l, x, z).is_empty():   # no grass on the floor of a walk-in building
			return true
		for b: Dictionary in lay.buildings:   # nor on a building's footing: RuleTown.inside only covers the square inside
			if str(b.kind) in RuleTown.NO_STRUCTURE:   # a dome's walls (0.78 r), so blades grew between it and the round wall (audit)
				continue
			var br := float(b.rot)
			var bx := tx - float(b.x); var bz := tz - float(b.z)
			if str(b.kind) in ["dome", "tower", "lighthouse", "windmill"]:
				if Vector2(bx, bz).length() < float(b.w) * 0.5 + 0.3:
					return true
			elif absf(bx * cos(br) - bz * sin(br)) < float(b.w) * 0.5 + 0.3 and absf(bx * sin(br) + bz * cos(br)) < float(b.d) * 0.5 + 0.3:
				return true
	return false
