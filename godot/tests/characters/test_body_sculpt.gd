extends TestCase
# Presentation rebuild (2026-11-04): races, builds and named fighters get their own body shape on the shared rig.

func _mannequin() -> MeshInstance3D:
	var scene: Node = (load("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	mi.get_parent().remove_child(mi)
	scene.free()
	return mi

func _extent(mesh: ArrayMesh, y0: float, y1: float) -> float:
	var w := 0.0
	for s in mesh.get_surface_count():
		for v: Vector3 in (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.y > y0 and v.y < y1 and absf(v.x) < 0.2:
				w = maxf(w, absf(v.x))
	return w

func test_neutral_profile_keeps_the_mesh() -> void:
	var mi := _mannequin()
	var base := BodyRegions.dressed_mesh(mi)
	ok(BodySculpt.sculpted(base, {}) == base, "no profile, no copy")
	ok(BodySculpt.sculpted(base, BodySculpt.profile_for({"race": "Human", "build": "Average"})) != null, "human builds")
	mi.free()

func test_sculpt_keeps_skin_weights_and_rest_positions() -> void:
	var mi := _mannequin()
	var base := BodyRegions.dressed_mesh(mi)
	var m := BodySculpt.sculpted(base, BodySculpt.profile_for({"race": "Majin", "build": "Muscular"}))
	eq(m.get_surface_count(), base.get_surface_count(), "same surfaces")
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var b: Array = base.surface_get_arrays(s)
		eq((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "same vertices")
		ok(a[Mesh.ARRAY_BONES] == b[Mesh.ARRAY_BONES] and a[Mesh.ARRAY_WEIGHTS] == b[Mesh.ARRAY_WEIGHTS], "skinning untouched")
		ok(a[Mesh.ARRAY_CUSTOM0] == b[Mesh.ARRAY_CUSTOM0], "rest positions (outfit regions, face) untouched")
		ok(a[Mesh.ARRAY_VERTEX] != b[Mesh.ARRAY_VERTEX], "shape changed")
	ok(BodySculpt.sculpted(base, BodySculpt.profile_for({"race": "Majin", "build": "Muscular"})) == m, "cached per profile")
	mi.free()

func test_races_read_differently() -> void:
	var mi := _mannequin()
	var base := BodyRegions.dressed_mesh(mi)
	var waist := {}
	for r: String in ["Human", "Namekian", "FrostDemon", "Majin"]:
		waist[r] = _extent(BodySculpt.sculpted(base, BodySculpt.profile_for({"race": r})), 1.0, 1.1)
	ok(float(waist.Majin) > float(waist.Human) * 1.15, "Majin are round in the middle")
	ok(float(waist.FrostDemon) < float(waist.Human) * 0.85, "Frost Demons are wasp-waisted")
	ok(float(waist.Namekian) < float(waist.Human) * 0.9, "Namekians taper to a narrow waist")
	ok(float(BodySculpt.profile_for({"race": "Namekian"}).get("height", 1.0)) > 1.0, "Namekians stand taller")
	mi.free()

func test_named_physiques_exist_for_named_fighters() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in chars:
		var look: Variant = (chars[id] as Dictionary).get("look")
		if look is Dictionary and (look as Dictionary).has("physique"):
			ok(BodySculpt.NAMED.has(str(look.physique)), "%s's physique %s is defined" % [id, look.physique])

func test_fighters_build_with_physiques() -> void:
	for p: String in BodySculpt.NAMED:
		var f := Fighter.create({"race": "Human", "build": "Average", "physique": p})
		ok(f.body_mesh.mesh != null, "builds %s" % p)
		f.free()

func test_sockets_sit_on_the_body() -> void:
	var f := Fighter.create({"race": "Saiyan", "build": "Average"})
	for n: String in Fighter.SOCKETS:
		var p := f.socket(n).origin
		ok(p.y > -0.1 and p.y < 2.2 and absf(p.x) < 1.0, "%s socket on the fighter (%s)" % [n, p])
	ok(f.socket("head").origin.y > f.socket("chest").origin.y, "head above chest")
	ok(f.socket("hand_l").origin.x > 0.5 and f.socket("hand_r").origin.x < -0.5, "hands out to the sides in rest pose")
	f.free()
