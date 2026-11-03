extends "res://tests/rules/game_case.gd"
func test_both_saiyan_families_evolve_grades_and_apes_with_mastery() -> void:
	for race: String in ["Saiyan","HalfSaiyan"]:
		var g := fresh(race,2000)
		g.slot.forms = ["SSJ","Oozaru","SSJ2"]
		g.slot.quests.m02_raditz = {"status":"done"}
		eq(g.select_form("SSJ"),null)
		g.add_form_mastery(1000)
		for id: String in ["SSJGrade2","SSJGrade3","SSJFullPower"]:
			ok(id in g.slot.forms,id)
		eq(g.player.form,"SSJFullPower")
		g.select_form("Oozaru")
		g.add_form_mastery(1000)
		eq(g.player.form,"GoldenOozaru")
		g.add_form_mastery(2000)
		eq(g.player.form,"SSJ4")
func test_endgame_paths_are_exclusive_and_test_override_is_explicit() -> void:
	var g := fresh("Saiyan",1999)
	ok(g.choose_form_path("instinct")!=null)
	g.slot.level = 2000
	eq(g.choose_form_path("instinct"),null)
	ok(g.choose_form_path("ego")!=null)
	g.slot.forms = ["UIPerfected","UltraEgo"]
	ok(g.select_form("UltraEgo")!=null)
	g.slot.loadout.testAllPaths = true
	eq(g.select_form("UltraEgo"),null)
func test_rage_story_mastery_and_no_idle_gain() -> void:
	var g := fresh("HalfSaiyan",2000)
	g.slot.forms = ["SSJ2"]
	g.select_form("SSJ2")
	var edge: Dictionary = g.mastery.evolutions.filter(func(e: Dictionary) -> bool:return e.to=="SSJRage")[0]
	g.add_form_mastery(edge.required+1)
	ok("SSJRage" not in g.slot.forms)
	g.slot.quests[edge.after] = {"status":"done"}
	g.add_form_mastery(1)
	ok("SSJRage" in g.slot.forms)
	var key: String = g.mastery.mastery_key(g.player.form)
	var before: float = g.slot.formMastery.get(key,0)
	tick(g,{},30)
	near(g.slot.formMastery.get(key,0),before)
func test_ui_sign_is_weaker_and_customization_accessory_commands_validate() -> void:
	var g := fresh("Saiyan",2000)
	g.player.uiTechniqueUntil = 3
	var weak: Dictionary = g.forms.instinct_benefits(g.player,1)
	g.player.form = "UIPerfected"
	var full: Dictionary = g.forms.instinct_benefits(g.player,1)
	ok(weak.chance<full.chance)
	ok(g.customize_appearance({"kiColorHex":"broken"})!=null)
	eq(g.customize_appearance({"kiColorHex":"#112233"}),null)
	ok(g.equip_accessory("Scouter")!=null)
	g.slot.quests.m02_raditz = {"status":"done"}
	eq(g.equip_accessory("Scouter"),null)
	eq(g.slot.appearance.accessory,"Scouter")
