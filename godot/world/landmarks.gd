class_name WorldLandmarks
extends RefCounted
# The buildings, ships and arenas that make each world recognisable, ported from web/src/world/landmarks.js:
# same shapes, sizes and colours, placed by Codex's RuleZone (dug craters sit on the dug ground, flattened
# sites on their base height). Stone and concrete get the CC0 rock scan projected triplanar instead of flat
# colour. Landmarks with `collide` get a collision cylinder (as the JS game: radius * scale, 12 m * scale tall).

const BUILDERS := ["pod", "crater", "crashpod", "farmhouse", "kamehouse", "snakehead", "kingkaihouse", "car",
	"namekhouse", "gurutower", "friezaship", "capsuleship", "timemachine", "yardrathut", "capsulecorp", "dome",
	"labdoor", "ruin", "husk", "palace", "htcdoor", "htcroom", "cellarena", "budokai", "babidiship", "zsword",
	"crystals", "pyramid", "stands", "bunker", "pillar", "zenobox", "hangar", "radartower"]

static func has_builder(type: String) -> bool:
	return type in BUILDERS

static func build(zone: RefCounted) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	for l: Dictionary in zone.landmarks:
		if not has_builder(l.type):
			push_warning("Landmarks: no builder for '%s'" % l.type)
			continue
		var g := Node3D.new()
		g.name = "%s_%d" % [l.type, root.get_child_count()]
		g.set_meta("landmark", l)
		var y: float = zone.height_at(l.x, l.z) if l.get("dig") != null else (float(l.base) if l.get("flatten") != null else zone.height_at(l.x, l.z))
		g.position = Vector3(l.x, y, l.z)
		g.rotation.y = float(l.get("rot", 0.0))
		g.scale = Vector3.ONE * float(l.get("scale", 1.0))
		var b := Builder.new(g, zone, l)
		b.call("_" + l.type)
		root.add_child(g)
		if l.get("collide") != null:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			var s := float(l.get("scale", 1.0))
			cyl.radius = float(l.collide) * s
			cyl.height = 12.0 * s
			shape.shape = cyl
			shape.position.y = 6.0 * s
			body.add_child(shape)
			body.position = Vector3(l.x, zone.height_at(l.x, l.z), l.z)
			root.add_child(body)
	return root

