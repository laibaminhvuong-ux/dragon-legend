extends TestCase
# Different faces (user request, 2026-11-04): every character gets its own eyes, brows, mouth, nose and jaw.

func test_same_seed_same_face_different_seed_different_face() -> void:
	var a := FaceShape.params("gokan")
	eq(a, FaceShape.params("gokan"), "a seed always gives the same face")
	var distinct := {}
	for s in ["gokan", "vegara", "krilan", "trainee_1", "trainee_2", "bulna", "farmer", "roshu"]:
		distinct[str(FaceShape.params(s))] = true
	eq(distinct.size(), 8, "eight seeds, eight different faces")

func test_params_stay_in_range() -> void:
	for i in 200:
		var p := FaceShape.params("seed%d" % i)
		var e: Vector4 = p.eyes
		ok(e.x >= 0.8 and e.x <= 1.2, "eye size in range")
		ok(absf(e.y) <= 0.006 and absf(e.z) <= 0.35, "eye gap/tilt in range")
		ok(float(p.nose) >= 0.8 and float(p.nose) <= 1.3, "nose in range")

func test_fighter_applies_its_face() -> void:
	var f1 := Fighter.create({"race": "Human", "faceSeed": "farmer_a"})
	var f2 := Fighter.create({"race": "Human", "faceSeed": "farmer_b"})
	ok(f1.material.get_shader_parameter("face_eyes") != f2.material.get_shader_parameter("face_eyes") or
		f1.material.get_shader_parameter("face_brows") != f2.material.get_shader_parameter("face_brows"), "two farmers, two faces")
	f1.free(); f2.free()

func test_every_named_character_has_a_face_seed() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	var missing := 0
	for id: String in chars:
		var look: Variant = (chars[id] as Dictionary).get("look")
		if look is Dictionary and not (look as Dictionary).has("faceSeed"):
			missing += 1
	eq(missing, 0, "every character's look carries its own face seed")

func test_female_fighters_have_their_own_model() -> void:
	var m := Fighter.create({"race": "Human", "faceSeed": "x"})
	var f := Fighter.create({"race": "Human", "faceSeed": "x", "female": true, "hair": "Long"})
	ok(float(f.sculpt.get("bust", 0.0)) > 0.02 and float(m.sculpt.get("bust", 0.0)) == 0.0, "female figure")
	ok(float(f.sculpt.get("hips", 1.0)) > float(m.sculpt.get("hips", 1.0)), "wider hips")
	ok(f.body.scale.y < m.body.scale.y, "a little shorter")
	eq(float(f.material.get_shader_parameter("feminine")), 1.0, "female face (lashes, lips)")
	ok(f.hair != null and f.hair_base == "long", "long hair")
	for style in ["Long", "Bun"]:
		ok(Hair.mesh(Hair.BASE[style]) != null, "%s hair builds" % style)
	m.free(); f.free()
