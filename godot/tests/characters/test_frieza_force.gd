extends TestCase
# Cast batch B3: Frieza Force armour, FrostBody, scouter/horn gear, dome/shell colours, skinMetal and the Frigor
# form extras (form_looks chitin / shells / gear; fields at the top of characters/outfits.gd).

func _has(f: Fighter, key: String) -> bool:
	if not Parts._meshes.has(key):
		return false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes[key]:
			return true
	return false

func test_outfits() -> void:
	var ff := Outfits.parts("FriezaForce", 0x1c2a5c)
	ok(ff.armor.flaps and ff.armor.belly and not ff.armor.pads, "FriezaForce: flaps and belly panel, no round pads")
	eq(ff.top, 0x1c2a5c, "suit is the tint")
	var bare := BodyRegions.colours(Outfits.parts("FrostBody", 0))
	for c in bare:
		eq(c.a, 0.0, "FrostBody: every region shows the skin")
	var p := Outfits.for_look({"outfit": "FriezaForce", "outfitParts": {"flaps": false, "pants": "skin"}}, 0x1c2a5c)
	ok(not p.armor.flaps, "outfitParts flaps false")
	eq(BodyRegions.colours(p)[BodyRegions.PANTS].a, 0.0, "\"skin\" region shows the skin")
	var f := Fighter.create({"race": "Saiyan", "outfit": "FriezaForce", "costume": ["scouter", "mustache"]})
	ok(_has(f, "ff_flap1") and _has(f, "ff_flap-1") and _has(f, "ff_hip1") and _has(f, "ff_belly"), "flap, hip flap and belly pieces")
	ok(_has(f, "scouter_unit") and _has(f, "scouter_lens") and _has(f, "mustache"), "scouter and moustache gear")
	f.free()

func test_dome_shell_metal() -> void:
	var f := Fighter.create({"race": "FrostDemon", "outfit": "FrostBody", "domeRgb": 0x2a5ad8, "shellRgb": 0x8a3ab8, "skinMetal": 0.6})
	eq((f.dome.material_override as StandardMaterial3D).albedo_color, Parts.hx(0x2a5ad8), "own dome colour")
	var shells: Array = f.get_meta("shells")
	eq(shells.size(), 3, "two shoulder shells and the chest shell")
	eq((shells[0] as MeshInstance3D).material_override.albedo_color, Parts.hx(0x8a3ab8), "own shell colour")
	near(float(f.material.get_shader_parameter("skin_metal")), 0.6, 1e-4, "skinMetal")
	f.set_form("Golden")
	f.set_form("")
	eq((f.dome.material_override as StandardMaterial3D).albedo_color, Parts.hx(0x2a5ad8), "own dome back after a form")
	near(float(f.material.get_shader_parameter("skin_metal")), 0.6, 1e-4, "skinMetal back after a form")
	f.free()

func test_frigor_forms() -> void:
	var fl: Dictionary = Fighter.Tables().form_looks
	for id: String in ["FirstForm", "SecondForm", "ThirdForm", "FinalFormFrost", "FrostAssault", "ZarbonMonster"]:
		ok(fl.has(id), "form look %s" % id)
	var f := Fighter.create(Fighter.Tables().characters.frieza.look)
	var base: PackedColorArray = f.material.get_shader_parameter("colors")
	f.set_form("SecondForm")
	ok(_has(f, "frost_horns_big"), "2nd form horns")
	eq((f.material.get_shader_parameter("colors") as PackedColorArray)[BodyRegions.PLATE].a, 1.0, "chitin torso")
	ok(f.body.scale.y > f.base_scale.y * 1.2, "2nd form is taller")
	f.set_form("ThirdForm")
	ok(_has(f, "third_crest") and not _has(f, "frost_horns_big"), "3rd form crest, horns gone")
	f.set_form("")
	ok(not _has(f, "third_crest"), "form gear removed")
	eq(f.material.get_shader_parameter("colors"), base, "outfit colours restored")
	f.free()

func test_b3_cast_builds() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["frieza", "golden_frieza", "black_frieza", "mecha_frieza", "king_cold", "frost", "zarbon", "dodoria", "ginyu",
			"recoome", "burter", "guldo", "jeice", "frieza_soldier", "sorbet", "tagoma", "raditz", "nappa", "saibaman", "lemo", "giran"]:
		ok(chars.has(id), "%s exists" % id)
		var f := Fighter.create(chars[id].look)
		ok(f.anim != null, "%s builds" % id)
		f.free()
	var g := Fighter.create(chars.golden_frieza.look)
	eq(g.form_id, "Golden", "Golden Frigor spawns golden")
	g.free()
	eq(Parts.features("Majin", chars.ginyu.look).antenna, "", "Ginnu: no Buu antenna")
	ok(not Parts.features("FrostDemon", chars.burter.look).dome, "Burtor: no Frost dome")
