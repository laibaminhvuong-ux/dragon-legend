class_name GreatApe
extends Node3D
# Original procedural Great Ape (port of the JS great_ape): heavy fur torso, long arms, muzzle, fangs and a
# curved tail. Built at human size (origin at the feet, facing +Z); the fighter scales it up with the form.

var hips: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var _time := 0.0
var _last_attack := 0
var _attack_until := 0.0
var _stride := 0.0

static func create(golden: bool) -> GreatApe:
	var g := GreatApe.new()
	g.name = "GoldenGreatApe" if golden else "GreatApe"
	g._build(golden)
	return g

func _build(golden: bool) -> void:
	var fur := Parts.material(Color.hex(0xd6a72cff if golden else 0x5b3520ff), 0.95)
	var skin := Parts.material(Color.hex(0x9c7138ff if golden else 0x8c6246ff), 0.9)
	var dark := Parts.material(Color.hex(0x1b1514ff), 0.9)
	var ivory := Parts.material(Color.hex(0xffefd0ff), 0.6)
	var eyes := StandardMaterial3D.new(); eyes.albedo_color = Color.hex(0xf02020ff); eyes.emission_enabled = true; eyes.emission = Color.hex(0xb40000ff); eyes.emission_energy_multiplier = 0.7
	var ball := SphereMesh.new(); ball.radius = 1.0; ball.height = 2.0; ball.radial_segments = 16; ball.rings = 10
	var add := func(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale_v: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
		mi.position = pos; mi.scale = scale_v; mi.rotation = rot
		parent.add_child(mi); return mi
	hips = Node3D.new(); hips.position.y = 0.78; add_child(hips)
	add.call(hips, ball, fur, Vector3(0, 0.1, 0), Vector3(0.38, 0.32, 0.25))
	add.call(hips, ball, fur, Vector3(0, 0.52, -0.025), Vector3(0.49, 0.49, 0.31))
	add.call(hips, ball, skin, Vector3(0, 0.43, 0.265), Vector3(0.29, 0.29, 0.075))
	var head := Node3D.new(); head.position = Vector3(0, 0.98, 0.06); hips.add_child(head)
	add.call(head, ball, fur, Vector3.ZERO, Vector3(0.27, 0.29, 0.23))
	add.call(head, ball, skin, Vector3(0, -0.055, 0.17), Vector3(0.21, 0.2, 0.12))
	add.call(head, ball, skin, Vector3(0, -0.14, 0.265), Vector3(0.17, 0.09, 0.11))
	add.call(head, ball, dark, Vector3(0, -0.07, 0.325), Vector3(0.09, 0.045, 0.035))
	var box := BoxMesh.new()
	add.call(head, box, dark, Vector3(0, -0.17, 0.35), Vector3(0.22, 0.035, 0.018))
	var fang := CylinderMesh.new(); fang.top_radius = 0.018; fang.bottom_radius = 0.0; fang.height = 0.09; fang.radial_segments = 6
	for sign: float in [-1.0, 1.0]:
		add.call(head, ball, skin, Vector3(sign * 0.275, 0.005, 0), Vector3(0.07, 0.095, 0.045))
		add.call(head, ball, eyes, Vector3(sign * 0.095, 0.035, 0.211), Vector3(0.06, 0.028, 0.018))
		add.call(head, ball, fur, Vector3(sign * 0.1, 0.076, 0.2), Vector3(0.11, 0.04, 0.035), Vector3(0, 0, sign * 0.18))
		add.call(head, fang, ivory, Vector3(sign * 0.08, -0.17, 0.36), Vector3.ONE)
		var arm := Node3D.new(); arm.position = Vector3(sign * 0.44, 0.69, 0); hips.add_child(arm)
		add.call(arm, ball, fur, Vector3(sign * 0.03, -0.18, 0), Vector3(0.19, 0.3, 0.19))
		add.call(arm, ball, fur, Vector3(sign * 0.06, -0.51, 0.02), Vector3(0.16, 0.27, 0.15))
		add.call(arm, ball, skin, Vector3(sign * 0.07, -0.77, 0.055), Vector3(0.15, 0.16, 0.12))
		for i in 3:
			add.call(arm, ball, skin, Vector3(sign * 0.07 + (i - 1) * 0.07, -0.86, 0.08), Vector3(0.036, 0.1, 0.047))
		arms.append(arm)
		var leg := Node3D.new(); leg.position = Vector3(sign * 0.21, 0, 0); hips.add_child(leg)
		add.call(leg, ball, fur, Vector3(0, -0.2, 0), Vector3(0.19, 0.28, 0.18))
		add.call(leg, ball, fur, Vector3(0, -0.49, 0.02), Vector3(0.14, 0.25, 0.14))
		add.call(leg, ball, skin, Vector3(0, -0.7, 0.12), Vector3(0.17, 0.08, 0.23))
		legs.append(leg)
	var g := Geo.new()
	g.tube(PackedVector3Array([Vector3(0, 0.85, -0.2), Vector3(0.2, 0.65, -0.65), Vector3(0.5, 0.85, -0.9), Vector3(0.45, 1.25, -0.8)]), 0.065, 0.06, 16, 8)
	add.call(self, g.mesh(), fur, Vector3.ZERO, Vector3.ONE)

func update(dt: float, anim: Dictionary) -> void:
	_time += dt
	var serial := int(anim.get("attackSerial", 0))
	if serial != 0 and serial != _last_attack:
		_last_attack = serial
		_attack_until = _time + 0.55
	var stride := minf(1.0, float(anim.get("speed", 0.0)) / 8.0)
	_stride = lerpf(_stride,stride,1.0-exp(-dt*5.0))
	var swing := sin(_time * 6.0) * _stride * 0.5
	arms[0].rotation.x = -swing; arms[1].rotation.x = swing; legs[0].rotation.x = swing; legs[1].rotation.x = -swing
	if _attack_until > _time:
		arms[_last_attack % 2].rotation.x = -1.3 * MotionStyle.strike(0.55-(_attack_until-_time),0.55)
	if anim.get("blocking", false):
		for a in arms: a.rotation.x = -1.2
	hips.rotation.x = 0.25 if anim.get("dashing", false) else 0.0
	hips.position.y = 0.78 + absf(sin(_time * 6.0)) * 0.04 * _stride

	if anim.get("charging",false):
		hips.rotation.x = -0.1
		for a in arms: a.rotation.x = 0.25+sin(_time*24)*0.012
	if anim.get("hurt",false):
		hips.rotation.x -= 0.18
	if anim.get("flying",false):
		hips.rotation.x += 0.75*_stride
