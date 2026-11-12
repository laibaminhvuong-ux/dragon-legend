extends TestCase
# Cast batch B4: Boo saga, Cyborgs, Cel, Red Ribbon (skin patterns, face colour, Majin mark, wings, RRUniform,
# Cel stages; fields at the top of characters/outfits.gd, code in characters/cast_b4.gd).

func _has(f: Fighter, key: String) -> bool:
	if not Parts._meshes.has(key):
		return false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes[key]:
			return true
	return false

func test_rr_uniform_and_extras() -> void:
	var p := Outfits.parts("RRUniform", 0x2a4ab0)
	eq(p.top, 0x2a4ab0, "jacket is the tint")
	ok(p.sleeves and p.has("badge"), "long sleeves and a chest badge")
	ok(not Outfits.ALL.has("RRUniform"), "NPC-only outfit")
	var f := Fighter.create({"race": "Human", "outfit": "RRUniform", "outfitParts": {"epaulettes": 0xe0b040, "cape": 0xc8202a, "cape_collar": 0xe8662a}})
	ok(_has(f, "rr_badge") and _has(f, "epaulette1") and _has(f, "cape_collar") and f.cape != null, "badge, epaulettes, cape and wizard collar")
	f.free()
	var g := Fighter.create({"race": "Human", "outfit": "RRUniform", "outfitParts": {"badge": false}})
	ok(not _has(g, "rr_badge"), "badge false removes it")
	g.free()

func test_skin_pattern_face_mark() -> void:
	var f := Fighter.create({"race": "Namekian", "raceParts": false, "skinPattern": "spots", "patternRgb": 0x1e3a12, "faceRgb": 0xeceaf2, "mark": "majin"})
	eq(int(f.material.get_shader_parameter("skin_pattern")), 1, "spots")
	eq(f.material.get_shader_parameter("pattern_color"), Parts.hx(0x1e3a12), "spot colour")
	near((f.material.get_shader_parameter("face_tint") as Color).a, 1.0, 1e-4, "face colour on")
	near(float(f.material.get_shader_parameter("forehead_mark")), 1.0, 1e-4, "Majin M")
	f.set_form("SSJ")
	f.set_form("")
	eq(int(f.material.get_shader_parameter("skin_pattern")), 1, "pattern survives a form")
	f.free()
	var plain := Fighter.create({"race": "Human"})
	eq(int(plain.material.get_shader_parameter("skin_pattern")), 0, "no pattern by default")
	near((plain.material.get_shader_parameter("face_tint") as Color).a, 0.0, 1e-4, "no face colour by default")
	near(float(plain.material.get_shader_parameter("forehead_mark")), 0.0, 1e-4, "no mark by default")
	plain.free()

func test_cell_stages() -> void:
	var fl: Dictionary = Fighter.Tables().form_looks
	for id: String in ["CellImperfect", "CellSemiPerfect", "CellPerfect", "CellSuperPerfect"]:
		ok(fl.has(id), "form look %s" % id)
	var f := Fighter.create(Fighter.Tables().characters.cell.look)
	ok(_has(f, "cell_crest") and _has(f, "cell_wing1") and _has(f, "cell_wing-1"), "crest and wings")
	eq(Parts.features("Namekian", f.look).antenna, "", "no Namek antennae")
	f.set_form("CellImperfect")
	ok(_has(f, "cell_tail") and _has(f, "cell_beak"), "Imperfect: stinger tail and beak")
	f.set_form("CellSemiPerfect")
	ok(_has(f, "cell_tail") and not _has(f, "cell_beak"), "Semi-Perfect: tail, no beak")
	ok(f.body.scale.x > f.base_scale.x * 1.2, "Semi-Perfect is bulky")
	f.set_form("CellSuperPerfect")
	ok(not _has(f, "cell_tail") and f.form_aura != null, "Super Perfect: no tail, aura")
	f.set_form("")
	ok(not _has(f, "cell_tail"), "form gear removed")
	f.free()

func test_b4_cast_builds() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["fat_buu", "super_buu", "kid_buu", "babidi", "dabura", "pui_pui", "yakon", "spopovich", "android_8", "android_16",
			"android_17", "android_18", "android_19", "gero", "hedo", "gamma1", "gamma2", "magenta", "cell", "cell_jr", "cell_max", "red",
			"blue", "white", "silver"]:
		ok(chars.has(id), "%s exists" % id)
		var f := Fighter.create(chars[id].look)
		ok(f.anim != null, "%s builds" % id)
		f.free()
	for id: String in ["dabura", "ginyu", "gamma1", "gamma2", "babidi", "android_19", "yakon"]:
		eq(Parts.features(str(chars[id].look.race), chars[id].look).antenna, "", "%s: no Buu antenna" % id)
	eq(Parts.features("Majin", chars.kid_buu.look).antenna, "buu", "Kid Boo keeps his antenna")
	eq(str(chars.spopovich.look.get("mark", "")), "majin", "Spopovik has the M")
