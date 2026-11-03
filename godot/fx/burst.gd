class_name Burst
extends Node3D
# One-shot impact: an expanding shock ring, a flash and sparks. Frees itself.

const GLOW := preload("res://fx/shaders/glow_point.gdshader")
const ENERGY := preload("res://fx/shaders/energy.gdshader")
var life := 0.0
var max_life := 0.45
var ring: MeshInstance3D
var flash: MeshInstance3D
static var _ring_mesh: TorusMesh
static var _flash_mesh: SphereMesh
static var _energy: ShaderMaterial

static func spawn(parent: Node, pos: Vector3, color: Color, size := 1.0) -> Burst:
	var b := Burst.new()
	b.position = pos
	b.scale = Vector3.ONE * size
	parent.add_child(b)
	b._build(color)
	return b

func _build(color: Color) -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new(); _ring_mesh.inner_radius = 0.9; _ring_mesh.outer_radius = 1.0; _ring_mesh.rings = 32; _ring_mesh.ring_segments = 6
		_flash_mesh = SphereMesh.new(); _flash_mesh.radius = 0.5; _flash_mesh.height = 1.0; _flash_mesh.radial_segments = 16; _flash_mesh.rings = 8
		_energy = ShaderMaterial.new(); _energy.shader = ENERGY
	ring = MeshInstance3D.new(); ring.mesh = _ring_mesh; ring.material_override = _energy
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation.x = randf() * 0.6 - 0.3 + PI / 2.0
	ring.set_instance_shader_parameter("energy_color", color)
	add_child(ring)
	flash = MeshInstance3D.new(); flash.mesh = _flash_mesh; flash.material_override = _energy
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.set_instance_shader_parameter("energy_color", color)
	add_child(flash)
	var sp := CPUParticles3D.new()
	sp.one_shot = true; sp.emitting = true; sp.amount = 18; sp.lifetime = 0.4; sp.explosiveness = 1.0
	sp.direction = Vector3.UP; sp.spread = 180.0; sp.initial_velocity_min = 3.0; sp.initial_velocity_max = 7.0
	sp.gravity = Vector3(0, -6, 0); sp.scale_amount_min = 0.6; sp.scale_amount_max = 1.2
	var q := QuadMesh.new(); q.size = Vector2(0.09, 0.09)
	var m := ShaderMaterial.new(); m.shader = GLOW; m.set_shader_parameter("tint", color.lerp(Color.WHITE, 0.4))
	q.material = m
	sp.mesh = q
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sp)

func _process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	life += dt
	var k := clampf(life / max_life, 0.0, 1.0)
	ring.scale = Vector3.ONE * (0.2 + k * 1.3)
	ring.set_instance_shader_parameter("strength", (1.0 - k) * 1.2)
	flash.scale = Vector3.ONE * (0.5 + k * 0.8)
	flash.set_instance_shader_parameter("strength", maxf(0.0, 1.0 - k * 2.5) * 1.5)
	if life >= max_life + 0.3:
		queue_free()
