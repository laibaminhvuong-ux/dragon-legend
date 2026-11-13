extends TestCase
# Cast fixes (2026-11-13): broad-shoulder sculpt fold (Brolo), hair on hairless races (form hair, skull fit), Namekian
# size forms (Giant size, Orange robeOff), dresses (characters/skirt.gd), the cat creatures and the seated Grand Elder.

func _visible_mesh(f: Fighter, mesh: Mesh) -> bool:
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == mesh and mi.is_visible_in_tree():
			return true
	return false

func test_broad_shoulders_do_not_fold() -> void:
	var pr := BodySculpt.combine(BodySculpt.profile_for({"race": "Saiyan", "build": "Muscular", "physique": "brolo"}), {})
	ok(float(pr.shoulders) > 1.2, "Brolo is broad (%.2f)" % float(pr.shoulders))
	var last := -1.0
	for i in 40:   # along the arm at shoulder height: the sculpted x keeps growing (no fold over the deltoid)
		var x := 0.16 + 0.01 * i
		var q := BodySculpt.shape(Vector3(x, 1.44, -0.065), Vector3.UP, pr)
		ok(q.x > last, "arm x monotonic at %.2f" % x)
		last = q.x
	# the thick neck no longer pushes the top of the shoulder out as far as the shoulders themselves
	var trap := BodySculpt.shape(Vector3(0.2, 1.5, -0.02), Vector3.UP, pr)
	ok(trap.x < 0.28, "trapezius not widened by the neck (%.3f)" % trap.x)

func test_hairless_races_grow_no_form_hair() -> void:
	var races: Dictionary = Fighter.Tables().races
	ok(not Hair.race_has_hair({}, races.Namekian), "Namekians have no hair")
	ok(Hair.race_has_hair({"hairAnyRace": true}, races.FrostDemon), "hairAnyRace allows it")
	ok(Hair.race_has_hair({}, races.Saiyan), "Saiyans have hair")
	for race: String in ["Namekian", "FrostDemon", "Majin"]:
		var f := Fighter.create({"race": race, "hair": "Spiky"})
		ok(f.hair == null, "%s: bald" % race)
		f.set_form("SSJ")   # a form look with hair "ssj1" (and UIOmen's "same")
		ok(f.hair == null, "%s: no Super Saiyan hair" % race)
		f.set_form("UIOmen")
		ok(f.hair == null, "%s: no 'same' form hair" % race)
		f.set_form("")
		f.free()
	var s := Fighter.create({"race": "Saiyan", "hair": "Spiky"})
	s.set_form("SSJ")
	ok(s.hair != null, "a Saiyan still gets Super Saiyan hair")
	s.free()

func test_hair_fits_hairless_skulls() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["merus", "cheelai", "supreme_kai", "zamasu"]:
		var f := Fighter.create(chars[id].look)
		ok(f.hair != null, "%s has hair" % id)
		ok(f._hair_fit != Transform3D.IDENTITY, "%s: hair refitted to the race's skull" % id)
		var sk := Hair.skull(f.body_mesh.mesh)
		var rest := f.skeleton.get_bone_global_rest(f.skeleton.find_bone("DEF-head")) * f.hair.transform
		var low := 9.0   # the hair's lowest point over the crown centre: on the scalp, not floating above it
		for p: Vector3 in f.hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var q: Vector3 = rest * p
			if absf(q.x) < 0.03 and absf(q.z - 0.0) < 0.05:
				low = minf(low, q.y)
		ok(low < float(sk.top) + 0.01, "%s: hair sits on the crown (%.3f vs %.3f)" % [id, low, float(sk.top)])
		f.free()
	var g := Fighter.create(chars.goku.look)
	eq(g._hair_fit, Transform3D.IDENTITY, "races with hair keep their placement")
	g.free()

