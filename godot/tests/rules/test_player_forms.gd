extends "res://tests/rules/game_case.gd"
# Player forms made from look-only form_looks (tools/godot_additions.mjs playerFormLines, 2026-11-13): the Saiyar
# god / wrathful line and the Frost Fiend suppressed shapes. Data parity, tiers, unlock paths, apply + restore.
const ADDED := {"SSJRose": ["Saiyan","HalfSaiyan"], "Wrathful": ["Saiyan","HalfSaiyan"], "SSJBroly": ["Saiyan","HalfSaiyan"],
	"SSJBlueEvolved": ["Saiyan","HalfSaiyan"], "FirstForm": ["FrostDemon"], "SecondForm": ["FrostDemon"], "ThirdForm": ["FrostDemon"]}
const CANON := ["Saiyan", "Goku", "Vegeta", "Broly", "Frieza", "Black", "Trunks", "Zamasu"]

func test_data_parity_for_every_added_form() -> void:
	var forms: Dictionary = RuleTables.table("forms")
	var looks: Dictionary = RuleTables.table("form_looks")
	var races: Dictionary = RuleTables.table("races")
	var quests: Dictionary = {}
	for q: Dictionary in RuleTables.table("quests"):
		quests[q.id] = q
	var npcs: Dictionary = {}
	for n: Dictionary in RuleTables.table("npcs"):
		npcs[n.id] = n
	var zones: Dictionary = RuleTables.table("zones")
	var listed: Array = RuleTables.table("godot_additions").get("forms", [])
	eq(listed.size(), ADDED.size(), "godot_additions.forms lists every added form")
	var prog := RuleProgression.new()
	for id: String in ADDED:
		ok(id in listed, "%s listed as Godot-only" % id)
		ok(forms.has(id), "%s is a form" % id)
		if not forms.has(id):
			continue
		var f: Dictionary = forms[id]
		ok(looks.has(id), "%s has a form look" % id)
		for word: String in CANON:
			ok(not str(f.name).contains(word), "%s display name '%s' is renamed" % [id, f.name])
		ok(float(f.multiplier) > 1.0 and float(f.kiDrain) > 0, "%s has a multiplier and a ki cost" % id)
		eq(str(f.unlockQuest), "Form_" + id)
		ok(quests.has(f.unlockQuest), "%s unlock quest exists" % id)
		var q: Dictionary = quests.get(f.unlockQuest, {})
		eq(int(q.get("level", -1)), int(f.unlockLevel), "%s quest level = unlock level" % id)
		eq(q.get("rewards", {}).get("forms", []), [id], "%s quest gives the form" % id)
		ok(npcs.has(q.get("giver", "")), "%s giver exists" % id)
		for s: Dictionary in q.get("steps", []):
			ok(not s.has("zone") or zones.has(s.zone), "%s step zone %s" % [id, s.get("zone")])
		for after: String in q.get("after", []):
			ok(quests.has(after), "%s prerequisite %s exists" % [id, after])
		for race: String in ADDED[id]:
			ok(id in races[race].forms, "%s in the %s form list" % [id, race])
			ok(prog.form_for_race(id, race), "%s usable by %s" % [id, race])
		for race: String in races:
			if race not in ADDED[id]:
				ok(not prog.form_for_race(id, race), "%s not for %s" % [id, race])
		if f.has("mastery"):
			ok(q.get("automatic", false), "%s mastery quest is automatic" % id)
			ok(RuleTables.table("mastery_evolutions").any(func(e: Dictionary) -> bool: return e.to == id), "%s mastery edge" % id)

func test_tiers_sit_between_existing_forms_and_below_the_race_top() -> void:
	var forms: Dictionary = RuleTables.table("forms")
	var m := func(id: String) -> float: return float(forms[id].multiplier)
	ok(m.call("SSJGod") < m.call("Wrathful") and m.call("Wrathful") < m.call("SSJBlue"), "Wrathful between God and Blue")
	eq(m.call("SSJRose"), m.call("SSJBlue"), "Rosé is Blue's equal")
	eq(int(forms.SSJRose.unlockLevel), int(forms.SSJBlue.unlockLevel))
	ok(m.call("SSJBlue") < m.call("SSJBroly") and m.call("SSJBroly") < m.call("SSJBlueEvolved"), "Wrathful SSJ, then Blue Evolved")
	ok(m.call("SSJBlueEvolved") < m.call("LegendarySSJ"), "Blue Evolved stays below Legendary")
	ok(m.call("FirstForm") < m.call("SecondForm") and m.call("SecondForm") < m.call("ThirdForm") and m.call("ThirdForm") < m.call("FinalForm"),
		"suppressed shapes below the Final Form")
	ok(int(forms.ThirdForm.unlockLevel) < int(forms.FinalForm.unlockLevel), "and reached before it")
	var added: Array = RuleTables.table("godot_additions").forms
	for race: String in ["Saiyan", "FrostDemon"]:
		var top := 0.0
		for id: String in RuleTables.table("races")[race].forms:
			if id not in added:
				top = maxf(top, m.call(id))
		for id: String in RuleTables.table("races")[race].forms:
			if id in added:
				ok(m.call(id) < top, "%s below the %s top tier" % [id, race])

