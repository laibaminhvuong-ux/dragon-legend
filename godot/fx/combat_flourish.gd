class_name CombatFlourish
extends Node3D
# Short-lived, inexpensive mesh trails. A view-owned container caps concurrent instances.
var age := 0.0
var duration := 0.25
var kind := "arc"
var mesh: MeshInstance3D
var material: StandardMaterial3D
static func create(type: String,color: Color,direction := Vector3.FORWARD) -> CombatFlourish:
	var f := CombatFlourish.new()
	f.kind = type
	f.material = StandardMaterial3D.new()
	f.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f.material.albedo_color = color
	f.material.emission_enabled = true
	f.material.emission = color
	f.material.emission_energy_multiplier = 1.8
	f.material.cull_mode = BaseMaterial3D.CULL_DISABLED
	f.mesh = MeshInstance3D.new()
	f.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.mesh.material_override = f.material
	f.add_child(f.mesh)
	if type=="arc":
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 16:
			var a := -1.25+float(i)/16*2.5
			var b := -1.25+float(i+1)/16*2.5
			var p := Vector3(sin(a),cos(a)*0.45,cos(a))*0.8
			var q := Vector3(sin(b),cos(b)*0.45,cos(b))*0.8
			for v: Vector3 in [p,p*1.14,q,q,p*1.14,q*1.14]: im.surface_add_vertex(v)
		im.surface_end()
		f.mesh.mesh = im
		f.duration = 0.18
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.87; ring.outer_radius = 1.0; ring.rings = 32; ring.ring_segments = 6
		f.mesh.mesh = ring
		f.duration = 0.4 if type=="surge" else 0.25
		if type=="impact" and direction.length_squared()>0.001:
			f.mesh.basis = Basis(Quaternion(Vector3.UP,direction.normalized()))
	return f
func _process(dt: float) -> void:
	tick(dt)
func tick(dt: float) -> void:
	age += dt
	var p := clampf(age/duration,0,1)
	mesh.scale = Vector3.ONE*(lerpf(0.35,1.6,p) if kind!="arc" else lerpf(0.8,1.2,p))
	material.albedo_color.a = (1.0-p)*(1.0-p)*0.8
	if age>=duration:
		queue_free()
