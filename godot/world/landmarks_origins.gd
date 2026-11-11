class_name LandmarksOrigins
extends RefCounted
# Extra landmark builders for this world group, called from WorldLandmarks (hook keeps landmarks.gd small).
# Add a type name to TYPES and a match arm in build().
#
# Batch B1 (Origins Earth, 2026-11-10): rebuilt silhouettes for the childhood places, matched to the reference pack
# (art/reference/maps_audit.md, batch 1). Each builder is primitive-built like landmarks.gd, then merged with MeshMerge
# into one mesh per material (a whole castle costs a handful of draw calls). Materials are cached so equal colours
# share one material and merge together. Local +z is the front (the side facing the arrival / NPCs).
# Optional landmark params (all have defaults): "trees" (bool, decorative trees/props round the site),
# "clouds" (korrinspire: cloud collar round the shaft), "lawn" (kingcastle: garden disc under the palace).
# Preview each builder on the GPU with godot/tests/preview_origins_landmarks.gd (DL_PREVIEW_LANDMARK=<type>|all).

const TYPES: Array[String] = ["kamecottage", "paozucabin", "paozuhome", "firekeep", "pilavpalace", "musclefort",
	"korrinspire", "lookoutpalace", "baabaisle", "kingcastle", "budokaihall", "rrfortress"]

