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
## Scales a piece built for the neutral body around `centre` so it fits the fighter's sculpted body (BodySculpt).
static func _fit(f: Fighter, centre: Vector3, sx: float, sz: float, sy := 1.0) -> Transform3D:
	var b := Basis.from_scale(Vector3(sx, sy, sz))
	return Transform3D(b, centre - b * centre)

static func _sc(f: Fighter, k: String) -> float:
	return float(f.sculpt.get(k, 1.0))

static func dress(f: Fighter, parts: Dictionary, race_id: String, skin: Color) -> void:
	# outfit pieces follow the sculpted body: belt with waist and hips (and belly), wristbands with the forearm,
	# shoulder pads with the upper arm and shoulders, collar and cape pads with the neck and shoulders
	var waist := lerpf(_sc(f, "waist"), _sc(f, "hips"), 0.4)
	var belt := _fit(f, Vector3(0, 0.965, -0.008), waist * 1.02, waist + float(f.sculpt.get("belly", 0.0)) * 4.0)
	var wrist := _sc(f, "forearm")
	var pad := sqrt(_sc(f, "upper_arm") * _sc(f, "shoulders"))
	if parts.has("sash"):
		f.add_piece("DEF-hips", belt, _mesh("sash", func(g: Geo) -> void:
			g.cylinder(Transform3D(Basis.from_scale(Vector3(1, 1, 0.78)), Vector3(0, 0.965, -0.008)), 0.158, 0.162, 0.06, 28)
			g.box(Transform3D(Basis.from_euler(Vector3(0, 0, 0.15)), Vector3(0.05, 0.89, 0.116)), Vector3(0.05, 0.16, 0.012))
			g.box(Transform3D(Basis.from_euler(Vector3(0, 0, -0.1)), Vector3(-0.03, 0.895, 0.116)), Vector3(0.05, 0.14, 0.012))), material(hx(parts.sash), 0.75))
	if parts.has("wrist"):
		for s in [1, -1]:
			var wc := Vector3(s * 0.7, 1.4408, -0.068)
			var wfit := Transform3D(Basis.from_scale(Vector3(1.0, wrist, wrist)), wc - Basis.from_scale(Vector3(1.0, wrist, wrist)) * wc)
			f.add_piece("DEF-forearm." + ("L" if s > 0 else "R"), wfit, _mesh("wrist%d" % s, func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.7, 1.4408, -0.068)), 0.047, 0.047, 0.075, 20)), material(hx(parts.wrist), 0.7))
	if parts.has("armor") and parts.armor.get("pads", false):
		for s in [1, -1]:
			var pc := Vector3(s * 0.215, 1.47, -0.06)
			# the pad sits where the sculpted shoulder now is (the trunk's shoulder width moves the joint outwards)
			var moved := Vector3(pc.x * _sc(f, "shoulders"), pc.y, pc.z)
			var pfit := Transform3D(Basis.from_scale(Vector3.ONE * pad), moved - Basis.from_scale(Vector3.ONE * pad) * pc)
			f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), pfit, _mesh("pad%d" % s, func(g: Geo) -> void:
				var h := SphereMesh.new(); h.radius = 0.085; h.height = 0.085; h.is_hemisphere = true; h.radial_segments = 24; h.rings = 8
				g.add_primitive(h, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.45)) * Basis.from_scale(Vector3(1.3, 0.8, 1.25)), Vector3(s * 0.215, 1.47, -0.06)))), material(hx(parts.armor.trim), 0.4, 0.1))
	if parts.has("collar"):
		f.add_piece("DEF-spine.003", _fit(f, Vector3(0, 1.47, -0.012), _sc(f, "neck"), _sc(f, "neck")), _mesh("collar", func(g: Geo) -> void:
			g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 1.47, -0.012)), 0.1, 0.018)), material(hx(parts.collar), 0.3, 0.5))
	if parts.has("cape"):
		var cape := f.add_piece("DEF-spine.003", Transform3D(Basis.from_euler(Vector3(0.06, 0, 0)), Vector3(0, 1.47, -0.155)), _mesh("cape", func(g: Geo) -> void:
			g.sheet(Transform3D.IDENTITY, 0.46, 1.05)), material(hx(parts.cape), 0.8, 0.0, true))
		f.cape = cape
		f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("cape_pads", func(g: Geo) -> void:
			for s in [1, -1]:
				var h := SphereMesh.new(); h.radius = 0.07; h.height = 0.07; h.is_hemisphere = true
				g.add_primitive(h, Transform3D(Basis.from_scale(Vector3(1.4, 0.6, 1.2)), Vector3(s * 0.17, 1.47, -0.02)))), material(hx(parts.cape), 0.8))
	face(f, race_id, skin)
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
			# long pointed ears sweeping up and back
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("namek_ears", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.04, 0.018, -0.015), Vector3(s * 0.085, 0.045, -0.04)], Vector3(s * 0.088, 0.03, -0.005)), 0.022, 0.002, 12, 10)), material(skin, 0.55)), 1.0)
			for s in [1, -1]:
				f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("namek_patch%d" % s, func(g: Geo) -> void:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.6, 0.55, 0.95)), Vector3(s * 0.33, 1.47, -0.062)), 0.05)), material(Color.hex(0xd88a9aff), 0.5))
		"FrostDemon":
			f.dome = f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("dome", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.04, 0.95, 1.12)), Vector3(0, 0.075, -0.01)), 0.108, PI * 0.36, PI * 0.46)), material(Color.hex(0x8a3ab8ff), 0.15, 0.1))
			# bone-white shoulder domes and a chest plate: the armoured carapace of the race
			var shell := material(Color.hex(0xe8e4f0ff), 0.25, 0.05)
			for s in [1, -1]:
				var dc := Vector3(s * 0.2, 1.455, -0.06)
				f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D(Basis.from_scale(Vector3.ONE * pad), Vector3(dc.x * _sc(f, "shoulders"), dc.y, dc.z) - Basis.from_scale(Vector3.ONE * pad) * dc), _mesh("frost_dome%d" % s, func(g: Geo) -> void:
					var h := SphereMesh.new(); h.radius = 0.075; h.height = 0.075; h.is_hemisphere = true; h.radial_segments = 24; h.rings = 8
					g.add_primitive(h, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.5)) * Basis.from_scale(Vector3(1.15, 0.9, 1.1)), Vector3(s * 0.2, 1.455, -0.06)))), shell)
			f.add_piece("DEF-spine.003", _fit(f, Vector3(0, 1.36, 0.0), _sc(f, "shoulders"), _sc(f, "chest")), _mesh("frost_chest", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.5, 0.75, 0.42)), Vector3(0, 1.36, 0.075)), 0.09, 10, 18)), shell)
			f.add_skin_piece(f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("frost_tail", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.3, -0.25), Vector3(0.05, -0.75, -0.35), Vector3(0.25, -0.9, -0.1), Vector3(0.35, -0.92, 0.15)], Vector3(0, 0.88, -0.14)), 0.06, 0.02, 30)), material(skin, 0.45)), 1.0)
		"Majin":
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("majin_antenna", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, 0.12, -0.04), Vector3(0, 0.2, -0.14), Vector3(0, 0.17, -0.24), Vector3(0, 0.08, -0.26)], Vector3(0, 0.13, 0)), 0.035, 0.012, 24)), material(skin, 0.5)), 1.0)