func test_namekian_size_forms() -> void:
	var T := Fighter.Tables()
	near(float(T.forms.Giant.size), 3.0, 1e-6, "Giant Form has a size (camera, reach, Ki origin)")
	near(float(T.form_looks.Giant.scale), float(T.forms.Giant.size), 1e-6, "drawn as big as it fights")
	ok(T.form_looks.Orange.get("robeOff", false), "Orange drops the robe")
	var f := Fighter.create(T.characters.piccolo.look)
	var turban: Mesh = Parts._meshes["b6_namek_turban"]
	ok(_visible_mesh(f, turban) and f.cape.visible, "base: turban and cape")
	f.set_form("Orange")
	ok(not _visible_mesh(f, turban) and not f.cape.is_visible_in_tree(), "Orange: no turban, no cape")
	ok(_visible_mesh(f, Parts._meshes["antennae"]), "Orange: antennae out")
	ok(f.body.scale.x / f.base_scale.x > f.body.scale.y / f.base_scale.y, "Orange: bulkier than taller")
	f.set_form("Giant")
	ok(_visible_mesh(f, turban), "Giant keeps the turban")
	near(f.body.scale.y, f.base_scale.y * 3.0, 1e-4, "Giant body x3")
	f.set_form("")
	ok(_visible_mesh(f, turban) and f.cape.visible, "back to base: robe back")
	f.free()

func test_dresses() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	eq(str(chars.bulma.look.outfit), "Dress", "Bulna wears a dress")
	eq(str(chars.chichi.look.outfit), "LongDress", "Chi-Mei wears a long dress")
	var p := Outfits.for_look({"outfit": "LongDress", "outfitParts": {"skirtLen": 0.84}}, 0xc83232)
	near(float(p.skirtLen), 0.84, 1e-6, "skirtLen override")
	ok(Outfits.for_look({"outfit": "TurtleGi"}, 0xc83232).get("skirt") == null, "gi: no skirt")
	for id: String in ["bulma", "chichi", "bulma_young", "princess_snake", "baba"]:
		var f := Fighter.create(chars[id].look)
		eq(f.skirt.size(), 2, "%s: two skirt halves" % id)
		for i in 3:
			f.update(1.0 / 30.0, {"speed": 4.0, "onGround": true})   # (Skirt.update runs every frame)
		var half: MeshInstance3D = (f.skirt[0] as Array)[0]
		ok(half.transform.origin.is_finite() and absf(half.transform.basis.determinant() - 1.0) < 0.01, "%s: skirt transform sane" % id)
		f.free()
	# the swing a half follows: a thigh kicked forward / spread outwards (hips at rest, thigh hanging down)
	var hr := Basis.IDENTITY
	var rest := Basis(Vector3.RIGHT, PI)   # the leg bone's +Y points down
	var fwd := Skirt.angles(hr, Basis(Vector3.RIGHT, -0.6) * rest, rest)
	ok(fwd.x > 0.5 and absf(fwd.y) < 0.01, "forward kick swings the half forward (%s)" % fwd)
	var side := Skirt.angles(hr, Basis(Vector3.BACK, 0.3) * rest, rest)
	ok(side.y > 0.25 and absf(side.x) < 0.01, "spread swings it out (%s)" % side)
	ok(Skirt.angles(hr, rest, rest).length() < 1e-5, "standing straight: no swing")
	var g := Fighter.create({"race": "Human", "outfit": "TurtleGi"})
	ok(g.skirt.is_empty(), "no skirt on a gi")
	g.free()

func test_cat_creatures_and_seated_elder() -> void:
	var T := Fighter.Tables()
	for id: String in ["puar", "korin"]:
		var f := Fighter.create(T.characters[id].look)
		ok(f.get_meta("creature", false) and not f.body_mesh.visible, "%s: a round cat, not a man" % id)
		ok(_visible_mesh(f, Parts._meshes["b6_cat_body"]) and _visible_mesh(f, Parts._meshes["b6_cat_head"]), "%s: cat body and head" % id)
		f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
		f.free()
	var guru: Dictionary = {}
	for n: Dictionary in T.npcs:
		if n.get("id") == "guru":
			guru = n
	ok(guru.get("sit", false), "the Grand Elder sits")
	ok((T.characters.guru.look.costume as Array).has("seat_stool"), "on a stool")
	eq(T.characters.guru.look.outfitParts.get("cape"), false, "his look keeps its own outfit parts")