func test_each_form_applies_and_restores() -> void:
	for id: String in ADDED:
		for race: String in ADDED[id]:
			var g := fresh(race, 2000)
			g.slot.forms = [id]
			var base_hp: float = g.player.maxHealth
			var base_str: float = g.player.strength
			g.player.ki = g.player.maxKi
			ok(id in g.form_order(), "%s %s in the picker" % [race, id])
			eq(g.select_form(id), null, "%s %s transforms" % [race, id])
			eq(g.player.form, id)
			near(g.player.strength, base_str * float(g.forms.forms[id].multiplier), 1e-6, "%s strength x multiplier" % id)
			ok(g.player.maxHealth > base_hp, "%s raises max health" % id)
			ok(g.player.ki < g.player.maxKi, "%s costs ki to enter" % id)
			eq(g.select_form(""), null, "%s back to base" % id)
			eq(g.player.form, "")
			near(g.player.maxHealth, base_hp, 1e-6, "%s max health restored" % id)
			near(g.player.strength, base_str, 1e-6, "%s strength restored" % id)

func test_locked_until_level_and_race() -> void:
	var g := fresh("Saiyan", 1100)
	g.slot.forms = ["Wrathful", "SSJRose"]
	ok(g.select_form("Wrathful") != null, "Wrathful needs level 1150")
	g.slot.level = 1150
	eq(g.select_form("Wrathful"), null)
	ok(g.select_form("SSJRose") != null, "Rosé needs level 1250")
	var h := fresh("Human", 2000)
	h.slot.forms = ["SSJRose", "FirstForm"]
	ok(h.select_form("SSJRose") != null and h.select_form("FirstForm") != null, "other races cannot use them")

func test_mastery_evolutions() -> void:
	var g := fresh("Saiyan", 2000)
	g.slot.forms = ["Wrathful", "SSJBlue"]
	g.player.ki = g.player.maxKi
	eq(g.select_form("Wrathful"), null)
	g.add_form_mastery(1000)
	ok("SSJBroly" in g.slot.forms, "Wrathful mastery -> Wrathful Super Saiyar")
	eq(g.player.form, "SSJBroly")
	eq(g.slot.quests.Form_SSJBroly.status, "done")
	g.player.ki = g.player.maxKi
	eq(g.select_form("SSJBlue"), null)
	g.add_form_mastery(1600)
	ok("SSJBlueEvolved" not in g.slot.forms, "Blue Evolved waits for the Granolah chapter")
	g.slot.quests.m38_granolah = {"status": "done"}
	g.add_form_mastery(1)
	ok("SSJBlueEvolved" in g.slot.forms, "then evolves")
	var p: Dictionary = g.mastery.mastery_progress(g.slot, "SSJBlue")
	eq(p.next, null, "nothing left after Blue Evolved")
	var f := fresh("FrostDemon", 199)
	f.slot.forms = ["FirstForm"]
	f.player.ki = f.player.maxKi
	eq(f.select_form("FirstForm"), null)
	eq(f.mastery.mastery_progress(f.slot, "FirstForm").next, "SecondForm")
	f.add_form_mastery(500)
	eq(f.player.form, "SecondForm")
	f.add_form_mastery(1000)
	ok("ThirdForm" not in f.slot.forms, "Third Form needs level 200")
	f.slot.level = 200
	f.add_form_mastery(1)
	eq(f.player.form, "ThirdForm")

func test_saves_keep_the_new_forms() -> void:
	var g := fresh("FrostDemon", 300)
	g.slot.forms = ["FirstForm", "SecondForm", "ThirdForm", "FinalForm"]
	g.slot.formMastery = {"FirstForm": 600.0}
	var code: String = g.schema.export_code({"version": RuleSchema.SCHEMA_VERSION, "slots": [g.slot, null, null]})
	var back: Dictionary = g.schema.import_code(code)
	ok(back.ok)
	eq(back.profile.slots[0].forms, ["FirstForm", "SecondForm", "ThirdForm", "FinalForm"])
	near(float(back.profile.slots[0].formMastery.FirstForm), 600.0, 1e-6)