## 3D facial structure on top of the painted eyes/brows/mouth (presentation rebuild): nose, ears and brow ridges,
## different per race. Model rest-space coordinates on DEF-head (front of the face z about 0.118, eyes at y 1.703,
## x ±0.039, mouth y 1.628, side of the head x ±0.086); they follow the sculpted head through Fighter._head_xform.
static func face(f: Fighter, race_id: String, skin: Color) -> void:
	var flesh := material(skin, 0.62)
	var key := "face_" + race_id
	match race_id:
		"Saiyan", "HalfSaiyan", "Human":
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D.IDENTITY, _mesh(key, func(g: Geo) -> void:
				# nose: a bridge running down from between the eyes to a rounded tip with nostril wings
				g.tube(PackedVector3Array([Vector3(0, 1.694, 0.113), Vector3(0, 1.676, 0.122), Vector3(0, 1.659, 0.131)]), 0.0055, 0.0085, 10, 8)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.15, 0.85, 1.0)), Vector3(0, 1.654, 0.128)), 0.0105, 8, 10)
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 0.8)), Vector3(s * 0.0105, 1.651, 0.121)), 0.0075, 6, 8)
					# ears: a flattened shell standing a little off the side of the head
					g.sphere(Transform3D(Basis.from_euler(Vector3(0, s * 0.35, 0)) * Basis.from_scale(Vector3(0.32, 1.0, 0.68)), Vector3(s * 0.087, 1.684, -0.008)), 0.027, 8, 12)
					pass), flesh), 1.0)
		"Namekian":
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D.IDENTITY, _mesh(key, func(g: Geo) -> void:
				# flat wide nose without a bridge, heavy brow ridges over each eye
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.5, 0.75, 0.9)), Vector3(0, 1.656, 0.122)), 0.011, 8, 10)
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_euler(Vector3(0, 0, s * 0.3)) * Basis.from_scale(Vector3(1.9, 0.55, 0.8)), Vector3(s * 0.04, 1.722, 0.108)), 0.016, 8, 12)
					pass), flesh), 1.0)
		"FrostDemon":
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D.IDENTITY, _mesh(key, func(g: Geo) -> void:
				# no nose or ears: sharp cheek ridges sweeping back under the eyes
				for s in [1, -1]:
					g.tube(PackedVector3Array([Vector3(s * 0.034, 1.682, 0.11), Vector3(s * 0.06, 1.676, 0.094), Vector3(s * 0.08, 1.68, 0.06)]), 0.007, 0.002, 10, 8)), flesh), 1.0)
		"Majin":
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D.IDENTITY, _mesh(key, func(g: Geo) -> void:
				# no nose; small ear holes rimmed in skin
				for s in [1, -1]:
					g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.086, 1.686, -0.005)), 0.012, 0.004)), flesh), 1.0)

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
