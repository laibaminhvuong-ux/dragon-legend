class_name Parts
extends RefCounted
# Rigid pieces on bones (port of the JS dress()): sash, wristbands, armour pads, collar, cape, and race
# features (Saiyan tail, Namekian antennae and arm patches, Frost Demon dome and tail, Majin antenna), which each
# look can switch on or off one by one (Parts.features; field list at the top of outfits.gd).
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
	var wrist := _sc(f, "forearm")
	var pad := sqrt(_sc(f, "upper_arm") * _sc(f, "shoulders"))
	var loose := float(f.cloth.get("amount", 0.0))
	if not f.is_anime():   # classic look (everyone but the cel-styled fighters): the original sash and wristbands
		var belt := _fit(f, Vector3(0, 0.965, -0.008), waist * 1.02, waist + float(f.sculpt.get("belly", 0.0)) * 4.0)
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
	else:
		if parts.has("sash"):
			# a thick cloth sash sitting on the loose top (it grows with the cloth), tied in a knot at the front with two
			# hanging tails (a separate piece: Fighter.update sways it from the knot)
			var sfit := _fit(f, Vector3(0, 0.965, -0.008), waist * 1.02 * (1.0 + 0.11 * loose), (waist + float(f.sculpt.get("belly", 0.0)) * 4.0) * (1.0 + 0.13 * loose))
			var sash_mat := material(hx(parts.sash), 0.75)
			var band := f.add_piece("DEF-hips", sfit, _mesh("sash2", func(g: Geo) -> void:
				var sq := Basis.from_scale(Vector3(1, 1, 0.78))
				g.cylinder(Transform3D(sq, Vector3(0, 0.946, -0.008)), 0.166, 0.158, 0.038, 32)
				g.cylinder(Transform3D(sq, Vector3(0, 0.984, -0.008)), 0.158, 0.166, 0.038, 32)
				# the knot: a bunched lump with a wrap round it
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.25, 1.0, 0.75)), Vector3(0.062, 0.962, 0.128)), 0.03, 10, 14)
				g.torus(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0.35)) * Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0.062, 0.962, 0.13)), 0.026, 0.011)), sash_mat)
			band.set_meta("ink", true)
			var knot := Vector3(0.062, 0.948, 0.13)
			f.sash_tails = f.add_piece("DEF-hips", sfit * Transform3D(Basis.IDENTITY, knot), _mesh("sash_tails", func(g: Geo) -> void:
				var flat := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.38)), Vector3.ZERO)
				g.tube(PackedVector3Array([Vector3(0, 0.01, 0), Vector3(0.012, -0.08, 0.02 / 0.38), Vector3(0.03, -0.2, 0.03 / 0.38)]), 0.024, 0.03, 12, 10, flat)
				g.tube(PackedVector3Array([Vector3(-0.01, 0.01, 0), Vector3(-0.022, -0.07, 0.016 / 0.38), Vector3(-0.03, -0.155, 0.026 / 0.38)]), 0.022, 0.027, 10, 10, flat)), sash_mat)
			f.sash_tails.set_meta("ink", true)
		if parts.has("wrist"):
			for s in [1, -1]:
				var wc := Vector3(s * 0.7, 1.4408, -0.068)
				var wfit := Transform3D(Basis.from_scale(Vector3(1.0, wrist, wrist)), wc - Basis.from_scale(Vector3(1.0, wrist, wrist)) * wc)
				# thick padded wristbands with rounded rims
				var band := f.add_piece("DEF-forearm." + ("L" if s > 0 else "R"), wfit, _mesh("wrist2_%d" % s, func(g: Geo) -> void:
					var along := Basis.from_euler(Vector3(0, 0, PI / 2))
					g.cylinder(Transform3D(along, Vector3(s * 0.7, 1.4408, -0.068)), 0.055, 0.055, 0.084, 22)
					for e in [-1.0, 1.0]:
						g.torus(Transform3D(along, Vector3(s * (0.7 + e * 0.042), 1.4408, -0.068)), 0.051, 0.007, 22, 8)), material(hx(parts.wrist), 0.7))
				band.set_meta("ink", true)
	if parts.has("armor") and parts.armor.get("pads", false):
		for s in [1, -1]:
			var pc := Vector3(s * 0.215, 1.47, -0.06)
			# the pad sits where the sculpted shoulder now is (the trunk's shoulder width moves the joint outwards)
			var moved := Vector3(pc.x * _sc(f, "shoulders"), pc.y, pc.z)
			var pfit := Transform3D(Basis.from_scale(Vector3.ONE * pad), moved - Basis.from_scale(Vector3.ONE * pad) * pc)
			f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), pfit, _mesh("pad%d" % s, func(g: Geo) -> void:
				var h := SphereMesh.new(); h.radius = 0.085; h.height = 0.085; h.is_hemisphere = true; h.radial_segments = 24; h.rings = 8
				g.add_primitive(h, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.45)) * Basis.from_scale(Vector3(1.3, 0.8, 1.25)), Vector3(s * 0.215, 1.47, -0.06)))), material(hx(parts.armor.trim), 0.4, 0.1))
	if parts.has("armor"):
		_armor_flaps(f, parts.armor, pad, waist)
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
	if f.hero_body_kind() == "":   # the Universal Base Characters heads have their own nose and ears
		face(f, race_id, skin)
	var rp := features(race_id, f.look)
	if rp.tail == "saiyan":
		f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("saiyan_tail", func(g: Geo) -> void:
			g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.12, -0.12), Vector3(0.12, -0.28, -0.18), Vector3(0.22, -0.32, -0.05), Vector3(0.18, -0.22, 0.04)], Vector3(0, 0.9, -0.12)), 0.032, 0.022)), material(Color.hex(0x4a2e1cff), 0.85))
	if rp.antenna == "namek":
		f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("antennae", func(g: Geo) -> void:
			for s in [1, -1]:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.02, 0.06, 0.02), Vector3(s * 0.05, 0.12, 0.0)], Vector3(s * 0.03, 0.135, 0.07)), 0.009, 0.006, 12, 8)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.08, 0.255, 0.07)), 0.011, 8, 10)), material(skin * 0.9, 0.55)), 0.9)
	elif rp.antenna == "long":   # two long thin feelers swept back (King Kae)
		f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("antennae_long", func(g: Geo) -> void:
			for s in [1, -1]:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.015, 0.09, -0.02), Vector3(s * 0.04, 0.2, -0.08), Vector3(s * 0.07, 0.28, -0.17)], Vector3(s * 0.03, 0.14, 0.04)), 0.008, 0.005, 16, 8)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.1, 0.42, -0.13)), 0.01, 8, 10)), material(skin * 0.9, 0.55)), 0.9)
	elif rp.antenna == "buu":
		f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("majin_antenna", func(g: Geo) -> void:
			g.tube(_offset([Vector3(0, 0, 0), Vector3(0, 0.12, -0.04), Vector3(0, 0.2, -0.14), Vector3(0, 0.17, -0.24), Vector3(0, 0.08, -0.26)], Vector3(0, 0.13, 0)), 0.035, 0.012, 24)), material(skin, 0.5)), 1.0)
	if rp.ears == "pointed":   # long pointed ears sweeping up and back (Namekians, Kais)
		f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("namek_ears", func(g: Geo) -> void:
			for s in [1, -1]:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.04, 0.018, -0.015), Vector3(s * 0.085, 0.045, -0.04)], Vector3(s * 0.088, 0.03, -0.005)), 0.022, 0.002, 12, 10)), material(skin, 0.55)), 1.0)
	if rp.patches:
		for s in [1, -1]:
			f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("namek_patch%d" % s, func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.6, 0.55, 0.95)), Vector3(s * 0.33, 1.47, -0.062)), 0.05)), material(Color.hex(0xd88a9aff), 0.5))
	if rp.dome:
		f.dome = f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("dome", func(g: Geo) -> void:
			g.cap(Transform3D(Basis.from_scale(Vector3(1.04, 0.95, 1.12)), Vector3(0, 0.075, -0.01)), 0.108, PI * 0.36, PI * 0.46)), material(hx(dome_colour(f.look)), 0.15, 0.1))
	if rp.shells:
		# bone-white shoulder domes and a chest plate: the armoured carapace of the Frost race (look.shellRgb / form shells)
		var shell := material(hx(shell_colour(f.look)), 0.25, 0.05)
		var shells: Array = []
		for s in [1, -1]:
			var dc := Vector3(s * 0.2, 1.455, -0.06)
			shells.append(f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D(Basis.from_scale(Vector3.ONE * pad), Vector3(dc.x * _sc(f, "shoulders"), dc.y, dc.z) - Basis.from_scale(Vector3.ONE * pad) * dc), _mesh("frost_dome%d" % s, func(g: Geo) -> void:
				var h := SphereMesh.new(); h.radius = 0.075; h.height = 0.075; h.is_hemisphere = true; h.radial_segments = 24; h.rings = 8
				g.add_primitive(h, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.5)) * Basis.from_scale(Vector3(1.15, 0.9, 1.1)), Vector3(s * 0.2, 1.455, -0.06)))), shell))
		shells.append(f.add_piece("DEF-spine.003", _fit(f, Vector3(0, 1.36, 0.0), _sc(f, "shoulders"), _sc(f, "chest")), _mesh("frost_chest", func(g: Geo) -> void:
			g.sphere(Transform3D(Basis.from_scale(Vector3(1.5, 0.75, 0.42)), Vector3(0, 1.36, 0.075)), 0.09, 10, 18)), shell))
		f.set_meta("shells", shells)
	if rp.tail == "frost":
		f.add_skin_piece(f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("frost_tail", func(g: Geo) -> void:
			g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.3, -0.25), Vector3(0.05, -0.75, -0.35), Vector3(0.25, -0.9, -0.1), Vector3(0.35, -0.92, 0.15)], Vector3(0, 0.88, -0.14)), 0.06, 0.02, 30)), material(skin, 0.45)), 1.0)
	elif rp.tail == "cat":   # a thin whip tail with a tufted tip (the cat gods)
		f.add_skin_piece(f.add_piece("DEF-hips", Transform3D.IDENTITY, _mesh("cat_tail", func(g: Geo) -> void:
			g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.25, -0.12), Vector3(0.04, -0.6, -0.2), Vector3(0.16, -0.78, -0.06), Vector3(0.22, -0.74, 0.1)], Vector3(0, 0.9, -0.13)), 0.018, 0.01, 26, 8)), material(skin, 0.5)), 1.0)
	form_reset(f)

