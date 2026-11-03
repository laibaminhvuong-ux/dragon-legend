class_name WorldWater
extends RefCounted
# Water for worlds with an ocean or a lake (zone.water: {x, z, radius, level, ocean}): a big disc at the exact
# water level with a depth-coloured, wave-normal, reflective shader and a foam line where it meets the shore.

const SHADER := preload("res://world/shaders/water.gdshader")

static func build(zone: RefCounted) -> Node3D:
	if zone.water == null:
		return null
	return build_body(zone, zone.water)

## One body of water ({x, z, radius, level, ocean}); planet maps add their areas' lakes with this.
static func build_body(zone: RefCounted, w: Dictionary) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var disc := CylinderMesh.new()
	var radius: float = zone.size * 2.0 if w.get("ocean", false) else float(w.radius)
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 96
	disc.rings = 1
	mi.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("wave_a", _noise(3, 0.6, true))
	m.set_shader_parameter("wave_b", _noise(11, 1.4, true))
	m.set_shader_parameter("foam_noise", _noise(23, 2.0, false))
	var col: Variant = zone.biome.get("water")
	if col != null:
		m.set_shader_parameter("deep_color", Color.hex((int(col) << 8) | 0xff))
	mi.material_override = m
	mi.position = Vector3(float(w.get("x", 0)), float(w.level), float(w.get("z", 0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A smooth, seamless noise texture (simplex), optionally as a normal map.
static func _noise(seed: int, freq: float, normal: bool) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = seed
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq / 100.0
	fn.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = fn
	t.as_normal_map = normal
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	return t
