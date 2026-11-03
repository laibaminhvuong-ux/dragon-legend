class_name Aura
extends Node3D
# Transformation auras (port of the JS aura): two shells of rising, flickering flame, optional lightning that
# crackles around the body (sparks 1 or 2) and rising glitter (motes). Looks come from form_looks / kaioken /
# KI_CHARGE_LOOK. Sits at a model's feet; call update(dt) every frame.

const SHELL := preload("res://fx/shaders/aura.gdshader")
const GLOW := preload("res://fx/shaders/glow_point.gdshader")
const BOLT := preload("res://fx/shaders/bolt.gdshader")
const SEG := 9
static var _sphere: SphereMesh
static var _shell_mat: ShaderMaterial

var look: Dictionary
var t := 0.0
var burst := 1.0
var outer: MeshInstance3D
var inner: MeshInstance3D
var bolts: MeshInstance3D
var motes: CPUParticles3D
var _bolt_clock := 0.0
var _rng := RandomNumberGenerator.new()

static func create(l: Dictionary) -> Aura:
	var a := Aura.new()
	a.name = "Aura"
	a.look = l
	a._build()
	return a

static func hx(v: Variant) -> Color:
	return Color.hex((int(v) << 8) | 0xff)

func _build() -> void:
	if _sphere == null:
		_sphere = SphereMesh.new(); _sphere.radius = 1.0; _sphere.height = 2.0; _sphere.radial_segments = 40; _sphere.rings = 32
		_shell_mat = ShaderMaterial.new(); _shell_mat.shader = SHELL
	t = _rng.randf() * 10.0
	outer = _shell(1.0, 1.0, false)
	inner = _shell(0.8, 0.45, true)
	if int(look.get("sparks", 0)) > 0:
		bolts = MeshInstance3D.new()
		bolts.mesh = ImmediateMesh.new()
		var m := ShaderMaterial.new(); m.shader = BOLT
		m.set_shader_parameter("tint", hx(look.get("sparkColor", 0xcfe8ff)))
		bolts.material_override = m
		bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolts.extra_cull_margin = 2.0
		add_child(bolts)
	if look.get("motes") != null:
		motes = CPUParticles3D.new()
		motes.amount = 36
		motes.lifetime = 2.4
		motes.preprocess = 2.4
		motes.local_coords = true
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		motes.emission_ring_axis = Vector3.UP
		motes.emission_ring_radius = 0.65
		motes.emission_ring_inner_radius = 0.3
		motes.emission_ring_height = 0.2
		motes.direction = Vector3.UP
		motes.spread = 8.0
		motes.gravity = Vector3.ZERO
		motes.initial_velocity_min = 0.4
		motes.initial_velocity_max = 1.2
		var q := QuadMesh.new(); q.size = Vector2(0.06, 0.06)
		var m := ShaderMaterial.new(); m.shader = GLOW
		m.set_shader_parameter("tint", hx(look.motes))
		q.material = m
		motes.mesh = q
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(motes)
	update(0.0)

func _shell(scale_k: float, intensity: float, is_core: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _shell_mat
	var s := float(look.get("size", 1.0))
	mi.scale = Vector3(0.6 * s * scale_k, 1.05 * s * scale_k, 0.55 * s * scale_k)
	mi.position.y = 0.92
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.5   # the vertex shader stretches it past its bounds
	mi.sorting_offset = 1.0
	add_child(mi)
	var c: Color = hx(look.get("core", 0xffffff)) if is_core else hx(look.get("color", 0xffd24a))
	mi.set_instance_shader_parameter("color", c)
	mi.set_instance_shader_parameter("core", hx(look.get("core", 0xffffff)))
	mi.set_instance_shader_parameter("intensity", intensity)
	mi.set_instance_shader_parameter("flicker", float(look.get("flicker", 0.8)))
	mi.set_instance_shader_parameter("calm", 1.0 if look.get("style", "") == "calm" else 0.0)
	return mi

func set_color(hex: int) -> void:
	look["color"] = hex
	outer.set_instance_shader_parameter("color", hx(hex))

## A flare, as at the moment of transforming.
func flare() -> void:
	burst = 1.0

func update(dt: float) -> void:
	t += dt
	burst = maxf(0.0, burst - dt * 1.8)
	for mi in [outer, inner]:
		mi.set_instance_shader_parameter("time", t)
		mi.set_instance_shader_parameter("burst", burst * burst)
	if bolts != null:
		_bolt_clock -= dt
		if _bolt_clock <= 0.0:
			_bolt_clock = 0.05 + _rng.randf() * 0.05
			_redraw_bolts()

func _redraw_bolts() -> void:
	var im: ImmediateMesh = bolts.mesh
	im.clear_surfaces()
	var n := (2 + (1 if _rng.randf() < 0.5 else 0)) if int(look.get("sparks", 0)) >= 2 else (1 if _rng.randf() < 0.45 else 0)
	if n == 0:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in n:
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a) * 0.28, 0.25 + _rng.randf() * 1.55, sin(a) * 0.22)
		var d := Vector3(cos(a) * 0.03, (_rng.randf() - 0.5) * 0.12, sin(a) * 0.03)
		for s in SEG:
			var q := p + d + Vector3((_rng.randf() - 0.5) * 0.07, (_rng.randf() - 0.5) * 0.09, (_rng.randf() - 0.5) * 0.07)
			for off: float in [0.0, 0.006]:
				im.surface_add_vertex(p + Vector3(off, 0, 0)); im.surface_add_vertex(q + Vector3(off, 0, 0))
			p = q
	im.surface_end()

func dispose() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
