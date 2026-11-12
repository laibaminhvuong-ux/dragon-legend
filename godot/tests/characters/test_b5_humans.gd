extends TestCase
# Cast batch B5 (Earth humans): new hair styles, facial hair (Parts.facial_hair), glasses / hats / third eye / face
# marks / jewellery / neckwear (FaceGear) and the B5 looks (fields at the top of characters/outfits.gd).

func _has(f: Fighter, key: String) -> bool:
	if not Parts._meshes.has(key):
		return false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes[key]:
			return true
	return false

func _count(f: Fighter) -> int:
	return f.find_children("*", "MeshInstance3D", true, false).size()

func test_hair_styles() -> void:
	var human: Dictionary = Fighter.Tables().races.Human
	for id: String in ["CenterPart", "Bob", "TwinTails", "Afro", "BigCurly", "Topknot", "SidePonytail", "ShoulderStraight", "Slick"]:
		var style := Hair.base_style({"hair": id}, human)
		ok(style != "", "%s maps to a style" % id)
		var m := Hair.mesh(style)
		ok(m != null and m.get_surface_count() == 1 and m.surface_get_array_len(0) > 100, "%s builds a mesh" % id)
	eq(Hair.form_style("same", "afro"), "goku", "forms on a B5 style fall back to the spiky base")

func test_facial_hair() -> void:
	var plain := Fighter.create({"race": "Human", "hair": "None"})
	var n := _count(plain)
	plain.free()
	for mo: String in ["thick", "bushy", "long", "thin"]:
		var f := Fighter.create({"race": "Human", "hair": "None", "moustache": mo})
		eq(_count(f), n + 1, "moustache %s adds one piece" % mo)
		f.free()
	for be: String in ["long", "full", "short", "goatee"]:
		var f := Fighter.create({"race": "Human", "hair": "None", "beard": be})
		eq(_count(f), n + 1, "beard %s adds one piece" % be)
		f.free()
	var w := Fighter.create({"race": "Human", "hair": "None", "hairColor": 5, "moustache": "bushy", "beard": "long"})
	ok(_has(w, "fh_bushy") and _has(w, "fh_beard_long"), "Roshu's moustache and beard")
	for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes["fh_bushy"]:
			eq((mi.material_override as StandardMaterial3D).albedo_color, w.hair_color, "facial hair defaults to the hair colour")
	w.free()
	var t := Fighter.create({"race": "Human", "moustache": "thick", "facialHairRgb": 0xd8d8d8})
	ok(_has(t, "mustache"), "thick reuses B3's moustache mesh")
	for mi: MeshInstance3D in t.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes["mustache"]:
			eq((mi.material_override as StandardMaterial3D).albedo_color, Parts.hx(0xd8d8d8), "facialHairRgb recolours it")
	t.free()

func test_face_gear() -> void:
	var f := Fighter.create({"race": "Human", "hair": "None", "glasses": "sunglasses", "hat": "pompom", "hatRgb": 0x1e1e22,
		"thirdEye": true, "faceMarks": ["dots", "cheek_circles", "scar_cheek", "scar_eye"], "jewellery": ["champion_belt", "earrings", "bracelets", "necklace"],
		"neckwear": "scarf"})
	for key: String in ["fg_sunglasses", "fg_temples", "fg_skullcap", "fg_pompom", "fg_third_eye", "fg_dots", "fg_cheeks", "fg_scar_cheek",
			"fg_scar_eye", "fg_champ_belt", "fg_earrings", "fg_bracelet1", "fg_necklace", "fg_scarf"]:
		ok(_has(f, key), "piece %s" % key)
	f.free()
	for g: String in ["round", "square"]:
		var x := Fighter.create({"race": "Human", "glasses": g})
		ok(_has(x, "fg_%s_frames" % g), "%s glasses" % g)
		x.free()
	for h: String in ["skullcap", "beanie", "bandana", "headband", "ribbon", "turban"]:
		var x := Fighter.create({"race": "Human", "hat": h})
		ok(_has(x, "fg_" + ("turban_b5" if h == "turban" else h)), "hat %s" % h)
		x.free()
	var fur := Fighter.create({"race": "Human", "neckwear": "fur_collar"})
	ok(_has(fur, "fg_fur"), "fur collar")
	fur.free()

func test_b5_cast() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	var ids := ["krillin", "krillin_kid", "yamcha", "yamcha_young", "tien", "tien_young", "chiaotzu", "roshi", "jackie_chun", "grandpa_gohan",
		"bulma", "bulma_young", "chichi", "dr_brief", "videl", "mr_satan", "ox_king", "tao", "tao_cyborg", "murasaki", "nam", "yajirobe",
		"baba", "mai", "princess_snake", "trunks", "trunks_kid"]
	for id: String in ids:
		ok(chars.has(id), "%s exists" % id)
		var f := Fighter.create(chars[id].look)
		ok(f.anim != null, "%s builds" % id)
		f.free()
	var k := Fighter.create(chars.krillin.look)
	ok(_has(k, "fg_dots"), "Krilan's forehead dots")
	k.free()
	var t := Fighter.create(chars.tien.look)
	ok(_has(t, "fg_third_eye"), "Tenzo's third eye")
	t.free()
	var r := Fighter.create(chars.roshi.look)
	ok(_has(r, "fh_beard_long") and _has(r, "fg_sunglasses"), "Roshu's beard and sunglasses")
	r.free()
	var s := Fighter.create(chars.mr_satan.look)
	eq(s.hair_base, "afro", "Mr. Sadan's afro")
	ok(_has(s, "fg_champ_belt") and s.cape != null, "champion belt and cape")
	s.free()
	eq(str(chars.bulma.look.hair), "Bob", "Bulna's bob")
	eq(str(chars.trunks.look.hair), "CenterPart", "Tronks' centre part")
	eq(str(chars.krillin.name), "Krilan", "display names stay renamed")
