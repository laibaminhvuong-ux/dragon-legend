extends TestCase
# World wind (world/wind.gd): per-biome defaults, biome.wind overrides, the shader globals every wind shader reads,
# "low" quality stills it, and the grass / foliage / bush / hair shaders read the globals (the GPU check is manual).

class FakeZone extends RefCounted:
	var id := "test"
	var planet := "Earth"
	var ground := "grass"
	var mesas: Array = []
	var biome: Dictionary = {}
	var def: Dictionary = {}

func _zone(id: String) -> RefCounted:
	return load("res://rules/zone.gd").new(id)

func test_biome_defaults() -> void:
	var plains: Dictionary = WorldWind.settings_for(_zone("earth_plains"))
	var interior: Dictionary = WorldWind.settings_for(_zone("interior_home"))
	var other: Dictionary = WorldWind.settings_for(_zone("king_kai"))
	var snow: Dictionary = WorldWind.settings_for(_zone("broly_glacier"))
	var waste: Dictionary = WorldWind.settings_for(_zone("gizard_wasteland"))
	eq(float(interior.strength), 0.0, "still air indoors")
	ok(float(other.strength) < 0.3, "Other World is calm (%s)" % other.strength)
	ok(float(plains.strength) > float(other.strength), "Earth plains breezier than Other World")
	ok(float(snow.strength) >= float(plains.strength), "snow fields at least as windy as the plains")
	ok(float(waste.strength) > float(DEFAULT_STRENGTH()), "wasteland gusts")
	near((plains.dir as Vector2).length(), 1.0, 1e-4, "unit direction")
	eq(WorldWind.settings_for(_zone("earth_plains")).dir, plains.dir, "a map's wind direction never changes")

func DEFAULT_STRENGTH() -> float:
	return float(WorldWind.DEFAULT.strength)

func test_biome_override() -> void:
	var z := FakeZone.new()
	z.biome = {"wind": {"dir": 90, "strength": 1.3, "gust": 0.2}}
	var w: Dictionary = WorldWind.settings_for(z)
	near(float(w.strength), 1.3, 1e-6, "strength")
	near(float(w.gust), 0.2, 1e-6, "gust")
	near((w.dir as Vector2).x, 0.0, 1e-5, "90 degrees blows towards +z (x)")
	near((w.dir as Vector2).y, 1.0, 1e-5, "90 degrees blows towards +z (z)")
	z.biome = {"wind": {"dir": [3, -4]}}
	w = WorldWind.settings_for(z)
	near((w.dir as Vector2).x, 0.6, 1e-5, "[x, z] direction normalised")
	near(float(w.strength), float(WorldWind.DEFAULT.strength), 1e-6, "missing keys keep the default")
	z.biome = {"wind": {"strength": 99}}
	ok(float(WorldWind.settings_for(z).strength) <= 2.0, "strength clamped")

func test_shader_globals_and_quality() -> void:
	WorldWind.apply(_zone("earth_plains"), "high")
	var v: Variant = RenderingServer.global_shader_parameter_get(&"wind_field")
	ok(v is Vector4 or DisplayServer.get_name() == "headless", "wind_field registered (%s)" % type_string(typeof(v)))
	if v is Vector4:   # the headless dummy renderer keeps no globals
		near((v as Vector4).z, WorldWind.strength, 1e-5, "strength published")
		near(Vector2((v as Vector4).x, (v as Vector4).y).length(), 1.0, 1e-4, "direction published")
	var t0 := WorldWind.time
	WorldWind._last_frame = -1
	WorldWind.advance(0.5)
	near(WorldWind.time, fmod(t0 + 0.5, 3600.0), 1e-4, "clock advances")
	WorldWind.advance(0.5)
	near(WorldWind.time, fmod(t0 + 0.5, 3600.0), 1e-4, "advances once per frame however many callers")
	ok(WorldWind.vector().length() > 0.5, "moving air while a world ticks")
	WorldWind.apply(_zone("earth_plains"), "low")
	eq(WorldWind.strength, 0.0, "low quality: no wind")
	eq(WorldWind.vector(), Vector3.ZERO, "low quality: no moving air")
	WorldWind.apply(_zone("earth_plains"), "high")

func test_gust_bounds() -> void:
	WorldWind.apply(_zone("gizard_wasteland"), "high")
	var lo := 9.0
	var hi := 0.0
	for i in 400:
		var g := WorldWind.gust_now(i * 0.37)
		lo = minf(lo, g); hi = maxf(hi, g)
	ok(lo >= 0.0 and hi <= 1.0 + WorldWind.gust + 1e-4, "gusts within 1 ± gust (%s..%s)" % [lo, hi])
	ok(hi - lo > 0.3, "gusty wind actually gusts")

func test_wind_shaders_read_globals() -> void:
	WorldWind.ensure_globals()
	for path in ["res://world/shaders/grass.gdshader", "res://world/shaders/foliage.gdshader", "res://world/shaders/foliage_scan.gdshader",
			"res://characters/shaders/hair.gdshader", "res://characters/shaders/hair_toon.gdshader", "res://characters/shaders/outline.gdshader"]:
		var sh: Shader = load(path)
		ok(sh != null and (sh.code.contains("wind_time") or sh.code.contains("hair_motion.gdshaderinc")), "%s reads the wind clock" % path.get_file())
	var inc: ShaderInclude = load("res://characters/shaders/hair_motion.gdshaderinc")
	ok(inc != null and inc.code.contains("global uniform float wind_time") and inc.code.contains("instance uniform vec4 hair_sway"), "hair motion include")

func test_props_and_grass_wire_wind() -> void:
	var m: ArrayMesh = load("res://world/props.gd").tree_mesh("palm", 0)
	var mat: ShaderMaterial = m.surface_get_material(m.get_surface_count() - 1)
	near(float(mat.get_shader_parameter("sway")), 1.0, 1e-6, "palm fronds sway")
	var arrays := m.surface_get_arrays(m.get_surface_count() - 1)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var tips := 0
	for c in cols:
		if c.b > 0.5 and c.g > 0.99:
			tips += 1
	ok(tips > 0, "palm frond tips carry full flex")
	var crystal: ArrayMesh = load("res://world/props.gd").tree_mesh("crystal", 0)
	near(float((crystal.surface_get_material(0) as ShaderMaterial).get_shader_parameter("sway")), 0.0, 1e-6, "crystals stay rigid")
	var zone := _zone("earth_plains")
	var root: Node3D = load("res://world/props.gd").build(zone, "low")
	var bushes := 0
	for c in root.find_children("Scan_*", "MultiMeshInstance3D", true, false):
		var o: Material = (c as MultiMeshInstance3D).material_override
		if o is ShaderMaterial and (o as ShaderMaterial).shader.resource_path.ends_with("foliage_scan.gdshader"):
			bushes += 1
	ok(bushes > 0, "bushes use the wind shader (%d tiles)" % bushes)
	root.free()