# ------------------------------------------------------------------------------------------------ cast batch B3
# Frieza Force armour flaps, Frost dome/shell colours, per-form extras (form_looks shells / chitin / gear) and the
# B3 gear ids (field list at the top of outfits.gd).

## Frieza Force armour: big flared shoulder flaps over the chest plate, hip flaps over the thighs and a ribbed belly
## panel, all in the armour's trim colour with a white rim (armor.flaps / armor.belly).
static func _armor_flaps(f: Fighter, armor: Dictionary, pad: float, waist: float) -> void:
	var col := material(hx(armor.trim), 0.45, 0.05, true)
	var rim := material(hx(armor.plate), 0.4, 0.05, true)
	if armor.get("flaps", false):
		for s in [1, -1]:
			var pc := Vector3(s * 0.25, 1.5, -0.055)
			var moved := Vector3(pc.x * _sc(f, "shoulders"), pc.y, pc.z)
			var fit := Transform3D(Basis.from_scale(Vector3.ONE * pad), moved - Basis.from_scale(Vector3.ONE * pad) * pc)
			# a wide, low shell over the shoulder whose outer end flares up (rim: a slightly bigger white shell under it)
			var tilt := Basis.from_euler(Vector3(0, 0, s * 0.3))
			f.add_piece("DEF-spine.003", fit, _mesh("ff_flap%d" % s, func(g: Geo) -> void:
				g.cap(Transform3D(tilt * Basis.from_scale(Vector3(2.25, 0.62, 1.45)), pc + Vector3(0, 0.006, 0)), 0.1, PI * 0.5, PI * 0.5, 8, 24)), col)
			f.add_piece("DEF-spine.003", fit, _mesh("ff_flap_rim%d" % s, func(g: Geo) -> void:
				g.cap(Transform3D(tilt * Basis.from_scale(Vector3(2.38, 0.6, 1.56)), pc), 0.1, PI * 0.5, PI * 0.5, 8, 24)), rim)
			# hip flap: a curved plate on the outside front of each thigh, hanging from the belt
			var n := Vector3(s, 0, 0.55).normalized()
			var down := Vector3(0, -1, 0)
			var hb := Basis(n.cross(down), n, down) * Basis.from_scale(Vector3(0.95, 0.38, 1.45))
			f.add_piece("DEF-thigh." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, _mesh("ff_hip%d" % s, func(g: Geo) -> void:
				g.cap(Transform3D(hb, Vector3(s * 0.138, 0.84, 0.035)), 0.1, PI * 0.5, PI * 0.5, 8, 20)), col)
	if armor.get("belly", false):
		var bfit := _fit(f, Vector3(0, 1.08, 0.0), waist, waist + float(f.sculpt.get("belly", 0.0)) * 4.0)
		f.add_piece("DEF-spine.001", bfit, _mesh("ff_belly", func(g: Geo) -> void:
			g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 0.5)), Vector3(0, 1.075, 0.058)), 0.1, 10, 18)
			for k in 3:   # ribs across the panel
				g.torus(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.52)), Vector3(0, 1.035 + k * 0.03, 0.06)), 0.094 - absf(k - 1) * 0.008, 0.0045, 24, 6)), col)

