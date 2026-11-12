class_name LandmarksAlien
extends RefCounted
# Extra landmark builders for this world group, called from WorldLandmarks (hook keeps landmarks.gd small).
# Add a type name to TYPES and a match arm in build().
#
# Batch B4 (Alien planets, 2026-11-10): rebuilt silhouettes for the alien worlds, matched to the reference pack
# (art/reference/maps_audit.md, batch 4). Same pattern as LandmarksOrigins: primitive-built, then merged with
# MeshMerge into one mesh per material (the helper class A reuses LandmarksOrigins.B's cached materials and shapes).
# Local +z is the front. All new types; the old ones in landmarks.gd (namekhouse, gurutower, friezaship, yardrathut,
# farmhouse) are untouched, zones switch over through data (art/reference/map_data_requests_alien.md).
#   namekdome      Nameck house: long ribbed white dome, twin horns, big front porthole, oval door, side portholes
#   namekvillage   3 namekdomes joined by ribbed tube connectors ("count" 2-4)
#   elderspire     the Grand Elder's house: a namekdome x2.5 on top of the pillar mesa under it (as gurutower)
#   tyrantship     the tyrant's saucer: dark hull, silver studs, yellow lobed skirt, red panels, open top hatch
#   heetersship    Grain landing ship: long lavender hull, gridded glass canopy, tower with the H crest, pods
#   cerealhut      Monaido's farm hut: clay drum with a domed roof, round windows, fence, crop rows
#   yardratvillage round lilac huts and mushroom-like plants ("huts" 2-6)
#   floatcups      floating bowl-shaped spectator cups on gold stems (Nameless Planet), "count" 3-8, arc in front
#   vampacrater    Vampa: lumpy yellow rock rim round a green pond, giant spider-crabs ("critters" 0-16)
# Preview: godot/tests/preview_alien_landmarks.gd (DL_PREVIEW_LANDMARK=<type>|all).

const TYPES: Array[String] = ["namekdome", "namekvillage", "elderspire", "tyrantship", "heetersship", "cerealhut",
	"yardratvillage", "floatcups", "vampacrater"]