class Builder extends RefCounted:
	var g: Node3D
	var zone: RefCounted
	var l: Dictionary
	var rng := RandomNumberGenerator.new()

	func _init(group: Node3D, z: RefCounted, landmark: Dictionary) -> void:
		g = group; zone = z; l = landmark
		rng.seed = int(floor(float(l.x) * 13 + float(l.z) * 7))

	# --- materials and shapes (Three.js conventions: centred meshes, torus(r, tube) lying flat) ---
	func mat(color: int, o := {}) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.hex((color << 8) | 0xff)
		m.roughness = o.get("rough", 0.6)
		m.metallic = o.get("metal", 0.0)
		if o.has("emissive"):
			m.emission_enabled = true
			m.emission = Color.hex((int(o.emissive) << 8) | 0xff)
			m.emission_energy_multiplier = o.get("glow", 1.0) * 2.0
		if o.has("opacity"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = o.opacity
		if o.get("double", false):
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if o.get("stone", false):  # photo-scanned rock, tinted by the colour
			var rock: Dictionary = WorldMaterials.ground("rock")
			if rock.albedo != null:
				m.albedo_texture = rock.albedo
				m.normal_enabled = rock.normal != null
				m.normal_texture = rock.normal
				m.uv1_triplanar = true
				m.uv1_scale = Vector3.ONE * 0.25
				m.albedo_color = m.albedo_color.lightened(0.25)
		return m

	func put(mesh: Mesh, m: Material, x := 0.0, y := 0.0, z := 0.0, parent: Node3D = null) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(x, y, z)
		(parent if parent != null else g).add_child(mi)
		return mi

	func box(w: float, h: float, d: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null) -> MeshInstance3D:
		var b := BoxMesh.new(); b.size = Vector3(w, h, d)
		return put(b, m, x, y, z, p)

	func cyl(rt: float, rb: float, h: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null, seg := 24) -> MeshInstance3D:
		var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg
		return put(c, m, x, y, z, p)

	func cone(r: float, h: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null, seg := 24) -> MeshInstance3D:
		return cyl(0.0, r, h, m, x, y, z, p, seg)

	func sphere(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null, seg := 28, hemi := false) -> MeshInstance3D:
		var s := SphereMesh.new(); s.radius = r; s.height = r if hemi else r * 2.0; s.is_hemisphere = hemi
		s.radial_segments = seg; s.rings = maxi(seg / 2, 6)
		return put(s, m, x, y, z, p)

	func dome(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null) -> MeshInstance3D:
		return sphere(r, m, x, y, z, p, 32, true)

	func torus(r: float, t: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null) -> MeshInstance3D:
		var tm := TorusMesh.new(); tm.inner_radius = r - t; tm.outer_radius = r + t; tm.rings = 40; tm.ring_segments = 12
		return put(tm, m, x, y, z, p)

	## A row of round windows facing outwards around a dome or cylinder.
	func portholes(radius: float, y: float, count: int, size: float, m: Material, centre := Vector3.ZERO, p: Node3D = null) -> void:
		for i in count:
			var a := float(i) / count * TAU
			var d := Vector3(cos(a), 0, sin(a))
			var w := cyl(size, size, 0.2, m, centre.x + d.x * radius, y, centre.z + d.z * radius, p, 16)
			w.basis = Basis(Quaternion(Vector3.UP, d))

	func tilt(mi: MeshInstance3D, rx: float, rz: float) -> void:
		mi.basis = Basis.from_euler(Vector3(rx, 0, rz))

	# --- landmarks ---
	func _pod(p: Node3D = null) -> void:
		sphere(1.1, mat(0xdedde0, {"metal": 0.8, "rough": 0.3}), 0, 0.5, 0, p)
		var win := sphere(0.75, mat(0x7a1020, {"metal": 0.3, "rough": 0.1, "emissive": 0x300008}), 0.55, 0.75, 0.2, p, 20, true)
		win.rotation.z = -1.2
	func _crater() -> void: _pod()
	func _crashpod() -> void:
		_pod()
		g.rotation.z = 0.5

	func _farmhouse() -> void:
		box(7, 3.2, 5, mat(0xc9b28a), 0, 1.6, 0)
		var roof := cone(5.4, 2.4, mat(0x8a3a2a), 0, 4.4, 0, null, 4); roof.rotation.y = PI / 4; roof.scale = Vector3(1, 1, 0.75)
		box(1.2, 2, 0.1, mat(0x5a3a22), 0, 1, 2.55)
		box(3, 2, 2.4, mat(0x9a3a2a), 6, 1, -1)
		box(2.6, 1.2, 1.6, mat(0x3a4a7a, {"metal": 0.4}), -6, 0.8, 3)

	func _kamehouse() -> void:
		var walls := mat(0xf2a6b8); var roof := mat(0xc8322a, {"rough": 0.5}); var trim := mat(0xf6f0e6)
		box(7, 4, 6, walls, 0, 2, 0)
		box(7.3, 0.4, 6.3, trim, 0, 4.1, 0)
		var r := cone(5.9, 2.6, roof, 0, 5.6, 0, null, 4); r.rotation.y = PI / 4; r.scale = Vector3(1.05, 1, 0.9)
		box(1.4, 2.4, 0.15, mat(0x7a4a2a), 0, 1.2, 3.05)
		for x in [-2.2, 2.2]:
			box(1.2, 1.1, 0.12, mat(0xbfe6ff, {"metal": 0.2, "rough": 0.1}), x, 2.5, 3.05)
		box(9, 0.3, 8, trim, 0, 0.15, 0)

	func _snakehead() -> void:
		var green := mat(0x7da34a, {"rough": 0.7}); var horn := mat(0xe6d6a0)
		box(3, 2.8, 5, green, 0, 1.4, -4.5)
		box(3.2, 1.2, 3, green, 0, 0.6, -1.4)
		box(3.2, 1, 3, green, 0, 2.8, -1.4)
		for x in [-1.3, 1.3]:
			sphere(0.35, mat(0xffcc33, {"emissive": 0x664400}), x, 3.2, -3.2)
			cone(0.3, 2, horn, x, 4, -5.5).rotation.x = -0.6

	func _kingkaihouse() -> void:
		dome(4, mat(0xf3eadb), 0, 0, 0)
		var roof := mat(0xc83228)
		torus(4, 0.3, roof, 0, 0.1, 0)
		sphere(0.8, roof, 0, 4, 0)
		box(1.4, 2.2, 0.2, mat(0x6a4a2a), 0, 1.1, 3.9)

	func _car() -> void:
		box(3, 0.7, 1.6, mat(0xc8322a, {"metal": 0.5, "rough": 0.3}), 0, 0.7, 0)
		box(1.6, 0.6, 1.4, mat(0xddeeff, {"opacity": 0.5, "rough": 0.1}), -0.2, 1.3, 0)
		for w in [[-1, -0.8], [1, -0.8], [-1, 0.8], [1, 0.8]]:
			cyl(0.35, 0.35, 0.25, mat(0x222222), w[0], 0.35, w[1], null, 16).rotation.x = PI / 2

	func _namekhouse(p: Node3D = null) -> void:
		var white := mat(0xf4f1e6, {"rough": 0.45}); var win := mat(0x3a6a5a, {"rough": 0.2})
		dome(3.4, white, 0, 0.2, 0, p)
		cyl(3.5, 3.6, 0.6, white, 0, 0.3, 0, p)
		portholes(3.1, 1.5, 6, 0.45, win, Vector3.ZERO, p)
		cyl(0.25, 0.25, 1.6, white, 0, 3.8, 0, p)
		sphere(0.4, white, 0, 4.6, 0, p)

	func _gurutower() -> void:  # the elder's house on top of the pillar mesa
		var h := Node3D.new()
		h.position.y = (zone.height_at(l.x, l.z) - g.position.y) / maxf(g.scale.y, 0.01)
		h.scale = Vector3.ONE * 1.6
		g.add_child(h)
		_namekhouse(h)

	func _friezaship() -> void:
		var hull := mat(0xd8dbe2, {"metal": 0.7, "rough": 0.25}); var glow := mat(0xff5aa0, {"emissive": 0xff2a80, "glow": 1.5})
		var s := sphere(14, hull, 0, 6, 0, null, 48); s.scale = Vector3(1, 0.42, 1)
		torus(14, 0.6, mat(0x9aa0aa, {"metal": 0.8}), 0, 6, 0)
		portholes(13.4, 6.4, 18, 0.6, glow)
		for i in 6:
			var a := float(i) / 6 * TAU
			tilt(cyl(0.5, 0.8, 5, hull, cos(a) * 9, 2.5, sin(a) * 9, null, 10), -sin(a) * 0.3, cos(a) * 0.3)

	func _capsuleship() -> void:
		var hull := mat(0xeeeef0, {"metal": 0.5, "rough": 0.3}); var blue := mat(0x2e5ea8, {"metal": 0.3})
		sphere(3, hull, 0, 3.6, 0)
		torus(3, 0.25, blue, 0, 3.6, 0)
		portholes(2.9, 4.4, 8, 0.32, mat(0x8fd0ff, {"emissive": 0x1a3a5a}))
		for i in 4:
			var a := float(i) / 4 * TAU + 0.4
			tilt(cyl(0.15, 0.2, 2.6, blue, cos(a) * 2.6, 1.2, sin(a) * 2.6, null, 8), -sin(a) * 0.4, cos(a) * 0.4)

	func _timemachine() -> void:
		var body := mat(0xf0e6c8, {"metal": 0.4, "rough": 0.35})
		cyl(1.2, 1.2, 2.2, body, 0, 1.6, 0, null, 20).rotation.z = 0.05
		dome(1.2, mat(0xbfe6ff, {"opacity": 0.55, "rough": 0.05}), 0, 2.7, 0)
		for i in 4:
			var a := float(i) / 4 * TAU
			tilt(cyl(0.08, 0.12, 1.4, body, cos(a) * 1.1, 0.5, sin(a) * 1.1, null, 6), -sin(a) * 0.5, cos(a) * 0.5)

	func _yardrathut() -> void:
		var shell := mat(0xd9c2f0, {"rough": 0.35}); var band := mat(0x8a6ad0)
		sphere(3, shell, 0, 0.8, 0).scale = Vector3(1, 0.85, 1)
		torus(2.9, 0.2, band, 0, 1.2, 0)
		cone(0.5, 2.6, band, 0, 4.6, 0, null, 8)

	func _capsulecorp() -> void:
		var white := mat(0xf6f3ea, {"rough": 0.35}); var yellow := mat(0xf2c94c, {"rough": 0.45}); var glass := mat(0x8fbfdf, {"rough": 0.08, "metal": 0.2})
		dome(16, white, 0, 0, 0).scale = Vector3(1, 0.72, 1)
		torus(16, 0.6, yellow, 0, 0.6, 0)
		portholes(13.6, 5.2, 16, 1.0, glass)
		cyl(5, 5, 14, white, 15, 7, -6, null, 32)
		dome(5, white, 15, 14, -6)
		torus(5.1, 0.35, yellow, 15, 9, -6)
		portholes(5, 11, 8, 0.6, glass, Vector3(15, 0, -6))
		box(5, 3.4, 0.4, glass, 0, 1.7, 16.1)

	func _dome() -> void:
		var white := mat(0xf2efe6, {"rough": 0.4})
		var accent := mat([0x6aa6d8, 0xd88a6a, 0x8ac87a][rng.randi_range(0, 2)])
		dome(6, white, 0, 0, 0).scale = Vector3(1, 0.8, 1)
		torus(6, 0.3, accent, 0, 0.4, 0)
		portholes(5.3, 2.4, 10, 0.5, mat(0x8fbfdf, {"rough": 0.1}))

	func _labdoor() -> void:
		box(6, 5, 1.2, mat(0x8a9098, {"metal": 0.85, "rough": 0.35}), 0, 2.5, 0)
		box(5.4, 4.4, 0.3, mat(0x50565e, {"metal": 0.8, "rough": 0.4}), 0, 2.3, 0.7)
		box(0.4, 4.4, 0.4, mat(0xb03a2a), 0, 2.3, 0.9)

	func _ruin() -> void:  # broken concrete buildings
		var conc := mat(0x8c8a84, {"rough": 0.9, "stone": true}); var dark := mat(0x3a3a3c, {"rough": 0.9})
		for i in 4:
			var w := 4 + rng.randf() * 6; var h := 4 + rng.randf() * 14; var d := 4 + rng.randf() * 6
			var b := box(w, h, d, conc, (rng.randf() - 0.5) * 14, h / 2 - 0.5, (rng.randf() - 0.5) * 14)
			b.rotation = Vector3(0, rng.randf() * 0.4, (rng.randf() - 0.5) * 0.15)
			for k in 3:
				box(w * 0.2, 1, 0.1, dark, b.position.x + (rng.randf() - 0.5) * w * 0.6, 2 + rng.randf() * (h - 3), b.position.z + d / 2 + 0.06)
		for i in 8:
			box(1 + rng.randf() * 2, 0.6 + rng.randf(), 1 + rng.randf() * 2, conc, (rng.randf() - 0.5) * 20, 0.3, (rng.randf() - 0.5) * 20).rotation = Vector3(rng.randf(), rng.randf(), rng.randf())

	func _husk() -> void:
		var s := sphere(1.4, mat(0x6a8a3a, {"rough": 0.5, "double": true}), 0, 1.2, 0, null, 20)
		s.scale = Vector3(0.8, 1.4, 0.8); s.rotation.x = 0.5

	func _palace() -> void:  # Kamu's Palace on the Lookout
		var white := mat(0xf4f1ea, {"rough": 0.4}); var gold := mat(0xd8b04a, {"metal": 0.6, "rough": 0.3})
		cyl(9, 10, 6, white, 0, 3, 0, null, 40)
		dome(9, white, 0, 6, 0)
		sphere(1, gold, 0, 15.2, 0)
		for i in 4:
			var a := float(i) / 4 * TAU + PI / 4
			cyl(1.6, 1.6, 10, white, cos(a) * 12, 5, sin(a) * 12, null, 20)
			cone(1.8, 3, gold, cos(a) * 12, 11.5, sin(a) * 12, null, 20)
		box(4, 4.4, 0.4, mat(0x7a5a3a), 0, 2.2, 10)

	func _htcdoor() -> void:
		var white := mat(0xf7f5ef, {"rough": 0.35})
		box(6, 6, 5, white, 0, 3, 0)
		box(2.6, 4.2, 0.2, mat(0xd8d2c6), 0, 2.1, 2.55)
		cone(4.6, 2, white, 0, 7, 0, null, 4).rotation.y = PI / 4

	func _htcroom() -> void:
		var white := mat(0xfbfaf6, {"rough": 0.3})
		box(16, 6, 10, white, 0, 3, 0)
		for x in [-6, 6]:
			cyl(1.2, 1.2, 9, white, x, 4.5, 5.2, null, 16)

	func _cellarena() -> void:  # square ring of stone tiles
		var tile := mat(0xd6d2c6, {"rough": 0.85, "stone": true}); var seam := mat(0x8c887e, {"rough": 0.9})
		box(50, 1, 50, tile, 0, 0.5, 0)
		for i in range(-20, 21, 10):
			box(50, 0.05, 0.25, seam, 0, 1.02, i)
			box(0.25, 0.05, 50, seam, i, 1.02, 0)
		for c in [[-26, -26], [26, -26], [-26, 26], [26, 26]]:
			cyl(0.6, 0.6, 5, seam, c[0], 2.5, c[1], null, 12)
			sphere(0.7, mat(0xff4a3a, {"emissive": 0x801010}), c[0], 5.4, c[1])

	func _budokai() -> void:
		var stone := mat(0xd8cdb4, {"rough": 0.8, "stone": true}); var red := mat(0xb8322a, {"rough": 0.5}); var line := mat(0x9a8e76)
		box(40, 1.6, 40, stone, 0, 0.8, 0)
		for i in range(-16, 17, 8):
			box(40, 0.05, 0.2, line, 0, 1.62, i)
			box(0.2, 0.05, 40, line, i, 1.62, 0)
		for x in [-8, 8]:
			cyl(0.9, 0.9, 12, red, x, 6, 26, null, 16)
		box(22, 1.2, 2.4, red, 0, 12.4, 26)
		box(26, 1.2, 4, mat(0x3a3a3a), 0, 13.6, 26)

	func _babidiship() -> void:
		var hull := mat(0xc4a87a, {"rough": 0.75, "stone": true}); var dark := mat(0x3a2a1a)
		sphere(22, hull, 0, 4, 0, null, 40).scale = Vector3(1, 0.55, 1)
		for i in 4:
			var a := float(i) / 4 * TAU
			box(4, 2.5, 0.6, dark, cos(a) * 21.6, 5, sin(a) * 21.6).rotation.y = -a + PI / 2
		box(5, 4, 3, dark, 0, 2, -21)

	func _zsword() -> void:
		sphere(2.4, mat(0x8a8274, {"rough": 0.9, "stone": true}), 0, 0.4, 0, null, 10).scale = Vector3(1.2, 0.6, 1)
		box(0.3, 4.6, 0.9, mat(0xd6dce6, {"metal": 0.95, "rough": 0.15}), 0, 3.4, 0)
		box(1.8, 0.4, 0.5, mat(0xd8b04a, {"metal": 0.7}), 0, 5.8, 0)
		box(0.3, 1.4, 0.3, mat(0x5a3a22), 0, 6.6, 0)

	func _crystals() -> void:
		var c := mat(0xf0c8ff, {"rough": 0.1, "emissive": 0x8a4ad0, "glow": 0.6})
		for i in 7:
			var h := 2 + (i % 3) * 2.2
			cone(0.6 + (i % 2) * 0.3, h, c, cos(i * 2.4) * 1.8, h / 2, sin(i * 2.4) * 1.8, null, 6).rotation = Vector3((i % 3 - 1) * 0.2, i, (i % 2 - 0.5) * 0.3)

	func _pyramid() -> void:  # Beeros's temple
		var stone := mat(0xc8b48c, {"rough": 0.7, "stone": true}); var purple := mat(0x6a3a9a, {"rough": 0.5})
		for i in 4:
			box(34 - i * 7, 5, 34 - i * 7, stone, 0, 2.5 + i * 5, 0)
		cyl(2, 2.4, 6, purple, 0, 23, 0, null, 16)
		sphere(2.6, mat(0xffe6a0, {"emissive": 0xaa7a20, "glow": 1.2}), 0, 27.5, 0)

	func _stands() -> void:
		var seat := mat(0x8a8a90, {"rough": 0.8, "stone": true})
		for i in 5:
			box(40, 1, 3, seat, 0, i * 1.2 + 0.5, i * 3)

	func _bunker() -> void:
		dome(5, mat(0x6a6a66, {"rough": 0.9, "stone": true}), 0, 0, 0).scale = Vector3(1, 0.5, 1)
		box(2, 2, 2, mat(0x3a3a3a), 0, 1, 4.4)

	func _pillar() -> void:  # Tournament of Might stage pillar
		var stone := mat(0xbab4c8, {"rough": 0.6, "stone": true}); var glow := mat(0x9a8aff, {"emissive": 0x5a4ad0, "glow": 1.4})
		cyl(2.2, 2.6, 22, stone, 0, 11, 0, null, 12)
		torus(2.5, 0.25, glow, 0, 16, 0)
		torus(2.5, 0.25, glow, 0, 6, 0)

	func _zenobox() -> void:  # Grand Zenno's floating viewing stand
		var gold := mat(0xd8c070, {"metal": 0.7, "rough": 0.3}); var white := mat(0xf2f0ff, {"rough": 0.3})
		cyl(12, 9, 3, white, 0, 26, 0, null, 36)
		torus(12, 0.6, gold, 0, 27.5, 0)
		cone(1.2, 24, white, 0, 12, 0, null, 12).rotation.x = PI

	func _hangar() -> void:  # Crimson Ribbon base buildings
		var wall := mat(0xa8a49a, {"rough": 0.8}); var red := mat(0xb8322a, {"rough": 0.6})
		box(30, 10, 20, wall, 0, 5, 0)
		var roof := cyl(10, 10, 30, wall, 0, 10, 0, null, 24); roof.rotation.z = PI / 2; roof.scale = Vector3(1, 1, 0.5)
		box(30.2, 1.6, 0.2, red, 0, 7, 10.1)
		box(10, 7, 0.3, mat(0x4a4a48, {"metal": 0.6}), 0, 3.5, 10.2)

	func _radartower() -> void:
		var steel := mat(0x8a8a8a, {"metal": 0.8, "rough": 0.4})
		cyl(0.5, 0.9, 24, steel, 0, 12, 0, null, 8)
		var dish := sphere(3, steel, 0, 25, 0, null, 24, true); dish.rotation.x = 2.4
