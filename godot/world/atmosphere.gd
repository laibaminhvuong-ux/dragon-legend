class_name WorldAtmosphere
extends RefCounted
# Sky, sun, fog, cloud layers, weather and post-processing for one world, from its biome (data/zones.js):
#   sky: { type: "physical", elevation, azimuth } or { type: "gradient", top, horizon, bottom, elevation, azimuth, sunColor }
#        optional for "physical" (defaults = the old fixed clear blue): zenith (or top), horizon, ground: hex;
#        tint: hex (multiplies the sky colours); sunColor: hex (both types)
#        optional for both: stars, starColor, sunHalo, nebula, bodies (see world/sky_bodies.gd)
#   fog: [colour, density] or absent
#   clouds: false hides the high deck; cloudColor: hex (0xfffaf2), cloudCoverage: float (0.44, lower = more cloud)
#   cloudSea: { y, color } under floating worlds
#   cloudLayers: [ { y, color: hex, coverage: 0.5, scale: 0.002, opacity: 0.7, softness: 0.3, speed: 0.004,
#                    mist: bool (soft where it meets the ground, fades as you fly through it) } ]  extra layers
#   weather: { type: "rain"|"dust"|"snow"|"embers", density: 1.0, color: hex }  (world/weather.gd)
# Dev: --skypreview=1 (or env DL_SKY_PREVIEW=1) merges PREVIEW below over the zone's biome so the proposed
# data (art/reference/map_data_requests.md) can be checked on the GPU before it lands in data/zones.json.

const PHYS_TOP := Color(0.22, 0.45, 0.82)
const PHYS_HORIZON := Color(0.68, 0.8, 0.92)
const PHYS_GROUND := Color(0.3, 0.33, 0.3)

