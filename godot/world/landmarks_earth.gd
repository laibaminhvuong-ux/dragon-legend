class_name LandmarksEarth
extends RefCounted
# Extra landmark builders for this world group, called from WorldLandmarks (hook keeps landmarks.gd small).
# Add a type name to TYPES and a match arm in build().
#
# Batch B2 (Z-era Earth, 2026-11-10): new silhouettes for the Z/Super-era Earth places, matched to the reference pack
# (art/reference/maps_audit.md, batch 2). Same approach as LandmarksOrigins (the helpers and the material cache are
# inherited from LandmarksOrigins.B): primitive-built, then merged into one mesh per material. Local +z is the front
# (doors, signs, steps). The zone swaps (type, rot, collide, flatten) are listed in
# art/reference/map_data_requests_earth.md. Optional params: "trees" (bool, palms/lamps/fence/rubble round the site,
# default true), "apron" (cellring: dirt square round the ring, default true), "len" (archbridge length, default 60).
# Preview each builder with godot/tests/preview_earth_landmarks.gd (DL_PREVIEW_LANDMARK=<type>|all).

const TYPES: Array[String] = ["cellring", "capsulehq", "capsulehouse", "htcpalace", "babidihatch", "rrhangar", "rrtower",
	"archbridge", "brokentower", "seracs", "gingertower", "gingerhouse", "herostatue"]

