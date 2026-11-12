class_name WorldSkyBodies
extends RefCounted
# The painted sky (world/shaders/sky.gdshader) for worlds whose biome.sky asks for stars, a nebula or sky
# bodies; worlds that don't keep Godot's ProceduralSkyMaterial (atmosphere.gd). All optional biome.sky fields:
#   stars: bool | float          starfield density (true = 1.0)
#   starColor: hex               default 0xffffff
#   sunHalo: bool                default true; false hides the main sun's halo (e.g. an eclipse world)
#   nebula: { colors: [hex, hex, hex], amount: float = 0.8, scale: float = 1.0, offset: [u, v] }
#   bodies: [ { kind: "sun"|"moon"|"planet"|"ringed"|"bubble"|"eclipse", az: deg, el: deg, size: deg (angular
#              radius), color: hex, color2: hex, tilt: float (ring squash, 0.3), roll: deg, glow: float (sun halo, 1),
#              light: float (sun only: energy of an extra shadowless light, 0 = none), seed: float } ]  (max 8)

const SHADER := preload("res://world/shaders/sky.gdshader")
const MAX_BODIES := 8
const KINDS := {"sun": 0, "moon": 1, "planet": 2, "ringed": 3, "bubble": 4, "eclipse": 5}

static var _noise: NoiseTexture2D

## True when this sky needs the painted shader rather than the plain procedural gradient.
static func wants_shader(sky_def: Dictionary) -> bool:
	var s: Variant = sky_def.get("stars", false)
	var has_stars: bool = (s is bool and s) or ((s is float or s is int) and float(s) > 0.0)
	return has_stars or sky_def.get("nebula") is Dictionary or (sky_def.get("bodies") is Array and not (sky_def.bodies as Array).is_empty())

