class_name WishDragon
extends Node3D
# Original low-poly wish dragons (port of web/src/character/wish_dragon.js): a coiled body rising out of a
# summoning ring, with a muscular, finned or winged variant. Looks from data dragon_looks.

var body: Node3D
var head: Node3D
var ring: MeshInstance3D
var time := 0.0

static func create(id: String) -> WishDragon:
	var d := WishDragon.new()
	d.name = "WishDragon_" + id
	d._build(id)
	return d

static func _hex(v: Variant) -> Color:
	return Color.hex((int(v) << 8) | 0xff)

func _build(id: String) -> void:
	var looks: Dictionary = RuleTables.table("dragon_looks") if RuleTables.table("dragon_looks") is Dictionary else {}
	var look: Dictionary = looks.get(id, looks.values()[0] if not looks.is_empty() else {"body": 0x2f9d4a, "belly": 0xd9c27a, "horns": 0xe8dcc0, "eyes": 0xff3030, "kind": "classic"})
	body = Node3D.new(); add_child(body)
	var skin := StandardMaterial3D.new(); skin.albedo_color = _hex(look.body); skin.roughness = 0.58
	if id == "super":
		skin.metallic = 0.35; skin.emission_enabled = true; skin.emission = _hex(0x815600); skin.emission_energy_multiplier = 0.35
	var belly := Parts.material(_hex(look.belly), 0.58)
	var horn := Parts.material(_hex(look.horns), 0.58)
	var eye := StandardMaterial3D.new(); eye.albedo_color = _hex(look.eyes); eye.emission_enabled = true; eye.emission = _hex(look.eyes); eye.emission_energy_multiplier = 0.6
	var sphere := SphereMesh.new(); sphere.radius = 1.0; sphere.height = 2.0; sphere.radial_segments = 14; sphere.rings = 8
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 1.0; cone.height = 1.0; cone.radial_segments = 8
	var part := func(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, sc: Vector3) -> MeshInstance3D:
		var m := MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.position = pos; m.scale = sc
		parent.add_child(m); return m
	var pts := [Vector3(0, 0.25, -1), Vector3(-2, 0.5, -1.8), Vector3(-2.5, 1.1, 1), Vector3(1, 1.5, 2), Vector3(2.4, 2.5, -0.4), Vector3(0.5, 3.5, -1), Vector3(0, 5.2, -0.3), Vector3(0, 6.8, 0)]
	var g := Geo.new()
	g.tube(PackedVector3Array(pts), 0.43, 0.43, 64, 10)
	part.call(body, g.mesh(), skin, Vector3.ZERO, Vector3.ONE)
	var curve := Curve3D.new()
	for k in pts.size():
		var tan: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]) / 6.0
		curve.add_point(pts[k], -tan, tan)
	var length := curve.get_baked_length()
	for i in 13:
		var p := curve.sample_baked((0.15 + i * 0.058) * length, true)
		part.call(body, sphere, belly, Vector3(p.x, p.y, p.z + 0.32), Vector3(0.31, 0.23, 0.15))
	head = Node3D.new(); head.position = Vector3(0, 6.9, 0.1); body.add_child(head)
	part.call(head, sphere, skin, Vector3.ZERO, Vector3(0.67, 0.52, 0.7))
	part.call(head, sphere, skin, Vector3(0, -0.1, 0.7), Vector3(0.51, 0.25, 0.52))
	part.call(head, sphere, belly, Vector3(0, -0.37, 0.65), Vector3(0.48, 0.13, 0.55))
	var whisker := CylinderMesh.new(); whisker.top_radius = 0.02; whisker.bottom_radius = 0.015; whisker.height = 1.5; whisker.radial_segments = 5
	for side: float in [-1.0, 1.0]:
		part.call(head, sphere, eye, Vector3(side * 0.47, 0.1, 0.48), Vector3(0.15, 0.1, 0.08))
		(part.call(head, cone, horn, Vector3(side * 0.5, 0.68, -0.18), Vector3(0.16, 0.95, 0.16)) as Node3D).rotation.z = -side * 0.3
		part.call(head, sphere, horn, Vector3(side * 0.24, 0.05, 1.04), Vector3(0.07, 0.045, 0.05))
		(part.call(head, cone, horn, Vector3(side * 0.3, -0.31, 0.95), Vector3(0.065, 0.3, 0.065)) as Node3D).rotation.z = PI
		(part.call(head, whisker, horn, Vector3(side * 0.85, -0.1, 0.8), Vector3.ONE) as Node3D).rotation.z = side * 1.1
		(part.call(body, sphere, skin, Vector3(side * 0.85, 5, 0.05), Vector3(0.8, 0.24, 0.26)) as Node3D).rotation.z = -side * 0.45
		part.call(body, sphere, skin, Vector3(side * 1.45, 4.65, 0.35), Vector3(0.3, 0.2, 0.32))
		for i in 3:
			(part.call(body, cone, horn, Vector3(side * (1.3 + i * 0.13), 4.45, 0.52), Vector3(0.045, 0.28, 0.045)) as Node3D).rotation.x = PI * 0.8
	match str(look.get("kind", "")):
		"muscular":
			part.call(body, sphere, skin, Vector3(0, 5, 0.05), Vector3(1.25, 1.15, 0.65))
			part.call(body, sphere, belly, Vector3(0, 5, 0.6), Vector3(0.85, 0.85, 0.13))
			for side: float in [-1.0, 1.0]:
				part.call(body, sphere, skin, Vector3(side * 1.25, 5.5, 0), Vector3(0.55, 0.65, 0.55))
		"finned":
			var fins := Parts.material(_hex(0xedd4b9), 0.58, 0.0, true)
			for side: float in [-1.0, 1.0]:
				part.call(head, _fin(side, 1.6), fins, Vector3(side * 0.5, 0.1, -0.2), Vector3.ONE)
		"winged":
			var wm := StandardMaterial3D.new(); wm.albedo_color = _hex(0xffd864); wm.metallic = 0.4; wm.cull_mode = BaseMaterial3D.CULL_DISABLED
			wm.emission_enabled = true; wm.emission = _hex(0x7a4400); wm.emission_energy_multiplier = 0.3
			var wings := Node3D.new(); wings.position = Vector3(0, 5.1, -0.8); body.add_child(wings)
			for side: float in [-1.0, 1.0]:
				part.call(wings, _fin(side, 4.0), wm, Vector3(side * 0.5, 0.1, -0.2), Vector3.ONE)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = _hex(0xffdb67 if id == "super" else 0x81ffbb); rm.emission_enabled = true
	rm.emission = _hex(0xffb52b if id == "super" else 0x40b878); rm.emission_energy_multiplier = 1.0
	var t := TorusMesh.new(); t.inner_radius = 0.975; t.outer_radius = 1.025; t.rings = 48; t.ring_segments = 6
	ring = part.call(self, t, rm, Vector3(0, 0.05, 0), Vector3.ONE)
	body.scale = Vector3.ONE * 0.25 * 0.01

static func _fin(side: float, size: float) -> ArrayMesh:
	var pts := [Vector2(0, 0), Vector2(side * size * 0.6, size * 0.85), Vector2(side * size * 1.2, size * 0.25), Vector2(side * size, size * -0.4), Vector2(0, -size * 0.2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for i in range(1, pts.size() - 1):
		for p: Vector2 in [pts[0], pts[i], pts[i + 1]]:
			st.add_vertex(Vector3(p.x, p.y, 0))
	return st.commit()

func update(dt: float, _anim: Dictionary = {}) -> void:
	time += maxf(0.0, dt)
	var rise := 1.0 - exp(-time * 2.5)
	body.scale = Vector3.ONE * maxf(0.0025, 0.25 * rise)
	body.position.y = sin(time * 1.5) * 0.04
	head.rotation.y = sin(time * 0.6) * 0.06
	ring.rotation.z = time * 0.25

func dispose() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
