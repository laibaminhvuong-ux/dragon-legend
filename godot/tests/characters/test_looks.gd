extends TestCase
# Stage 6 Tasks 2 and 4: hair, race features and transformations. Every form applies on every race, the base
# look comes back exactly when the form ends, unknown forms are harmless, and swaps never leak nodes.

func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c

func test_hair_only_for_races_with_hair() -> void:
	for race: String in ["Saiyan", "Human", "HalfSaiyan", "Namekian", "FrostDemon", "Majin"]:
		var f := Fighter.create({"race": race, "hair": "Spiky"})
		var has_hair: bool = (Fighter.Tables().races[race].hairStyles as Array).has("Spiky")
		eq(f.hair != null, has_hair, "%s hair" % race)
		f.free()

func test_every_hair_style_builds() -> void:
	for h: String in Hair.BASE:
		var m := Hair.mesh(Hair.BASE[h])
		ok(m != null and m.get_surface_count() == 1 and m.get_aabb().size.y > 0.1, "%s builds a mesh" % h)
	for s: String in Hair.FORM_STYLES + ["flame_ssj1", "flame_ssj2"]:
		ok(Hair.mesh(s).get_aabb().size.y > 0.1, "form hair %s builds" % s)
	ok(Hair.mesh("goku") == Hair.mesh("goku"), "hair meshes are shared")

func test_race_features() -> void:
	var names := func(f: Fighter) -> Array:
		var out := []
		for a in f.skeleton.get_children():
			if a is BoneAttachment3D: out.append(a.bone_name)
		return out
	var saiyan := Fighter.create({"race": "Saiyan", "outfit": "SaiyanArmor"})
	ok("DEF-hips" in names.call(saiyan), "Saiyan tail on the hips")
	ok("DEF-upper_arm.L" in names.call(saiyan) and "DEF-upper_arm.R" in names.call(saiyan), "armour shoulder pads")
	saiyan.free()
	var frost := Fighter.create({"race": "FrostDemon"})
	ok(frost.dome != null, "Frost Demon dome")
	frost.free()
	var namek := Fighter.create({"race": "Namekian", "outfit": "NamekRobe"})
	ok(namek.cape != null, "Namekian robe has a cape")
	namek.free()

func test_every_form_applies_and_restores() -> void:
	var forms: Dictionary = Fighter.Tables().form_looks
	for race: String in ["Saiyan", "Namekian", "FrostDemon", "Majin", "Human"]:
		var f := Fighter.create({"race": race, "hair": "Spiky", "outfit": "TurtleGi"})
		var base_nodes := _count(f)
		var base_scale := f.body.scale
		var base_skin: Color = f.material.get_shader_parameter("skin_color")
		var base_hair: Mesh = f.hair.mesh if f.hair != null else null
		for id: String in forms:
			f.set_form(id)
			eq(f.form_id, id, "%s takes %s" % [race, id])
			f.set_form("")
			eq(f.body.scale, base_scale, "%s %s: size restored" % [race, id])
			eq(f.material.get_shader_parameter("skin_color"), base_skin, "%s %s: skin restored" % [race, id])
			eq(f.hair.mesh if f.hair != null else null, base_hair, "%s %s: hair restored" % [race, id])
		_flush(f)
		eq(_count(f), base_nodes, "%s: no nodes left behind by %d forms" % [race, forms.size()])
		f.free()

func test_form_changes_hair_eyes_and_size() -> void:
	var f := Fighter.create({"race": "Saiyan", "hair": "Spiky"})
	var base_hair: Mesh = f.hair.mesh
	f.set_form("SSJ3")
	ok(f.hair.mesh != base_hair, "SSJ3 hair")
	eq(f.material.get_shader_parameter("brows"), 0.0, "SSJ3 has no brows")
	eq(f.material.get_shader_parameter("eye_color"), Parts.hx(Fighter.Tables().form_looks.SSJ3.eyes), "SSJ3 eyes")
	f.set_form("SSJGrade3")
	near(f.body.scale.x, 1.42, 1e-5, "Grade 3 bulk")
	f.set_form("")
	f.free()

func test_unknown_form_shows_base() -> void:
	var f := Fighter.create({"race": "Majin"})
	var skin: Color = f.material.get_shader_parameter("skin_color")
	f.set_form("NoSuchForm")
	eq(f.material.get_shader_parameter("skin_color"), skin, "unknown form keeps the base skin")
	eq(f.body.scale, f.base_scale, "and the base size")
	f.free()

func test_fifty_swaps_do_not_leak() -> void:
	var f := Fighter.create({"race": "Saiyan", "hair": "Swept"})
	var base := _count(f)
	for i in 50:
		f.set_form(["SSJ4", "SSJ", "Beast", ""][i % 4])
		_flush(f)
	f.set_form("")
	_flush(f)
	eq(_count(f), base, "50 swaps leave the node count unchanged")
	f.free()

func _flush(_f: Fighter) -> void:
	pass  # fighters not in the tree free their form nodes immediately

func test_form_aura_and_great_ape() -> void:
	var f := Fighter.create({"race": "Saiyan", "hair": "Spiky"})
	f.set_form("SSJ2")
	ok(f.form_aura != null and f.form_aura.bolts != null, "SSJ2 aura crackles with lightning")
	ok(f.form_aura.burst > 0.9, "transforming flares the aura")
	f.update(0.5, {})
	ok(f.form_aura.burst < 0.5, "the flare fades")
	f.set_form("SSJBlue")
	ok(f.form_aura.motes != null, "Blue has rising glitter")
	f.set_form("Oozaru")
	ok(f.ape != null and not f.skeleton.visible, "Great Ape replaces the body")
	near(f.body.scale.y, 3.2, 1e-5, "and is huge")
	f.update(1.0 / 60.0, {"speed": 6.0, "attackSerial": 1})
	f.set_form("")
	ok(f.ape == null and f.form_aura == null and f.skeleton.visible, "base form: no ape, no aura")
	f.free()

func test_charge_and_kaioken_auras() -> void:
	var f := Fighter.create({"race": "Human", "kiColor": 2})
	f.update(1.0 / 60.0, {"charging": true})
	ok(f.charge_aura != null and f.charge_aura.visible, "charging shows the Ki aura")
	eq(f.charge_aura.look.color, f.ki_color(), "in the fighter's Ki colour")
	f.set_ki_color(0x63cfff)
	eq(f.ki_color(), 0x63cfff, "custom Ki hex")
	f.update(1.0 / 60.0, {})
	ok(not f.charge_aura.visible, "hidden when charging stops")
	f.update(1.0 / 60.0, {"kaioken": 3})
	ok(f.kaioken_aura != null and f.kaioken_aura.visible, "Kaiyoken overlay aura")
	f.update(1.0 / 60.0, {"kaioken": 0})
	ok(not f.kaioken_aura.visible, "overlay off")
	f.dispose()
