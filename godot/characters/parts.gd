class_name Parts
extends RefCounted
# Rigid pieces on bones (port of the JS dress()): sash, wristbands, armour pads, collar, cape, and race
# features (Saiyan tail, Namekian antennae and arm patches, Frost Demon dome and tail, Majin antenna).
# Positions are in model space at the rest (T-) pose, or in Hair.HEAD_SPACE for head pieces.
# Meshes and materials are cached and shared.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

static func material(c: Color, rough := 0.6, metal := 0.0, two_sided := false) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%s" % [c.to_html(false), rough, metal, two_sided]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c; m.roughness = rough; m.metallic = metal
		if two_sided: m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]

static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var g := Geo.new()
		build.call(g)
		_meshes[key] = g.mesh()
	return _meshes[key]

static func hx(v: Variant) -> Color:
	return Color.hex((int(v) << 8) | 0xff)

## Adds the outfit's extra pieces and the race's features to a fighter.
static func dress(f: Fighter, parts: Dictionary, race_id: String, skin: Color) -> void:
	if parts.has("sash"):
		f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("sash", func(g: Geo) -> void:
			g.cylinder(Transform3D(Basis.from_scale(Vector3(1, 1, 0.78)), Vector3(0, 0.965, -0.008)), 0.158, 0.162, 0.06, 28)
			g.box(Transform3D(Basis.from_euler(Vector3(0, 0, 0.15)), Vector3(0.05, 0.89, 0.116)), Vector3(0.05, 0.16, 0.012))
			g.box(Transform3D(Basis.from_euler(Vector3(0, 0, -0.1)), Vector3(-0.03, 0.895, 0.116)), Vector3(0.05, 0.14, 0.012))), material(hx(parts.sash), 0.75))
	if parts.has("wrist"):
		for s in [1, -1]:
			f.add_piece("DEF-forearm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("wrist%d" % s, func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.7, 1.4408, -0.068)), 0.047, 0.047, 0.075, 20)), material(hx(parts.wrist), 0.7))
	if parts.has("armor") and parts.armor.get("pads", false):
		for s in [1, -1]:
			f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("pad%d" % s, func(g: Geo) -> void:
				var h := SphereMesh.new(); h.radius = 0.085; h.height = 0.085; h.is_hemisphere = true; h.radial_segments = 24; h.rings = 8
				g.add_primitive(h, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.45)) * Basis.from_scale(Vector3(1.3, 0.8, 1.25)), Vector3(s * 0.215, 1.47, -0.06)))), material(hx(parts.armor.trim), 0.4, 0.1))
	if parts.has("collar"):
		f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("collar", func(g: Geo) -> void:
			g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 1.47, -0.012)), 0.1, 0.018)), material(hx(parts.collar), 0.3, 0.5))
	if parts.has("cape"):
		var cape := f.add_piece("DEF-spine.003", Transform3D(Basis.from_euler(Vector3(0.06, 0, 0)), Vector3(0, 1.47, -0.155)), _mesh("cape", func(g: Geo) -> void:
			g.sheet(Transform3D.IDENTITY, 0.46, 1.05)), material(hx(parts.cape), 0.8, 0.0, true))
		f.cape = cape
		f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("cape_pads", func(g: Geo) -> void:
			for s in [1, -1]:
				var h := SphereMesh.new(); h.radius = 0.07; h.height = 0.07; h.is_hemisphere = true
				g.add_primitive(h, Transform3D(Basis.from_scale(Vector3(1.4, 0.6, 1.2)), Vector3(s * 0.17, 1.47, -0.02)))), material(hx(parts.cape), 0.8))
	match race_id:
		"Saiyan":
			f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("saiyan_tail", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.12, -0.12), Vector3(0.12, -0.28, -0.18), Vector3(0.22, -0.32, -0.05), Vector3(0.18, -0.22, 0.04)], Vector3(0, 0.9, -0.12)), 0.032, 0.022)), material(Color.hex(0x4a2e1cff), 0.85))
		"Namekian":
			var green := material(skin * 0.9, 0.55)
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("antennae", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.02, 0.06, 0.02), Vector3(s * 0.05, 0.12, 0.0)], Vector3(s * 0.03, 0.135, 0.07)), 0.009, 0.006, 12, 8)
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.08, 0.255, 0.07)), 0.011, 8, 10)), green), 0.9)
			for s in [1, -1]:
				f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("namek_patch%d" % s, func(g: Geo) -> void:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.6, 0.55, 0.95)), Vector3(s * 0.33, 1.47, -0.062)), 0.05)), material(Color.hex(0xd88a9aff), 0.5))
		"FrostDemon":
			f.dome = f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("dome", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.04, 0.95, 1.12)), Vector3(0, 0.075, -0.01)), 0.108, PI * 0.36, PI * 0.46)), material(Color.hex(0x8a3ab8ff), 0.15, 0.1))
			f.add_skin_piece(f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("frost_tail", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.3, -0.25), Vector3(0.05, -0.75, -0.35), Vector3(0.25, -0.9, -0.1), Vector3(0.35, -0.92, 0.15)], Vector3(0, 0.88, -0.14)), 0.06, 0.02, 30)), material(skin, 0.45)), 1.0)
		"Majin":
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("majin_antenna", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, 0.12, -0.04), Vector3(0, 0.2, -0.14), Vector3(0, 0.17, -0.24), Vector3(0, 0.08, -0.26)], Vector3(0, 0.13, 0)), 0.035, 0.012, 24)), material(skin, 0.5)), 1.0)

## NPC-only costume pieces on top of the outfit (look.costume). Head pieces are in Hair.HEAD_SPACE
## (head centre about (0, 0.06, 0), radius about 0.105, +Z is the face).
static func costume(f: Fighter, id: String) -> void:
	match id:
		"yemmo":   # King Yemmo: a thick black beard round the jaw and a tall judge's hat with a gold plate
			var black := material(Color.hex(0x161212ff), 0.85)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("yemmo_beard", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.25, 1.05, 0.95)), Vector3(0, -0.035, 0.035)), 0.1, 12, 18)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.25, 0.8)), Vector3(0, -0.1, 0.06)), 0.075, 10, 16)
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(0.6, 1.3, 0.8)), Vector3(s * 0.095, 0.0, 0.0)), 0.045, 8, 12)
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.6, 0.55, 0.7)), Vector3(s * 0.035, 0.155, 0.098)), 0.026, 8, 12)), black)
			var hat := material(Color.hex(0x2c2a52ff), 0.55)
			var gold := material(Color.hex(0xd8a733ff), 0.3, 0.8)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("yemmo_hat", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.92)), Vector3(0, 0.215, -0.005)), 0.112, 0.118, 0.15, 24)
				g.cylinder(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.92)), Vector3(0, 0.145, -0.005)), 0.122, 0.122, 0.022, 24)), hat)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("yemmo_hat_plate", func(g: Geo) -> void:
				g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.215, 0.104)), Vector3(0.075, 0.09, 0.012))), gold)

static func _offset(pts: Array, o: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in pts:
		out.append(p + o)
	return out