## The Frost dome colour outside forms (look.domeRgb, default purple).
static func dome_colour(look: Dictionary) -> int:
	var c := Outfits.rgb(look.get("domeRgb"))
	return c if c >= 0 else 0x8a3ab8

## The Frost shoulder/chest shell colour outside forms (look.shellRgb, default bone white).
static func shell_colour(look: Dictionary) -> int:
	var c := Outfits.rgb(look.get("shellRgb"))
	return c if c >= 0 else 0xe8e4f0

static func _paint_shells(f: Fighter, hex: int) -> void:
	for mi: Variant in f.get_meta("shells", []):
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_override = material(hx(hex), 0.25, 0.05)

## Base look after a form ends (and when the fighter is built): dome and shell colours, the outfit's region
## colours (form chitin undone) and look.skinMetal.
static func form_reset(f: Fighter) -> void:
	if f.dome != null:
		f.dome.material_override = material(hx(dome_colour(f.look)), 0.15, 0.1)
	_paint_shells(f, shell_colour(f.look))
	if f.has_meta("base_colors"):
		f.material.set_shader_parameter("colors", f.get_meta("base_colors"))
	else:
		f.set_meta("base_colors", f.material.get_shader_parameter("colors"))
	var metal := clampf(float(f.look.get("skinMetal", 0.0)), 0.0, 1.0)
	if metal > 0.0:
		f._set_skin(f.skin, metal)