static func build(zone: RefCounted, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "Atmosphere"
	var b: Dictionary = biome_of(zone)
	var sky_def: Dictionary = b.get("sky", {"type": "physical", "elevation": 35, "azimuth": 205})
	var env := Environment.new()
	var sky := Sky.new()
	var sun_color := Color(1.0, 0.96, 0.9)
	var gradient: bool = sky_def.get("type") == "gradient"
	var top: Color
	var horizon_c: Color
	var ground_h: Color
	var ground_b: Color
	var curve: float
	var sun_max: float
	var sun_curve: float
	if gradient:
		top = _hex(sky_def.get("top", 0x4a78c0))
		horizon_c = _hex(sky_def.get("horizon", 0xc8d8e8))
		ground_h = horizon_c
		ground_b = _hex(sky_def.get("bottom", 0x606060))
		curve = 0.12
		sun_max = 8.0
		sun_curve = 0.15   # ProceduralSkyMaterial default
	else:
		# "physical" (Earth-like): a clear blue sky, bright towards the horizon, with a visible sun; zones may tint it
		top = _hex(sky_def.get("zenith", sky_def.get("top"))) if sky_def.has("zenith") or sky_def.has("top") else PHYS_TOP
		horizon_c = _hex(sky_def.horizon) if sky_def.has("horizon") else PHYS_HORIZON
		ground_h = horizon_c
		ground_b = _hex(sky_def.ground) if sky_def.has("ground") else PHYS_GROUND
		if sky_def.has("tint"):
			var tint := _hex(sky_def.tint)
			top *= tint; horizon_c *= tint; ground_h *= tint; ground_b *= tint
		curve = 0.09
		sun_max = 6.0
		sun_curve = 0.08
	if sky_def.has("sunColor"):
		sun_color = _hex(sky_def.sunColor)
	if WorldSkyBodies.wants_shader(sky_def):
		sky.sky_material = WorldSkyBodies.material(sky_def, top, horizon_c, ground_h, ground_b, curve, sun_max, sun_curve)
	else:
		var p := ProceduralSkyMaterial.new()
		p.sky_top_color = top
		p.sky_horizon_color = horizon_c
		p.ground_horizon_color = ground_h
		p.ground_bottom_color = ground_b
		p.sky_curve = curve
		p.sun_angle_max = sun_max
		if not gradient:
			p.sun_curve = sun_curve
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
		env.fog_light_color = _hex(sky_def.get("horizon", 0xbfd1e2)) if gradient or sky_def.has("horizon") else Color(0.72, 0.8, 0.9)
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
	for extra in WorldSkyBodies.extra_lights(sky_def):
		root.add_child(extra)
	var horizon: Color = _hex(sky_def.get("horizon", 0xaec8e0)) if gradient else horizon_c
	var cloud_col: Color = _hex(b.cloudColor) if b.has("cloudColor") else Color(1.0, 0.98, 0.95)
	if b.get("clouds") != false:  # a drifting deck high in the sky
		root.add_child(_cloud_layer("Clouds", 480.0, cloud_col, horizon, 0.00045, float(b.get("cloudCoverage", 0.44)), 8000.0))
	var sea: Variant = b.get("cloudSea")
	if sea is Dictionary:  # floating worlds sit above a sea of clouds
		root.add_child(_cloud_layer("CloudSea", float(sea.get("y", -50)), _hex(sea.get("color", 0xffffff)), horizon, 0.004, 0.02, 6000.0))
	_add_layers(root, b.get("cloudLayers"), cloud_col, horizon, clampf(float(zone.size) * 2.4, 600.0, 8000.0), Vector3.ZERO, 0.0)
	var w := WorldWeather.create(b.get("weather"), quality)
	if w != null:
		root.add_child(w)
	if zone is RulePlanet:
		# a planet's areas keep their own mist layers and weather, placed over the area (the sky is the planet's)
		var pdef: Variant = RuleTables.table("planets").get(zone.id)
		var main_region: String = str(pdef.get("biome", "")) if pdef is Dictionary else ""
		var regions: Dictionary = (zone as RulePlanet).regions
		for rid: String in regions:
			if rid == main_region:
				continue
			var r: Dictionary = regions[rid]
			var rb: Dictionary = biome_of(r.zone)
			var at := Vector3(float(r.x), float(r.get("lift", 0.0)), float(r.z))
			var rad := float(r.radius)
			_add_layers(root, rb.get("cloudLayers"), cloud_col, horizon, rad * 2.6, at, rad)
			var rw := WorldWeather.create(rb.get("weather"), quality, Vector2(at.x, at.z), rad)
			if rw != null:
				rw.name = "Weather_" + rid
				root.add_child(rw)
	return root

## Extra cloud / mist layers (biome.cloudLayers), at most 4 per call. `at` offsets them (a planet's area);
## region > 0 fades them out towards that radius around `at` so an area's mist ends softly.
static func _add_layers(root: Node3D, layers: Variant, cloud_col: Color, horizon: Color, size: float, at: Vector3, region: float) -> void:
	if not (layers is Array):
		return
	var i := 0
	for raw: Variant in layers:
		if not (raw is Dictionary) or i >= 4:
			continue
		var l: Dictionary = raw
		var mist: bool = l.get("mist", false)
		var mi := _cloud_layer("CloudLayer%d" % root.get_child_count(), float(l.get("y", 120)), _hex(l.color) if l.has("color") else cloud_col, horizon,
			float(l.get("scale", 0.002)), float(l.get("coverage", 0.5)), size)
		mi.position += at
		var m: ShaderMaterial = mi.material_override
		m.set_shader_parameter("opacity", float(l.get("opacity", 0.55 if mist else 0.85)))
		m.set_shader_parameter("softness", float(l.get("softness", 0.45 if mist else 0.3)))
		m.set_shader_parameter("speed", float(l.get("speed", 0.004)))
		m.set_shader_parameter("fade_start", maxf(size * 0.18, 300.0))
		m.set_shader_parameter("fade_end", maxf(size * 0.45, 900.0))
		if region > 0.0:
			m.set_shader_parameter("region", Vector3(at.x, at.z, region))
		if mist:
			m.set_shader_parameter("shade", 1.0)
			m.set_shader_parameter("soft_depth", 14.0)
			m.set_shader_parameter("near_fade", 8.0)
		root.add_child(mi)
		i += 1

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

## The zone's biome; with the dev sky preview on, the proposed PREVIEW data merged over it (a copy: the
## zone's own dictionary is never changed).
static func biome_of(zone: RefCounted) -> Dictionary:
	var b: Dictionary = zone.biome
	if not _preview_on():
		return b
	var key: String = zone.id
	if zone is RulePlanet:   # a planet's biome comes from one of its areas
		var pdef: Variant = RuleTables.table("planets").get(key)
		key = str(pdef.get("biome", key)) if pdef is Dictionary else key
	if not PREVIEW.has(key):
		return b
	var out: Dictionary = b.duplicate(true)
	var p: Dictionary = PREVIEW[key]
	for k: String in p:
		if k == "sky" and out.get("sky") is Dictionary:
			var s: Dictionary = out.sky
			for sk: String in p.sky:
				s[sk] = p.sky[sk]
		else:
			out[k] = p[k]
	return out

static var _preview := -1

static func _preview_on() -> bool:
	if _preview < 0:
		_preview = 1 if OS.get_environment("DL_SKY_PREVIEW") == "1" or OS.get_cmdline_user_args().has("--skypreview=1") else 0
	return _preview == 1

# Proposed biome data per zone, merged with the dev preview. Empty: the 0.0.8 map pass applied every B5 entry to the
# zone data (tools/godot_additions.mjs, mapPass008). New proposals go here as {zone id: biome fields}.
const PREVIEW := {}
