class_name WorldAtmosphere
extends RefCounted
# Sky, sun, fog and post-processing for one world, from its biome (data/zones.js):
#   sky: { type: "physical", elevation, azimuth } or { type: "gradient", top, horizon, bottom, elevation, azimuth, sunColor }
#   fog: [colour, density] or absent

static func build(zone: RefCounted, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "Atmosphere"
	var b: Dictionary = zone.biome
	var sky_def: Dictionary = b.get("sky", {"type": "physical", "elevation": 35, "azimuth": 205})
	var env := Environment.new()
	var sky := Sky.new()
	var sun_color := Color(1.0, 0.96, 0.9)
	if sky_def.get("type") == "gradient":
		var g := ProceduralSkyMaterial.new()
		g.sky_top_color = _hex(sky_def.get("top", 0x4a78c0))
		g.sky_horizon_color = _hex(sky_def.get("horizon", 0xc8d8e8))
		g.ground_horizon_color = _hex(sky_def.get("horizon", 0xc8d8e8))
		g.ground_bottom_color = _hex(sky_def.get("bottom", 0x606060))
		g.sky_curve = 0.12
		g.sun_angle_max = 8.0
		sky.sky_material = g
		if sky_def.has("sunColor"):
			sun_color = _hex(sky_def.sunColor)
	else:
		# "physical" (Earth-like): a clear blue sky, bright towards the horizon, with a visible sun
		var p := ProceduralSkyMaterial.new()
		p.sky_top_color = Color(0.22, 0.45, 0.82)
		p.sky_horizon_color = Color(0.68, 0.8, 0.92)
		p.ground_horizon_color = Color(0.68, 0.8, 0.92)
		p.ground_bottom_color = Color(0.3, 0.33, 0.3)
		p.sky_curve = 0.09
		p.sun_angle_max = 6.0
		p.sun_curve = 0.08
		sky.sky_material = p
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	var high := quality == "high"
	env.ssao_enabled = high  # the most expensive effect measured on a GTX 1650 Ti (24 -> 39 fps); high only, half-res
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.ssil_enabled = high
	env.sdfgi_enabled = false
	# distance haze everywhere; denser fog where the biome asks for it
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	var fog: Variant = b.get("fog")
	if fog is Array and fog.size() >= 2:
		env.fog_light_color = _hex(fog[0])
		env.fog_density = clampf(float(fog[1]) * 0.6, 0.0004, 0.02)
	else:
		env.fog_light_color = _hex(sky_def.get("horizon", 0xbfd1e2)) if sky_def.get("type") == "gradient" else Color(0.72, 0.8, 0.9)
		env.fog_density = 0.00045
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.5
	if high:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0015
		env.volumetric_fog_albedo = env.fog_light_color
		env.volumetric_fog_length = 120.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-float(sky_def.get("elevation", 35)), float(sky_def.get("azimuth", 205)), 0)
	sun.light_color = sun_color
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 220.0 if high else 120.0
	sun.shadow_blur = 1.5
	root.add_child(sun)
	var horizon: Color = _hex(sky_def.get("horizon", 0xaec8e0)) if sky_def.get("type") == "gradient" else Color(0.68, 0.8, 0.92)
	if b.get("clouds") != false:  # a drifting deck high in the sky
		root.add_child(_cloud_layer("Clouds", 480.0, Color(1.0, 0.98, 0.95), horizon, 0.00045, 0.44, 8000.0))
	var sea: Variant = b.get("cloudSea")
	if sea is Dictionary:  # floating worlds sit above a sea of clouds
		root.add_child(_cloud_layer("CloudSea", float(sea.get("y", -50)), _hex(sea.get("color", 0xffffff)), horizon, 0.004, 0.02, 6000.0))
	return root

static var _noise_tex: NoiseTexture2D

static func _cloud_layer(name: String, y: float, color: Color, horizon: Color, scale: float, coverage: float, size: float) -> MeshInstance3D:
	if _noise_tex == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.008
		fn.fractal_octaves = 5
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 512; _noise_tex.height = 512
		_noise_tex.seamless = true
		_noise_tex.noise = fn
		_noise_tex.generate_mipmaps = true
	var mi := MeshInstance3D.new()
	mi.name = name
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	mi.position.y = y
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/shaders/clouds.gdshader")
	m.set_shader_parameter("noise_tex", _noise_tex)
	m.set_shader_parameter("cloud_color", color)
	m.set_shader_parameter("horizon_color", horizon)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("coverage", coverage)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _hex(v: Variant) -> Color:
	return Color.hex((int(v) << 8) | 0xff)
