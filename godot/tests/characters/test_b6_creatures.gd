extends TestCase
# Cast batch B6: Namekian turban, animal heads, demon wings/crest, props and the two creature bodies
# (characters/creature_bodies.gd, look.costume ids) and the B6 cast looks from tools/godot_additions.mjs.

func _has(f: Fighter, key: String) -> bool:
	if not Parts._meshes.has("b6_" + key):
		return false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes["b6_" + key] and mi.visible:
			return true
	return false

func test_every_gear_id_builds() -> void:
	for id: String in CreatureBodies.IDS:
		var f := Fighter.create({"race": "Human", "outfit": "TurtleGi", "costume": [id]})
		ok(f.anim != null, "%s builds" % id)
		f.free()

func test_heads_and_props() -> void:
	var f := Fighter.create({"race": "Namekian", "antenna": false, "costume": ["namek_turban", "prop_cane"]})
	ok(_has(f, "namek_turban") and _has(f, "prop_cane"), "turban and cane")
	ok(not Parts._meshes.has("antennae") or f.find_children("*", "MeshInstance3D", true, false).all(
		func(mi: MeshInstance3D) -> bool: return mi.mesh != Parts._meshes["antennae"]), "antennae tucked under the turban")
	f.free()
	f = Fighter.create({"race": "Human", "costume": ["cat_head", "pig_head", "dog_head", "bat_wings"]})
	ok(_has(f, "cat_muzzle") and _has(f, "whiskers") and Parts._meshes.has("cat_ears"), "cat head with cat ears")
	ok(_has(f, "pig_snout") and _has(f, "dog_muzzle") and _has(f, "bat_wing_skin") and _has(f, "bat_wing_bones"), "pig, dog, wings")
	f.free()

func test_creature_bodies_hide_humanoid() -> void:
	for id: String in ["battle_walker", "oracle_fish"]:
		var f := Fighter.create({"race": "Human", "costume": [id]})
		ok(f.get_meta("creature", false), "%s marks a creature" % id)
		ok(not f.body_mesh.visible, "%s hides the humanoid body" % id)
		ok(_has(f, "walker_body" if id == "battle_walker" else "fish_bowl"), "%s body drawn" % id)
		f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
		f.free()

func test_b6_cast_looks() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["piccolo", "piccolo_jr", "kami", "king_piccolo", "nail", "dende", "guru", "moori", "monaito", "tambourine",
			"cymbal", "drum", "oolong", "puar", "korin", "bubbles", "shu", "pilaf", "pilav_robot", "oracle_fish", "king_yemma",
			"toppo", "saibaman"]:
		ok(chars.has(id), "%s exists" % id)
		var f := Fighter.create(chars[id].look)
		ok(f.anim != null, "%s builds" % id)
		f.free()
	eq(Parts.features("Namekian", chars.piccolo.look).antenna, "", "Piccor: antennae under the turban")
	for id: String in ["tambourine", "cymbal", "drum"]:
		var rp := Parts.features("Namekian", chars[id].look)
		ok(rp.antenna == "" and not rp.patches and rp.ears == "pointed", "%s: demon, not Namekian parts" % id)
	ok((chars.oolong.look.costume as Array).has("pig_head"), "Ulong is a pig")
	ok((chars.pilav_robot.look.costume as Array).has("battle_walker"), "Pilav's walker is a mech")