## Form-look extras (Fighter.set_form): shells colour, chitin (torso, forearm guards: two-tone Frost forms) and gear
## worn only in the form. Returns the pieces added, so the fighter removes them when the form ends.
static func form_extras(f: Fighter, F: Dictionary) -> Array[Node]:
	var out: Array[Node] = []
	if Outfits.rgb(F.get("shells")) >= 0:
		_paint_shells(f, Outfits.rgb(F.shells))
	if Outfits.rgb(F.get("chitin")) >= 0 and f.has_meta("base_colors"):
		var c: PackedColorArray = (f.get_meta("base_colors") as PackedColorArray).duplicate()
		for r: int in [BodyRegions.TOP, BodyRegions.PLATE, BodyRegions.UNDERSHIRT, BodyRegions.TRIM, BodyRegions.FOREARM, BodyRegions.WRIST]:
			c[r] = hx(Outfits.rgb(F.chitin))
		f.material.set_shader_parameter("colors", c)
	var ids: Variant = F.get("gear")
	if ids is Array:
		var before := f.skeleton.find_children("*", "MeshInstance3D", true, false)
		for id: Variant in ids:
			gear(f, str(id))
		for mi: Node in f.skeleton.find_children("*", "MeshInstance3D", true, false):
			if not before.has(mi):
				out.append(mi)
	return out

static func _lens(hex: int) -> StandardMaterial3D:
	var key := "lens_%06x" % hex
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hx(hex), 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1; m.metallic = 0.2
		m.emission_enabled = true; m.emission = hx(hex); m.emission_energy_multiplier = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]

## The B3 gear ids (Parts.gear passes ids it does not know on here). Head pieces in Hair.HEAD_SPACE.
static func gear_b3(f: Fighter, id: String) -> void:
	match id:
		"scouter", "scouter_red", "scouter_purple", "scouter_blue":   # over the left eye: ear unit, arm, tinted lens
			var lens: int = {"scouter": 0x3ad84a, "scouter_red": 0xe8303a, "scouter_purple": 0xa04ad8, "scouter_blue": 0x3a8ae8}[id]
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("scouter_unit", func(g: Geo) -> void:
				g.box(Transform3D(Basis.IDENTITY, Vector3(0.1, 0.035, 0.0)), Vector3(0.026, 0.07, 0.06))
				g.box(Transform3D(Basis.from_euler(Vector3(0, -0.28, 0)), Vector3(0.088, 0.062, 0.07)), Vector3(0.012, 0.014, 0.09))
				g.box(Transform3D(Basis.IDENTITY, Vector3(0.066, 0.052, 0.113)), Vector3(0.012, 0.03, 0.01))), material(Color.hex(0xe4e4e8ff), 0.35, 0.2))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("scouter_lens", func(g: Geo) -> void:
				g.box(Transform3D(Basis.from_euler(Vector3(0, 0.12, 0)), Vector3(0.034, 0.04, 0.116)), Vector3(0.056, 0.038, 0.003))), _lens(lens))
		"frost_horns":   # two short dark horns pointing out and up from the sides of the head (1st form, Frosk, Ginnu)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("frost_horns", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.06, 0.02, -0.01), Vector3(s * 0.12, 0.055, -0.02), Vector3(s * 0.17, 0.1, -0.03)], Vector3(s * 0.085, 0.1, -0.01)), 0.022, 0.002, 18, 8)), material(Color.hex(0x2a2a32ff), 0.3, 0.2))
		"frost_horns_big", "cold_horns":   # big horns sweeping out then straight up (2nd form; King Kold's are purple)
			var hc := 0x4a3a6e if id == "cold_horns" else 0x2a2a32
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("frost_horns_big", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.07, 0.015, 0.0), Vector3(s * 0.13, 0.07, -0.01), Vector3(s * 0.155, 0.18, -0.03), Vector3(s * 0.15, 0.28, -0.05)], Vector3(s * 0.08, 0.09, -0.01)), 0.032, 0.003, 24, 8)), material(Color.hex((hc << 8) | 0xff), 0.3, 0.2))
		"third_crest":   # 3rd form: a long head crest swept back (the dome's colour) with white chitin spikes
			var dm: Material = f.dome.material_override if f.dome != null else material(hx(dome_colour(f.look)), 0.15, 0.1)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("third_crest", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_euler(Vector3(-0.4, 0, 0)) * Basis.from_scale(Vector3(0.95, 0.85, 1.75)), Vector3(0, 0.085, -0.06)), 0.1, 12, 18)), dm)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("third_spikes", func(g: Geo) -> void:
				for s in [1, -1]:
					g.spike(Vector3(s * 0.075, 0.09, -0.02), 0.16, 0.03, Vector3(s * 0.45, 1.0, -0.5))
					g.spike(Vector3(s * 0.085, 0.04, -0.09), 0.14, 0.028, Vector3(s * 0.9, 0.55, -0.7))), material(Color.hex(0xdfe6e0ff), 0.35))
		"head_spikes":   # Dodorra: short skin-coloured spikes over the top of the head
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("head_spikes", func(g: Geo) -> void:
				for i in 9:
					var a := float(i) / 9.0 * TAU
					var lat := 0.55 if i % 2 == 0 else 0.95
					var d := Vector3(sin(a) * sin(lat), cos(lat), cos(a) * sin(lat) - 0.15)
					g.spike(Vector3(0, 0.06, -0.01) + d.normalized() * 0.1, 0.05, 0.018, d)
				g.spike(Vector3(0, 0.165, -0.01), 0.06, 0.02, Vector3.UP)), material(f.skin * 0.92, 0.5)), 0.92)
		"mustache":   # a thick black moustache under the nose (Nappo)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("mustache", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.016, -0.002, -0.002), Vector3(s * 0.032, -0.012, -0.01), Vector3(s * 0.038, -0.03, -0.016)], Vector3(s * 0.004, -0.016, 0.112)), 0.008, 0.004, 12, 8)), material(Color.hex(0x141210ff), 0.85))
		"tiara":   # Zarvon: a thin gold circlet with a front jewel, and gold earrings
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("tiara", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(0.18, 0, 0)), Vector3(0, 0.1, -0.008)), 0.104, 0.006, 32, 6)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.3, 0.6)), Vector3(0, 0.122, 0.1)), 0.012, 8, 10)
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.098, -0.03, 0.0)), 0.012, 8, 10)), material(Color.hex(0xe0b040ff), 0.3, 0.7))
		"red_bands":   # Radix: red bands round the left upper arm and left thigh
			var red := material(Color.hex(0xc8202aff), 0.6)
			f.add_piece("DEF-upper_arm.L", Transform3D.IDENTITY, _mesh("red_band_arm", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(0.36, 1.443, -0.066)), 0.052, 0.011, 22, 6)), red)
			f.add_piece("DEF-thigh.L", Transform3D.IDENTITY, _mesh("red_band_leg", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.IDENTITY, Vector3(0.1, 0.68, 0.0)), 0.074, 0.012, 22, 6)), red)
		"cap":   # Lemmo: an orange soldier's cap with a short visor
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("soldier_cap", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.05, 0.85, 1.08)), Vector3(0, 0.06, -0.005)), 0.118, PI * 0.4, PI * 0.5)
				g.box(Transform3D(Basis.from_euler(Vector3(-0.15, 0, 0)), Vector3(0, 0.09, 0.12)), Vector3(0.14, 0.008, 0.06))), material(Color.hex(0xe0782aff), 0.7))
		"four_eyes":   # Gurdo: a second pair of eyes above the first
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("four_eyes", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.2, 0.85, 0.5)), Vector3(s * 0.034, 0.088, 0.096)), 0.017, 8, 12)), material(Color.hex(0xf4f2eaff), 0.3))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("four_pupils", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.5)), Vector3(s * 0.034, 0.087, 0.105)), 0.0065, 6, 8)), material(Color.hex(0x141414ff), 0.3))

## The race features a look wears (see the field list at the top of outfits.gd): each race has its defaults and
## look.tail / dome / shells / antenna / ears / patches override them one by one; look.raceParts = false starts from none.
## Returns {tail: "" | "saiyan" | "frost" | "cat", dome: bool, shells: bool, antenna: "" | "namek" | "long" | "buu",
## ears: "" | "pointed", patches: bool}.
static func features(race_id: String, look: Dictionary) -> Dictionary:
	var rp := {"tail": "", "dome": false, "shells": false, "antenna": "", "ears": "", "patches": false}
	if look.get("raceParts", true) != false:
		match race_id:
			"Saiyan": rp.tail = "saiyan"
			"Namekian": rp.antenna = "namek"; rp.ears = "pointed"; rp.patches = true
			"FrostDemon": rp.tail = "frost"; rp.dome = true; rp.shells = true
			"Majin": rp.antenna = "buu"
	var kinds := {"tail": ["saiyan", "frost", "cat"], "antenna": ["namek", "long", "buu"], "ears": ["pointed"]}
	for k: String in rp:
		if not look.has(k) or look[k] == null:
			continue
		var v: Variant = look[k]
		if rp[k] is bool:
			rp[k] = v is bool and v
		elif v is bool:
			rp[k] = (rp[k] if rp[k] != "" else str(kinds[k][0])) if v else ""
		elif v is String and (kinds[k] as Array).has(v):
			rp[k] = v
	return rp

## 3D facial structure on top of the painted eyes/brows/mouth (presentation rebuild): nose, ears and brow ridges,
## different per race. Model rest-space coordinates on DEF-head (front of the face z about 0.118, eyes at y 1.703,
## x ±0.039, mouth y 1.628, side of the head x ±0.086); they follow the sculpted head through Fighter._head_xform.
static func face(f: Fighter, race_id: String, skin: Color) -> void:
	var flesh := material(skin, 0.62)
	var key := "face_" + race_id
	match race_id:
		"Saiyan", "HalfSaiyan", "Human":
			var ns := float(f.face_params.get("nose", 1.0))
			var nose_at := Vector3(0, 1.665, 0.118)
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D(Basis.from_scale(Vector3(ns, ns, ns)), nose_at - nose_at * ns), _mesh(key + "_nose", func(g: Geo) -> void:
				g.tube(PackedVector3Array([Vector3(0, 1.694, 0.113), Vector3(0, 1.676, 0.122), Vector3(0, 1.659, 0.131)]), 0.0055, 0.0085, 10, 8)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.15, 0.85, 1.0)), Vector3(0, 1.654, 0.128)), 0.0105, 8, 10)
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 0.8)), Vector3(s * 0.0105, 1.651, 0.121)), 0.0075, 6, 8)), flesh), 1.0)
			f.add_skin_piece(f.add_piece("DEF-head", Transform3D.IDENTITY, _mesh(key, func(g: Geo) -> void:
				for s in [1, -1]:
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
	gear(f, id)
	match id:
		"vael":   # Vael the Unwound: a pale porcelain mask and a mantle of floating clock shards
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("vael_mask", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.15, 0.45)), Vector3(0, 0.05, 0.085)), 0.085, 10, 16)), material(Color.hex(0xf2eee6ff), 0.25))
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("vael_shards", func(g: Geo) -> void:
				for i in 9:
					var a := -1.1 + float(i) / 8.0 * 2.2
					g.box(Transform3D(Basis.from_euler(Vector3(0.3, a, 0.4 * sin(float(i)))), Vector3(sin(a) * 0.26, 1.48 + 0.04 * float(i % 3), -0.12 + cos(a) * -0.06)),
						Vector3(0.05, 0.22, 0.02))), material(Color.hex(0x8af0ffff), 0.15, 0.4))
		"morrigath":   # Warden Morrigath: a cage helm and heavy chains over the shoulders
			var iron := material(Color.hex(0x4a4a52ff), 0.4, 0.8)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("cagehelm", func(g: Geo) -> void:
				for i in 8:
					var a := float(i) / 8.0 * TAU
					g.cylinder(Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.12, 0.06, cos(a) * 0.12 - 0.005)), 0.008, 0.008, 0.26, 6)
				g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 0.18, -0.005)), 0.12, 0.012)
				g.torus(Transform3D(Basis.IDENTITY, Vector3(0, -0.05, -0.005)), 0.12, 0.012)), iron)
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("chains", func(g: Geo) -> void:
				for s in [1.0, -1.0]:
					for k in 7:
						g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2 if k % 2 == 0 else 0.0)), Vector3(s * (0.2 - k * 0.03), 1.45 - k * 0.05, 0.12 - k * 0.005)), 0.025, 0.008)), iron)
		"nyxara":   # Empress Nyxara: an obsidian crown and a long night-black cloak
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("nyx_crown", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -0.005)), 0.115, 0.11, 0.04, 20)
				for i in 7:
					var a := -1.2 + float(i) / 6.0 * 2.4
					g.spike(Vector3(sin(a) * 0.11, 0.17, cos(a) * 0.11), 0.07 + 0.04 * float(i == 3), 0.018, Vector3(sin(a) * 0.15, 1, cos(a) * 0.15))), material(Color.hex(0x1a1428ff), 0.15, 0.6))
			f.cape = f.add_piece("DEF-spine.003", Transform3D(Basis.from_euler(Vector3(0.06, 0, 0)), Vector3(0, 1.47, -0.155)), _mesh("nyx_cape", func(g: Geo) -> void:
				g.sheet(Transform3D.IDENTITY, 0.62, 1.3)), material(Color.hex(0x24123aff), 0.7, 0.0, true))
		"zero":   # Zero-Origin: a faceless head of light inside a halo
			var light := material(Color.hex(0xfff8e8ff), 0.1)
			light.emission_enabled = true; light.emission = Color.hex(0xfff0c8ff); light.emission_energy_multiplier = 2.5
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("zero_halo", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(0, 0.08, -0.12)), 0.17, 0.012)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.02, 1.05, 1.02)), Vector3(0, 0.055, 0.0)), 0.112, 12, 18)), light)
		"hollow":   # Hollow Kings: shadow copies with burning red eyes
			var eyes := material(Color.hex(0xff2020ff), 0.2)
			eyes.emission_enabled = true; eyes.emission = Color.hex(0xff1010ff); eyes.emission_energy_multiplier = 3.0
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("hollow_eyes", func(g: Geo) -> void:
				for s in [1.0, -1.0]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.3, 0.6, 0.5)), Vector3(s * 0.038, 0.06, 0.1)), 0.016, 6, 10)), eyes)
		"powerpole":   # kid Gokan: the red Power Pole strapped diagonally across the back
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("powerpole", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(0, 0, 0.55)), Vector3(0, 1.25, -0.16)), 0.022, 0.022, 1.3, 10)
				for e in [-0.6, 0.6]:
					g.cylinder(Transform3D(Basis.from_euler(Vector3(0, 0, 0.55)), Vector3(sin(0.55) * -e, 1.25 + cos(0.55) * e, -0.16)), 0.026, 0.026, 0.08, 10)), material(Color.hex(0xc8322aff), 0.5))
		"oxhelmet":   # the Ox-Lord: a big horned helmet
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("oxhelmet", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.1, 1.0, 1.15)), Vector3(0, 0.06, -0.01)), 0.12, PI * 0.42, PI * 0.6)
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.08, 0.05, 0.0), Vector3(s * 0.14, 0.16, 0.02)], Vector3(s * 0.1, 0.12, 0.0)), 0.03, 0.006, 12, 8)), material(Color.hex(0x7a6a5aff), 0.4, 0.5))
		"witchhat":   # Fortuneteller Baaba: a tall witch's hat (her crystal ball floats beside her: Parts piece on the hand)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("witchhat", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0)), 0.2, 0.2, 0.012, 24)
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, 0.14, -0.02), Vector3(0.02, 0.26, -0.08), Vector3(0.06, 0.3, -0.16)], Vector3(0, 0.13, 0)), 0.1, 0.008, 18, 14)), material(Color.hex(0x2a2a3aff), 0.7))
			f.add_piece("DEF-hand.L", Transform3D.IDENTITY, _mesh("crystalball", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0.8, 1.55, 0.05)), 0.14, 14, 18)), material(Color.hex(0x9fe0ffff), 0.05, 0.3))
		"braid":   # Mercenary Tau: one long braid down the back
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("braid", func(g: Geo) -> void:
				g.tube(_offset([Vector3(0, 0, 0), Vector3(0, -0.08, -0.06), Vector3(0, -0.24, -0.08), Vector3(0, -0.42, -0.06)], Vector3(0, 0.08, -0.11)), 0.03, 0.014, 20, 8)), material(Color.hex(0x141414ff), 0.8))
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

## Divine/alien gear (cast batch B1). Several can be worn at once (look.costume as an array).
static func gear(f: Fighter, id: String) -> void:
	gear_b3(f, id)   # Frieza Force / Frost Demon gear (scouters, horns, ...)
	match id:
		"halo":   # angels: a glowing pale-blue ring floating round the back of the neck
			var glow := material(Color.hex(0xbfe8ffff), 0.1)
			glow.emission_enabled = true; glow.emission = Color.hex(0x8fd4ffff); glow.emission_energy_multiplier = 1.6
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _mesh("halo", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), Vector3(0, 1.52, -0.07)), 0.15, 0.012, 36, 8)), glow)
		"potara", "potara_green":   # Kai earrings: a ring and a ball hanging from each ear lobe
			var col := 0x3fbf5a if id == "potara_green" else 0xf2c230
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("potara", func(g: Geo) -> void:
				for s in [1, -1]:
					g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.098, -0.005, 0.0)), 0.011, 0.004, 14, 6)
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.098, -0.03, 0.0)), 0.014, 8, 10)), material(Color.hex((col << 8) | 0xff), 0.3, 0.6))
		"shades":   # round black sunglasses
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("shades", func(g: Geo) -> void:
				for s in [1, -1]:
					g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(s * 0.042, 0.04, 0.108)), 0.028, 0.028, 0.008, 18)
				g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.048, 0.11)), Vector3(0.03, 0.006, 0.006))), material(Color.hex(0x101014ff), 0.15, 0.3))
		"cat_ears":   # tall pointed cat ears (the cat gods)
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("cat_ears", func(g: Geo) -> void:
				for s in [1, -1]:
					g.spike(Vector3(s * 0.075, 0.12, -0.015), 0.16, 0.055, Vector3(s * 0.4, 1, -0.1))), material(f.skin, 0.55)), 1.0)
		"ramhorns":   # thick ram horns curling back and down past the ears
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("ramhorns", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_offset([Vector3(0, 0, 0), Vector3(s * 0.05, 0.06, -0.04), Vector3(s * 0.1, 0.03, -0.11), Vector3(s * 0.12, -0.06, -0.08), Vector3(s * 0.11, -0.09, 0.0)], Vector3(s * 0.06, 0.13, 0.02)), 0.032, 0.01, 24, 10)), material(Color.hex(0xd9cfb0ff), 0.55))
		"turban":   # a white wrapped turban with a red jewel at the front
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("turban", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.08, 1.0, 1.1)), Vector3(0, 0.01, -0.008)), 0.132, PI * 0.4, PI * 0.58)
				g.torus(Transform3D(Basis.from_euler(Vector3(0.12, 0, 0)), Vector3(0, 0.04, -0.004)), 0.128, 0.024, 28, 8)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 1.0)), Vector3(0, 0.13, -0.02)), 0.075, 10, 14)), material(Color.hex(0xf2f0eaff), 0.8))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, _mesh("turban_jewel", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 0.6)), Vector3(0, 0.06, 0.15)), 0.017, 8, 10)), material(Color.hex(0xd8203aff), 0.2, 0.3))

static func _offset(pts: Array, o: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in pts:
		out.append(p + o)
	return out