static func build(type: String, g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	var b := A.new(g, zone, l)
	match type:
		"namekdome": b.namek_house(null)
		"namekvillage": b.namekvillage()
		"elderspire": b.elderspire()
		"tyrantship": b.tyrantship()
		"heetersship": b.heetersship()
		"cerealhut": b.cerealhut()
		"yardratvillage": b.yardratvillage()
		"floatcups": b.floatcups()
		"vampacrater": b.vampacrater()
		_:
			return
	b.finish()

class A extends LandmarksOrigins.B:
	func _init(group: Node3D, z: RefCounted, landmark: Dictionary) -> void:
		super(group, z, landmark)

	## A cylinder (or cone when r_top = 0) from a to b.
	func rod(a: Vector3, b: Vector3, r_bot: float, r_top: float, m: Material, seg := 8, p: Node3D = null) -> MeshInstance3D:
		var d := b - a
		var c := cyl(r_top, r_bot, d.length(), m, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5, seg, p)
		var up := d.normalized()
		if absf(up.dot(Vector3.UP)) < 0.999:
			var axis := Vector3.UP.cross(up).normalized()
			c.basis = Basis(axis, Vector3.UP.angle_to(up))
		elif up.y < 0.0:
			c.basis = Basis(Vector3.RIGHT, PI)
		return c

	func blob(r: float, m: Material, x: float, y: float, z: float, s: Vector3, seg := 16, p: Node3D = null) -> MeshInstance3D:
		var mi := sphere(r, m, x, y, z, seg, p)
		mi.scale = s
		return mi

	## Torus ring standing upright in the x-y plane (axis along z), squashed by `s`.
	func ring_z(r: float, t: float, m: Material, x: float, y: float, z: float, s := Vector3.ONE, p: Node3D = null) -> MeshInstance3D:
		var mi := torus(r, t, m, x, y, z, p)
		mi.basis = Basis.from_scale(s) * Basis(Vector3.RIGHT, PI / 2)
		return mi

	## Torus ring standing upright in the y-z plane (axis along x), squashed by `s`.
	func ring_x(r: float, t: float, m: Material, x: float, y: float, z: float, s := Vector3.ONE, p: Node3D = null) -> MeshInstance3D:
		var mi := torus(r, t, m, x, y, z, p)
		mi.basis = Basis.from_scale(s) * Basis(Vector3.BACK, PI / 2)
		return mi

	# ======================================================================================================
	## Nameck dome house (ref 137/139): a long white dome (long axis z), ribbed, a spine rib, two horns swept
	## back from the top front, a big porthole above an oval door, blue portholes round the sides. ~7.2 x 9.7 x 3.3 m.
	func namek_house(p: Node3D) -> void:
		const R := 3.6
		const SY := 0.9
		const SZ := 1.35
		var white := mat(0xeef2f4, {"rough": 0.4}); var rib := mat(0xd2dae2, {"rough": 0.45})
		var port := mat(0x2c4aa8, {"rough": 0.12, "metal": 0.25}); var door := mat(0x33427e, {"rough": 0.5})
		var body := dome(R, white, 0, 0, 0, 28, p)
		body.scale = Vector3(1, SY, SZ)
		var skirt := cyl(R + 0.06, R + 0.16, 0.3, rib, 0, 0.12, 0, 28, p)
		skirt.scale = Vector3(1, 1, SZ)
		for zz in [-2.9, -1.2, 0.6, 2.3]:   # cross ribs
			var k := sqrt(1.0 - pow(zz / (R * SZ), 2))
			ring_z(R * k, 0.07, rib, 0, 0, zz, Vector3(1, SY, 1), p)
		ring_x(R, 0.055, rib, 0, 0, 0, Vector3(1, SY, SZ), p)   # spine rib over the top
		# side portholes on a band at y 1.3
		var ky := sqrt(1.0 - pow(1.3 / (R * SY), 2))
		for a in [0.85, 1.6, 2.35, -0.85, -1.6, -2.35, PI]:
			var px := R * ky * sin(a); var pz := R * SZ * ky * cos(a)
			blob(0.42, port, px * 0.99, 1.3, pz * 0.99, Vector3(1, 1, 1), 12, p)
		# front: oval door with a brow, big porthole above, two horns
		var dz := R * SZ * sqrt(1.0 - pow(1.0 / (R * SY), 2))
		var d := blob(1.0, door, 0, 0.95, dz - 0.12, Vector3(0.6, 1.05, 0.25), 16, p)
		d.rotation.x = -0.3
		var fr := blob(1.0, rib, 0, 1.0, dz - 0.2, Vector3(0.74, 1.18, 0.22), 16, p)
		fr.rotation.x = -0.3
		var hz := R * SZ * sqrt(1.0 - pow(2.8 / (R * SY), 2))
		blob(0.5, port, 0, 2.8, hz + 0.05, Vector3(1, 1, 0.8), 14, p)
		var collar := torus(0.52, 0.11, rib, 0, 2.8, hz + 0.05, p)
		collar.basis = Basis(Vector3.RIGHT, 1.0)
		for s in [-1.0, 1.0]:
			var base := Vector3(s * 1.15, 2.85, 0.9)
			rod(base, base + Vector3(s * 1.35, 2.3, -0.9), 0.36, 0.0, white, 10, p)
			torus(0.36, 0.06, rib, base.x, base.y + 0.05, base.z, p)

	## Three (2-4) domes joined by ribbed tube connectors (ref 137/138).
	func namekvillage() -> void:
		var n := clampi(int(l.get("count", 3)), 2, 4)
		var spots := [[-8.5, 0.0, 0.5, 0.85], [0.0, -3.5, 0.0, 1.0], [8.5, 0.0, -0.5, 0.8], [0.0, 9.5, PI, 0.75]]
		var white := mat(0xeef2f4, {"rough": 0.4}); var rib := mat(0xd2dae2, {"rough": 0.45})
		var port := mat(0x2c4aa8, {"rough": 0.12, "metal": 0.25})
		for i in n:
			var sp: Array = spots[i]
			var pv := pivot(sp[0], gy(sp[0], sp[1]), sp[1], sp[2])
			pv.scale = Vector3.ONE * float(sp[3])
			namek_house(pv)
		for i in n - 1:
			var a: Array = spots[i if i < 2 else 1]
			var b: Array = spots[i + 1]
			var pa := Vector3(a[0], gy(a[0], a[1]) + 1.0, a[1]); var pb := Vector3(b[0], gy(b[0], b[1]) + 1.0, b[1])
			rod(pa, pb, 0.95, 0.95, white, 14)
			var steps := int(pa.distance_to(pb) / 1.4)
			for k in range(1, steps):
				var t := float(k) / steps
				if t < 0.25 or t > 0.75:
					continue   # inside the domes
				var c := pa.lerp(pb, t)
				var r := torus(1.0, 0.08, rib, c.x, c.y, c.z)
				var dir := (pb - pa).normalized()
				r.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir)) if absf(dir.y) < 0.999 else Basis()
				if k % 2 == 0:
					var side := dir.cross(Vector3.UP).normalized()
					sphere(0.26, port, c.x + side.x * 0.92, c.y + 0.15, c.z + side.z * 0.92, 8)

	## The Grand Elder's house on the pillar mesa (as gurutower: sits on the terrain under its centre), x2.5.
	func elderspire() -> void:
		var pv := pivot(0, gy(0, 0), 0)
		pv.scale = Vector3.ONE * float(l.get("houseScale", 2.5))
		namek_house(pv)

	## The tyrant's saucer (ref 140): dark grey-purple hull, a light trim line, silver dome studs in two rows and a
	## big one at the front, red slatted panels, a ring of yellow lobed skirt pods, an open hatch on top. 28 m wide.
	func tyrantship() -> void:
		const R := 14.0
		const HY := 0.34
		const CY := 5.5
		var hull := mat(0x4a3f4c, {"metal": 0.35, "rough": 0.45}); var hull2 := mat(0x3a3240, {"metal": 0.3, "rough": 0.5})
		var trim := mat(0xc8c0cc, {"metal": 0.5, "rough": 0.35}); var stud := mat(0xb8bcc6, {"metal": 0.8, "rough": 0.22})
		var red := mat(0xb4483a, {"rough": 0.5}); var yellow := mat(0xf0a41e, {"rough": 0.4, "metal": 0.1})
		var black := mat(0x120e14, {"rough": 0.9}); var win := mat(0xe8c8d8, {"emissive": 0x6a3a50, "glow": 0.6})
		blob(R, hull, 0, CY, 0, Vector3(1, HY, 1), 48)
		var hy := func(r: float) -> float: return CY + R * HY * sqrt(maxf(1.0 - pow(r / R, 2), 0.0))
		torus(12.4, 0.12, trim, 0, hy.call(12.4) + 0.05, 0)
		torus(R - 0.05, 0.22, hull2, 0, CY + 0.6, 0)
		# lower band with windows, then the yellow pods hanging round it
		cyl(12.2, 11.0, 1.8, hull2, 0, 2.2, 0, 40)
		for i in 24:
			var a := float(i) / 24 * TAU
			on_ring(0, 0, 11.75, a, 2.2, 0.9, 0.7, 0.2, win)
		for i in 18:
			var a := (float(i) + 0.5) / 18 * TAU
			var pod := blob(1.0, yellow, sin(a) * 13.0, 2.6, cos(a) * 13.0, Vector3(0.78, 1.75, 0.55), 12)
			pod.rotation.y = a
			pod.rotate_object_local(Vector3.RIGHT, -0.2)
		# studs: rim row, upper row, the big front one
		for i in 26:
			var a := float(i) / 26 * TAU
			sphere(0.7, stud, sin(a) * 13.85, CY + 0.9, cos(a) * 13.85, 10)
		for i in 14:
			var a := (float(i) + 0.5) / 14 * TAU
			if absf(wrapf(a, -PI, PI)) < 0.3:
				continue
			var s := sphere(0.8, stud, sin(a) * 10.6, hy.call(10.6) - 0.1, cos(a) * 10.6, 10)
			s.scale = Vector3(1, 0.75, 1)
		blob(1.7, stud, 0, hy.call(10.8) + 0.1, 10.8, Vector3(1, 0.6, 1), 18)
		# red slatted panels on two sectors of the upper hull
		for sector in [-0.95, 0.95, PI - 0.6]:
			for k in 6:
				var a: float = sector + (float(k) - 2.5) * 0.06
				var pv := pivot(sin(a) * 11.9, hy.call(11.9) + 0.05, cos(a) * 11.9, a)
				var slat := box(0.42, 0.12, 2.6, red, 0, 0, 0, 0.0, pv)
				slat.rotation.x = 0.5
		# top hatch: a raised collar round a black opening
		var top: float = hy.call(0.0)
		cyl(4.6, 5.2, 0.7, hull2, 0, top - 0.1, 0, 36)
		cyl(3.4, 3.4, 0.75, black, 0, top - 0.05, 0, 32)
		torus(4.0, 0.16, trim, 0, top + 0.27, 0)

	## The landing ship on Grain (ref 170): long lavender hull with a gridded dark-glass canopy, a tower at the
	## stern with the H crest and a side fin, engine pods, a door + ramp at the front (+z). ~40 m long.
	func heetersship() -> void:
		var hull := mat(0xc2cae8, {"rough": 0.35, "metal": 0.2}); var hull2 := mat(0x9aa6cc, {"rough": 0.4, "metal": 0.2})
		var glass := mat(0x2c5450, {"rough": 0.12, "metal": 0.3}); var grid := mat(0x7a8aa0, {"rough": 0.4, "metal": 0.4})
		var red := mat(0xd02a2a, {"rough": 0.45}); var white := mat(0xf2f4f8, {"rough": 0.4}); var dark := mat(0x5a6070, {"rough": 0.6})
		blob(7.0, hull, 0, 5.4, 0, Vector3(2.6, 0.72, 1.1), 36)
		blob(7.0, hull, 0, 2.8, 0, Vector3(2.5, 0.42, 1.02), 32)
		# canopy and its grid
		const GX := 2.0
		const GY := 0.52
		const GZ := 0.98
		const GR := 6.4
		blob(GR, glass, -1.0, 7.4, 0, Vector3(GX, GY, GZ), 32)
		for xx in [-9.6, -6.4, -3.2, 0.0, 3.2, 6.4, 9.6]:
			var k := sqrt(maxf(1.0 - pow(xx / (GR * GX), 2), 0.0))
			ring_x(GR * k, 0.07, grid, xx - 1.0, 7.4, 0, Vector3(1, GY, GZ))
		for t in [0.3, 0.6, 0.85]:
			var k := sqrt(1.0 - t * t)
			var r := torus(GR * k, 0.07, grid, -1.0, 7.4 + GR * GY * t, 0)
			r.scale = Vector3(GX, 1, GZ)
		torus(GR, 0.18, hull2, -1.0, 7.4, 0).scale = Vector3(GX, 1, GZ)
		# stern tower with the H crest, a fin and a cap
		cyl(3.0, 3.6, 10.0, hull, 14.5, 9.0, 0, 28)
		cyl(2.4, 3.0, 3.0, hull, 14.5, 15.5, 0, 24)
		dome(2.4, hull, 14.5, 17.0, 0, 20)
		for yy in [13.6, 14.6, 15.6]:
			box(0.15, 0.25, 1.4, dark, 12.0, yy + 1.5, 2.0, -0.6)
		cyl(0.12, 0.12, 2.4, grid, 14.5, 19.8, 0, 6)
		var crest := pivot(14.5, 9.5, 3.55, 0.0)
		box(3.4, 3.8, 0.2, white, 0, 0, 0, 0.0, crest)
		box(0.7, 2.8, 0.25, red, -0.95, 0, 0.05, 0.0, crest)
		box(0.7, 2.8, 0.25, red, 0.95, 0, 0.05, 0.0, crest)
		box(1.4, 0.6, 0.25, red, 0, 0, 0.05, 0.0, crest)
		blob(3.0, hull, 18.5, 11.5, 1.5, Vector3(2.2, 0.18, 0.75), 16)
		# engine pods along the lower sides, a stern nozzle
		for sx in [-11.0, 11.0]:
			for sz in [-6.4, 6.4]:
				blob(2.6, hull2, sx, 3.0, sz, Vector3(2.0, 0.85, 0.85), 16)
				ring_x(1.5, 0.25, dark, sx - signf(sx) * -5.0, 3.0, sz, Vector3(1, 0.8, 0.8))
		cyl(1.6, 2.2, 2.0, dark, -18.4, 5.0, 0, 16).rotation.z = PI / 2
		# door and ramp at the front
		box(2.8, 3.4, 0.4, dark, 0, 2.0, 7.05)
		box(3.0, 0.2, 0.2, hull2, 0, 3.8, 7.15)
		var ramp := box(2.8, 0.2, 3.0, hull2, 0, 0.6, 8.4)
		ramp.rotation.x = 0.28

	## Monaido's farm hut on Grain (ref 172): clay drum with a domed roof, a door, round windows, a vent, a low
	## fence round a few crop rows. ~16 m across.
	func cerealhut() -> void:
		var clay := mat(0xc89a62, {"rough": 0.9}); var roof := mat(0xa8704a, {"rough": 0.85}); var dark := mat(0x3a2a20)
		var wood := mat(0x7a5a3a, {"rough": 0.9}); var crop := mat(0x7a4a8a, {"rough": 0.85}); var soil := mat(0x7a5236, {"rough": 1.0})
		var glass := mat(0x2a3a4a, {"rough": 0.2})
		cyl(4.2, 4.5, 3.4, clay, 0, 1.7, 0, 24)
		dome(4.6, roof, 0, 3.3, 0, 24).scale = Vector3(1, 0.62, 1)
		torus(4.4, 0.2, clay, 0, 3.35, 0)
		cyl(0.5, 0.6, 1.6, clay, 1.8, 5.3, -1.2, 10)
		box(1.4, 2.2, 0.3, dark, 0, 1.1, 4.4)
		var arch := cyl(0.7, 0.7, 0.3, dark, 0, 2.2, 4.4, 14)
		arch.rotation.x = PI / 2
		for a in [1.0, -1.0, 2.2, -2.2]:
			var w := cyl(0.45, 0.45, 0.3, glass, sin(a) * 4.3, 2.2, cos(a) * 4.3, 12)
			w.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2)
		# crop rows and a fence to the right
		for r in 4:
			var z := -4.0 + r * 2.2
			var rx := 9.5
			box(5.5, 0.25, 1.0, soil, rx, gy(rx, z) + 0.12, z)
			for k in 5:
				blob(0.4, crop, rx - 2.2 + k * 1.1, gy(rx, z) + 0.55, z, Vector3(0.8, 1.4, 0.8), 6)
		for i in 9:
			var fz := -5.6 + i * 1.4
			cyl(0.08, 0.1, 1.1, wood, 12.8, gy(12.8, fz) + 0.55, fz, 5)
		box(0.08, 0.1, 11.4, wood, 12.8, gy(12.8, 0) + 0.85, 0)
		box(0.08, 0.1, 11.4, wood, 12.8, gy(12.8, 0) + 0.45, 0)
		cyl(0.6, 0.55, 1.2, wood, -4.6, 0.6, 3.2, 12)   # water barrel

	## Pybara's settlement (ref 150): round lilac huts with a band and a stubby spire, mushroom-like plants.
	func yardratvillage() -> void:
		var n := clampi(int(l.get("huts", 4)), 2, 6)
		var shell := mat(0xd9c2f0, {"rough": 0.35}); var band := mat(0x8a6ad0); var dark := mat(0x40305a)
		var stalk := mat(0xf0ead8, {"rough": 0.6})
		var caps := [mat(0xf29ac8, {"rough": 0.5}), mat(0x8ad8d0, {"rough": 0.5}), mat(0xf2d27a, {"rough": 0.5})]
		var rng := RandomNumberGenerator.new(); rng.seed = int(l.get("seed", 150))
		for i in n:
			var a := float(i) / n * TAU + 0.4
			var r := 9.0 + rng.randf() * 3.0
			var x := sin(a) * r; var z := cos(a) * r
			var s := rng.randf_range(0.75, 1.1)
			var pv := pivot(x, gy(x, z), z, a + PI)
			pv.scale = Vector3.ONE * s
			blob(3.0, shell, 0, 0.9, 0, Vector3(1, 0.85, 1), 20, pv)
			torus(2.95, 0.2, band, 0, 1.3, 0, pv)
			cone(0.5, 2.0, band, 0, 4.2, 0, 8, pv)
			box(1.2, 1.8, 0.4, dark, 0, 0.9, 2.85, 0.0, pv)
		for i in 10:
			var a := rng.randf() * TAU
			var r := rng.randf_range(3.0, 17.0)
			var x := sin(a) * r; var z := cos(a) * r
			var h := rng.randf_range(1.2, 3.4)
			var y := gy(x, z)
			cyl(0.16, 0.26, h, stalk, x, y + h * 0.5, z, 8)
			var cap := dome(h * 0.45 + 0.4, caps[i % 3], x, y + h - 0.1, z, 14)
			cap.scale = Vector3(1, 0.55, 1)

	## Floating spectator cups (ref 126): green bowls with gold rims and bands, blue cushion tops, gold stems and
	## claw feet, hovering on an arc in front of the landmark (+z).
	func floatcups() -> void:
		var n := clampi(int(l.get("count", 5)), 3, 8)
		var arc := float(l.get("radius", 26.0))
		var bowl := mat(0x3fae7a, {"rough": 0.35}); var gold := mat(0xe0b040, {"metal": 0.7, "rough": 0.3})
		var tops := [mat(0x3aa8e0, {"rough": 0.6}), mat(0xe8f0f4, {"rough": 0.5}), mat(0x3aa8e0, {"rough": 0.6})]
		for i in n:
			var a := (float(i) / (n - 1) - 0.5) * 1.6
			var x := sin(a) * arc; var z := cos(a) * arc
			var y := 7.0 + float((i * 7) % 4) * 1.4
			var big := 1.0 if i % 2 == 0 else 0.75
			var pv := pivot(x, y, z, a + PI)
			pv.scale = Vector3.ONE * big
			cyl(4.2, 2.2, 2.6, bowl, 0, 0, 0, 28, pv)
			torus(4.2, 0.24, gold, 0, 1.3, 0, pv)
			torus(3.2, 0.13, gold, 0, 0.0, 0, pv)
			for k in 8:   # gold scrolls down the bowl
				var ka := float(k) / 8 * TAU
				on_ring(0, 0, 3.15, ka, 0.0, 0.25, 2.2, 0.12, gold, pv).rotation.x = 0.42
			dome(3.95, tops[i % 3], 0, 1.3, 0, 24, pv).scale = Vector3(1, 0.32, 1)
			cyl(0.45, 0.55, 2.8, gold, 0, -2.6, 0, 10, pv)
			sphere(0.75, gold, 0, -4.1, 0, 10, pv)
			for f in 3:
				var fa := float(f) / 3 * TAU
				rod(Vector3(0, -4.1, 0), Vector3(sin(fa) * 1.3, -5.0, cos(fa) * 1.3), 0.3, 0.12, gold, 6, pv)

	## Vampa (ref 168): a crater of lumpy yellow rock round a murky green pond, boulder mounds, giant spider-crabs
	## with orange spotted shells. ~44 m across; pair with a data "dig" for a deeper bowl.
	func vampacrater() -> void:
		var rock := mat(0xd8bc48, {"rough": 0.95}); var rock2 := mat(0xb89a34, {"rough": 0.95})
		var pond := mat(0x3e5a2a, {"rough": 0.08, "metal": 0.1}); var shell := mat(0xd0562a, {"rough": 0.6})
		var spot := mat(0x7a2a14, {"rough": 0.7}); var leg := mat(0x3a2a22, {"rough": 0.6})
		var rng := RandomNumberGenerator.new(); rng.seed = int(l.get("seed", 168))
		torus(15.0, 3.2, rock, 0, 0.0, 0).scale = Vector3(1, 0.45, 1)
		cyl(13.0, 13.0, 0.2, pond, 0, 0.35, 0, 40)
		for i in 14:
			var a := rng.randf() * TAU
			var r := rng.randf_range(15.0, 22.0)
			var s := rng.randf_range(2.0, 5.0)
			blob(s, rock2 if i % 3 == 0 else rock, sin(a) * r, s * 0.25, cos(a) * r, Vector3(1.3, rng.randf_range(0.5, 0.9), 1.0), 12)
		blob(5.0, rock, -19.0, 4.0, -12.0, Vector3(1.0, 1.6, 0.9), 14)
		blob(3.6, rock2, -17.0, 8.6, -12.5, Vector3(1.2, 0.9, 1.0), 12)
		for i in clampi(int(l.get("critters", 8)), 0, 16):
			var a := rng.randf() * TAU
			var r := rng.randf_range(16.0, 26.0)
			var x := sin(a) * r; var z := cos(a) * r
			var pv := pivot(x, gy(x, z), z, rng.randf() * TAU)
			pv.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
			blob(1.0, shell, 0, 1.3, 0, Vector3(1.0, 0.75, 1.15), 14, pv)
			for k in 5:
				var sa := rng.randf() * TAU
				blob(0.18, spot, sin(sa) * 0.75, 1.75, cos(sa) * 0.85, Vector3(1, 0.5, 1), 6, pv)
			for k in 8:
				var side := -1.0 if k < 4 else 1.0
				var fz := (float(k % 4) - 1.5) * 0.45
				var knee := Vector3(side * 1.6, 1.9, fz * 1.6)
				rod(Vector3(side * 0.6, 1.2, fz), knee, 0.09, 0.07, leg, 5, pv)
				rod(knee, Vector3(side * 2.3, 0.0, fz * 2.1), 0.07, 0.03, leg, 5, pv)
