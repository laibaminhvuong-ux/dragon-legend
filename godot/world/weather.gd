class_name WorldWeather
extends Node3D
# Simple weather around the camera from biome.weather (optional):
#   { type: "rain" | "dust" | "snow" | "embers", density: float = 1.0, color: hex (per type default) }
# One GPUParticles3D box that follows the active camera (world-space particles, so moving doesn't drag them).
# Costs one cheap transparent draw; "low" quality halves the particle count.

const TYPES := ["rain", "dust", "snow", "embers"]

var _particles: GPUParticles3D
var _lift := 0.0
var _center := Vector2.ZERO
var _radius := 0.0   # > 0: only falls while the camera is within this distance of _center (an area of a planet)

static func create(def: Variant, quality := "high", center := Vector2.ZERO, radius := 0.0) -> WorldWeather:
	if not (def is Dictionary) or not TYPES.has(String(def.get("type", ""))):
		return null
	var w := WorldWeather.new()
	w.name = "Weather"
	w._center = center
	w._radius = radius
	w._build(def, quality)
	return w

func _build(def: Dictionary, quality: String) -> void:
	var type := String(def.type)
	var density := clampf(float(def.get("density", 1.0)), 0.05, 3.0) * (1.0 if quality == "high" else 0.5)
	var p := GPUParticles3D.new()
	p.name = "Particles"
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	var fade := Gradient.new()   # fade in and out over each particle's life
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	var col: Color
	match type:
		"rain":
			col = _col(def, 0xb4bcc0, 0.3)
			p.amount = int(1500 * density)
			p.lifetime = 0.8
			_lift = 16.0
			pm.emission_box_extents = Vector3(30, 4, 30)
			pm.direction = Vector3(0.08, -1, 0.04)
			pm.spread = 2.0
			pm.initial_velocity_min = 34.0
			pm.initial_velocity_max = 42.0
			pm.gravity = Vector3(0, -12, 0)
			quad.size = Vector2(0.03, 1.2)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		"snow":
			col = _col(def, 0xffffff, 0.85)
			p.amount = int(1400 * density)
			p.lifetime = 6.0
			_lift = 14.0
			pm.emission_box_extents = Vector3(32, 6, 32)
			pm.direction = Vector3(0.3, -1, 0.1)
			pm.spread = 25.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 3.0
			pm.gravity = Vector3(0, -0.6, 0)
			quad.size = Vector2(0.14, 0.14)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_dot()
		"embers":
			col = _col(def, 0xff8a2a, 0.95)
			p.amount = int(260 * density)
			p.lifetime = 5.0
			_lift = -4.0
			pm.emission_box_extents = Vector3(34, 3, 34)
			pm.direction = Vector3(0.2, 1, 0)
			pm.spread = 30.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 4.0
			pm.gravity = Vector3(0, 0.4, 0)
			quad.size = Vector2(0.12, 0.12)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_dot()
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_:   # dust: big soft drifting puffs low over the ground
			col = _col(def, 0xd8b88a, 0.14)
			p.amount = int(220 * density)
			p.lifetime = 7.0
			_lift = 2.0
			pm.emission_box_extents = Vector3(40, 5, 40)
			pm.direction = Vector3(1, 0.05, 0.35)
			pm.spread = 15.0
			pm.initial_velocity_min = 4.0
			pm.initial_velocity_max = 8.0
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.6
			pm.scale_max = 1.6
			quad.size = Vector2(3.5, 3.5)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_dot()
	pm.color = col
	p.amount = maxi(p.amount, 16)
	p.preprocess = p.lifetime if _radius <= 0.0 else 0.0   # an area's weather starts off and begins when you arrive
	p.emitting = _radius <= 0.0
	p.process_material = pm
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-45, -40, -45), Vector3(90, 70, 90))
	p.position.y = _lift
	add_child(p)
	_particles = p

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	global_position = at
	if _radius > 0.0:
		var d := Vector2(at.x, at.z).distance_to(_center)
		if _particles.emitting and d > _radius * 1.05:
			_particles.emitting = false
		elif not _particles.emitting and d < _radius:
			_particles.emitting = true

static func _col(def: Dictionary, dflt: int, alpha: float) -> Color:
	var c := Color.hex((int(def.get("color", dflt)) << 8) | 0xff)
	c.a = alpha
	return c

static var _dot: GradientTexture2D

static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot
