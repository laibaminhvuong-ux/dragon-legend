class_name FaceGear
extends RefCounted
# Cast batch B5 (Earth humans): glasses, headwear, a third eye, face marks, jewellery and neckwear, each a look field
# (documented at the top of outfits.gd). Facial hair is Parts.facial_hair. Called from Parts.dress; looks without
# these fields get nothing. Head pieces are in Hair.HEAD_SPACE (head centre about (0, 0.06, 0), radius about 0.105,
# +Z is the face; eyes at y 0.04, x ±0.042, face front z about 0.105; the character's left is +X).

const GOLD := 0xe0b040

static func dress(f: Fighter) -> void:
	var L := f.look
	if L.get("glasses") is String and str(L.glasses) != "":
		glasses(f, str(L.glasses), _col(L.get("glassesRgb"), 0x18181c))
	if L.get("hat") is String and str(L.hat) != "":
		hat(f, str(L.hat), _col(L.get("hatRgb"), 0xc8322a), _col(L.get("hatRgb2"), 0xd8202a))
	if L.get("thirdEye", false) == true:
		third_eye(f)
	for m: Variant in _list(L.get("faceMarks")):
		mark(f, str(m), Outfits.rgb(L.get("markRgb")))
	for j: Variant in _list(L.get("jewellery")):
		jewel(f, str(j), _col(L.get("jewelRgb"), GOLD))
	if L.get("neckwear") is String and str(L.neckwear) != "":
		neckwear(f, str(L.neckwear), _col(L.get("neckRgb"), 0xf0c832))

static func _col(v: Variant, fallback: int) -> int:
	var c := Outfits.rgb(v)
	return c if c >= 0 else fallback

static func _list(v: Variant) -> Array:
	if v is Array: return v
	if v is String and v != "": return [v]
	return []

static func _head(f: Fighter, key: String, mat: Material, build: Callable) -> MeshInstance3D:
	return f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("fg_" + key, build), mat)

# ------------------------------------------------------------------------------------------------ glasses
## "round" (thin round frames, clear lenses: Jackie Chung, Dr. Brisk), "sunglasses" (dark rounded lenses: Master
## Roshu), "square" (rectangular frames: the Ox-Lord).
static func glasses(f: Fighter, kind: String, frame: int) -> void:
	var fm := Parts.material(Parts.hx(frame), 0.3, 0.4)
	_head(f, "temples", fm, func(g: Geo) -> void:
		for s in [1, -1]:
			g.box(Transform3D(Basis.from_euler(Vector3(0, s * 0.12, 0)), Vector3(s * 0.086, 0.046, 0.055)), Vector3(0.004, 0.005, 0.1))
		g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.046, 0.112)), Vector3(0.026, 0.005, 0.005)))
	match kind:
		"sunglasses":
			_head(f, "sunglasses", Parts.material(Color.hex(0x0c0c10ff), 0.08, 0.5), func(g: Geo) -> void:
				for s in [1, -1]:
					g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)) * Basis.from_scale(Vector3(1.2, 1.0, 0.85)), Vector3(s * 0.042, 0.04, 0.109)), 0.026, 0.026, 0.008, 20))
		"square":
			_head(f, "square_frames", fm, func(g: Geo) -> void:
				for s in [1, -1]:
					for e in [-1.0, 1.0]:
						g.box(Transform3D(Basis.IDENTITY, Vector3(s * 0.042, 0.04 + e * 0.018, 0.11)), Vector3(0.05, 0.005, 0.006))
						g.box(Transform3D(Basis.IDENTITY, Vector3(s * 0.042 + e * 0.025, 0.04, 0.11)), Vector3(0.005, 0.04, 0.006)))
			_head(f, "square_lens", Parts._lens(0xd8e8f0), func(g: Geo) -> void:
				for s in [1, -1]:
					g.box(Transform3D(Basis.IDENTITY, Vector3(s * 0.042, 0.04, 0.109)), Vector3(0.048, 0.034, 0.002)))
		_:   # round
			_head(f, "round_frames", fm, func(g: Geo) -> void:
				for s in [1, -1]:
					g.torus(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(s * 0.042, 0.04, 0.11)), 0.024, 0.0035, 22, 6))
			_head(f, "round_lens", Parts._lens(0xd8e8f0), func(g: Geo) -> void:
				for s in [1, -1]:
					g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(s * 0.042, 0.04, 0.109)), 0.022, 0.022, 0.002, 18))

# ------------------------------------------------------------------------------------------------ headwear
## "skullcap" (young Tenzo), "pompom" (a round Chinese cap with a ball on top: Chaozo, Grandpa Gohin), "beanie" (Future
## Mae), "bandana" (cloth tied at the back), "turban" (Namu), "headband" (a band round the forehead: Murasake), "ribbon" (a bow at
## the side-ponytail tie: young Bulna). colour = look.hatRgb, second colour (pompom, band, knot) = look.hatRgb2.
static func hat(f: Fighter, kind: String, c1: int, c2: int) -> void:
	var m1 := Parts.material(Parts.hx(c1), 0.75, 0.0, true)   # caps are open shells: draw both sides
	var m2 := Parts.material(Parts.hx(c2), 0.7)
	match kind:
		"skullcap", "pompom":
			_head(f, "skullcap", m1, func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.0, 1.02, 1.1)), Vector3(0, 0.05, -0.008)), 0.12, PI * 0.33, PI * 0.55))
			if kind == "pompom":
				_head(f, "pompom", m2, func(g: Geo) -> void:
					g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.178, -0.008)), 0.006, 0.008, 0.02, 8)
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 0.196, -0.008)), 0.017, 8, 10))
		"beanie":
			_head(f, "beanie", m1, func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.02, 1.1, 1.1)), Vector3(0, 0.05, -0.008)), 0.124, PI * 0.38, PI * 0.56)
				g.torus(Transform3D(Basis.from_euler(Vector3(-0.31, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.08)), Vector3(0, 0.075, -0.006)), 0.122, 0.014, 32, 8))
		"bandana":
			_head(f, "bandana", m1, func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.02, 1.02, 1.1)), Vector3(0, 0.05, -0.008)), 0.122, PI * 0.38, PI * 0.58)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 0.03, -0.128)), 0.016, 8, 10)
				for s in [1.0, -1.0]:
					g.tube(PackedVector3Array([Vector3(s * 0.006, 0.03, -0.13), Vector3(s * 0.025, -0.02, -0.14), Vector3(s * 0.035, -0.08, -0.13)]), 0.014, 0.006, 10, 6, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.4)), Vector3(0, 0, -0.078))))
		"headband":
			_head(f, "headband", m1, func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(-0.2, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.1)), Vector3(0, 0.1, -0.008)), 0.114, 0.011, 32, 6)
				for s in [1.0, -1.0]:
					g.tube(PackedVector3Array([Vector3(s * 0.005, 0.07, -0.125), Vector3(s * 0.02, 0.03, -0.14), Vector3(s * 0.03, -0.03, -0.15)]), 0.012, 0.006, 10, 6))
		"turban":   # a plain wrapped turban sitting high on the head (Namu); hatRgb2 = an optional front jewel
			_head(f, "turban_b5", m1, func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.02, 1.04, 1.1)), Vector3(0, 0.05, -0.008)), 0.122, PI * 0.38, PI * 0.54)
				for k in 3:
					g.torus(Transform3D(Basis.from_euler(Vector3(-0.28 + k * 0.12, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.08)), Vector3(0, 0.092 + k * 0.025, -0.008)), 0.118 - k * 0.016, 0.018, 28, 8)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0, 0.162, -0.01)), 0.06, 10, 14))
		"ribbon":   # a bow where the side ponytail is tied (Hair "sideponytail")
			_head(f, "ribbon", m1, func(g: Geo) -> void:
				var tie := Vector3(0.094, 0.13, -0.05)
				for e in [-1.0, 1.0]:
					g.sphere(Transform3D(Basis.from_euler(Vector3(0, 0, e * 0.6)) * Basis.from_scale(Vector3(0.45, 1.4, 1.0)), tie + Vector3(0.008, e * 0.026, 0.0)), 0.02, 8, 10)
				g.sphere(Transform3D(Basis.IDENTITY, tie), 0.011, 6, 8))
		_:
			push_warning("FaceGear: unknown hat %s" % kind)

# ------------------------------------------------------------------------------------------------ face
## Tenzo's third eye: an upright eye in the middle of the forehead.
static func third_eye(f: Fighter) -> void:
	_head(f, "third_eye", Parts.material(Color.hex(0xf6f4eeff), 0.3), func(g: Geo) -> void:
		g.sphere(Transform3D(Basis.from_scale(Vector3(0.72, 1.25, 0.35)), Vector3(0, 0.093, 0.092)), 0.017, 8, 12))
	_head(f, "third_pupil", Parts.material(Color.hex(0x18120eff), 0.3), func(g: Geo) -> void:
		g.sphere(Transform3D(Basis.from_scale(Vector3(0.9, 1.15, 0.4)), Vector3(0, 0.093, 0.097)), 0.0075, 6, 8))
	_head(f, "third_lids", Parts.material(f.skin.darkened(0.45), 0.6), func(g: Geo) -> void:
		for e in [-1.0, 1.0]:
			g.tube(PackedVector3Array([Vector3(0, 0.093 + e * 0.023, 0.09), Vector3(e * 0.01, 0.093, 0.096), Vector3(0, 0.093 - e * 0.023, 0.09)]), 0.0022, 0.0022, 10, 5))

## Face marks: "dots" (six forehead dots: Krilan), "cheek_circles" (round red cheeks: Chaozo), "scar_cheek" (an X scar
## on the left cheek) and "scar_eye" (a scar down over the right eye: Yamcho). colour = look.markRgb.
static func mark(f: Fighter, kind: String, colour: int) -> void:
	match kind:
		"dots":
			_head(f, "dots", Parts.material(Parts.hx(colour if colour >= 0 else 0x5a3a2a), 0.7), func(g: Geo) -> void:
				for row in 2:
					for col in 3:
						var y := 0.1 + row * 0.019
						g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.4)), Vector3((col - 1) * 0.019, y, 0.101 - row * 0.008 - absf(col - 1) * 0.002)), 0.0048, 6, 8))
		"cheek_circles":
			_head(f, "cheeks", Parts.material(Parts.hx(colour if colour >= 0 else 0xe0505a), 0.6), func(g: Geo) -> void:
				for s in [1.0, -1.0]:
					var at := Vector3(s * 0.055, -0.022, 0.09)
					var n := Vector3(s * 0.6, 0, 1.0).normalized()
					g.cylinder(Transform3D(Basis(Quaternion(Vector3.UP, n)), at), 0.014, 0.014, 0.004, 16))
		"scar_cheek", "scar_eye":
			var sm := Parts.material(Parts.hx(colour if colour >= 0 else 0x9a4a3a), 0.6)
			if kind == "scar_cheek":
				_head(f, "scar_cheek", sm, func(g: Geo) -> void:
					for e in [-1.0, 1.0]:
						g.tube(PackedVector3Array([Vector3(0.054 - 0.012 * e, -0.004, 0.09), Vector3(0.056, -0.017, 0.092), Vector3(0.058 + 0.012 * e, -0.03, 0.087)]), 0.0022, 0.0018, 8, 5))
			else:
				_head(f, "scar_eye", sm, func(g: Geo) -> void:
					g.tube(PackedVector3Array([Vector3(-0.034, 0.078, 0.1), Vector3(-0.039, 0.056, 0.106), Vector3(-0.043, 0.026, 0.108), Vector3(-0.046, 0.008, 0.102)]), 0.0022, 0.0018, 10, 5))
		_:
			push_warning("FaceGear: unknown face mark %s" % kind)

# ------------------------------------------------------------------------------------------------ jewellery
## "champion_belt" (a wide gold belt with a big front plate: Mr. Sadan), "earrings" (hoops: Princess Serpa),
## "bracelets", "necklace". colour = look.jewelRgb (default gold).
static func jewel(f: Fighter, kind: String, colour: int) -> void:
	var gm := Parts.material(Parts.hx(colour), 0.28, 0.75)
	match kind:
		"champion_belt":
			var loose := float(f.cloth.get("amount", 0.0))
			var waist := lerpf(Parts._sc(f, "waist"), Parts._sc(f, "hips"), 0.4)
			var fit := Parts._fit(f, Vector3(0, 0.965, -0.008), waist * 1.04 * (1.0 + 0.11 * loose), (waist + float(f.sculpt.get("belly", 0.0)) * 4.0) * (1.04 + 0.13 * loose))
			f.add_piece("DEF-hips", fit, Parts._mesh("fg_champ_belt", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_scale(Vector3(1, 1, 0.8)), Vector3(0, 0.965, -0.008)), 0.172, 0.17, 0.07, 32)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.75, 0.25)), Vector3(0, 0.965, 0.128)), 0.07, 10, 16)), gm)
			f.add_piece("DEF-hips", fit, Parts._mesh("fg_champ_gem", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.5)), Vector3(0, 0.965, 0.145)), 0.022, 8, 10)), Parts.material(Color.hex(0xc8202aff), 0.2, 0.3))
		"earrings":
			_head(f, "earrings", gm, func(g: Geo) -> void:
				for s in [1, -1]:
					g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.1, -0.018, 0.0)), 0.016, 0.0035, 16, 6))
		"bracelets":
			for s in [1, -1]:
				f.add_piece("DEF-forearm." + ("L" if s > 0 else "R"), Transform3D.IDENTITY, Parts._mesh("fg_bracelet%d" % s, func(g: Geo) -> void:
					g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.69, 1.4408, -0.068)), 0.05, 0.007, 22, 6)), gm)
		"necklace":
			f.add_piece("DEF-spine.003", Parts._fit(f, Vector3(0, 1.45, 0.0), Parts._sc(f, "neck"), Parts._sc(f, "neck")), Parts._mesh("fg_necklace", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(0.45, 0, 0)), Vector3(0, 1.44, 0.01)), 0.1, 0.005, 32, 6)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0.1)), 0.013, 8, 10)), gm)
		_:
			push_warning("FaceGear: unknown jewellery %s" % kind)

## "scarf" (a knotted neck scarf with a short tail: Bulna) or "fur_collar" (a thick white fur ruff: Princess Serpa).
## colour = look.neckRgb.
static func neckwear(f: Fighter, kind: String, colour: int) -> void:
	var fit := Parts._fit(f, Vector3(0, 1.47, -0.012), Parts._sc(f, "neck") * Parts._sc(f, "shoulders"), Parts._sc(f, "neck"))
	match kind:
		"scarf":
			f.add_piece("DEF-spine.003", fit, Parts._mesh("fg_scarf", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(0.2, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 0.9)), Vector3(0, 1.475, -0.005)), 0.085, 0.024, 28, 8)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0.03, 1.455, 0.085)), 0.022, 8, 10)
				g.tube(PackedVector3Array([Vector3(0.03, 1.45, 0.09), Vector3(0.045, 1.4, 0.11), Vector3(0.05, 1.33, 0.115)]), 0.02, 0.012, 10, 6, Transform3D.IDENTITY)), Parts.material(Parts.hx(colour), 0.8))
		"fur_collar":
			f.add_piece("DEF-spine.003", fit, Parts._mesh("fg_fur", func(g: Geo) -> void:
				for i in 18:
					var a := TAU * i / 18.0
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.12, 1.46 + 0.012 * float(i % 2), cos(a) * 0.105 - 0.01)), 0.042, 6, 8)), Parts.material(Parts.hx(colour), 0.95))
		_:
			push_warning("FaceGear: unknown neckwear %s" % kind)
