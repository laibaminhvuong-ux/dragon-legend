extends TestCase
# Player forms added from look-only form_looks (tools/godot_additions.mjs playerFormLines, 2026-11-13): a player-built
# fighter of each race shows the form (aura, size, hair / skin / horns) and comes back to its own look in base.

const CASES := [["Saiyan", "SSJRose"], ["Saiyan", "Wrathful"], ["Saiyan", "SSJBroly"], ["Saiyan", "SSJBlueEvolved"],
	["HalfSaiyan", "SSJRose"], ["HalfSaiyan", "Wrathful"], ["FrostDemon", "FirstForm"], ["FrostDemon", "SecondForm"], ["FrostDemon", "ThirdForm"]]

func _has(f: Fighter, key: String) -> bool:
	if not Parts._meshes.has(key):
		return false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes[key]:
			return true
	return false

func _hair(f: Fighter) -> Variant:
	return f.hair.get_instance_shader_parameter("hair_color") if f.hair != null else null

func test_player_fighters_show_and_drop_each_new_form() -> void:
	var looks: Dictionary = Fighter.Tables().form_looks
	for c: Array in CASES:
		var race: String = c[0]
		var id: String = c[1]
		var F: Dictionary = looks[id]
		var f := Fighter.create(RuleSchema.new().default_look(race))
		var skin: Variant = f.material.get_shader_parameter("skin_color")
		var colors: Variant = f.material.get_shader_parameter("colors")
		var hair: Variant = _hair(f)
		var scale := f.body.scale
		f.set_form(id)
		eq(f.form_id, id, "%s %s set" % [race, id])
		ok(f.form_aura != null, "%s %s aura" % [race, id])
		if F.get("bulk") is Array:
			near(f.body.scale.y, scale.y * float(F.bulk[1]), 1e-4, "%s %s bulk" % [race, id])
		elif F.get("scale") != null:
			near(f.body.scale.y, scale.y * float(F.scale), 1e-4, "%s %s scale" % [race, id])
		if F.get("hair") is Dictionary and f.hair != null:
			eq(_hair(f), Parts.hx(F.hair.color), "%s %s hair colour" % [race, id])
		if F.get("skin") != null:
			eq(f.material.get_shader_parameter("skin_color"), Parts.hx(F.skin), "%s %s skin" % [race, id])
		for g: String in F.get("gear", []):
			ok(_has(f, g), "%s %s wears %s" % [race, id, g])
		f.set_form("")
		eq(f.form_id, "")
		ok(f.form_aura == null, "%s %s aura gone" % [race, id])
		eq(f.body.scale, scale, "%s %s size restored" % [race, id])
		eq(f.material.get_shader_parameter("skin_color"), skin, "%s %s skin restored" % [race, id])
		eq(f.material.get_shader_parameter("colors"), colors, "%s %s outfit colours restored" % [race, id])
		eq(_hair(f), hair, "%s %s hair restored" % [race, id])
		for g: String in F.get("gear", []):
			ok(not _has(f, g), "%s %s %s removed" % [race, id, g])
		f.free()

func test_brolo_keeps_his_own_super_saiyar_and_the_frost_shapes_chain() -> void:
	var f := Fighter.create(RuleSchema.new().default_look("FrostDemon"))
	f.set_form("FirstForm")
	ok(_has(f, "frost_horns"), "first form horns")
	f.set_form("SecondForm")
	ok(_has(f, "frost_horns_big") and not _has(f, "frost_horns"), "second form swaps the horns")
	f.set_form("ThirdForm")
	ok(_has(f, "third_crest") and not _has(f, "frost_horns_big"), "third form crest")
	f.set_form("FinalForm")
	ok(not _has(f, "third_crest"), "final form drops the crest")
	f.free()
	var chars: Dictionary = Fighter.Tables().characters
	var b := Fighter.create(chars.broly.look)
	eq(b.form_look("SSJ"), Fighter.Tables().form_looks.SSJBroly, "Brolo's own SSJ variant is unchanged")
	b.free()
