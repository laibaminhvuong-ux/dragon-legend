extends TestCase
# Cast batch B1: per-look race-part toggles, hair on any race, free hair/eye/outfit colours and costume lists
# (fields documented at the top of characters/outfits.gd). Looks without the new fields must draw as before.

func _meshes(f: Fighter) -> Array:
	var out := []
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		out.append(mi.mesh)
	return out

func _has(f: Fighter, key: String) -> bool:
	return Parts._meshes.has(key) and _meshes(f).has(Parts._meshes[key])

func test_race_defaults_unchanged() -> void:
	eq(Parts.features("Saiyan", {}).tail, "saiyan", "Saiyan tail by default")
	var frost := Parts.features("FrostDemon", {})
	ok(frost.dome and frost.shells and frost.tail == "frost", "Frost dome, shells and tail by default")
	var namek := Parts.features("Namekian", {})
	ok(namek.antenna == "namek" and namek.ears == "pointed" and namek.patches, "Namek antennae, ears, patches")
	eq(Parts.features("Majin", {}).antenna, "buu", "Majin antenna by default")
	eq(Parts.features("Human", {}), {"tail": "", "dome": false, "shells": false, "antenna": "", "ears": "", "patches": false}, "Human: none")

func test_race_part_toggles() -> void:
	eq(Parts.features("Saiyan", {"tail": false}).tail, "", "adult Saiyan drops the tail")
	eq(Parts.features("Majin", {"antenna": false}).antenna, "", "no Buu antenna")
	eq(Parts.features("Namekian", {"antenna": "buu"}).antenna, "buu", "antenna kind can be swapped")
	eq(Parts.features("Human", {"antenna": true}).antenna, "namek", "true adds the first kind")
	eq(Parts.features("Human", {"antenna": "nonsense"}).antenna, "", "unknown kinds are ignored")
	var kai := Parts.features("FrostDemon", {"raceParts": false, "ears": "pointed"})
	ok(not kai.dome and not kai.shells and kai.tail == "" and kai.ears == "pointed", "raceParts false then add ears back")
	var f := Fighter.create({"race": "FrostDemon", "raceParts": false})
	ok(f.dome == null, "no dome on the fighter")
	ok(not _has(f, "frost_tail") and not _has(f, "frost_chest"), "no Frost tail or shells")
	f.free()
	var with_tail := Fighter.create({"race": "Saiyan"})
	ok(_has(with_tail, "saiyan_tail"), "Saiyan keeps the tail by default")
	with_tail.free()
	var s := Fighter.create({"race": "Saiyan", "tail": false})
	ok(not _has(s, "saiyan_tail"), "tail off for a Saiyan")
	s.free()

func test_hair_on_any_race() -> void:
	var frost: Dictionary = Fighter.Tables().races.FrostDemon
	eq(Hair.base_style({"hair": "Short"}, frost), "", "hairless race still drops hair by default")
	eq(Hair.base_style({"hair": "Short", "hairAnyRace": true}, frost), "short", "hairAnyRace draws it")
	eq(Hair.base_style({"hair": "Short"}, Fighter.Tables().races.Saiyan), "short", "a Saiyan with Short hair is not bald")
	eq(Hair.base_style({"hair": "None", "hairAnyRace": true}, frost), "", "None stays bald")
	for h: String in ["Mohawk", "AngelCrest", "Dreadlocks"]:
		var f := Fighter.create({"race": "Majin", "hair": h, "hairAnyRace": true})
		ok(f.hair != null and f.hair.mesh.get_aabb().size.y > 0.1, "%s drawn on a Majin" % h)
		f.free()

func test_free_colours() -> void:
	eq(Outfits.rgb(0x12abef), 0x12abef, "int colour")
	eq(Outfits.rgb(1223663.0), 1223663, "JSON float colour")
	eq(Outfits.rgb("#12ABEF"), 0x12abef, "hex string colour")
	eq(Outfits.rgb(null), -1, "unset")
	eq(Outfits.rgb("teal"), -1, "invalid")
	var f := Fighter.create({"race": "Human", "hair": "Short", "hairColor": 2, "hairRgb": 0x40c8a0, "eyeRgb": 0xc81e1e})
	eq(f.hair_color, Parts.hx(0x40c8a0), "hairRgb overrides the palette")
	eq(f.material.get_shader_parameter("eye_color"), Parts.hx(0xc81e1e), "eyeRgb sets the base eyes")
	var forms: Dictionary = Fighter.Tables().form_looks
	for id: String in forms:
		f.set_form(id)
		f.set_form("")
	eq(f.material.get_shader_parameter("eye_color"), Parts.hx(0xc81e1e), "own eyes come back after forms")
	eq(f.hair_color, Parts.hx(0x40c8a0), "own hair colour kept through forms")
	f.free()

func test_outfit_colours() -> void:
	var base := Outfits.parts("TurtleGi", 0xe86a1a)
	eq(Outfits.for_look({"outfit": "TurtleGi"}, 0xe86a1a), base, "no fields: same parts as before")
	var p := Outfits.for_look({"outfit": "TurtleGi", "outfitRgb": 0x2a9e9a, "outfitRgb2": 0xe0552a}, 0xe86a1a)
	ok(p.top == 0x2a9e9a and p.pants == 0x2a9e9a, "outfitRgb is the main colour")
	ok(p.sash == 0xe0552a and p.wrist == 0xe0552a and p.undershirt == 0xe0552a, "outfitRgb2 is the accent")
	var q := Outfits.for_look({"outfit": "AngelRobe", "outfitParts": {"pants": "#f2f0ea", "collar": false, "plate": 0x18181c, "cape": 0x8a1a2a}}, 0xe86a1a)
	eq(q.pants, 0xf2f0ea, "per-part colour")
	ok(not q.has("collar"), "false removes a part")
	ok(q.armor.plate == 0x18181c and not q.armor.pads, "plate adds a cuirass without pads")
	var f := Fighter.create({"race": "Human", "outfit": "AngelRobe", "outfitParts": {"cape": 0x8a1a2a}, "costume": ["halo", "potara"]})
	ok(f.cape != null, "a cape on any outfit")
	ok(_has(f, "halo") and _has(f, "potara"), "costume list wears every piece")
	f.free()

func test_b1_cast_data() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["supreme_kai", "whis", "vados", "grand_priest", "mr_popo", "king_kai"]:
		var f := Fighter.create(chars[id].look)
		ok(f.dome == null and not _has(f, "frost_tail"), "%s: no Frost dome or tail" % id)
		f.free()
	for id: String in ["whis", "supreme_kai", "kibito", "gas", "cheelai", "zamasu", "paragus"]:
		var f := Fighter.create(chars[id].look)
		ok(f.hair != null, "%s has visible hair" % id)
		f.free()
	for id: String in ["beerus", "hit", "jiren", "zeno", "moro"]:
		eq(Parts.features("Majin", chars[id].look).antenna, "", "%s: no Buu antenna" % id)