static func build(type: String, g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	var b := B.new(g, zone, l)
	match type:
		"kamecottage": b.kamecottage()
		"paozucabin": b.paozucabin()
		"paozuhome": b.paozuhome()
		"firekeep": b.firekeep()
		"pilavpalace": b.pilavpalace()
		"musclefort": b.musclefort()
		"korrinspire": b.korrinspire()
		"lookoutpalace": b.lookoutpalace()
		"baabaisle": b.baabaisle()
		"kingcastle": b.kingcastle()
		"budokaihall": b.budokaihall()
		"rrfortress": b.rrfortress()
		_:
			return
	b.finish()

class B extends RefCounted:
	static var _mats: Dictionary = {}
	static var _lock := Mutex.new()
	var g: Node3D
	var zone: RefCounted
	var l: Dictionary
	var no_shadow: Array[Material] = []

	func _init(group: Node3D, z: RefCounted, landmark: Dictionary) -> void:
		g = group; zone = z; l = landmark

	## Merge every static piece into one mesh per material; glow/water/cloud surfaces don't cast shadows.
	func finish() -> void:
		MeshMerge.merge(g)
		for c in g.get_children():
			var mi := c as MeshInstance3D
			if mi != null and mi.material_override in no_shadow:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func flag(key: String, def := true) -> bool:
		return bool(l.get(key, def))

	# --- materials (cached: same look -> same material instance, so MeshMerge folds them together) ---
	func mat(color: int, o := {}) -> Material:
		var key := "%06x|%s" % [color, str(o)]
		_lock.lock()
		var hit: Variant = _mats.get(key)
		_lock.unlock()
		if hit != null:
			return hit
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.hex((color << 8) | 0xff)
		m.roughness = float(o.get("rough", 0.6))
		m.metallic = float(o.get("metal", 0.0))
		if o.has("emissive"):
			m.emission_enabled = true
			m.emission = Color.hex((int(o.emissive) << 8) | 0xff)
			m.emission_energy_multiplier = float(o.get("glow", 1.0)) * 2.0
		if o.has("opacity"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = float(o.opacity)
		if bool(o.get("unshaded", false)):
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if bool(o.get("stone", false)):  # photo-scanned rock, tinted by the colour (triplanar: needs no UVs after merge)
			var rock: Dictionary = WorldMaterials.ground("rock")
			if rock.albedo != null:
				m.albedo_texture = rock.albedo
				m.normal_enabled = rock.normal != null
				m.normal_texture = rock.normal
				m.uv1_triplanar = true
				m.uv1_scale = Vector3.ONE * float(o.get("tile", 0.25))
				m.albedo_color = m.albedo_color.lightened(0.25)
		_lock.lock()
		_mats[key] = m
		_lock.unlock()
		return m

	## Flickering flame tongues: the vertex shader sways the tips (higher = more), colour runs hot base -> red tip.
	## Works on the merged mesh (object space = the landmark's space; no UVs needed).
	func flame_mat(base_y: float, top_y: float) -> Material:
		var key := "flame|%.1f|%.1f" % [base_y, top_y]
		_lock.lock()
		var hit: Variant = _mats.get(key)
		_lock.unlock()
		if hit != null:
			return hit
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float base_y = 0.0;
uniform float top_y = 10.0;
varying float k;
void vertex() {
	k = clamp((VERTEX.y - base_y) / max(top_y - base_y, 0.01), 0.0, 1.0);
	float w = k * k;
	VERTEX.x += sin(TIME * 4.3 + VERTEX.y * 0.55 + VERTEX.z * 0.35) * w * 1.3;
	VERTEX.z += cos(TIME * 3.7 + VERTEX.y * 0.45 + VERTEX.x * 0.35) * w * 1.3;
	VERTEX.y += sin(TIME * 6.0 + VERTEX.x * 0.8 + VERTEX.z * 0.6) * w * 0.6;
}
void fragment() {
	vec3 hot = vec3(1.0, 0.82, 0.22);
	vec3 mid = vec3(1.0, 0.40, 0.04);
	vec3 tip = vec3(0.78, 0.09, 0.02);
	ALBEDO = k < 0.45 ? mix(hot, mid, k / 0.45) : mix(mid, tip, (k - 0.45) / 0.55);
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("base_y", base_y)
		m.set_shader_parameter("top_y", top_y)
		_lock.lock()
		_mats[key] = m
		_lock.unlock()
		return m

	# --- shapes (centred meshes, as landmarks.gd) ---
	func put(mesh: Mesh, m: Material, x: float, y: float, z: float, p: Node3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(x, y, z)
		(p if p != null else g).add_child(mi)
		return mi

	func box(w: float, h: float, d: float, m: Material, x := 0.0, y := 0.0, z := 0.0, ry := 0.0, p: Node3D = null) -> MeshInstance3D:
		var bm := BoxMesh.new(); bm.size = Vector3(w, h, d)
		var mi := put(bm, m, x, y, z, p)
		mi.rotation.y = ry
		return mi

	func cyl(rt: float, rb: float, h: float, m: Material, x := 0.0, y := 0.0, z := 0.0, seg := 20, p: Node3D = null) -> MeshInstance3D:
		var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 1
		return put(c, m, x, y, z, p)

	func cone(r: float, h: float, m: Material, x := 0.0, y := 0.0, z := 0.0, seg := 16, p: Node3D = null) -> MeshInstance3D:
		return cyl(0.0, r, h, m, x, y, z, seg, p)

	func sphere(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, seg := 18, p: Node3D = null) -> MeshInstance3D:
		var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = maxi(seg / 2, 6)
		return put(s, m, x, y, z, p)

	## Upper half sphere, its flat base at y.
	func dome(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, seg := 24, p: Node3D = null) -> MeshInstance3D:
		var s := SphereMesh.new(); s.radius = r; s.height = r; s.is_hemisphere = true; s.radial_segments = seg; s.rings = maxi(seg / 3, 6)
		return put(s, m, x, y, z, p)

	func torus(r: float, t: float, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null) -> MeshInstance3D:
		var tm := TorusMesh.new(); tm.inner_radius = r - t; tm.outer_radius = r + t; tm.rings = 32; tm.ring_segments = 8
		return put(tm, m, x, y, z, p)

	func prism(w: float, h: float, d: float, m: Material, x := 0.0, y := 0.0, z := 0.0, ry := 0.0, p: Node3D = null) -> MeshInstance3D:
		var pm := PrismMesh.new(); pm.size = Vector3(w, h, d)
		var mi := put(pm, m, x, y, z, p)
		mi.rotation.y = ry
		return mi

	func pivot(x: float, y: float, z: float, ry := 0.0, p: Node3D = null) -> Node3D:
		var n := Node3D.new(); n.position = Vector3(x, y, z); n.rotation.y = ry
		(p if p != null else g).add_child(n)
		return n

	## Gable roof with its eaves at y and ridge along local z (rotate with ry); `ends` fills the gable triangles.
	func gable(w: float, d: float, h: float, roof: Material, ends: Material, x: float, y: float, z: float, ry := 0.0, over := 0.45) -> void:
		var n := pivot(x, y, z, ry)
		var half := w * 0.5
		var ang := atan2(h, half)
		var slope := sqrt(half * half + h * h) + over
		for s in [-1.0, 1.0]:
			var b := box(slope, 0.28, d + over * 2.0, roof, s * half * 0.5, h * 0.5 + 0.14, 0, 0.0, n)
			b.rotation.z = -s * ang
		if ends != null:
			prism(w - 0.1, h - 0.05, d - 0.05, ends, 0, h * 0.5, 0, 0.0, n)

	## Hip (pyramid) roof over a w x d footprint, base at y.
	func hip(w: float, d: float, h: float, m: Material, x: float, y: float, z: float, p: Node3D = null) -> MeshInstance3D:
		var c := cyl(0.0, 0.70711, h, m, x, y + h * 0.5, z, 4, p)
		c.basis = Basis.from_scale(Vector3(w, 1, d)) * Basis(Vector3.UP, PI / 4)
		return c

	## A box facing outwards from a ring (windows, slits, merlons), centre (cx, cz), angle a from +z.
	func on_ring(cx: float, cz: float, r: float, a: float, y: float, w: float, h: float, d: float, m: Material, p: Node3D = null) -> MeshInstance3D:
		return box(w, h, d, m, cx + sin(a) * r, y, cz + cos(a) * r, a, p)

	func ring_merlons(cx: float, cz: float, r: float, y: float, count: int, w: float, h: float, m: Material) -> void:
		for i in count:
			on_ring(cx, cz, r, float(i) / count * TAU, y + h * 0.5, w, h, w * 0.8, m)

	## Merlons along a straight wall top from (x0,z0) to (x1,z1).
	func line_merlons(x0: float, z0: float, x1: float, z1: float, y: float, count: int, w: float, h: float, m: Material) -> void:
		var ry := atan2(x1 - x0, z1 - z0) + PI / 2
		for i in count:
			var t := (float(i) + 0.5) / count
			box(w, h, w * 0.8, m, lerpf(x0, x1, t), y + h * 0.5, lerpf(z0, z1, t), ry)

	## A straight crenellated wall from (x0,z0) to (x1,z1).
	func wall(x0: float, z0: float, x1: float, z1: float, h: float, t: float, m: Material, cren: Material) -> void:
		var len := Vector2(x1 - x0, z1 - z0).length()
		var ry := atan2(x1 - x0, z1 - z0) + PI / 2
		box(len, h, t, m, (x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5, ry)
		line_merlons(x0, z0, x1, z1, h, maxi(2, int(len / 2.6)), 1.3, 1.2, cren)

	## Onion dome sitting at y with a gold finial.
	func onion(r: float, m: Material, gold: Material, x: float, y: float, z: float) -> void:
		var s := sphere(r, m, x, y + r * 0.95, z, 16)
		s.scale = Vector3(1, 1.15, 1)
		cone(r * 0.45, r * 1.1, m, x, y + r * 2.3, z, 12)
		cyl(0.08 * r, 0.08 * r, r * 0.9, gold, x, y + r * 3.1, z, 6)
		sphere(r * 0.16, gold, x, y + r * 3.0, z, 8)

	func label(text: String, pos: Vector3, px: float, fg: Color, outline: Color, ry := 0.0) -> void:
		var s := Label3D.new()
		s.text = text
		s.font_size = 128; s.pixel_size = px; s.outline_size = 14
		s.modulate = fg; s.outline_modulate = outline
		s.position = pos; s.rotation.y = ry
		g.add_child(s)

	func light(color: Color, energy: float, rng: float, pos: Vector3) -> void:
		var o := OmniLight3D.new(); o.light_color = color; o.light_energy = energy; o.omni_range = rng; o.position = pos
		g.add_child(o)

	## Terrain height under a local point, in the landmark's local units (0 on a flattened site / in previews).
	func gy(lx: float, lz: float) -> float:
		if zone == null or not zone.has_method("height_at"):
			return 0.0
		var w := g.position + g.basis * Vector3(lx, 0, lz)
		return (float(zone.call("height_at", w.x, w.z)) - g.position.y) / maxf(g.scale.y, 0.01)

	func palm(x: float, z: float, h: float) -> void:
		var y := gy(x, z)
		var trunk := mat(0x8a6a48, {"rough": 0.9}); var leaf := mat(0x3f9a3a, {"rough": 0.85})
		var t := cyl(0.22, 0.35, h, trunk, x, y + h * 0.5, z, 8)
		t.rotation.z = 0.08
		for k in 6:
			var a := float(k) / 6.0 * TAU
			var f := box(3.6, 0.15, 0.9, leaf, x + sin(a) * 1.6 + h * 0.04, y + h - 0.2, z + cos(a) * 1.6)
			f.basis = Basis(Vector3.UP, a - PI / 2) * Basis(Vector3.BACK, -0.35)

	## Columnar cypress (the Lookout and Baaba's islands).
	func cypress(x: float, y: float, z: float, h: float) -> void:
		var dark := mat(0x2f6a2a, {"rough": 0.9}); var lite := mat(0x5aa03a, {"rough": 0.9})
		cyl(0.18, 0.25, 1.2, mat(0x6a4a2a), x, y + 0.6, z, 6)
		var c := sphere(h * 0.2, dark, x, y + 0.9 + h * 0.45, z, 12)
		c.scale = Vector3(1, 2.4, 1)
		var c2 := sphere(h * 0.14, lite, x + h * 0.05, y + 0.9 + h * 0.58, z + h * 0.05, 10)
		c2.scale = Vector3(1, 2.6, 1)

	func round_tree(x: float, z: float, r: float) -> void:
		var y := gy(x, z)
		cyl(r * 0.12, r * 0.18, r * 1.4, mat(0x6a4a2a), x, y + r * 0.7, z, 8)
		sphere(r, mat(0x3e8a34, {"rough": 0.9}), x, y + r * 1.9, z, 12)
		sphere(r * 0.7, mat(0x56a83e, {"rough": 0.9}), x + r * 0.5, y + r * 2.3, z + r * 0.3, 10)

	# ======================================================================================================
	## Kama House (kame_island): pink clapboard cottage, red gable roof with the lettering on the front gable, a
	## lower hip-roofed side wing with a dormer, porch awning over the green door, shutters, rooster weathervane,
	## beach chair and table. Footprint ~14 x 11 m (as the old kamehouse slab).
	func kamecottage() -> void:
		var pink := mat(0xf3b0c8, {"rough": 0.8}); var board := mat(0xe59ab6, {"rough": 0.85})
		var red := mat(0xd23028, {"rough": 0.5}); var white := mat(0xf6f0e6, {"rough": 0.7})
		var glass := mat(0x3a5ab8, {"rough": 0.15, "metal": 0.2}); var green := mat(0x3f8a5a, {"rough": 0.6})
		box(15, 0.3, 11, white, -1, 0.15, 0)
		# main block, front gable faces +z
		box(7, 4.0, 7, pink, 1, 2.3, 0)
		for i in 7:   # clapboard lines on the front and the right side
			box(7.05, 0.07, 0.05, board, 1, 0.75 + i * 0.5, 3.52)
			box(0.05, 0.07, 7.05, board, 4.52, 0.75 + i * 0.5, 0)
		gable(7.0, 7.0, 3.3, red, pink, 1, 4.3, 0)
		label("KAMA\nHOUSE", Vector3(1.0, 5.25, 3.62), 0.006, Color("#e0242a"), Color("#fbe3ea"))
		# side wing with a hip roof and a dormer
		box(4.6, 3.2, 6.0, pink, -4.8, 1.9, -0.4)
		hip(5.6, 7.0, 2.4, red, -4.8, 3.5, -0.4)
		box(1.7, 1.5, 1.6, pink, -4.8, 4.4, 1.4)
		gable(1.9, 1.9, 0.8, red, pink, -4.8, 5.15, 1.4)
		box(0.8, 0.9, 0.08, glass, -4.8, 4.4, 2.22)
		var wing_win := box(1.7, 1.3, 0.08, glass, -4.8, 2.0, 2.62)
		wing_win.name = "WingWindow"
		box(1.9, 0.12, 0.1, white, -4.8, 2.7, 2.64)
		# front window with white shutters
		box(1.8, 1.25, 0.08, mat(0x1e1e2a), 0.0, 2.3, 3.53)
		for sx in [-1.25, 1.25]:
			box(0.7, 1.35, 0.1, white, 0.0 + sx, 2.3, 3.55)
		# porch: deck, awning, posts, green door with a blue inner panel, steps
		box(3.6, 0.35, 2.6, white, 2.4, 0.48, 4.8)
		var awn := box(4.0, 0.18, 2.9, red, 2.4, 3.55, 4.9)
		awn.rotation.x = 0.22
		for px in [0.7, 4.1]:
			cyl(0.09, 0.09, 2.9, white, px, 2.1, 5.9, 8)
		box(1.4, 2.4, 0.1, green, 2.6, 1.85, 3.54)
		box(0.9, 1.9, 0.12, mat(0x4a6ad0, {"rough": 0.5}), 2.6, 1.75, 3.56)
		box(1.6, 0.2, 0.7, white, 0.0, 0.4, 5.6)
		# weathervane on the ridge
		cyl(0.05, 0.05, 1.6, mat(0x5a5a5a, {"metal": 0.6}), 1, 8.3, -2.2, 6)
		box(1.4, 0.06, 0.06, mat(0x5a5a5a, {"metal": 0.6}), 1, 8.6, -2.2)
		var rooster := sphere(0.32, white, 1, 9.25, -2.2, 10); rooster.scale = Vector3(1.4, 1, 0.5)
		sphere(0.16, white, 1.38, 9.55, -2.2, 8)
		cone(0.25, 0.4, white, 0.6, 9.45, -2.2, 6).rotation.z = 0.8
		if flag("trees"):
			# beach table and lounger beside the house
			cyl(0.7, 0.7, 0.08, white, -8.5, 1.0, 3.2, 14)
			cyl(0.05, 0.05, 0.7, white, -8.5, 0.65, 3.2, 6)
			var lounger := box(0.9, 0.12, 2.0, white, -6.6, 0.75, 4.2); lounger.rotation.x = 0.0
			var back := box(0.9, 0.9, 0.12, white, -6.6, 1.15, 3.25); back.rotation.x = -0.3
			for p in [Vector2(-8.6, -5.0), Vector2(6.5, -6.5), Vector2(8.6, 4.5)]:
				palm(p.x, p.y, 7.5)

	## Grandpa Gohin's cabin (mt_paozu): rectangular wooden cabin on a stone footing, brown gable roof, round
	## doorway, red diamond charms, a hanging lantern, chimney, woodpile and stepping stones.
	func paozucabin() -> void:
		var wood := mat(0x9a6a3e, {"rough": 0.9}); var plank := mat(0x6e4626, {"rough": 0.9})
		var roof := mat(0x8a4a2a, {"rough": 0.8}); var stone := mat(0x9a948a, {"rough": 0.9})
		var red := mat(0xc8282a, {"rough": 0.5}); var gold := mat(0xe0b040, {"metal": 0.5, "rough": 0.35})
		var dark := mat(0x22180e)
		box(9.2, 0.6, 7.2, stone, 0, 0.3, 0)
		box(8.0, 3.2, 6.0, wood, 0, 2.2, 0)
		for i in 9:   # vertical planks
			box(0.08, 3.2, 0.05, plank, -3.6 + i * 0.9, 2.2, 3.02)
		for sx in [-1.0, 1.0]:   # corner posts
			for sz in [-1.0, 1.0]:
				box(0.35, 3.4, 0.35, plank, sx * 4.0, 2.3, sz * 3.0)
		gable(6.0, 8.0, 2.6, roof, wood, 0, 3.8, 0, PI / 2, 0.6)
		# round doorway with a wooden ring and curtain
		var door := cyl(1.05, 1.05, 0.12, dark, 0, 1.95, 3.04, 20); door.rotation.x = PI / 2
		var ring := torus(1.12, 0.12, plank, 0, 1.95, 3.1); ring.rotation.x = PI / 2
		box(1.6, 0.9, 0.1, mat(0x3a6ab0, {"rough": 0.8}), 0, 2.55, 3.12)
		# diamond charms and windows either side
		for sx in [-1.0, 1.0]:
			var dmd := box(0.9, 0.9, 0.08, red, sx * 2.3, 2.6, 3.06); dmd.rotation.z = PI / 4
			var inner := box(0.45, 0.45, 0.1, gold, sx * 2.3, 2.6, 3.08); inner.rotation.z = PI / 4
			box(1.2, 0.8, 0.08, dark, sx * 4.02, 2.4, 0, PI / 2)
		# hanging lantern, chimney
		cyl(0.02, 0.02, 0.6, dark, 2.6, 3.6, 3.7, 4)
		var lan := sphere(0.32, mat(0xe8402a, {"emissive": 0xa02010, "glow": 0.6}), 2.6, 3.15, 3.7, 10); lan.scale = Vector3(1, 1.3, 1)
		box(0.9, 2.4, 0.9, stone, -2.4, 5.6, -1.2)
		if flag("trees"):
			for i in 6:   # woodpile
				var lg := cyl(0.22, 0.22, 2.4, plank, 5.4, 0.25 + (i % 3) * 0.42, -1.0 + (i / 3) * 0.5, 8); lg.rotation.x = PI / 2
			for i in 6:   # stepping stones to the door
				cyl(0.7, 0.7, 0.12, mat(0xa09a90), 0, gy(0, 5.0 + i * 1.6) + 0.06, 5.0 + i * 1.6, 10)

	## Gokan's later home (optional, mt_paozu): cream capsule dome core with red diamond emblem and a long blue window,
	## two gabled timber wings on stone footings, chimneys.
	func paozuhome() -> void:
		var cream := mat(0xf0deb0, {"rough": 0.6}); var wood := mat(0x9a6a3e, {"rough": 0.9}); var roof := mat(0xa0582e, {"rough": 0.8})
		var stone := mat(0xb4ab98, {"rough": 0.9}); var red := mat(0xc8282a); var glass := mat(0x5a7ad0, {"rough": 0.15})
		var steel := mat(0x8a929e, {"metal": 0.6, "rough": 0.4})
		var core := dome(4.6, cream, 0, 0, 0.6); core.scale = Vector3(1, 0.95, 1)
		box(4.2, 0.9, 0.3, glass, 0, 1.4, 4.85).rotation.x = -0.2
		var dm := box(1.3, 1.3, 0.1, red, 0, 3.0, 4.05); dm.rotation = Vector3(-0.75, 0, PI / 4)
		cyl(0.5, 0.5, 1.4, steel, 0, 4.8, 0.6, 12)
		cyl(0.65, 0.65, 0.3, steel, 0, 5.6, 0.6, 12)
		for sx in [-1.0, 1.0]:
			var x: float = sx * 6.2
			box(4.8, 1.6, 5.4, stone, x, 0.8, 0)
			box(4.8, 2.2, 5.4, wood, x, 2.7, 0)
			gable(4.8, 5.4, 2.0, roof, wood, x, 3.8, 0)
			box(1.1, 1.1, 0.1, red, x, 4.4, 2.72).rotation.z = PI / 4
			box(1.4, 1.2, 0.1, glass, x - sx * 0.8, 1.8, 2.72)
			box(0.7, 1.2, 0.7, mat(0xd8d2c4), x + sx * 1.2, 6.0, -1.0)

	## The Ox-Lord's castle (fire_mountain): crenellated square curtain wall with four round corner turrets and cone
	## caps, a gatehouse, a pale keep with a hip roof and dormers, a gabled side hall, wrapped in a ring of animated
	## flame tongues. Footprint 34 x 34 m (request collide 17).
	func firekeep() -> void:
		var stone := mat(0xa49a8c, {"rough": 0.9}); var cren := mat(0x8e8478, {"rough": 0.9})
		var keep_m := mat(0xe6ddc8, {"rough": 0.8}); var slate := mat(0x3a3f56, {"rough": 0.55})
		var dark := mat(0x1e1a1a); var gold := mat(0xd8a733, {"metal": 0.7, "rough": 0.3})
		cyl(22.0, 25.0, 1.6, mat(0x6a5e52, {"rough": 0.9}), 0, 0.3, 0, 24)   # scorched rock footing
		const H := 15.0
		var c := [Vector2(-H, -H), Vector2(H, -H), Vector2(H, H), Vector2(-H, H)]
		for i in 4:
			var a: Vector2 = c[i]; var b2: Vector2 = c[(i + 1) % 4]
			if i == 2:   # front wall: split round the gate
				wall(a.x, a.y, 3.5, b2.y, 7.0, 1.6, stone, cren)
				wall(-3.5, a.y, b2.x, b2.y, 7.0, 1.6, stone, cren)
			else:
				wall(a.x, a.y, b2.x, b2.y, 7.0, 1.6, stone, cren)
		for p: Vector2 in c:   # corner turrets
			cyl(3.2, 3.4, 13.0, stone, p.x, 6.5, p.y, 18)
			cyl(3.6, 3.6, 0.6, cren, p.x, 13.2, p.y, 18)
			cone(4.1, 6.5, slate, p.x, 16.75, p.y, 18)
			cyl(0.12, 0.12, 3.0, gold, p.x, 21.2, p.y, 6)
			for k in 3:
				on_ring(p.x, p.y, 3.25, float(k) * 2.1 + 0.4, 10.0, 0.7, 1.4, 0.2, dark)
		# gatehouse: arch flanked by two small turrets
		box(7.0, 9.0, 3.0, stone, 0, 4.5, H)
		box(4.0, 5.0, 0.3, dark, 0, 2.5, H + 1.55)
		var arch := cyl(2.0, 2.0, 0.3, dark, 0, 5.0, H + 1.55, 16); arch.rotation.x = PI / 2
		line_merlons(-3.5, H, 3.5, H, 9.0, 3, 1.3, 1.2, cren)
		for sx in [-1.0, 1.0]:
			cyl(1.5, 1.6, 11.0, stone, sx * 4.2, 5.5, H + 0.6, 14)
			cone(1.9, 4.0, slate, sx * 4.2, 13.0, H + 0.6, 14)
		# the keep and its roof with dormers
		box(18.0, 10.0, 14.0, keep_m, -1.5, 5.0, -2.0)
		hip(19.5, 15.5, 6.0, slate, -1.5, 10.0, -2.0)
		for k in 3:
			var dx := -7.0 + k * 5.5
			box(2.4, 2.8, 2.0, keep_m, dx, 11.8, 4.4)
			gable(2.6, 2.4, 1.3, slate, keep_m, dx, 13.2, 4.4)
			box(1.2, 1.8, 0.1, dark, dx, 11.8, 5.42)
		for row in 2:   # window rows on the keep front
			for k in 7:
				box(0.9, 1.5, 0.1, dark, -9.0 + k * 2.5, 3.0 + row * 3.6, 5.03)
		box(7.0, 11.0, 10.0, keep_m, 9.0, 5.5, -0.5)   # gabled side hall
		gable(7.0, 10.6, 3.2, slate, keep_m, 9.0, 11.0, -0.5)
		box(1.8, 3.2, 0.2, dark, 9.0, 1.6, 4.55)
		# ring of fire round the castle (animated tongues of three stacked cones each)
		var fl := flame_mat(0.0, 12.0)
		no_shadow.append(fl)
		for i in 30:
			var a := float(i) / 30.0 * TAU
			var r := 23.5 + float(i % 3) * 1.3
			var x := sin(a) * r; var z := cos(a) * r
			var hh := 7.0 + float((i * 7) % 5) * 1.6
			var y0 := gy(x, z)
			cone(2.4, hh, fl, x, y0 + hh * 0.5, z, 8)
			cone(1.6, hh * 0.75, fl, x + sin(a + 1.2) * 1.4, y0 + hh * 0.5, z + cos(a + 1.2) * 1.4, 8)
			cone(1.2, hh * 1.15, fl, x - sin(a + 0.6) * 1.0, y0 + hh * 0.55, z - cos(a + 0.6) * 1.0, 8)
		light(Color(1.0, 0.5, 0.15), 3.0, 70.0, Vector3(0, 14, 0))

	## Emperor Pilav's palace (pilav_castle): three-tier stepped pyramid base with a grand central stair, an arcade
	## band, the palace block with a big central dome (radar dish on top), four corner domes and six minarets with
	## onion caps; giant mushroom trees round the site. Base 50 x 42 m, top terrace 17 m up (request collide 23).
	func pilavpalace() -> void:
		var sand := mat(0xe2cfa0, {"rough": 0.85}); var wall_m := mat(0xf0e4c4, {"rough": 0.75})
		var dome_m := mat(0x3f9a86, {"rough": 0.4, "metal": 0.2}); var gold := mat(0xd8a733, {"metal": 0.7, "rough": 0.3})
		var dark := mat(0x2a2218); var steel := mat(0xb8bcc4, {"metal": 0.7, "rough": 0.35})
		var tiers := [[50.0, 42.0, 6.0], [42.0, 34.0, 6.0], [34.0, 26.0, 5.0]]
		var y := 0.0
		for t: Array in tiers:
			var tw: float = t[0]; var td: float = t[1]; var th: float = t[2]
			box(tw, th, td, sand, 0, y + th * 0.5, 0)
			box(tw + 0.6, 0.4, td + 0.6, wall_m, 0, y + th - 0.2, 0)
			y += th
		# grand stair up the front (+z) from the ground to the terrace, with a dark gate under it
		for i in 24:
			var sh := y * float(i + 1) / 24.0
			box(10.0, sh, 1.0, sand, 0, sh * 0.5, 36.5 - float(i))
		box(4.0, 4.0, 0.3, dark, -8.0, 2.0, 21.16); box(4.0, 4.0, 0.3, dark, 8.0, 2.0, 21.16)
		for k in 14:   # arcade band round the top tier
			box(1.2, 2.0, 0.2, dark, -15.6 + k * 2.4, 14.2, 13.06)
			box(1.2, 2.0, 0.2, dark, -15.6 + k * 2.4, 14.2, -13.06)
		# the palace on the terrace
		var t0 := y
		box(30.0, 8.0, 22.0, wall_m, 0, t0 + 4.0, -1.0)
		for k in 10:
			box(1.2, 1.6, 0.15, dark, -12.6 + k * 2.8, t0 + 3.0, 10.08)
		box(18.0, 6.0, 14.0, wall_m, 0, t0 + 11.0, -1.0)
		cyl(8.0, 8.0, 3.0, wall_m, 0, t0 + 15.5, -1.0, 28)
		for k in 12:
			on_ring(0, -1.0, 8.0, float(k) / 12.0 * TAU, t0 + 15.5, 0.9, 1.4, 0.2, dark)
		dome(8.0, dome_m, 0, t0 + 17.0, -1.0, 28)
		# radar dish on the dome
		box(3.0, 1.2, 3.0, steel, 0, t0 + 25.4, -1.0)
		var dish := dome(2.6, steel, 0.6, t0 + 27.8, -1.0, 18); dish.rotation = Vector3(0.0, 0.0, -2.2)
		cyl(0.08, 0.08, 2.2, steel, 0.4, t0 + 27.3, -1.0, 6).rotation.z = 0.95
		for p in [Vector2(-10, -9), Vector2(10, -9), Vector2(-10, 7), Vector2(10, 7)]:   # corner domes
			box(6.0, 5.0, 6.0, wall_m, p.x, t0 + 10.5, p.y)
			dome(3.4, dome_m, p.x, t0 + 13.0, p.y, 18)
			cyl(0.07, 0.07, 1.8, gold, p.x, t0 + 17.2, p.y, 6)
		for p in [Vector2(-15.5, -11.5), Vector2(15.5, -11.5), Vector2(-15.5, 11.5), Vector2(15.5, 11.5), Vector2(-6.5, 11.5), Vector2(6.5, 11.5)]:
			var mh := 20.0 if absf(p.x) > 10.0 else 15.0
			cyl(1.1, 1.3, mh, wall_m, p.x, t0 + mh * 0.5, p.y, 12)
			cyl(1.7, 1.5, 0.9, wall_m, p.x, t0 + mh * 0.62, p.y, 12)
			cyl(1.6, 1.6, 0.6, wall_m, p.x, t0 + mh, p.y, 12)
			for k in 4:
				on_ring(p.x, p.y, 1.12, float(k) * PI / 2, t0 + mh - 1.4, 0.35, 1.2, 0.15, dark)
			onion(1.3, dome_m, gold, p.x, t0 + mh + 0.3, p.y)
		if flag("trees"):   # giant desert mushroom trees
			var stem := mat(0xeadfc8, {"rough": 0.8}); var cap := mat(0xd8c49a, {"rough": 0.7}); var gill := mat(0xa8906a)
			for p in [Vector3(-40, 8, 16.0), Vector3(42, -4, 13.0), Vector3(-34, 34, 10.0), Vector3(36, 30, 15.0), Vector3(-46, -18, 9.0), Vector3(48, -28, 11.0)]:
				var gy0 := gy(p.x, p.y)
				var hh: float = p.z
				cyl(0.9, 1.4, hh, stem, p.x, gy0 + hh * 0.5, p.y, 10)
				var cp := sphere(hh * 0.42, cap, p.x, gy0 + hh, p.y, 18); cp.scale = Vector3(1, 0.32, 1)
				var gl := cyl(hh * 0.4, hh * 0.15, 0.6, gill, p.x, gy0 + hh - 0.3, p.y, 18)
				gl.name = "Gill"

	## Muscle Tower (muscle_tower): tapered brick tower on a wide crenellated skirt drum, slit windows, an overhanging
	## battlemented top with gun turrets and a radar dish, arched wooden door. ~44 m tall (request collide 13).
	func musclefort() -> void:
		var brick := mat(0xb04a32, {"rough": 0.85, "tile": 0.5}); var trim := mat(0x8e3422, {"rough": 0.9})
		var glass := mat(0x3a62d8, {"rough": 0.15, "metal": 0.2, "emissive": 0x0a1a50, "glow": 0.3})
		var steel := mat(0x9aa2ac, {"metal": 0.7, "rough": 0.35}); var wood := mat(0x7a5a3a, {"rough": 0.9})
		# skirt drum with battlements and its own turrets
		cyl(13.0, 13.4, 7.0, brick, 0, 3.5, 0, 32)
		cyl(13.5, 13.5, 0.5, trim, 0, 7.2, 0, 32)
		ring_merlons(0, 0, 13.0, 7.4, 22, 2.0, 1.3, brick)
		for k in 5:
			var a := 0.75 + float(k) * 1.1
			on_ring(0, 0, 13.25, a, 3.0, 4.0, 0.9, 0.25, glass)
		# tapered shaft with slit windows and bolts
		cyl(6.2, 8.6, 27.0, brick, 0, 7.0 + 13.5, 0, 28)
		for i in 9:   # brick courses
			var cy := 8.5 + float(i) * 3.0
			var cr := 8.6 - 2.4 * (cy - 7.0) / 27.0 + 0.03
			cyl(cr, cr, 0.14, trim, 0, cy, 0, 28)
		for row in 4:
			for k in 3:
				var a := float(k) * TAU / 3.0 + float(row) * 0.9
				var wy := 11.0 + row * 5.5
				var r := 8.6 - 2.4 * (wy - 7.0) / 27.0
				on_ring(0, 0, r + 0.05, a, wy, 3.0, 0.75, 0.3, glass)
				var bolt := sphere(0.35, trim, sin(a + 0.8) * r, wy + 2.0, cos(a + 0.8) * r, 8)
				bolt.name = "Bolt"
		# flared overhang and the top drum
		cyl(9.4, 6.2, 3.0, brick, 0, 35.5, 0, 28)
		cyl(9.4, 9.4, 5.0, brick, 0, 39.5, 0, 28)
		for k in 4:
			on_ring(0, 0, 9.5, float(k) * PI / 2 + 0.4, 39.8, 4.0, 0.8, 0.25, glass)
		cyl(9.8, 9.8, 0.4, trim, 0, 42.2, 0, 28)
		ring_merlons(0, 0, 9.3, 42.4, 16, 1.8, 1.1, brick)
		for k in 3:   # gun turrets on the battlement and the skirt
			var a := float(k) * TAU / 3.0 + 0.3
			var tx := sin(a) * 7.0; var tz := cos(a) * 7.0
			box(1.6, 1.0, 1.6, steel, tx, 43.0, tz)
			var gun := cyl(0.18, 0.18, 2.6, steel, tx + sin(a) * 1.4, 43.4, tz + cos(a) * 1.4, 8)
			gun.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2 - 0.25)
			var sa := a + 0.9
			box(1.4, 0.9, 1.4, steel, sin(sa) * 11.5, 8.0, cos(sa) * 11.5)
			var g2 := cyl(0.15, 0.15, 2.2, steel, sin(sa) * 12.7, 8.3, cos(sa) * 12.7, 8)
			g2.basis = Basis(Vector3.UP, sa) * Basis(Vector3.RIGHT, PI / 2 - 0.2)
		box(1.6, 1.4, 1.6, steel, -4.5, 43.2, -4.5)   # radar dish
		var dish := dome(2.2, steel, -4.5, 45.4, -4.5, 16); dish.rotation = Vector3(-2.3, 0.6, 0.0)
		# arched wooden door
		box(3.4, 3.8, 0.4, wood, 0, 1.9, 13.15)
		var top := cyl(1.7, 1.7, 0.4, wood, 0, 3.8, 13.15, 16); top.rotation.x = PI / 2
		box(4.2, 0.4, 0.5, trim, 0, 5.85, 13.2)

	## Korrin Tower (korrin_tower): slender carved sandstone shaft (ornamental bands every 8 m, capitals every 40 m)
	## rising 400 m to a wide saucer house with a windowed rim and round underside; a tepee camp at the foot and an
	## optional cloud collar half way up. Base plinth r 9 (request collide 7).
	func korrinspire() -> void:
		var sand := mat(0xdccca4, {"rough": 0.8, "tile": 0.5}); var carve := mat(0xc4b088, {"rough": 0.85, "tile": 0.5})
		var cream := mat(0xeee4c8, {"rough": 0.6}); var shade := mat(0xcfc3a3, {"rough": 0.7}); var dark := mat(0x4a4a44)
		cyl(7.5, 9.0, 4.0, carve, 0, 2.0, 0, 16)
		cyl(5.0, 6.0, 4.0, sand, 0, 6.0, 0, 16)
		cyl(2.7, 3.0, 392.0, sand, 0, 8.0 + 196.0, 0, 12)
		var y := 12.0
		while y < 396.0:
			cyl(3.3, 3.3, 0.9, carve, 0, y, 0, 12)
			for k in 4:
				on_ring(0, 0, 2.9, float(k) * PI / 2 + PI / 4, y + 3.0, 1.0, 3.2, 0.5, carve)
			if int(y - 12.0) % 40 == 0:
				cyl(3.9, 3.4, 1.6, carve, 0, y + 5.5, 0, 12)
			y += 8.0
		# the saucer house
		const T := 400.0
		cyl(4.0, 3.0, 4.0, carve, 0, T + 1.0, 0, 16)
		var under := sphere(15.0, shade, 0, T + 5.0, 0, 32); under.scale = Vector3(1, 0.26, 1)
		for k in 4:   # round openings under the saucer
			var a := float(k) * PI / 2
			cyl(1.3, 1.3, 0.3, dark, sin(a) * 5.0, T + 1.25, cos(a) * 5.0, 12)
		cyl(15.2, 15.2, 3.0, cream, 0, T + 6.0, 0, 36)
		for k in 14:
			on_ring(0, 0, 15.15, float(k) / 14.0 * TAU, T + 6.0, 3.6, 1.2, 0.3, dark)
		var top := sphere(14.0, cream, 0, T + 7.5, 0, 32); top.scale = Vector3(1, 0.22, 1)
		cyl(3.0, 3.6, 1.6, cream, 0, T + 10.6, 0, 16)
		cone(0.6, 2.0, cream, 0, T + 12.4, 0, 8)
		if flag("trees"):   # tepee camp at the foot
			var hide := mat(0xe8dcc0, {"rough": 0.9}); var band := mat(0xb0402a); var pole := mat(0x6a4a2a)
			for p in [Vector2(-20, 16), Vector2(-27, 27), Vector2(19, 21), Vector2(28, 31), Vector2(-6, 34)]:
				var ty := gy(p.x, p.y)
				cone(2.6, 5.2, hide, p.x, ty + 2.6, p.y, 9)
				cyl(1.62, 1.95, 0.5, band, p.x, ty + 1.9, p.y, 9)
				cone(0.5, 1.6, pole, p.x, ty + 5.6, p.y, 5)
				box(1.0, 1.6, 0.1, mat(0x3a2a1a), p.x, ty + 0.8, p.y + 2.05)
		if flag("clouds"):   # a cloud collar crossing the shaft
			var cloud := mat(0xffffff, {"rough": 1.0, "unshaded": true})
			no_shadow.append(cloud)
			for i in 16:
				var a := float(i) * 2.399
				var r := 14.0 + float(i % 5) * 7.0
				var puff := sphere(9.0 + float(i % 4) * 3.0, cloud, sin(a) * r, 150.0 + float(i % 3) * 5.0, cos(a) * r, 14)
				puff.scale = Vector3(1.6, 0.55, 1.2)

	## Kamu's Lookout (kamu_lookout): the same 40 m tiled disc and underside dome as before, with the palace rebuilt:
	## a round hall under a big GOLD dome with a windowed upper drum and gold cupola, a white side cupola tower,
	## magenta barrel-vault wings with glass fronts, rows of columnar cypress, saucer lamp-posts on thin stalks.
	func lookoutpalace() -> void:
		var tile := mat(0xf4f2ec, {"rough": 0.4}); var seam := mat(0xc8d0dc, {"rough": 0.5}); var white := mat(0xf8f6f0, {"rough": 0.55})
		var gold := mat(0xe8b830, {"metal": 0.55, "rough": 0.3}); var pink := mat(0xd8409a, {"rough": 0.45})
		var glass := mat(0x5a8ad8, {"rough": 0.1, "metal": 0.2}); var blue := mat(0x3a6ac8, {"rough": 0.4})
		cyl(40, 40, 1.0, tile, 0, -0.5, 0, 48)
		var under := dome(40, mat(0xd8d2c4, {"rough": 0.7}), 0, -1.0, 0, 40); under.rotation.x = PI
		for i in range(-36, 37, 6):   # tile seams
			var half := sqrt(maxf(0.0, 40.0 * 40.0 - float(i * i))) - 0.5
			box(half * 2.0, 0.03, 0.12, seam, 0, 0.01, i)
			box(0.12, 0.03, half * 2.0, seam, i, 0.01, 0)
		const PZ := 16.0
		# central hall, gold dome, upper drum and cupola
		cyl(9.0, 9.0, 6.0, white, 0, 3.0, PZ, 36)
		for k in 16:
			on_ring(0, PZ, 9.0, float(k) / 16.0 * TAU, 3.4, 1.4, 3.6, 0.2, glass)
		cyl(9.6, 9.6, 0.5, white, 0, 6.2, PZ, 36)
		var gd := dome(9.6, gold, 0, 6.4, PZ, 32); gd.scale = Vector3(1, 0.55, 1)
		cyl(5.0, 5.2, 3.4, white, 0, 13.4, PZ, 28)
		for k in 10:
			on_ring(0, PZ, 5.05, float(k) / 10.0 * TAU, 13.4, 1.0, 2.2, 0.2, glass)
		cyl(5.6, 5.6, 0.4, gold, 0, 15.2, PZ, 28)
		var cup := dome(4.4, gold, 0, 15.4, PZ, 24); cup.scale = Vector3(1, 0.75, 1)
		cyl(1.0, 1.0, 1.6, white, 0, 19.4, PZ, 12)
		dome(1.1, gold, 0, 20.2, PZ, 12)
		# white cupola tower behind on the left
		cyl(3.4, 3.4, 9.0, white, -11.0, 4.5, PZ + 8.0, 20)
		for k in 8:
			on_ring(-11.0, PZ + 8.0, 3.45, float(k) / 8.0 * TAU, 7.5, 0.8, 1.6, 0.2, glass)
		cyl(4.0, 4.0, 0.4, blue, -11.0, 9.2, PZ + 8.0, 20)
		dome(3.6, white, -11.0, 9.4, PZ + 8.0, 20)
		cyl(0.6, 0.6, 1.2, gold, -11.0, 13.4, PZ + 8.0, 10)
		# magenta barrel-vault wings either side
		for s in [-1.0, 1.0]:
			var wx: float = s * 15.0
			box(11.0, 4.6, 7.0, white, wx, 2.3, PZ)
			var vault := cyl(3.5, 3.5, 11.0, pink, wx, 4.6, PZ, 20); vault.rotation.z = PI / 2
			for e in [-1.0, 1.0]:
				var rim := torus(3.45, 0.18, gold, wx + e * 5.55, 4.6, PZ); rim.rotation.z = PI / 2
			for k in 4:   # glass front with white columns
				box(2.0, 3.4, 0.15, glass, wx - 3.9 + k * 2.6, 2.0, PZ + 3.52)
				cyl(0.25, 0.25, 4.6, white, wx - 5.2 + k * 2.6, 2.3, PZ + 3.7, 8)
		# rows of cypress and the saucer lamp-posts
		for k in 9:
			var cx := -24.0 + k * 6.0
			if absf(cx) < 5.0:
				continue
			cypress(cx, 0.0, PZ - 7.5, 9.0)
		for p in [Vector2(-28, 10), Vector2(28, 10), Vector2(-30, 20), Vector2(30, 20), Vector2(-24, 28), Vector2(24, 28)]:
			cypress(p.x, 0.0, p.y, 9.5)
		for p in [Vector2(-30, -16), Vector2(30, -16), Vector2(-34, 2), Vector2(34, 2), Vector2(-12, -32), Vector2(12, -32)]:
			cyl(0.2, 0.3, 14.0, white, p.x, 7.0, p.y, 8)
			cyl(2.2, 1.6, 0.6, white, p.x, 14.2, p.y, 16)
			cyl(2.25, 2.25, 0.2, blue, p.x, 14.0, p.y, 16)
			dome(0.9, white, p.x, 14.5, p.y, 12)
		box(9, 0.1, 8, mat(0x4a9a3a, {"rough": 0.9}), -12, 0.05, -2)   # garden patch

	## Fortuneteller Baaba's palace (baaba_palace): lake with square stone islands joined by causeways. The domed
	## palace with a lantern cupola sits on the centre island (landmark origin, request collide 8); the big ROUND tiled
	## arena lies out front over the water (centre local z -27, r 26 - spans the fight spots); pyramid islands with
	## cypress on both sides; an igloo-like dome hut on the shore. Request flatten 56.
	func baabaisle() -> void:
		var water := mat(0x3a8ac8, {"rough": 0.08, "metal": 0.2}); var slab := mat(0xd8d0c0, {"rough": 0.8})
		var tile := mat(0xe8e2d4, {"rough": 0.7}); var seam := mat(0x9a9284); var pink := mat(0xe4a6c0, {"rough": 0.6})
		var stone := mat(0xb8ae9a, {"rough": 0.9}); var dark := mat(0x2a2028); var gold := mat(0xd8a733, {"metal": 0.6, "rough": 0.3})
		no_shadow.append(water)
		cyl(54.0, 54.0, 0.2, water, 0, 0.06, -6.0, 48)
		# round arena with a stepped rim and tile grid
		const AZ := -27.0
		cyl(26.6, 27.0, 0.2, slab, 0, 0.1, AZ, 48)
		cyl(25.0, 25.0, 0.2, tile, 0, 0.2, AZ, 48)
		for i in range(-22, 23, 4):
			var half := sqrt(maxf(0.0, 25.0 * 25.0 - float(i * i))) - 0.3
			box(half * 2.0, 0.03, 0.12, seam, 0, 0.31, AZ + i)
			box(0.12, 0.03, half * 2.0, seam, i, 0.31, AZ)
		# causeways: arena -> palace, palace -> side islands, palace -> shore
		box(3.0, 0.4, 8.0, slab, 0, 0.2, -4.0)
		box(16.0, 0.4, 3.0, slab, -18.0, 0.2, 2.0); box(16.0, 0.4, 3.0, slab, 18.0, 0.2, 2.0)
		box(3.0, 0.4, 16.0, slab, 0, 0.2, 18.0)
		# centre island and the domed palace with a lantern cupola
		box(16.0, 0.6, 16.0, slab, 0, 0.3, 2.0)
		cyl(7.0, 7.4, 4.0, pink, 0, 2.6, 2.0, 28)
		for k in 5:
			on_ring(0, 2.0, 7.2, -0.9 + float(k) * 0.45, 2.6, 1.6, 0.7, 0.2, dark)
		box(1.4, 2.4, 0.4, dark, 0, 1.8, 9.2)
		var dm := dome(7.2, pink, 0, 4.6, 2.0, 28); dm.scale = Vector3(1, 0.75, 1)
		cyl(2.6, 2.6, 2.6, mat(0xf4f0ea), 0, 11.0, 2.0, 16)
		for k in 8:
			on_ring(0, 2.0, 2.62, float(k) / 8.0 * TAU, 11.0, 0.5, 1.4, 0.15, dark)
		torus(3.0, 0.12, gold, 0, 10.4, 2.0)
		dome(2.8, pink, 0, 12.3, 2.0, 16)
		cone(0.25, 3.0, gold, 0, 15.6, 2.0, 8)
		if flag("trees"):
			for p in [Vector2(-5.5, 7.5), Vector2(5.5, 7.5), Vector2(-6, -3.5), Vector2(6, -3.5)]:
				var t := sphere(1.9, mat(0x4a8a3a, {"rough": 0.9}), p.x, 3.4, p.y, 12); t.scale = Vector3(1, 1.3, 1)
				cyl(0.2, 0.25, 1.6, mat(0x6a4a2a), p.x, 1.4, p.y, 6)
		# pyramid islands with cypress
		for s in [-1.0, 1.0]:
			var ix: float = s * 32.0
			box(14.0, 0.6, 14.0, slab, ix, 0.3, 2.0)
			var pyr := hip(7.0, 7.0, 7.5, stone, ix, 0.6, 2.0)
			pyr.name = "Pyramid"
			if flag("trees"):
				for p in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5), Vector2(0, -5.5)]:
					cypress(ix + p.x, 0.6, 2.0 + p.y, 6.0)
		# igloo-like dome hut on the shore behind
		var hz := 32.0
		var hy := gy(0, hz)
		var igloo := dome(4.0, mat(0xece6da, {"rough": 0.8}), 10.0, hy, hz, 18); igloo.name = "Igloo"
		box(1.3, 1.8, 1.6, mat(0xece6da), 10.0, hy + 0.9, hz + 4.0)
		box(0.9, 1.4, 0.1, dark, 10.0, hy + 0.7, hz + 4.82)

	## King Castle (piccor_castle): the bright royal palace - a giant rounded dome with the arched portal and face
	## fountains, a tall tiered tower ringed by radiating spikes, domed side towers, garden trees and lawn.
	## Dome r 20 (request collide 19).
	func kingcastle() -> void:
		var cream := mat(0xf0d6b0, {"rough": 0.7}); var shade := mat(0xd8b88e, {"rough": 0.75})
		var roof := mat(0x7a8aa8, {"rough": 0.5, "metal": 0.15}); var gold := mat(0xd8a733, {"metal": 0.7, "rough": 0.3})
		var dark := mat(0x2a2430); var water := mat(0x9ad8ff, {"opacity": 0.75, "rough": 0.05, "emissive": 0x2a6a9a, "glow": 0.4})
		no_shadow.append(water)
		if flag("lawn"):
			cyl(36.0, 36.0, 0.1, mat(0x5aa03e, {"rough": 0.95}), 0, 0.05, 4.0, 40)
			box(6.0, 0.06, 18.0, mat(0xd8ccb0, {"rough": 0.8}), 0, 0.11, 30.0)
		var main := dome(20.0, cream, 0, 0, 0, 40); main.scale = Vector3(1, 0.72, 1)
		torus(20.0, 0.5, shade, 0, 0.4, 0)
		# arched portal on the front
		box(9.0, 9.0, 5.0, cream, 0, 4.5, 17.0)
		box(5.0, 5.5, 0.3, dark, 0, 2.75, 19.55)
		var arch := cyl(2.5, 2.5, 0.3, dark, 0, 5.5, 19.55, 18); arch.rotation.x = PI / 2
		var hood := cyl(4.6, 4.6, 5.2, cream, 0, 9.0, 17.0, 20); hood.rotation.x = PI / 2
		hood.scale = Vector3(1, 1, 0.55)
		# face medallion with a fountain arcing down to a basin
		var med := cyl(1.8, 1.8, 0.5, shade, 0, 10.8, 13.9, 18); med.rotation.x = PI / 2 - 0.75
		sphere(0.9, gold, 0, 10.9, 14.3, 10)
		for i in 12:
			var t := float(i) / 11.0
			sphere(0.8 - t * 0.25, water, 0, 10.4 - t * t * 9.6, 14.8 + t * 13.0, 8)
		cyl(4.0, 4.4, 1.0, shade, 0, 0.5, 28.0, 24)
		cyl(3.6, 3.6, 0.2, water, 0, 0.95, 28.0, 24)
		for s in [-1.0, 1.0]:   # garden fountains
			cyl(2.6, 3.0, 0.9, shade, s * 11.0, 0.45, 25.0, 18)
			cyl(0.35, 0.6, 6.0, water, s * 11.0, 3.6, 25.0, 10)
			sphere(1.1, water, s * 11.0, 6.8, 25.0, 10)
		# tiered central tower with the spike crown
		cyl(9.0, 10.0, 6.0, cream, 0, 15.0, 0, 32)
		for k in 18:
			on_ring(0, 0, 9.5, float(k) / 18.0 * TAU, 15.2, 1.0, 2.4, 0.2, dark)
		torus(10.0, 0.35, shade, 0, 18.1, 0)
		cyl(6.4, 8.4, 6.0, cream, 0, 21.0, 0, 32)
		box(3.0, 3.6, 0.3, dark, 0, 21.0, 7.4).rotation.x = -0.32
		cyl(8.6, 8.0, 1.2, shade, 0, 24.6, 0, 32)
		cyl(6.0, 6.2, 5.0, cream, 0, 27.7, 0, 28)
		for k in 8:
			on_ring(0, 0, 6.05, float(k) / 8.0 * TAU, 27.4, 1.6, 0.6, 0.2, dark)
		dome(6.0, shade, 0, 30.2, 0, 28)
		for k in 12:   # radiating spikes
			var a := float(k) / 12.0 * TAU
			var sp := cyl(0.12, 0.28, 10.0, gold, sin(a) * 9.0, 30.0, cos(a) * 9.0, 6)
			sp.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2 - 0.45)
		for k in 6:
			var a := float(k) / 6.0 * TAU + 0.26
			var sp := cyl(0.1, 0.22, 7.0, gold, sin(a) * 5.0, 34.5, cos(a) * 5.0, 6)
			sp.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.55)
		cyl(0.15, 0.4, 9.0, gold, 0, 40.0, 0, 8)
		sphere(0.7, gold, 0, 36.6, 0, 10)
		# domed side towers
		for p in [Vector3(-25, 6, 4.2), Vector3(25, 6, 4.2), Vector3(-17, -20, 3.6), Vector3(17, -20, 3.6), Vector3(-12, 20, 2.2), Vector3(12, 20, 2.2)]:
			var r: float = p.z
			var th := r * 5.0
			var bx: float = p.x; var bz: float = p.y
			var by := gy(bx, bz)
			cyl(r, r * 1.1, th, cream, bx, by + th * 0.5, bz, 18)
			torus(r * 1.02, 0.18, shade, bx, by + th * 0.55, bz)
			torus(r * 1.02, 0.18, shade, bx, by + th * 0.85, bz)
			for k in 4:
				on_ring(bx, bz, r * 1.0, float(k) * PI / 2 + 0.4, by + th * 0.7, r * 0.35, r * 0.6, 0.15, dark)
			cyl(r * 1.15, r * 1.15, 0.4, shade, bx, by + th + 0.2, bz, 18)
			var cp := dome(r * 1.05, roof, bx, by + th + 0.4, bz, 18); cp.scale = Vector3(1, 1.2, 1)
			cyl(0.06 * r, 0.12 * r, r * 1.6, gold, bx, by + th + r * 1.6, bz, 6)
		if flag("trees"):
			for p in [Vector2(-18, 28), Vector2(18, 28), Vector2(-28, 18), Vector2(28, 18), Vector2(-30, -6), Vector2(30, -6), Vector2(-6, 32), Vector2(6, 32)]:
				round_tree(p.x, p.y, 2.6)

	## Tournament grounds (tournament_island): the same 40 x 40 m tiled ring as before plus the venue behind it - a
	## long ochre wall with a brick band, the long thatched hall, the gatehouse (thatched porch, crest door, red
	## pillars) and its tower with a green pagoda roof, the big signboard, a lawn, walkway and beach umbrellas.
	func budokaihall() -> void:
		var stone := mat(0xe6e2d8, {"rough": 0.75}); var line := mat(0xa8a296)
		var ochre := mat(0xe8c070, {"rough": 0.8}); var brick := mat(0xb0503a, {"rough": 0.85}); var white := mat(0xf2ece0, {"rough": 0.7})
		var thatch := mat(0xa88a4a, {"rough": 1.0}); var green := mat(0x3a7a4a, {"rough": 0.6}); var red := mat(0xb8322a, {"rough": 0.5})
		var gold := mat(0xd8b04a, {"metal": 0.6, "rough": 0.35}); var dark := mat(0x2a2a30)
		box(40, 1.6, 40, stone, 0, 0.8, 0)
		for i in range(-16, 17, 8):
			box(40, 0.05, 0.2, line, 0, 1.62, i)
			box(0.2, 0.05, 40, line, i, 1.62, 0)
		for s in [-1.0, 1.0]:   # steps up the ring on the gate side
			box(6.0, 0.8, 1.2, stone, s * 12.0, 0.4, 20.6)
		box(4.5, 0.08, 12.0, mat(0xe8e0d0), 0, 0.04, 26.0)   # walkway to the gate
		box(96, 0.06, 14, mat(0x5aa83e, {"rough": 0.95}), 0, 0.03, 27.0)   # lawn
		# the wall, with brick bands stepped like the reference
		const WZ := 34.0
		box(90, 4.0, 1.2, ochre, 0, 2.0, WZ)
		for s in [-1.0, 1.0]:
			box(28.0, 1.2, 1.3, brick, s * 20.0, 1.6, WZ)
			box(20.0, 0.6, 1.3, brick, s * 22.0, 2.5, WZ)
		# the long thatched hall behind it
		box(80, 7.0, 16, white, 0, 3.5, WZ + 9.0)
		gable(18.0, 82.0, 6.0, thatch, thatch, 0, 7.0, WZ + 9.0, PI / 2, 0.8)
		for s in [-1.0, 1.0]:   # carved gold finials at the roof ends
			var fin := cone(0.9, 3.4, gold, s * 41.0, 14.2, WZ + 9.0, 6); fin.rotation.z = s * 0.35
		# gatehouse with its thatched porch roof and crest door
		box(9.0, 6.5, 5.0, white, 0, 3.25, WZ + 1.0)
		hip(10.5, 6.5, 3.0, thatch, 0, 6.5, WZ + 1.0)
		box(3.4, 4.0, 0.2, dark, 0, 2.0, WZ - 1.55)
		var crest := torus(0.9, 0.16, mat(0xe07a2a), 0, 2.6, WZ - 1.7); crest.rotation.x = PI / 2
		for s in [-1.0, 1.0]:
			box(0.6, 4.6, 0.6, red, s * 2.6, 2.3, WZ - 1.6)
			box(0.5, 1.4, 0.12, mat(0xe07a2a), s * 3.7, 3.6, WZ - 1.56)
		# gate tower with crest face and the green pagoda roof
		box(9.0, 9.0, 7.0, white, 0, 13.0, WZ + 6.0)
		var face := cyl(2.2, 2.2, 0.4, gold, 0, 14.0, WZ + 2.4, 16); face.rotation.x = PI / 2
		hip(12.0, 10.0, 4.0, green, 0, 17.5, WZ + 6.0)
		box(3.0, 2.0, 3.0, white, 0, 22.0, WZ + 6.0)
		hip(4.6, 4.6, 1.8, green, 0, 23.0, WZ + 6.0)
		# signboard on the roof front
		box(27.0, 4.6, 0.4, mat(0xe07a2a), 0, 10.8, WZ + 1.2)
		box(25.6, 3.6, 0.5, white, 0, 10.8, WZ + 1.1)
		label("WORLD TOURNAMENT", Vector3(0, 10.8, WZ + 0.82), 0.016, Color("#2f5a3a"), Color("#f2ece0"), PI)
		if flag("trees"):   # beach umbrellas on the lawn
			for p in [Vector2(-30, 24), Vector2(30, 24), Vector2(-40, 28), Vector2(40, 28)]:
				cyl(0.08, 0.08, 3.0, white, p.x, 1.5, p.y, 6)
				cone(2.0, 0.9, mat(0xf0c030, {"rough": 0.6}), p.x, 3.3, p.y, 12)
			for p in [Vector2(-34, 31), Vector2(-14, 31), Vector2(14, 31), Vector2(34, 31)]:
				var bush := sphere(1.4, mat(0x4a9a3a, {"rough": 0.9}), p.x, 1.0, p.y, 10); bush.scale = Vector3(1.6, 0.9, 1)

	## Crimson Ribbon HQ (optional, Origins chapter 3): grey stone fortress on a crenellated curtain wall - a huge round
	## keep tower with a slate cone roof and the army's red banner, a long arcaded wing with dormers, smaller domed
	## towers, a radar dish. 60 x 44 m (request collide 22). No lettering on the banner.
	func rrfortress() -> void:
		var stone := mat(0xa8a49c, {"rough": 0.9}); var cren := mat(0x8e8a82, {"rough": 0.9})
		var slate := mat(0x3a3e4a, {"rough": 0.5}); var dark := mat(0x1e1e24); var red := mat(0xc82a2a, {"rough": 0.6})
		var steel := mat(0x9aa0aa, {"metal": 0.7, "rough": 0.35}); var light_m := mat(0xd0ccc2, {"rough": 0.8})
		var c := [Vector2(-30, -22), Vector2(30, -22), Vector2(30, 22), Vector2(-30, 22)]
		for i in 4:
			var a: Vector2 = c[i]; var b2: Vector2 = c[(i + 1) % 4]
			wall(a.x, a.y, b2.x, b2.y, 8.0, 2.0, stone, cren)
		for p: Vector2 in c:
			cyl(3.0, 3.4, 12.0, stone, p.x, 6.0, p.y, 16)
			dome(3.3, slate, p.x, 12.0, p.y, 16)
		box(6.0, 6.0, 0.3, dark, 0, 3.0, 22.2)   # gate
		# long arcaded wing with a slate roof and dormers
		box(44.0, 12.0, 14.0, light_m, -4.0, 6.0, 2.0)
		for k in 12:
			box(1.6, 3.4, 0.2, dark, -24.0 + k * 3.6, 4.0, 9.06)
			var top := cyl(0.8, 0.8, 0.2, dark, -24.0 + k * 3.6, 5.7, 9.06, 10); top.rotation.x = PI / 2
		box(44.6, 0.6, 1.4, cren, -4.0, 8.0, 9.5)   # balcony
		gable(14.6, 45.0, 5.0, slate, light_m, -4.0, 12.0, 2.0, PI / 2)
		for k in 5:
			var dx := -20.0 + k * 8.0
			box(2.0, 2.2, 1.8, light_m, dx, 13.4, 7.8)
			gable(2.2, 2.2, 1.0, slate, light_m, dx, 14.5, 7.8)
		# the great keep tower
		cyl(8.0, 8.6, 26.0, stone, 18.0, 13.0, 8.0, 28)
		cyl(9.4, 8.0, 3.0, stone, 18.0, 27.5, 8.0, 28)
		for k in 6:
			on_ring(18.0, 8.0, 8.4, float(k) / 6.0 * TAU, 20.0, 1.6, 3.4, 0.2, dark)
			on_ring(18.0, 8.0, 9.3, float(k) / 6.0 * TAU + 0.5, 27.5, 1.4, 1.6, 0.2, dark)
		cone(10.4, 12.0, slate, 18.0, 35.0, 8.0, 28)
		cyl(0.15, 0.15, 7.0, steel, 18.0, 44.0, 8.0, 6)
		var flag_m := box(4.6, 2.6, 0.12, red, 20.4, 45.6, 8.0)
		flag_m.name = "Banner"
		# smaller towers along the wing
		for p in [Vector2(-28, 4), Vector2(-10, -8), Vector2(6, -10)]:
			cyl(2.6, 2.8, 18.0, light_m, p.x, 9.0, p.y, 14)
			for k in 3:
				on_ring(p.x, p.y, 2.65, float(k) * 2.1, 14.0, 0.6, 1.2, 0.2, dark)
			dome(2.9, slate, p.x, 18.0, p.y, 14)
			cyl(0.08, 0.08, 2.5, steel, p.x, 22.0, p.y, 6)
		box(3.0, 1.4, 3.0, steel, -22.0, 12.7, -14.0)   # radar dish
		var dish := dome(3.4, steel, -22.0, 16.2, -14.0, 16); dish.rotation = Vector3(-2.2, 0.8, 0.0)
		box(5.0, 1.4, 0.2, red, 0, 9.5, 22.2)   # red stripe over the gate
