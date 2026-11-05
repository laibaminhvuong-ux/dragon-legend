class_name WorldLandmarks
extends RefCounted
# The buildings, ships and arenas that make each world recognisable, ported from web/src/world/landmarks.js:
# same shapes, sizes and colours, placed by Codex's RuleZone (dug craters sit on the dug ground, flattened
# sites on their base height). Stone and concrete get the CC0 rock scan projected triplanar instead of flat
# colour. Landmarks with `collide` get a collision cylinder (as the JS game: radius * scale, 12 m * scale tall).

const BUILDERS := ["pod", "crater", "crashpod", "farmhouse", "kamehouse", "snakehead", "kingkaihouse", "car",
	"namekhouse", "gurutower", "friezaship", "capsuleship", "timemachine", "yardrathut", "capsulecorp", "dome",
	"labdoor", "ruin", "husk", "palace", "htcdoor", "htcroom", "cellarena", "budokai", "babidiship", "zsword",
	"crystals", "pyramid", "stands", "bunker", "pillar", "zenobox", "hangar", "radartower", "checkin", "town", "kaiplanet", "interior",
	"paozuhut", "firecastle", "pilavcastle", "muscletower", "baabapalace", "korrintower", "piccorcastle", "lookout", "nexus"]

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

	# --- interiors (RuleInterior): one closed room, furniture, lights, a glowing exit door on the +z wall ---
	func _interior() -> void:
		var style := str(l.get("style", "home"))
		var d: Dictionary = RuleInterior.dims(style)
		var w: float = d.w; var dd: float = d.d; var h: float = d.h
		var pal: Array = {
			"home": [0xe9dcc3, 0x8a6a48, 0xf4efe6], "tower": [0xdfe6ee, 0x6d7a8a, 0xf6f8fb], "lab": [0xe4ecf0, 0x8fa0ad, 0xf0f6fa],
			"temple": [0xd9c9a3, 0x9a8460, 0xcdb88a], "hangar": [0xb8bec6, 0x5d646d, 0x9aa1aa]}.get(style, [0xe9dcc3, 0x8a6a48, 0xf4efe6])
		var wall := mat(int(pal[0]), {"rough": 0.85}); var floor_m := mat(int(pal[1]), {"rough": 0.7}); var ceil_m := mat(int(pal[2]), {"rough": 0.9})
		box(w + 1.0, 0.3, dd + 1.0, floor_m, 0, -0.12, 0)   # top just above the ground plane (no flicker)
		box(w + 1.0, 0.3, dd + 1.0, ceil_m, 0, h + 0.15, 0)
		box(w + 1.0, h, 0.4, wall, 0, h * 0.5, -dd * 0.5 - 0.2)
		box(w + 1.0, h, 0.4, wall, 0, h * 0.5, dd * 0.5 + 0.2)
		box(0.4, h, dd + 1.0, wall, -w * 0.5 - 0.2, h * 0.5, 0)
		box(0.4, h, dd + 1.0, wall, w * 0.5 + 0.2, h * 0.5, 0)
		# skirting and a rug / floor markings
		for side in [-1.0, 1.0]:
			box(w, 0.25, 0.08, mat(int(pal[1])), 0, 0.12, side * (dd * 0.5 - 0.02))
		box(w * 0.45, 0.03, dd * 0.4, mat(0xa83a32 if style in ["home", "temple"] else 0x3a6ea8, {"rough": 1.0}), 0, 0.02, 0)
		# the exit door (glows so you can find it)
		box(2.0, 3.0, 0.15, mat(0x6a4426), 0, 1.5, dd * 0.5 - 0.05)
		box(2.4, 0.2, 0.2, mat(0xffe9a8, {"emissive": 0xffd070, "glow": 1.6}), 0, 3.15, dd * 0.5 - 0.1)
		# lights: a warm grid of lamps under the ceiling
		var lamp := mat(0xfff4d8, {"emissive": 0xffe6b0, "glow": 2.2})
		var nx := maxi(1, int(w / 9.0)); var nz := maxi(1, int(dd / 9.0))
		for i in nx:
			for k in nz:
				var lx := (float(i) + 0.5) / nx * w - w * 0.5
				var lz := (float(k) + 0.5) / nz * dd - dd * 0.5
				cyl(0.5, 0.5, 0.12, lamp, lx, h - 0.1, lz)
				var light := OmniLight3D.new()
				light.light_color = Color(1.0, 0.92, 0.8)
				light.light_energy = 1.4
				light.omni_range = maxf(w, dd) * 0.7
				light.position = Vector3(lx, h - 0.6, lz)
				g.add_child(light)
		# windows (bright panes) on the side walls
		var glass := mat(0xbfe2ff, {"emissive": 0x9ccfff, "glow": 0.9, "rough": 0.1})
		for side in [-1.0, 1.0]:
			for k in maxi(1, int(dd / 6.0)):
				box(0.1, 1.6, 2.0, glass, side * (w * 0.5 - 0.02), h * 0.55, (float(k) + 0.5) / maxi(1, int(dd / 6.0)) * dd - dd * 0.5)
		for f: Dictionary in RuleInterior.furniture(style):
			_furnish(f)

	func _furnish(f: Dictionary) -> void:
		var x: float = f.x; var z: float = f.z; var fw: float = f.w; var fd: float = f.d; var fh: float = f.h
		var wood := mat(0x7a5232, {"rough": 0.8}); var metal := mat(0xaab4c0, {"metal": 0.6, "rough": 0.35})
		match str(f.kind):
			"table", "desk", "bench":
				box(fw, 0.12, fd, wood if f.kind != "bench" else metal, x, fh, z)
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						box(0.12, fh, 0.12, wood if f.kind != "bench" else metal, x + sx * (fw * 0.5 - 0.15), fh * 0.5, z + sz * (fd * 0.5 - 0.15))
			"bed":
				box(fw, fh * 0.6, fd, wood, x, fh * 0.3, z)
				box(fw * 0.95, 0.22, fd * 0.95, mat(0xf2f2ee), x, fh * 0.6 + 0.11, z)
				box(fw * 0.7, 0.16, 0.6, mat(0xe8e8f6), x, fh * 0.6 + 0.3, z - fd * 0.35)
			"shelf":
				box(fw, fh, fd, wood, x, fh * 0.5, z)
				for i in 4:
					box(fw * 0.4, 0.3, fd * 0.8, mat([0xb04a3a, 0x3a6ab0, 0xd8b040, 0x4a9a5a][i]), x - 0.1, 0.5 + i * 0.5, z)
			"stove":
				box(fw, fh, fd, mat(0x3a3a3e, {"rough": 0.5}), x, fh * 0.5, z)
			"pillar":
				cyl(fw * 0.5, fw * 0.55, fh, mat(0xd8d2c4, {"rough": 0.7}), x, fh * 0.5, z, null, 16)
			"lift":
				box(fw, fh, 0.3, metal, x, fh * 0.5, z - fd * 0.4)
				box(fw * 0.45, fh * 0.85, 0.05, mat(0xc8d2dc, {"metal": 0.8, "rough": 0.2}), x - fw * 0.23, fh * 0.43, z - fd * 0.4 + 0.18)
				box(fw * 0.45, fh * 0.85, 0.05, mat(0xc8d2dc, {"metal": 0.8, "rough": 0.2}), x + fw * 0.23, fh * 0.43, z - fd * 0.4 + 0.18)
			"plant":
				cyl(fw * 0.35, fw * 0.3, 0.6, mat(0x8a5a3a), x, 0.3, z, null, 12)
				sphere(fw * 0.55, mat(0x3f8a3a, {"rough": 0.9}), x, 1.2, z, null, 12)
			"console":
				box(fw, fh, fd, metal, x, fh * 0.5, z)
				box(fw * 0.9, 0.6, 0.08, mat(0x5ad0ff, {"emissive": 0x2aa0ff, "glow": 1.4}), x, fh + 0.4, z - fd * 0.3)
			"pod":
				cyl(fw * 0.5, fw * 0.5, 0.4, metal, x, 0.2, z, null, 20)
				cyl(fw * 0.42, fw * 0.42, fh - 0.8, mat(0x9fe8ff, {"emissive": 0x5ac8ff, "glow": 0.6, "rough": 0.05}), x, fh * 0.5, z, null, 20)
				cyl(fw * 0.5, fw * 0.5, 0.4, metal, x, fh - 0.2, z, null, 20)
			"altar":
				box(fw, fh, fd, mat(0xcdb88a, {"rough": 0.6}), x, fh * 0.5, z)
				sphere(0.45, mat(0xffb040, {"emissive": 0xff9020, "glow": 2.0}), x, fh + 0.5, z, null, 16)
			"ship":
				sphere(fw * 0.5, mat(0xe8eaee, {"metal": 0.4, "rough": 0.3}), x, fh * 0.45, z, null, 28)
				cyl(fw * 0.52, fw * 0.52, 0.5, mat(0x8a96a8, {"metal": 0.6}), x, fh * 0.45, z, null, 28)
				for i in 3:
					var a := float(i) / 3.0 * TAU
					cyl(0.18, 0.25, fh * 0.45, metal, x + sin(a) * fw * 0.35, fh * 0.22, z + cos(a) * fw * 0.35, null, 8)
			"crates":
				for i in 3:
					box(fw * 0.45, fh * 0.5, fd * 0.45, mat(0x9a7a4a, {"rough": 0.9}), x + (i - 1) * fw * 0.3, fh * 0.25 + (fh * 0.5 if i == 1 else 0.0), z)
			_:
				box(fw, fh, fd, wood, x, fh * 0.5, z)

	# --- childhood arcs (2026-11-05) ---
	## Grandpa Gohin's little round hut on Mt. Paozu, with a woodpile and a stone path.
	func _paozuhut() -> void:
		var wall := mat(0xd8c49a, {"rough": 0.85}); var roof := mat(0x6a8a3a, {"rough": 0.9}); var wood := mat(0x7a5232, {"rough": 0.9})
		cyl(3.2, 3.4, 3.0, wall, 0, 1.5, 0)
		cone(4.2, 2.6, roof, 0, 4.3, 0, null, 18)
		box(1.4, 2.2, 0.2, wood, 0, 1.1, 3.3)
		for i in 5:
			cyl(0.22, 0.22, 2.4, wood, 4.8, 0.25 + (i % 3) * 0.45, -1.0 + (i / 3) * 0.5, null, 8).rotation.x = PI / 2
		for i in 6:
			cyl(0.7, 0.7, 0.1, mat(0xa09a90), 0, 0.05, 5.0 + i * 1.6, null, 10)

	## The Ox-Lord's castle on Fire Mountain: a big pagoda castle wreathed in flames.
	func _firecastle() -> void:
		var stone := mat(0x8a7a6a, {"rough": 0.9}); var red := mat(0xb03a2a, {"rough": 0.6}); var roof := mat(0x3a3a4a, {"rough": 0.5})
		box(30, 6, 26, stone, 0, 3, 0)
		box(20, 8, 16, red, 0, 10, 0)
		box(26, 1.2, 22, roof, 0, 14.4, 0)
		box(12, 6, 10, red, 0, 18, 0)
		cone(10, 6, roof, 0, 24, 0, null, 4).rotation.y = PI / 4
		var flame := mat(0xff7a1a, {"emissive": 0xff5a0a, "glow": 3.0, "rough": 0.4})
		for i in 14:
			var a := float(i) / 14.0 * TAU
			cone(1.6 + float(i % 3) * 0.6, 5.0 + float(i % 4) * 2.0, flame, sin(a) * 15.5, 6.0 + float(i % 4), cos(a) * 13.5, null, 8)
		var light := OmniLight3D.new(); light.light_color = Color(1.0, 0.5, 0.15); light.light_energy = 3.0; light.omni_range = 60.0
		light.position = Vector3(0, 12, 0); g.add_child(light)

	## Emperor Pilav's castle in the desert: onion domes and a walled keep.
	func _pilavcastle() -> void:
		var wall := mat(0xd8c08a, {"rough": 0.8}); var dome_m := mat(0x3a8a6a, {"rough": 0.4, "metal": 0.2}); var gold := mat(0xd8a733, {"metal": 0.7, "rough": 0.3})
		box(34, 7, 30, wall, 0, 3.5, 0)
		box(20, 10, 18, wall, 0, 12, 0)
		for p in [Vector2(-15, -13), Vector2(15, -13), Vector2(-15, 13), Vector2(15, 13)]:
			cyl(2.6, 2.8, 16, wall, p.x, 8, p.y, null, 16)
			sphere(3.2, dome_m, p.x, 17.5, p.y, null, 18)
			cone(0.6, 3.0, gold, p.x, 21.5, p.y, null, 8)
		sphere(8, dome_m, 0, 18.5, 0, null, 28)
		cone(1.0, 5.0, gold, 0, 28.5, 0, null, 8)
		box(4, 5, 0.4, mat(0x5a3a22), 0, 2.5, 15.1)

	## Muscle Tower: a tall red Red Ribbon tower in the snow, with ribbed floors.
	func _muscletower() -> void:
		var red := mat(0xb02a2a, {"rough": 0.6}); var trim := mat(0xd8d8d8, {"rough": 0.5}); var dark := mat(0x2a2a30)
		for i in 6:
			var r := 8.0 - i * 0.7
			cyl(r, r + 0.4, 7.0, red, 0, 3.5 + i * 7.0, 0, null, 8)
			cyl(r + 0.6, r + 0.6, 0.6, trim, 0, 7.0 + i * 7.0, 0, null, 8)
		cone(4.5, 6.0, red, 0, 45.0, 0, null, 8)
		box(3.0, 4.0, 0.3, dark, 0, 2.0, 8.3)
		box(6, 2.2, 0.3, mat(0xf4f4f4), 0, 30, 6.2)   # the ribbon sign
		box(5, 1.2, 0.35, red, 0, 30, 6.3)

	## Fortuneteller Baaba's palace: a pink palace on a lake with a fighting ring over the water.
	func _baabapalace() -> void:
		var pink := mat(0xe89ab8, {"rough": 0.6}); var white := mat(0xf4f0ea, {"rough": 0.7}); var gold := mat(0xd8a733, {"metal": 0.6, "rough": 0.3})
		cyl(24, 24, 0.3, mat(0x4a9ad8, {"rough": 0.05, "metal": 0.2}), 0, 0.1, 0, null, 40)
		box(16, 7, 12, pink, 0, 3.5, -10)
		sphere(5.5, pink, 0, 9.0, -10, null, 24)
		cone(0.6, 3.0, gold, 0, 15.0, -10, null, 8)
		box(14, 1.0, 14, white, 0, 1.5, 8)   # the ring over the water
		for p in [Vector2(-7, 1), Vector2(7, 1), Vector2(-7, 15), Vector2(7, 15)]:
			cyl(0.5, 0.5, 2.0, white, p.x, 0.6, p.y, null, 8)
		box(2.5, 0.4, 6, white, 0, 1.2, -1.5)   # bridge to the palace

	## Korrin Tower: a white pillar rising hundreds of metres into the clouds, with Korrin's house at the top.
	func _korrintower() -> void:
		var white := mat(0xf0ece2, {"rough": 0.6}); var trim := mat(0xc84a3a, {"rough": 0.6})
		cyl(3.2, 3.6, 400.0, white, 0, 200.0, 0, null, 16)
		for i in 20:
			cyl(3.5, 3.5, 0.6, trim, 0, 20.0 + i * 20.0, 0, null, 16)
		# Korrin's house: a wide vase-shaped room on top
		cyl(9.0, 4.0, 10.0, white, 0, 405.0, 0, null, 24)
		cyl(9.6, 9.6, 1.0, trim, 0, 410.5, 0, null, 24)
		dome(7.0, white, 0, 411.0, 0)
		var base := cyl(7.0, 9.0, 4.0, mat(0xd8d2c4, {"rough": 0.8}), 0, 2.0, 0, null, 16)
		base.name = "Base"

	## Kamu's Lookout: a white platform floating in the sky with the palace, palm trees and a garden.
	func _lookout() -> void:
		var tile := mat(0xf4f2ec, {"rough": 0.4}); var white := mat(0xf8f6f0, {"rough": 0.6}); var green := mat(0x4a9a3a, {"rough": 0.9})
		cyl(40, 40, 1.0, tile, 0, -0.5, 0, null, 48)
		sphere(40, mat(0xd8d2c4, {"rough": 0.7}), 0, -1.0, 0, null, 40, true).rotation.x = PI   # the dome underneath
		box(16, 7, 12, white, 0, 3.5, 14)
		sphere(5.0, white, -6, 8.0, 14, null, 20); sphere(5.0, white, 6, 8.0, 14, null, 20)
		dome(6.5, white, 0, 7.0, 14)
		for p in [Vector2(-22, -10), Vector2(-18, -20), Vector2(22, -10), Vector2(18, -22), Vector2(-26, 6), Vector2(26, 8)]:
			cyl(0.35, 0.5, 8.0, mat(0x8a6a48), p.x, 4.0, p.y, null, 8)
			for k in 5:
				var a := float(k) / 5.0 * TAU
				var leaf := box(4.0, 0.2, 1.2, green, p.x + sin(a) * 1.8, 8.0, p.y + cos(a) * 1.8)
				leaf.rotation = Vector3(0.35, a, 0)
		box(10, 0.3, 10, green, -12, 0.05, -2)   # garden

	## The Time Nexus (Rift Patrol hub): a sanctum outside time. Rune pillars round the platform, a huge clock ring
	## floating overhead, the Mission Board terminal on a dais, and the rift gate that missions launch through.
	func _nexus() -> void:
		var stone := mat(0x2a2840, {"rough": 0.6, "metal": 0.2}); var trim := mat(0xd8c890, {"metal": 0.8, "rough": 0.25})
		var glow := mat(0x9a7aff, {"emissive": 0x7a5aff, "glow": 2.4, "rough": 0.3})
		var cyan := mat(0x7ae8ff, {"emissive": 0x40c8ff, "glow": 2.0, "rough": 0.2})
		# rings inlaid in the floor
		for r in [20.0, 38.0, 60.0]:
			torus(r, 0.25, glow, 0, 0.05, 0)
		# rune pillars round the edge
		for i in 12:
			var a := float(i) / 12.0 * TAU
			var x := sin(a) * 64.0; var z := cos(a) * 64.0
			cyl(1.6, 2.0, 14.0, stone, x, 7.0, z, null, 8)
			box(0.3, 9.0, 0.6, glow, x - sin(a) * 1.7, 7.0, z - cos(a) * 1.7).rotation.y = a
			cyl(2.3, 2.3, 0.8, trim, x, 14.2, z, null, 8)
		# the great clock ring overhead (hour marks and two hands)
		var ring := Node3D.new(); ring.position = Vector3(0, 46, 0); g.add_child(ring)
		torus(34.0, 1.0, trim, 0, 0, 0, ring)
		torus(30.0, 0.35, glow, 0, 0, 0, ring)
		for h in 12:
			var a := float(h) / 12.0 * TAU
			box(0.8, 0.8, 3.6, trim, sin(a) * 31.5, 0, cos(a) * 31.5, ring).rotation.y = a
		box(1.0, 0.5, 22.0, trim, 0, 0.3, 11.0, ring)
		box(1.4, 0.5, 15.0, trim, 0, 0.6, -7.5, ring).rotation.y = 2.1
		ring.set_meta("spin", 0.05)
		# the Mission Board: a dais with a glowing tilted screen
		cyl(7.0, 8.0, 1.2, stone, 0, 0.6, 18.0, null, 32)
		box(7.5, 4.2, 0.4, cyan, 0, 4.3, 22.0).rotation.x = -0.25
		box(8.2, 4.8, 0.3, trim, 0, 4.3, 22.25).rotation.x = -0.25
		# the rift gate: a vertical ring with a swirling disc, behind the board
		var gate := Node3D.new(); gate.position = Vector3(0, 9.5, 46.0); g.add_child(gate)
		var gr := torus(8.0, 0.9, trim, 0, 0, 0, gate); gr.rotation.x = PI / 2
		var disc := cyl(7.2, 7.2, 0.2, mat(0x5a2aa8, {"emissive": 0x8a4aff, "glow": 2.6, "rough": 0.1}), 0, 0, 0, gate, 40); disc.rotation.x = PI / 2
		disc.set_meta("spin_z", 0.8)
		# drifting time shards
		for i in 26:
			var a := float(i) * 2.399
			var r := 18.0 + float(i % 7) * 7.0
			var shard := box(0.6, 1.8, 0.6, cyan if i % 3 == 0 else glow, sin(a) * r, 18.0 + float(i % 5) * 6.0, cos(a) * r)
			shard.rotation = Vector3(float(i) * 0.7, float(i) * 1.3, float(i) * 0.4)
		var light := OmniLight3D.new(); light.light_color = Color(0.7, 0.6, 1.0); light.light_energy = 2.0; light.omni_range = 90.0
		light.position = Vector3(0, 20, 0); g.add_child(light)

	## King Piccor's castle: a dark spiked fortress on a crag.
	func _piccorcastle() -> void:
		var dark := mat(0x3a3448, {"rough": 0.8}); var purple := mat(0x6a3a8a, {"rough": 0.5}); var stone := mat(0x5a5560, {"rough": 0.95})
		cyl(22, 28, 8, stone, 0, 4, 0, null, 10)
		box(28, 12, 22, dark, 0, 14, 0)
		for p in [Vector2(-13, -10), Vector2(13, -10), Vector2(-13, 10), Vector2(13, 10)]:
			cyl(2.4, 3.0, 26, dark, p.x, 13, p.y, null, 10)
			cone(3.2, 8, purple, p.x, 30, p.y, null, 10)
		cone(8, 16, purple, 0, 28, 0, null, 6)
		box(5, 7, 0.4, mat(0x1a1420), 0, 3.5, 11.2)
		var light := OmniLight3D.new(); light.light_color = Color(0.7, 0.4, 1.0); light.light_energy = 1.5; light.omni_range = 50.0
		light.position = Vector3(0, 30, 0); g.add_child(light)

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

	## King Yemmo's Check-In Station (Godot addition): an open lacquered hall with a two-tier roof over the
	## floor, his giant desk and chair (he sits there as an NPC), and the line of souls waiting at the desk.
	## Local +z points up Serpent Road; arrivals come in from the south (-z).
	func _checkin() -> void:
		var marble := mat(0xc9c0b2, {"rough": 0.35})
		var lacquer := mat(0xb3262a, {"rough": 0.35})
		var gold := mat(0xd8a733, {"metal": 0.8, "rough": 0.3})
		var tiles := mat(0x2f5d52, {"rough": 0.5})
		var wood := mat(0x5a3020, {"rough": 0.45})
		var dark_wood := mat(0x3a1e14, {"rough": 0.4})
		var paper := mat(0xf3eedf, {"rough": 0.8})
		# floor, steps at the arrival side, a red carpet to the desk
		cyl(53.5, 53.5, 0.3, marble, 0, -0.13, 0, null, 64)
		cyl(54.5, 55.0, 0.5, mat(0xb9ad98, {"stone": true}), 0, -0.45, 0, null, 64)
		box(5, 0.04, 44, mat(0x7a1219, {"rough": 0.95}), 0, 0.04, -27)
		for side in [-2.7, 2.7]:
			box(0.35, 0.05, 44, gold, side, 0.045, -27)
		box(8, 0.05, 1.0, gold, 0, 0.05, -49)
		# columns in a ring and the two-tier roof
		for i in 12:
			var a := (float(i) + 0.5) / 12.0 * TAU
			var cx := sin(a) * 33.0; var cz := cos(a) * 33.0
			cyl(1.25, 1.35, 22, lacquer, cx, 11, cz, null, 16)
			cyl(1.8, 1.8, 1.0, gold, cx, 22.3, cz, null, 16)
			cyl(1.9, 2.1, 0.8, mat(0x8a7d68, {"stone": true}), cx, 0.4, cz, null, 16)
		torus(33.0, 0.7, lacquer, 0, 22.6, 0)
		var roof := cone(47, 9, tiles, 0, 27.6, 0, null, 8); roof.rotation.y = PI / 8
		cyl(47.5, 47.5, 0.6, gold, 0, 23.2, 0, null, 8).rotation.y = PI / 8
		var upper := cone(25, 8, tiles, 0, 36, 0, null, 8); upper.rotation.y = PI / 8
		cyl(17, 17, 4, lacquer, 0, 31, 0, null, 8).rotation.y = PI / 8
		cyl(25.5, 25.5, 0.5, gold, 0, 32.1, 0, null, 8).rotation.y = PI / 8
		sphere(1.6, gold, 0, 40.6, 0)
		cone(0.5, 3, gold, 0, 42.6, 0, null, 12)
		# the sign over the south entrance
		box(26, 4, 0.6, lacquer, 0, 18.5, -33.6)
		box(27, 4.6, 0.3, gold, 0, 18.5, -33.3)
		var sign := Label3D.new()
		sign.text = "CHECK-IN STATION"
		sign.font_size = 160; sign.pixel_size = 0.012; sign.outline_size = 18
		sign.modulate = Color("#ffe3a0"); sign.outline_modulate = Color("#4a1206")
		sign.position = Vector3(0, 18.5, -34.0); sign.rotation.y = PI
		g.add_child(sign)
		# the giant desk (front faces the arrivals); he sits behind it on a raised dais
		const TOP := 3.6
		box(17, 0.7, 6.4, wood, 0, TOP - 0.35, 2.4)
		box(17.4, 0.22, 6.8, gold, 0, TOP - 0.8, 2.4)
		box(16.4, TOP - 0.8, 0.7, dark_wood, 0, (TOP - 0.8) / 2.0, -0.5)
		for x in [-7.9, 7.9]:
			box(0.9, TOP - 0.8, 6.0, dark_wood, x, (TOP - 0.8) / 2.0, 2.4)
		torus(0.85, 0.12, gold, 0, 1.05, -0.9).rotation.x = PI / 2
		sphere(0.68, mat(0xb3262a, {"rough": 0.3, "metal": 0.2}), 0, 1.05, -0.9, null, 20).scale = Vector3(1, 1, 0.3)
		var plate := Label3D.new()
		plate.text = "King Yemmo"
		plate.font_size = 72; plate.pixel_size = 0.01; plate.outline_size = 8
		plate.modulate = Color("#ffe3a0"); plate.outline_modulate = Color("#2a0a04")
		plate.position = Vector3(0, 2.3, -0.9); plate.rotation.y = PI
		g.add_child(plate)
		# on the desk: the open book of souls, a stamp, papers, an ink pot with a brush
		var book := box(3.2, 0.25, 2.2, paper, -3.5, TOP + 0.15, 3.0); book.rotation.y = 0.15
		box(3.4, 0.2, 2.4, mat(0x7a1a1a), -3.5, TOP + 0.02, 3.0).rotation.y = 0.15
		cyl(0.55, 0.65, 0.5, mat(0x7a1a1a), 4.2, TOP + 0.25, 2.6, null, 16)
		cyl(0.18, 0.18, 1.1, wood, 4.2, TOP + 1.0, 2.6, null, 10)
		sphere(0.35, gold, 4.2, TOP + 1.6, 2.6, null, 12)
		for k in 4:
			var pp := box(1.5, 0.05, 2.0, paper, 1.0 + k * 0.15, TOP + 0.03 + k * 0.05, 3.6 - k * 0.1); pp.rotation.y = -0.2 + k * 0.12
		cyl(0.4, 0.45, 0.6, mat(0x111111, {"rough": 0.2}), 6.6, TOP + 0.3, 4.0, null, 14)
		cyl(0.06, 0.06, 1.6, wood, 6.6, TOP + 1.0, 4.0, null, 8).rotation.z = 0.35
		# dais and chair (the dais top is the NPC's authored y, 1.4; the seat fits his seated pose at scale 4.2)
		box(15, 1.4, 10, mat(0x8a7d68, {"stone": true}), 0, 0.7, 10.5)
		box(15.4, 0.2, 10.4, gold, 0, 1.45, 10.5)
		box(9, 1.8, 5.5, lacquer, 0, 1.4 + 0.9, 10.2)
		box(9.4, 0.3, 5.9, gold, 0, 1.4 + 1.85, 10.2)
		box(9, 10, 1.2, lacquer, 0, 1.4 + 5.0, 13.2)
		box(9.6, 0.5, 1.6, gold, 0, 1.4 + 10.2, 13.2)
		for x in [-4.7, 4.7]:
			box(0.8, 1.6, 5.0, lacquer, x, 1.4 + 2.9, 10.4)
		# the line of souls: from the east of the hall, curling round to the front of the desk
		var q := SoulQueue.create(PackedVector3Array([Vector3(44, 0, -24), Vector3(34, 0, -30), Vector3(20, 0, -26),
			Vector3(12, 0, -16), Vector3(6, 0, -8), Vector3(1.5, 0, -3.2)]))
		g.add_child(q)
		# warm light under the roof
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 16, -4)
		lamp.light_color = Color("#ffd9a8")
		lamp.light_energy = 0.9
		lamp.omni_range = 48
		g.add_child(lamp)

	## An open-world town (Godot addition): drawn from its rules layout by WorldTown.
	func _town() -> void:
		g.scale = Vector3.ONE   # towns are laid out in metres
		WorldTown.build(g, zone, l)

	## King Kae's planet seen from Serpent Road's end (Godot addition): a small round world hanging in the sky with
	## his house, car and a tree on top and a ring of golden clouds. Fly into it to land there (story portal).
	func _kaiplanet() -> void:
		g.position.y = float(l.alt)   # it floats: the road world has nothing under it
		var r := float(l.radius)
		var grass := mat(0x5fae3c, {"rough": 0.85})
		var planet := sphere(r, grass, 0, 0, 0, null, 48)
		planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a few lighter patches and a little path so it doesn't read as a flat ball
		for i in 7:
			var a := float(i) / 7.0 * TAU
			var patch := sphere(r * 0.22, mat(0x7cc24e, {"rough": 0.9}), sin(a) * r * 0.62, r * 0.7, cos(a) * r * 0.62, null, 16)
			patch.scale = Vector3(1.0, 0.25, 1.0)
		var top := Node3D.new()
		top.position = Vector3(0, r - 0.4, 0)
		top.scale = Vector3.ONE * 1.6
		g.add_child(top)
		var house := Node3D.new(); top.add_child(house)
		dome(4, mat(0xf3eadb), 0, 0, 0, house)
		torus(4, 0.3, mat(0xc83228), 0, 0.1, 0, house)
		sphere(0.8, mat(0xc83228), 0, 4, 0, house)
		box(1.4, 2.2, 0.2, mat(0x6a4a2a), 0, 1.1, 3.9, house)
		var car := Node3D.new(); car.position = Vector3(-7, 0, 5); car.rotation.y = 1.2; top.add_child(car)
		box(3, 0.7, 1.6, mat(0xc8322a, {"metal": 0.5, "rough": 0.3}), 0, 0.7, 0, car)
		box(1.6, 0.6, 1.4, mat(0xddeeff, {"opacity": 0.5, "rough": 0.1}), -0.2, 1.3, 0, car)
		cyl(0.35, 0.5, 6, mat(0x6a4a2a), 6, 3, -5, top, 10)
		sphere(3.2, mat(0x2f8a3a, {"rough": 0.8}), 6, 7.5, -5, top, 20)
		# golden clouds round its middle
		var cloud := mat(0xfff0c0, {"rough": 1.0, "emissive": 0x806030, "glow": 0.4})
		for i in 18:
			var a := float(i) / 18.0 * TAU + 0.2
			var puff := sphere(r * 0.2, cloud, sin(a) * r * 1.12, -r * 0.15 + sin(a * 3.0) * 1.5, cos(a) * r * 1.12, null, 14)
			puff.scale = Vector3(1.6, 0.6, 1.0)
			puff.rotation.y = a
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
		portholes(14.6, 5.2, 16, 1.0, glass)  # on the dome's surface at that height (dome flattened to 0.72)
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