## The sky material: gradient colours as ProceduralSkyMaterial would use them, then stars/nebula/bodies.
static func material(sky_def: Dictionary, top: Color, horizon: Color, ground_h: Color, ground_b: Color, sky_curve: float, sun_max_deg: float, sun_curve: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("horizon_color", horizon)
	m.set_shader_parameter("ground_horizon", ground_h)
	m.set_shader_parameter("ground_bottom", ground_b)
	m.set_shader_parameter("sky_curve", sky_curve)
	m.set_shader_parameter("sun_angle_max", deg_to_rad(sun_max_deg))
	m.set_shader_parameter("sun_curve", sun_curve)
	m.set_shader_parameter("sun_disc", 1.0 if sky_def.get("sunHalo", true) else 0.0)
	m.set_shader_parameter("noise_tex", noise())
	var s: Variant = sky_def.get("stars", false)
	var stars := 0.0
	if s is bool:
		stars = 1.0 if s else 0.0
	elif s is float or s is int:
		stars = clampf(float(s), 0.0, 3.0)
	m.set_shader_parameter("stars", stars)
	m.set_shader_parameter("star_color", hexc(sky_def.get("starColor", 0xffffff)))
	var neb: Variant = sky_def.get("nebula")
	if neb is Dictionary:
		var cols: Array = neb.get("colors", [0x3a1650, 0xa0306e, 0x50e0a0])
		m.set_shader_parameter("nebula", float(neb.get("amount", 0.8)))
		m.set_shader_parameter("nebula_scale", float(neb.get("scale", 1.0)))
		var off: Array = neb.get("offset", [0.0, 0.0])
		m.set_shader_parameter("nebula_offset", Vector2(float(off[0]), float(off[1])) if off.size() >= 2 else Vector2.ZERO)
		for i in 3:
			m.set_shader_parameter(["nebula_a", "nebula_b", "nebula_c"][i], hexc(cols[mini(i, cols.size() - 1)]) if not cols.is_empty() else Color.BLACK)
	_set_bodies(m, sky_def.get("bodies", []))
	return m

static func _set_bodies(m: ShaderMaterial, list: Variant) -> void:
	var dirs := PackedVector4Array()
	var ts := PackedVector4Array()
	var bs := PackedVector4Array()
	var c1 := PackedVector4Array()
	var c2 := PackedVector4Array()
	dirs.resize(MAX_BODIES); ts.resize(MAX_BODIES); bs.resize(MAX_BODIES); c1.resize(MAX_BODIES); c2.resize(MAX_BODIES)
	var n := 0
	if list is Array:
		for raw: Variant in list:
			if n >= MAX_BODIES or not (raw is Dictionary):
				continue
			var bd: Dictionary = raw
			var kind: int = KINDS.get(String(bd.get("kind", "moon")), 1)
			var dir := direction(float(bd.get("az", 200)), float(bd.get("el", 30)))
			var rad := deg_to_rad(clampf(float(bd.get("size", 3.0)), 0.1, 60.0))
			var t := Vector3.UP.cross(dir)
			t = Vector3.RIGHT if t.length() < 0.001 else t.normalized()
			var b := dir.cross(t).normalized()
			var roll := deg_to_rad(float(bd.get("roll", 0.0)))
			if roll != 0.0:
				var t2 := t * cos(roll) + b * sin(roll)
				b = b * cos(roll) - t * sin(roll)
				t = t2
			var reach: float = rad * {0: 6.0, 3: 2.4, 5: 5.0}.get(kind, 1.05)
			var col := hexc(bd.get("color", 0xfff2d0)).srgb_to_linear()
			var dflt2: int = {0: 0xffffff, 1: 0x8a8a90, 2: 0xc89a70, 3: 0xd8c08a, 4: 0xffffff, 5: 0x050308}.get(kind, 0x808080)
			var col2 := hexc(bd.get("color2", dflt2)).srgb_to_linear()
			var extra: float = float(bd.get("glow", 1.0)) if kind == 0 else float(bd.get("tilt", 0.3))
			dirs[n] = Vector4(dir.x, dir.y, dir.z, rad)
			ts[n] = Vector4(t.x, t.y, t.z, cos(minf(reach, PI * 0.95)))
			bs[n] = Vector4(b.x, b.y, b.z, float(bd.get("seed", n * 0.37 + 0.11)))
			c1[n] = Vector4(col.r, col.g, col.b, float(kind))
			c2[n] = Vector4(col2.r, col2.g, col2.b, extra)
			n += 1
	m.set_shader_parameter("body_count", n)
	m.set_shader_parameter("body_dir", dirs)
	m.set_shader_parameter("body_t", ts)
	m.set_shader_parameter("body_b", bs)
	m.set_shader_parameter("body_col", c1)
	m.set_shader_parameter("body_col2", c2)

## Extra shadowless lights for "sun" bodies with light > 0 (several suns light the ground from several sides).
## They stay out of the sky shader (sky_mode light-only): the bodies draw their own discs.
static func extra_lights(sky_def: Dictionary) -> Array[DirectionalLight3D]:
	var out: Array[DirectionalLight3D] = []
	var list: Variant = sky_def.get("bodies", [])
	if not (list is Array):
		return out
	for raw: Variant in list:
		if not (raw is Dictionary) or String(raw.get("kind", "")) != "sun" or float(raw.get("light", 0.0)) <= 0.0:
			continue
		if out.size() >= 2:
			break   # keep the light count small
		var l := DirectionalLight3D.new()
		l.name = "Sun%d" % (out.size() + 2)
		l.rotation_degrees = Vector3(-float(raw.get("el", 30)), float(raw.get("az", 200)), 0)
		l.light_color = hexc(raw.get("color", 0xfff2d0))
		l.light_energy = float(raw.light)
		l.shadow_enabled = false
		l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		out.append(l)
	return out

## Direction towards a point of the sky (same convention as the sun: rotation (-el, az)).
static func direction(az: float, el: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-el), deg_to_rad(az), 0)) * Vector3(0, 0, 1)

static func noise() -> NoiseTexture2D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.seed = 7
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.006
		fn.fractal_octaves = 5
		_noise = NoiseTexture2D.new()
		_noise.width = 512; _noise.height = 512
		_noise.seamless = true
		_noise.noise = fn
		_noise.generate_mipmaps = true
	return _noise

static func hexc(v: Variant) -> Color:
	return Color.hex((int(v) << 8) | 0xff)