static func build(type: String, g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	var b := E.new(g, zone, l)
	match type:
		"cellring": b.cellring()
		"capsulehq": b.capsulehq()
		"capsulehouse": b.capsulehouse()
		"htcpalace": b.htcpalace()
		"babidihatch": b.babidihatch()
		"rrhangar": b.rrhangar()
		"rrtower": b.rrtower()
		"archbridge": b.archbridge()
		"brokentower": b.brokentower()
		"seracs": b.seracs()
		"gingertower": b.gingertower()
		"gingerhouse": b.gingerhouse()
		"herostatue": b.herostatue()
		_:
			return
	b.finish()

class E extends LandmarksOrigins.B:
	var rng := RandomNumberGenerator.new()

	func _init(group: Node3D, z: RefCounted, landmark: Dictionary) -> void:
		super(group, z, landmark)
		rng.seed = int(floor(float(landmark.get("x", 0)) * 13.0 + float(landmark.get("z", 0)) * 7.0)) + 17

	# --- shared pieces --------------------------------------------------------------------------------------
	## A curved pane lying on a flattened dome (radius r, vertical squash s, base at y0): centred on latitude phi and
	## longitude a (from +z), w m along the band and h m up the slope, 3 cm proud of the dome. Used for the long band
	## windows of the Capsule domes (task 4 2026-11-13: they were flat 22 cm boxes, slabs standing off the curve).
	func dome_panel(r: float, s: float, y0: float, phi: float, a: float, w: float, h: float, m: Material, cx := 0.0, cz := 0.0) -> MeshInstance3D:
		var da := w / maxf(r * cos(phi), 0.1)
		var dphi := h / (r * sqrt(sin(phi) * sin(phi) + s * s * cos(phi) * cos(phi)))
		var nu := maxi(2, int(ceil(w / 0.5))); var nv := 3
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in nv + 1:
			for i in nu + 1:
				var ph := phi - dphi * 0.5 + dphi * j / nv
				var aa := a - da * 0.5 + da * i / nu
				var nrm := Vector3(cos(ph) * sin(aa), sin(ph) / s, cos(ph) * cos(aa)).normalized()
				st.set_normal(nrm)
				st.set_uv(Vector2(float(i) / nu, float(j) / nv))
				st.add_vertex(Vector3(cx + sin(aa) * r * cos(ph), y0 + s * r * sin(ph), cz + cos(aa) * r * cos(ph)) + nrm * 0.03)
		for j in nv:
			for i in nu:
				var k := j * (nu + 1) + i
				for idx in [k, k + nu + 1, k + nu + 2, k, k + nu + 2, k + 1]:   # clockwise seen from outside: Godot's front
					st.add_index(idx)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.set_meta("no_collision", true)   # a skin on the dome, which is the solid
		g.add_child(mi)
		return mi

	## A row of band windows round a dome at latitude phi, leaving a gap round the front (+z) if `gap` > 0.
	func dome_band(r: float, s: float, y0: float, phi: float, count: int, fill: float, h: float, m: Material, gap := 0.0, cx := 0.0, cz := 0.0, off := 0.0) -> void:
		var hr := r * cos(phi)
		for i in count:
			var a := (float(i) + 0.5) / count * TAU + off
			if gap > 0.0 and absf(wrapf(a, -PI, PI)) < gap:
				continue
			dome_panel(r, s, y0, phi, a, TAU * hr / count * fill, h, m, cx, cz)

	## Band windows round a cylinder (rows of long panes).
	func cyl_bands(r: float, cx: float, cz: float, y0: float, rows: int, gap: float, per: int, fill: float, h: float, m: Material) -> void:
		for row in rows:
			for i in per:
				var a := (float(i) + 0.5) / per * TAU + row * 0.2
				on_ring(cx, cz, r + 0.05, a, y0 + row * gap, TAU * r / per * fill, h, 0.2, m)

	## White picket fence from (x0,z) to (x1,z) along x.
	func picket_fence(x0: float, x1: float, z: float, m: Material) -> void:
		var n := int(absf(x1 - x0) / 0.55)
		for i in n:
			var x := lerpf(x0, x1, (float(i) + 0.5) / n)
			var y := gy(x, z)
			box(0.14, 1.1, 0.06, m, x, y + 0.55, z)
		box(absf(x1 - x0), 0.1, 0.05, m, (x0 + x1) * 0.5, gy((x0 + x1) * 0.5, z) + 0.75, z - 0.05)
		box(absf(x1 - x0), 0.1, 0.05, m, (x0 + x1) * 0.5, gy((x0 + x1) * 0.5, z) + 0.35, z - 0.05)

	## Street lamp: thin pole with a glowing pale-blue globe (West Capital).
	func globe_lamp(x: float, z: float, h := 3.6) -> void:
		var y := gy(x, z)
		cyl(0.07, 0.09, h, mat(0x9aa4b0, {"metal": 0.6, "rough": 0.35}), x, y + h * 0.5, z, 6)
		sphere(0.38, mat(0xd8f0ff, {"emissive": 0x9ad8ff, "glow": 1.2, "rough": 0.1}), x, y + h + 0.3, z, 12)

	## Curved street lamp with a dish shade (Ginger Town).
	func hook_lamp(x: float, z: float, ry: float) -> void:
		var y := gy(x, z)
		var pole := mat(0x6a6e74, {"metal": 0.5, "rough": 0.4})
		var n := pivot(x, y, z, ry)
		cyl(0.09, 0.12, 5.4, pole, 0, 2.7, 0, 6, n)
		var arm := cyl(0.07, 0.07, 1.8, pole, 0, 5.55, 0.8, 6, n); arm.rotation.x = PI / 2 - 0.25
		var dish := dome(0.55, pole, 0, 5.55, 1.75, 12, n); dish.rotation.x = PI
		sphere(0.2, mat(0xfff0c8, {"emissive": 0xffe0a0, "glow": 1.0}), 0, 5.35, 1.75, 8, n)

	## Loose broken rocks / rubble chunks in a ring.
	func rubble(cx: float, cz: float, r0: float, r1: float, count: int, m: Material, size := 1.4) -> void:
		for i in count:
			var a := rng.randf() * TAU
			var d := rng.randf_range(r0, r1)
			var x := cx + sin(a) * d; var z := cz + cos(a) * d
			var s := size * rng.randf_range(0.4, 1.0)
			var rb := box(s * 1.4, s * 0.7, s, m, x, gy(x, z) + s * 0.2, z)
			rb.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))

	# ======================================================================================================
	## Cel Games ring (cell_games): a big square lavender-white tiled ring raised on a two-step base, with FOUR tall
	## white tapered obelisks on turned feet at the corners, on a dirt apron. Ring 50 x 50, top at 1.0 m (as the old
	## cellarena, so fight spots stay on it); obelisks ~26 m tall at the base corners (±28).
	func cellring() -> void:
		var base := mat(0xb4b0bc, {"rough": 0.85}); var rim := mat(0xe6e4ee, {"rough": 0.5})
		var tile := mat(0xd8cfee, {"rough": 0.55}); var seam := mat(0xbcb0d8, {"rough": 0.6})
		var white := mat(0xf6f6fb, {"rough": 0.3}); var shade := mat(0xc6cae0, {"rough": 0.35})
		if flag("apron"):
			box(70, 0.06, 70, mat(0xa88a62, {"rough": 1.0}), 0, 0.03, 0)
		box(60, 0.4, 60, base, 0, 0.2, 0)
		box(53, 0.36, 53, rim, 0, 0.58, 0)
		box(50.4, 0.06, 50.4, rim, 0, 0.79, 0)
		box(50, 0.24, 50, tile, 0, 0.88, 0)   # top at 1.0
		for i in range(-20, 21, 5):   # tile seams, 4 cm proud (1.5 cm z-fought into dashed lines beyond ~20 m)
			box(50, 0.06, 0.1, seam, 0, 1.01, i)
			box(0.1, 0.06, 50, seam, i, 1.01, 0)
		for c: Vector2 in [Vector2(-28, -28), Vector2(28, -28), Vector2(-28, 28), Vector2(28, 28)]:
			# turned foot: base disc, bulb, neck
			cyl(1.7, 1.9, 0.5, shade, c.x, 0.65, c.y, 16)
			var bulb := sphere(1.25, white, c.x, 1.8, c.y, 16); bulb.scale = Vector3(1, 0.75, 1)
			cyl(0.95, 0.75, 0.5, shade, c.x, 2.6, c.y, 16)
			cyl(0.7, 0.9, 1.4, white, c.x, 3.5, c.y, 16)
			cyl(1.3, 1.3, 0.35, shade, c.x, 4.3, c.y, 16)
			# collar flaring out, then the long tapering spike
			cyl(1.9, 0.75, 2.4, white, c.x, 5.65, c.y, 16)
			cyl(1.55, 1.9, 9.0, white, c.x, 11.35, c.y, 16)
			cone(1.55, 15.0, white, c.x, 23.35, c.y, 16)
		# a few stones broken off the apron edge
		if flag("trees"):
			rubble(0, 0, 33, 40, 14, mat(0x9a8a72, {"rough": 0.95}), 1.6)

	## Kapsule Corporation HQ (west_city): a big cream dome with rows of long blue band windows, the company name on
	## its face, a blue-awning door and an arched door, a tall banded side tower, a ball-on-stalk tower and a small
	## side dome; front lawn, paved paths, white picket fence with globe lamps, a sign arch and palms. Dome r 16 (as
	## the old capsulecorp; request collide 17); fence at local z 24, 60 m wide. Front (+z) = doors.
	func capsulehq() -> void:
		var cream := mat(0xe9d7a2, {"rough": 0.55}); var trim := mat(0xd2bd84, {"rough": 0.6})
		var glass := mat(0x6fb6e6, {"rough": 0.1, "metal": 0.25, "emissive": 0x163a56, "glow": 0.4})
		var blue := mat(0x3f8fd0, {"rough": 0.45}); var dark := mat(0x22324a, {"rough": 0.5})
		var white := mat(0xf6f6f2, {"rough": 0.6})
		# main dome: r 16 squashed to 11.5 m
		var s := 0.72
		dome(16, cream, 0, 0, 0, 40).scale = Vector3(1, s, 1)
		torus(16.0, 0.35, trim, 0, 0.35, 0)
		dome_band(16, s, 0, 0.2, 9, 0.66, 2.0, glass, 0.55)
		dome_band(16, s, 0, 0.55, 8, 0.66, 1.7, glass, 0.0, 0, 0, 0.35)
		dome_band(16, s, 0, 0.92, 7, 0.45, 1.1, glass)
		torus(16.0 * cos(1.2) + 0.05, 0.12, trim, 0, s * 16.0 * sin(1.2), 0)   # the seam near the top
		var name_tag := Label3D.new()
		name_tag.text = "KAPSULE CORP."
		name_tag.font_size = 160; name_tag.pixel_size = 0.016; name_tag.outline_size = 0
		name_tag.modulate = Color("#6a5a3a")
		name_tag.position = Vector3(0, 6.6, 12.95); name_tag.rotation.x = -0.6
		g.add_child(name_tag)
		# doors: blue awning door (left) and the tall arched door (right), each in a little vestibule
		box(5.2, 4.6, 3.0, cream, -5.5, 2.3, 14.4)
		box(3.0, 3.6, 0.2, dark, -5.5, 1.8, 15.95)
		var awn := cyl(1.9, 1.9, 3.6, blue, -5.5, 4.0, 16.4, 16); awn.rotation.x = PI / 2; awn.scale = Vector3(1, 1, 0.55)
		for x in [-7.1, -3.9]:
			cyl(0.06, 0.06, 4.0, white, x, 2.0, 18.0, 6)
		box(4.8, 5.4, 3.0, cream, 5.5, 2.7, 14.4)
		box(3.0, 4.0, 0.2, trim, 5.5, 2.0, 15.95)
		var arch := cyl(1.5, 1.5, 0.22, trim, 5.5, 4.0, 15.95, 16); arch.rotation.x = PI / 2
		box(0.08, 4.0, 0.24, mat(0xa8945c), 5.5, 2.0, 16.0)
		# tall banded side tower rising from the back right of the dome
		cyl(4.6, 4.6, 28, cream, 12.5, 14, -6, 28)
		cyl_bands(4.6, 12.5, -6, 13.0, 5, 3.0, 8, 0.7, 1.4, glass)
		dome(4.6, cream, 12.5, 28, -6, 24)
		torus(4.65, 0.2, trim, 12.5, 28.1, -6)
		# ball-on-stalk tower behind the left side
		cyl(1.5, 1.9, 20, cream, -12, 10, -10, 16)
		var ball := sphere(5.2, cream, -12, 23.5, -10, 28); ball.scale = Vector3(1, 0.78, 1)
		for k in 2:
			torus(5.05 - k * 0.6, 0.55, glass, -12, 23.0 + k * 2.2, -10)
		torus(5.25, 0.2, trim, -12, 21.4, -10)
		# small side dome on the left
		dome(9, cream, -20, 0, 2, 28).scale = Vector3(1, 0.8, 1)
		dome_band(9, 0.8, 0, 0.35, 7, 0.55, 1.1, glass, 0.0, -20, 2, 0.4)
		if not flag("trees"):
			return
		# lawn, pink paved paths, fence with a sign arch, globe lamps, palms
		var lawn := mat(0x5fb04a, {"rough": 0.95}); var path := mat(0xd99a8a, {"rough": 0.9})
		box(60, 0.08, 9.0, lawn, 0, 0.04, 19.5)
		for x in [-5.5, 5.5]:
			box(3.4, 0.1, 8.0, path, x, 0.06, 20.0)
		box(30, 0.1, 1.6, path, 0, 0.07, 23.0)
		picket_fence(-30, -8.0, 24.2, white)
		picket_fence(-3.0, 2.8, 24.2, white)
		picket_fence(8.2, 30, 24.2, white)
		for x in [-8.0, -3.0]:
			cyl(0.1, 0.1, 4.2, white, x, 2.1, 24.2, 8)
		box(5.6, 1.0, 0.12, white, -5.5, 3.9, 24.2)
		var sign := Label3D.new()
		sign.text = "KAPSULE CORP."
		sign.font_size = 64; sign.pixel_size = 0.01; sign.outline_size = 0
		sign.modulate = Color("#4a5a70")
		sign.position = Vector3(-5.5, 3.9, 24.3)
		g.add_child(sign)
		for x in [-24.0, -14.0, 13.0, 24.0]:
			globe_lamp(x, 24.8)
		palm(10.5, 20.5, 7.0)
		palm(-26.0, 19.0, 6.5)
		palm(22.0, 12.0, 7.5)

	## A West Capital dome home (west_city, Capsule style): cream/white dome with band windows, a coloured ring and
	## roof cap, an entry with a little awning on the front (+z). Dome r 6 (as the old `dome`; collide 7).
	func capsulehouse() -> void:
		var accents := [0x7a5ac8, 0xc84a5a, 0x3a9aa0, 0x4a7ad0, 0xd8a040]
		var acc := mat(int(accents[rng.randi_range(0, accents.size() - 1)]), {"rough": 0.4})
		var wall := mat(0xf2ead2 if rng.randf() < 0.5 else 0xf4f4f0, {"rough": 0.5})
		var glass := mat(0x6fb6e6, {"rough": 0.1, "metal": 0.25, "emissive": 0x163a56, "glow": 0.4})
		cyl(6.0, 6.0, 1.6, wall, 0, 0.8, 0, 28).set_meta("wall", true)   # the house's drum is a wall, not a 1.3-1.8 m ledge to climb
		dome(6.0, wall, 0, 1.6, 0, 28).scale = Vector3(1, 0.8, 1)
		torus(6.02, 0.22, acc, 0, 1.6, 0)
		dome_band(6.0, 0.8, 1.6, 0.25, 7, 0.55, 0.8, glass, 0.5)
		dome_band(6.0, 0.8, 1.6, 0.75, 5, 0.45, 0.6, glass, 0.0, 0, 0, 0.6)
		var cap := dome(2.6, acc, 0, 1.6 + 6.0 * 0.8 - 0.35, 0, 20); cap.scale = Vector3(1, 0.55, 1)
		box(2.6, 2.6, 1.6, wall, 0, 1.3, 6.0)
		box(1.4, 2.2, 0.12, mat(0x3a4a6a), 0, 1.1, 6.82)
		var awn := cyl(1.0, 1.0, 1.3, acc, 0, 2.55, 7.2, 14); awn.rotation.x = PI / 2; awn.scale = Vector3(1, 1, 0.45)
		awn.set_meta("no_collision", true)   # overhead: its box was an invisible wall 1 m in front of the door (task 4)
		if flag("trees"):
			globe_lamp(2.6, 8.4, 3.0)

	## The Hyperbolic Time Room's entrance building (htc): a white tiled platform with three curved steps, a white
	## rotunda with columns and a ribbed gold dome with a clock face, an onion finial, two white wings under orange
	## half-barrel roofs with gold-rimmed oval windows, two giant hourglasses of green sand and blue orb lamp-posts.
	## 54 m wide; the front steps reach local z 9.5 (request rot pi so they face Mr. Pupo / the spawn).
	func htcpalace() -> void:
		var tile := mat(0xeceef0, {"rough": 0.35}); var seam := mat(0xc8ccd2, {"rough": 0.5})
		var white := mat(0xf7f7f4, {"rough": 0.45}); var grey := mat(0xb8c4cc, {"rough": 0.4})
		var gold := mat(0xe2b830, {"metal": 0.55, "rough": 0.3}); var olive := mat(0xb8b048, {"metal": 0.5, "rough": 0.35})
		var orange := mat(0xe2702c, {"rough": 0.55}); var cyan := mat(0x6ad8e8, {"rough": 0.3})
		var glassm := mat(0xcfefff, {"opacity": 0.32, "rough": 0.05}); var sand := mat(0x58c04a, {"rough": 0.9})
		no_shadow.append(glassm)
		# platform + seams, front apron with three curved steps
		box(54, 0.4, 11, tile, 0, 0.2, 0)
		for x in range(-24, 25, 4):
			box(0.06, 0.02, 11, seam, x, 0.41, 0)
		box(16, 0.4, 4, tile, 0, 0.2, 7.5)
		for k in 3:
			var st := cyl(8.0 - k * 0.2, 8.0 - k * 0.2, 0.4 - k * 0.13, tile, 0, (0.4 - k * 0.13) * 0.5, 5.6 + k * 1.3, 32)
			st.scale = Vector3(1, 1, 0.45)
		# wings with orange half-barrel roofs and oval windows
		for sx in [-1.0, 1.0]:
			var wx: float = sx * 11.5
			box(13, 4.8, 7, white, wx, 2.8, -0.5)
			var roof := cyl(3.9, 3.9, 13.6, orange, wx, 5.2, -0.5, 20); roof.rotation.z = PI / 2; roof.scale = Vector3(0.55, 1, 1)
			box(13.8, 0.25, 7.9, gold, wx, 5.25, -0.5)
			box(4.2, 1.1, 0.12, gold, wx, 3.0, 3.02)
			box(3.6, 0.7, 0.14, mat(0x9ad8f0, {"rough": 0.1, "metal": 0.2}), wx, 3.0, 3.06)
			for ex in [-2.1, 2.1]:
				var end := cyl(0.55, 0.55, 0.12, gold, wx + ex, 3.0, 3.02, 12); end.rotation.x = PI / 2
		# rotunda: back wall drum, columns, cornice, gold ribbed dome, clock and finial
		cyl(5.0, 5.0, 6.6, white, 0, 3.7, -0.8, 28)
		box(3.0, 3.6, 0.3, mat(0x8a4a24, {"rough": 0.6}), 0, 2.2, 4.25)
		for k in 6:
			var a := -1.05 + float(k) / 5.0 * 2.1
			cyl(0.32, 0.36, 6.4, white, sin(a) * 5.6, 3.6, -0.8 + cos(a) * 5.6, 10)
			cyl(0.5, 0.5, 0.3, grey, sin(a) * 5.6, 0.55, -0.8 + cos(a) * 5.6, 10)
		cyl(6.2, 6.0, 0.7, grey, 0, 7.3, -0.8, 32)
		dome(6.0, gold, 0, 7.6, -0.8, 32).scale = Vector3(1, 0.72, 1)
		for k in 16:
			var a := float(k) / 16.0 * TAU
			var rib := box(0.12, 4.4, 0.3, mat(0xc89820, {"metal": 0.5, "rough": 0.35}), sin(a) * 4.7, 9.4, -0.8 + cos(a) * 4.7, a)
			rib.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.75)
		cyl(1.5, 1.7, 0.3, cyan, 0, 11.95, -0.8, 20)
		var fin := sphere(1.0, olive, 0, 12.9, -0.8, 16); fin.scale = Vector3(1, 1.1, 1)
		cone(0.55, 1.6, olive, 0, 14.4, -0.8, 12)
		var clock := cyl(1.15, 1.15, 0.2, mat(0xfbfbf6, {"rough": 0.4}), 0, 9.1, 4.25, 24); clock.rotation.x = PI / 2 - 0.35
		var ring := torus(1.15, 0.12, gold, 0, 9.1, 4.27); ring.rotation.x = PI / 2 - 0.35
		var hand := box(0.14, 0.85, 0.06, mat(0x3a2a20), 0, 9.42, 4.42); hand.rotation.x = -0.35
		# hourglasses
		for sx in [-1.0, 1.0]:
			var hx: float = sx * 19.5
			cyl(2.0, 2.2, 0.35, gold, hx, 0.58, 0, 20)
			cyl(1.9, 1.9, 0.35, gold, hx, 8.6, 0, 20)
			var cap := dome(2.0, gold, hx, 8.75, 0, 20); cap.scale = Vector3(1, 0.6, 1)
			cone(0.35, 1.6, gold, hx, 10.7, 0, 8)
			cyl(0.25, 1.75, 3.9, glassm, hx, 2.7, 0, 20)
			cyl(1.75, 0.25, 3.9, glassm, hx, 6.6, 0, 20)
			cyl(0.2, 1.55, 2.0, sand, hx, 1.75, 0, 16)
			cyl(1.0, 0.2, 1.2, sand, hx, 5.2, 0, 16)
			cyl(0.12, 0.12, 2.2, sand, hx, 3.8, 0, 6)
			# orb lamp-posts outside them
			var lx: float = sx * 25.5
			cyl(0.5, 0.6, 0.3, gold, lx, 0.55, 0, 12)
			cyl(0.12, 0.12, 5.6, mat(0xb8d8f0, {"rough": 0.2, "metal": 0.3}), lx, 3.3, 0, 8)
			cyl(0.45, 0.25, 0.4, gold, lx, 6.2, 0, 12)
			sphere(1.25, mat(0x2a4ad8, {"rough": 0.25, "emissive": 0x0a1a6a, "glow": 0.6}), lx, 7.5, 0, 20)

	## Babido's spaceship (babidi_ship), almost all buried: a low round tan hull mound with dark vents, and on top the
	## rounded entry hatch with its doorway facing +z, in cracked ground with broken rocks. Mound r 24, ~3 m high.
	func babidihatch() -> void:
		var hull := mat(0xc6a87a, {"rough": 0.75}); var band := mat(0x8a7454, {"rough": 0.7})
		var dark := mat(0x2a1e16); var metal := mat(0x9a8a6a, {"metal": 0.5, "rough": 0.45})
		var mound := sphere(24, hull, 0, -0.4, 0, 48); mound.scale = Vector3(1, 0.14, 1)
		# building audit: the mound was one solid 24 m circle, an invisible wall at its ground-level rim. Walk up it
		# instead: hidden 0.3 m terraces just under its surface carry you to the hatch.
		mound.set_meta("no_collision", true)
		var t := 0.3
		while t < 3.0:
			var tr := 24.0 * sqrt(1.0 - pow((minf(t, 2.9) + 0.4) / 3.36, 2)) * 0.98
			cyl(tr, tr, minf(t, 2.9) + 0.6, hull, 0, (minf(t, 2.9) - 0.6) * 0.5, 0, 32).set_meta("stand_on", true)
			t += 0.3
		torus(19.5, 0.35, band, 0, 1.45, 0)   # on the mound's surface (at 1.15 it was buried)
		for k in 8:   # vents round the mound
			var a := float(k) / 8.0 * TAU + 0.39
			var v := box(3.0, 0.5, 1.2, dark, sin(a) * 14.0, 2.2, cos(a) * 14.0, a)
			v.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.18)
		# the hatch: a collar and a rounded cap with its doorway
		cyl(5.6, 6.2, 1.0, band, 0, 3.0, 0, 28)
		cyl(4.6, 4.8, 1.6, hull, 0, 4.0, 0, 28)
		var cap := dome(4.6, hull, 0, 4.8, 0, 28); cap.scale = Vector3(1, 0.72, 1)
		torus(4.65, 0.18, metal, 0, 4.85, 0)
		cyl(0.5, 0.7, 0.6, metal, 0, 8.25, 0, 12)
		box(2.4, 3.0, 2.0, hull, 0, 4.5, 4.0)
		box(1.7, 2.5, 0.2, dark, 0, 4.25, 5.02)
		var lip := cyl(1.25, 1.25, 2.2, hull, 0, 6.0, 4.0, 16); lip.rotation.x = PI / 2
		for sx in [-1.0, 1.0]:   # little ramp down from the doorway, on the mound (was steeper than it: 5 of its 7 m sank in)
			var rail := box(0.3, 0.4, 7.0, band, sx * 1.0, 2.9, 8.5); rail.rotation.x = 0.07; rail.set_meta("no_collision", true)
		var ramp := box(1.9, 0.2, 7.0, metal, 0, 2.8, 8.5); ramp.rotation.x = 0.07; ramp.set_meta("no_collision", true)
		if flag("trees"):
			rubble(0, 0, 25, 34, 18, mat(0x8a7454, {"rough": 0.95}), 2.2)
			for k in 6:   # cracks radiating out of the ground
				var a := rng.randf() * TAU
				var c := box(0.4, 0.08, rng.randf_range(6.0, 10.0), band, sin(a) * 30.0, 0.05, cos(a) * 30.0, a)
				c.rotation.y = a + rng.randf_range(-0.3, 0.3)

	## Crimson Ribbon Super Hero hangar (red_ribbon): pale arched hangar with ribs, a big grey sliding door under a
	## red band on the front (+z), side annex with windows, roof skylight, concrete apron with hazard stripes.
	## 32 x 22 m (as the old hangar; collide 16).
	func rrhangar() -> void:
		var wall := mat(0xc8c6be, {"rough": 0.75}); var roof_m := mat(0xb4b4ae, {"rough": 0.55, "metal": 0.25})
		var rib := mat(0x8a8e94, {"metal": 0.5, "rough": 0.4}); var red := mat(0xc22a2a, {"rough": 0.55})
		var door := mat(0x6a6e74, {"metal": 0.55, "rough": 0.45}); var dark := mat(0x23262c)
		var conc := mat(0xa6a49e, {"rough": 0.9}); var yellow := mat(0xe8c020, {"rough": 0.6})
		box(32, 4.0, 22, wall, 0, 2.0, 0)
		var shell := cyl(16, 16, 22, roof_m, 0, 4.0, 0, 32); shell.rotation.x = PI / 2; shell.scale = Vector3(1, 1, 0.55)
		for k in 6:
			var r := cyl(16.25, 16.25, 0.45, rib, 0, 4.0, -10.6 + k * 4.24, 32); r.rotation.x = PI / 2; r.scale = Vector3(1, 1, 0.55)
		box(2.6, 0.3, 21.0, mat(0xa8d0e0, {"rough": 0.15, "metal": 0.3}), 0, 12.85, 0)
		# front: sliding door panels in a frame, red band over it
		box(22, 0.8, 0.5, rib, 0, 10.4, 11.1)
		for sx in [-1.0, 1.0]:
			box(0.8, 10.4, 0.5, rib, sx * 11.0, 5.2, 11.1)
		for k in 4:
			box(5.1, 9.9, 0.25, door, -7.65 + k * 5.1, 4.95, 11.0)
			box(0.12, 9.9, 0.3, dark, -10.2 + k * 5.1, 4.95, 11.05)
		box(32.2, 1.4, 0.3, red, 0, 3.0, 11.02)
		box(24, 1.2, 0.2, red, 0, 11.6, 11.0)
		box(0.25, 1.4, 22.2, red, 16.02, 3.0, 0)
		box(0.25, 1.4, 22.2, red, -16.02, 3.0, 0)
		# side annex with a window row
		box(6, 5.2, 12, wall, 19, 2.6, -2)
		box(6.4, 0.4, 12.4, rib, 19, 5.3, -2)
		for k in 4:
			box(0.15, 1.2, 1.8, dark, 22.05, 3.2, -6.5 + k * 3.0)
		box(1.4, 2.4, 0.15, dark, 19, 1.2, 4.05)
		if flag("trees"):
			box(34, 0.12, 14, conc, 0, 0.06, 18)
			for k in 9:   # hazard stripes along the door line
				box(1.2, 0.02, 0.6, yellow if k % 2 == 0 else dark, -9.6 + k * 2.4, 0.13, 11.8)
			box(0.3, 0.02, 12, yellow, -11, 0.13, 18)
			box(0.3, 0.02, 12, yellow, 11, 0.13, 18)
			for k in 3:   # fuel drums
				cyl(0.6, 0.6, 1.3, red if k != 1 else mat(0x4a6a3a), 23 + k * 1.3, 0.65, 8.0, 12)

	## Crimson Ribbon industrial tower (red_ribbon, Super Hero base): a tall pale stacked block with rounded corners,
	## a slimmer twin shaft, vertical pipes, dark inset windows, a red band, roof machinery and a dish. Base 26 x 18,
	## ~54 m tall (request collide 11).
	func rrtower() -> void:
		var pale := mat(0xdcd8ce, {"rough": 0.7}); var shade := mat(0xb8b4aa, {"rough": 0.75})
		var dark := mat(0x2a2c32); var pipe := mat(0x9aa0a8, {"metal": 0.55, "rough": 0.4}); var red := mat(0xc22a2a, {"rough": 0.55})
		# podium
		box(26, 9, 18, shade, 0, 4.5, 0)
		for k in 6:
			box(2.6, 2.2, 0.2, dark, -10 + k * 4.0, 5.5, 9.05)
		box(5, 5, 0.2, dark, 6.0, 2.5, 9.05)
		# main shaft: a rounded block 14 x 11, 46 m
		var mh := 46.0
		box(14, mh, 7, pale, -3, 9 + mh * 0.5, 0)
		box(10, mh, 11, pale, -3, 9 + mh * 0.5, 0)
		for c: Vector2 in [Vector2(-8, -3.5), Vector2(2, -3.5), Vector2(-8, 3.5), Vector2(2, 3.5)]:
			cyl(2.0, 2.0, mh, pale, c.x, 9 + mh * 0.5, c.y, 16)
		var top := cyl(5.5, 5.5, 14, pale, -3, 9 + mh, 0, 24); top.rotation.z = PI / 2; top.scale = Vector3(1, 1, 1)
		# window grid + bands on the front
		for row in 9:
			var y := 13.0 + row * 4.6
			box(14.2, 0.35, 11.2, shade, -3, y + 2.0, 0)
			for k in 3:
				if (row + k) % 4 == 3:
					continue
				box(2.0, 1.8, 0.2, dark, -7 + k * 4.0, y, 5.55)
		box(14.3, 1.6, 11.3, red, -3, 18.0, 0)
		# slim twin shaft
		box(7, 36, 7, shade, 8.5, 9 + 18, -2)
		for row in 7:
			box(1.6, 2.4, 0.2, dark, 8.5, 13.0 + row * 4.6, 1.55)
		dome(3.5, shade, 8.5, 45, -2, 16)
		# vertical pipes and a cross-over
		for x in [3.6, 4.6]:
			cyl(0.35, 0.35, 44, pipe, x, 9 + 22, 4.5, 8)
		var cross := cyl(0.45, 0.45, 8, pipe, 5.5, 38, 4.5, 8); cross.rotation.z = PI / 2
		# roof machinery and dish
		box(4, 2.5, 4, pipe, -6, 9 + mh + 6.5, 0)
		cyl(0.15, 0.15, 7, pipe, 0, 9 + mh + 8.5, 0, 6)
		var dish := dome(2.6, pipe, -6, 9 + mh + 9.6, 0, 16); dish.rotation = Vector3(-2.3, 0.6, 0)

	## Arched viaduct (red_ribbon base): stone piers with round arches under a deck, railing posts; the piers reach
	## down to the terrain. Runs along local x, `len` metres (default 60), deck top at 13 m.
	func archbridge() -> void:
		var stone := mat(0xc8c2b4, {"rough": 0.85}); var deck_m := mat(0xb0aa9c, {"rough": 0.8})
		var length := float(l.get("len", 60.0))
		var span := 10.0
		var n := maxi(2, int(length / span))
		var x0 := -float(n) * span * 0.5
		box(float(n) * span + 2.0, 1.2, 7, deck_m, 0, 12.4, 0)
		box(float(n) * span + 2.0, 1.6, 6.2, stone, 0, 11.0, 0)
		for i in n + 1:
			var px := x0 + float(i) * span
			var base_y := minf(gy(px, 0), 0.0) - 1.0
			var ph := 7.0 - base_y
			box(2.4, ph, 6.2, stone, px, base_y + ph * 0.5, 0)
		for i in n:   # arches: voussoirs on a half circle between the piers
			var cx := x0 + (float(i) + 0.5) * span
			for k in 9:
				var a := float(k) / 8.0 * PI
				var v := box(1.0, 1.3, 6.2, stone, cx - cos(a) * 3.85, 7.0 + sin(a) * 3.85, 0)
				v.rotation.z = a - PI / 2
			for sx in [-1.0, 1.0]:   # spandrel fill over the haunches
				box(2.2, 3.4, 6.2, stone, cx + sx * 3.9, 8.9, 0)
		for i in int(float(n) * span / 2.0) + 1:
			var px := x0 + float(i) * 2.0
			for sz in [-3.3, 3.3]:
				box(0.25, 1.0, 0.25, deck_m, px, 13.5, sz)
		for sz in [-3.3, 3.3]:
			box(float(n) * span + 2.0, 0.18, 0.3, deck_m, 0, 14.0, sz)

	## Future West Capital ruin (future_earth): a tall concrete tower with storeys of dark window bands, the top
	## sheared off in jagged broken floors, slabs hanging, rebar sticking out, a slight lean and rubble at its feet.
	## Footprint 13 x 10 m, 24-36 m tall (seeded per placement; request collide 7).
	func brokentower() -> void:
		var conc := mat(0x8e9088, {"rough": 0.9}); var slab := mat(0xa4a69c, {"rough": 0.85})
		var dark := mat(0x2a2e30, {"rough": 1.0}); var rebar := mat(0x4a3a30, {"metal": 0.4, "rough": 0.7})
		var t := pivot(0, 0, 0)
		t.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.06, 0.06))
		var floors := rng.randi_range(7, 10)
		var fh := 3.6
		var cut := rng.randf_range(-0.5, 0.5)   # slope of the shear across the top
		for f in floors:
			var y := float(f) * fh
			var broken := f >= floors - 3
			var w := 13.0; var d := 10.0; var ox := 0.0
			if broken:
				var k := float(f - (floors - 3) + 1)
				w = 13.0 - k * rng.randf_range(2.0, 3.4); ox = cut * k * 2.6
			box(w - 1.0, fh - 0.5, d - 1.0, dark, ox, y + fh * 0.5, 0, 0.0, t)   # dark interior behind the windows
			var s := box(w + 0.3, 0.55, d + 0.3, slab, ox, y + fh - 0.1, 0, 0.0, t)
			if broken and rng.randf() < 0.6:
				s.rotation.z = rng.randf_range(-0.25, 0.25)
			for cx in [-0.5, 0.0, 0.5]:   # columns on the long faces
				for sz in [-1.0, 1.0]:
					box(0.9, fh - 0.5, 0.9, conc, ox + float(cx) * (w - 1.0), y + fh * 0.5, sz * (d * 0.5 - 0.3), 0.0, t)
			box(0.9, fh - 0.5, d - 0.4, conc, ox - w * 0.5 + 0.45, y + fh * 0.5, 0, 0.0, t)
			box(0.9, fh - 0.5, d - 0.4, conc, ox + w * 0.5 - 0.45, y + fh * 0.5, 0, 0.0, t)
		box(13.4, 3.0, 10.4, conc, 0, -0.3, 0, 0.0, t).set_meta("wall", true)   # footing reaches 1.8 m down: the tower's tilt lifted one edge 0.4 m off the ground; a wall, not a 1.8-2 m ledge round the ruin (task 4)
		var top := float(floors) * fh
		for i in 7:   # rebar
			var r := cyl(0.06, 0.06, rng.randf_range(1.5, 3.5), rebar, rng.randf_range(-4.0, 4.0) + cut * 6.0, top - 1.5, rng.randf_range(-4.0, 4.0), 4, t)
			r.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var hang := box(6.0, 0.5, 8.0, slab, 6.0, top - fh * 2.0, 0, 0.0, t)   # a floor slab hanging off the side
		hang.rotation.z = -1.0
		if flag("trees"):
			rubble(0, 0, 6, 14, 16, conc, 2.4)

	## Ice seracs (broly_glacier): a cluster of jagged white-blue ice blades and a faceted ice wall, seeded per
	## placement. About 30 x 20 m, up to 22 m tall (request collide 9).
	func seracs() -> void:
		var ice := mat(0xe8f4fc, {"rough": 0.3}); var blue := mat(0x9cc8e8, {"rough": 0.2, "metal": 0.1})
		var deep := mat(0x6aa8d8, {"rough": 0.15, "emissive": 0x0a2a4a, "glow": 0.3})
		for i in 6:   # the wall: tall faceted slabs side by side
			var x := -12.0 + i * 4.8 + rng.randf_range(-0.8, 0.8)
			var h := rng.randf_range(10.0, 18.0)
			var s := cyl(0.0, 3.2, h, ice if i % 2 == 0 else blue, x, gy(x, -4) + h * 0.5 - 0.5, -4.0, 5)
			s.scale = Vector3(1.0, 1.0, 0.55)
			s.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * 0.6, rng.randf_range(-0.12, 0.12))
		for i in 11:   # blades leaning out in front
			var x := rng.randf_range(-15.0, 15.0); var z := rng.randf_range(-2.0, 9.0)
			var h := rng.randf_range(3.0, 14.0)
			var m: Material = [ice, blue, deep][i % 3]
			var b := cyl(0.0, rng.randf_range(0.8, 2.0), h, m, x, gy(x, z) + h * 0.45, z, 4)
			b.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
		var big := cyl(0.0, 4.0, 22.0, ice, 2.0, gy(2, -6) + 10.5, -6.0, 6)
		big.scale = Vector3(1, 1, 0.6); big.rotation.z = 0.08
		for i in 8:   # broken ice blocks
			var x := rng.randf_range(-16.0, 16.0); var z := rng.randf_range(4.0, 12.0)
			var s := rng.randf_range(0.8, 2.2)
			box(s * 1.3, s, s, blue if i % 2 == 0 else ice, x, gy(x, z) + s * 0.3, z, rng.randf() * TAU).rotation.x = rng.randf_range(-0.4, 0.4)

	## Ginger Town domed tower (gero_lab): a pale round tower with rows of arched windows and a dark dome with
	## dormers and a spire, a picket fence and a curved street lamp. r 5, ~22 m (request collide 5.5).
	func gingertower() -> void:
		var wall := mat(0xece6d6, {"rough": 0.7}); var dark := mat(0x2e3036, {"rough": 0.6}); var trim := mat(0xc8c0ac, {"rough": 0.7})
		var win := mat(0x30343c, {"rough": 0.4})
		cyl(5.0, 5.2, 16, wall, 0, 8, 0, 28)
		# the wall tapers 5.2 -> 5.0 m: trim and windows sit on its surface at their height (audit: at a fixed 5.05 m
		# they were buried in the wall, only slivers and a zig-zag trim line showed between the facets)
		var rw := func(y: float) -> float: return 5.2 - 0.2 * y / 16.0 + 0.04
		for row in 4:
			torus(rw.call(3.6 + row * 3.6), 0.12, trim, 0, 3.6 + row * 3.6, 0)
			for k in 6:
				var a := float(k) / 6.0 * TAU + row * 0.5
				on_ring(0, 0, rw.call(1.9 + row * 3.6), a, 1.9 + row * 3.6, 0.8, 1.3, 0.12, win)
				var ar: float = rw.call(2.55 + row * 3.6) + 0.02
				var arc := cyl(0.4, 0.4, 0.12, win, sin(a) * ar, 2.55 + row * 3.6, cos(a) * ar, 10)
				arc.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2)
		cyl(5.3, 5.3, 0.5, trim, 0, 16.2, 0, 28)
		dome(5.1, dark, 0, 16.4, 0, 28)
		for k in 4:   # dormers in the dome
			var a := float(k) / 4.0 * TAU + PI / 4
			on_ring(0, 0, 4.0, a, 18.2, 1.2, 1.6, 1.2, wall)
			on_ring(0, 0, 4.62, a, 18.2, 0.7, 1.0, 0.1, win)
		cyl(0.12, 0.2, 3.2, trim, 0, 23.0, 0, 6)
		box(1.6, 2.4, 0.2, mat(0x5a4a3a), 0, 1.2, 5.22)
		if flag("trees"):
			picket_fence(-9, 9, 9.0, mat(0xf2f0e8, {"rough": 0.7}))
			hook_lamp(7.0, 7.0, 0.5)
			rubble(0, 0, 9, 14, 6, mat(0x9a948a, {"rough": 0.95}), 1.0)

	## Ginger Town dome house (gero_lab): a low wide dome house with a band of arched windows, an arched porch,
	## a picket fence across the front and a curved street lamp. r 9 (request collide 8).
	func gingerhouse() -> void:
		var wall := mat(0xece6d6, {"rough": 0.7}); var trim := mat(0xc8c0ac, {"rough": 0.7}); var win := mat(0x30343c, {"rough": 0.4})
		cyl(9.0, 9.2, 2.6, wall, 0, 1.3, 0, 32)
		dome(9.0, wall, 0, 2.6, 0, 32).scale = Vector3(1, 0.5, 1)
		torus(9.05, 0.15, trim, 0, 2.6, 0)
		for k in 10:
			var a := (float(k) + 0.5) / 10.0 * TAU
			if absf(wrapf(a, -PI, PI)) < 0.4:
				continue
			on_ring(0, 0, 9.14, a, 1.4, 1.0, 1.4, 0.12, win)   # the wall is 9.09 m out at this height
			var arc := cyl(0.5, 0.5, 0.12, win, sin(a) * 9.12, 2.1, cos(a) * 9.12, 10)
			arc.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2)
		box(4.0, 3.6, 2.4, wall, 0, 1.8, 9.0)
		var porch := cyl(2.0, 2.0, 2.4, wall, 0, 3.6, 9.0, 16); porch.rotation.x = PI / 2
		box(1.6, 2.4, 0.15, mat(0x5a4a3a), 0, 1.2, 10.25)
		var arc2 := cyl(0.8, 0.8, 0.15, mat(0x5a4a3a), 0, 2.4, 10.25, 12); arc2.rotation.x = PI / 2
		cyl(0.6, 0.6, 0.6, trim, 0, 2.6 + 4.5, 0, 12)
		if flag("trees"):
			picket_fence(-11, -2, 13.0, mat(0xf2f0e8, {"rough": 0.7}))
			picket_fence(2, 11, 13.0, mat(0xf2f0e8, {"rough": 0.7}))
			hook_lamp(-8.0, 12.0, -0.4)

	## The champion's statue (amber_city / a Satan City plaza): a stepped stone plinth with a gold plaque, and a
	## big gold figure in a gi and cape with a fist raised in victory and a bushy head of hair. ~17 m tall.
	func herostatue() -> void:
		var stone := mat(0xc8c2b4, {"rough": 0.8}); var gold := mat(0xd8aa40, {"metal": 0.75, "rough": 0.3})
		var dgold := mat(0xa8802a, {"metal": 0.7, "rough": 0.35})
		box(9, 1.0, 9, stone, 0, 0.5, 0)
		box(7, 1.0, 7, stone, 0, 1.5, 0)
		box(5, 4.0, 5, stone, 0, 4.0, 0)
		box(3.4, 1.2, 0.1, gold, 0, 4.4, 2.56)
		var f := pivot(0, 6.0, 0)
		f.scale = Vector3.ONE * 1.55
		# legs in a wide stance, belt, torso, head with hair
		for sx in [-1.0, 1.0]:
			var leg := cyl(0.42, 0.5, 2.8, gold, sx * 0.75, 1.4, 0, 10, f); leg.rotation.z = sx * 0.18
			box(0.7, 0.35, 1.1, dgold, sx * 1.0, 0.18, 0.15, 0.0, f)
		box(1.9, 0.6, 1.1, gold, 0, 3.0, 0, 0.0, f)
		cyl(0.95, 0.95, 0.3, dgold, 0, 3.35, 0, 14, f)
		var torso := cyl(1.15, 0.9, 2.2, gold, 0, 4.6, 0, 14, f); torso.scale = Vector3(1, 1, 0.75)
		sphere(0.55, gold, 0, 6.05, 0, 12, f)
		var hair := sphere(0.75, dgold, 0, 6.35, -0.1, 12, f); hair.scale = Vector3(1.15, 0.85, 1.05)
		# arms: left raised fist, right fist on the hip
		var up := cyl(0.28, 0.32, 2.4, gold, -1.35, 6.2, 0, 8, f); up.rotation.z = 0.25
		sphere(0.42, gold, -1.65, 7.55, 0, 10, f)
		var upper := cyl(0.28, 0.32, 1.3, gold, 1.5, 4.95, 0.05, 8, f); upper.rotation.z = 0.5
		var fore := cyl(0.26, 0.28, 1.1, gold, 1.45, 4.0, 0.15, 8, f); fore.rotation.z = -0.72
		sphere(0.36, gold, 1.1, 3.6, 0.2, 10, f)
		# cape down the back
		var cape := box(2.2, 4.4, 0.18, dgold, 0, 3.4, -0.75, 0.0, f); cape.rotation.x = 0.15
		if flag("trees"):
			for k in 4:
				var a := float(k) / 4.0 * TAU + PI / 4
				globe_lamp(sin(a) * 6.8, cos(a) * 6.8, 3.4)
