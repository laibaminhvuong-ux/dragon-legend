extends "res://tests/rules/game_case.gd"
# User request 2026-11-03: forms are listed in the race's order and players can pin favourites.
func _saiyan() -> RuleGame:
	var g := fresh("Saiyan",2000)
	g.slot.quests.m02_raditz = {"status":"done"}
	g.slot.loadout.testAllPaths = true
	g.slot.forms = ["SSJ3","UltraEgo","SSJ","SSJBlue","SSJ2"]
	g.player.ki = g.player.maxKi
	return g
func test_form_order_follows_the_race_list_not_unlock_order() -> void:
	var g := _saiyan()
	var race_order: Array = g.progression.races.Saiyan.forms
	var order: Array = g.form_order()
	eq(order.size(),5)
	for i in order.size()-1:
		ok(race_order.find(order[i])<race_order.find(order[i+1]),"%s before %s" % [order[i],order[i+1]])
func test_transform_key_cycles_in_order() -> void:
	var g := _saiyan()
	var seen: Array = []
	for i in 6:
		g.player.ki = g.player.maxKi
		tick(g,{"transform":true})
		seen.append(g.player.form)
	eq(seen,g.form_order()+[""])
func test_favourites_toggle_stay_ordered_and_survive_a_save() -> void:
	var g := _saiyan()
	eq(g.toggle_favorite_form("UltraEgo"),null)
	eq(g.toggle_favorite_form("SSJ"),null)
	eq(g.favorite_forms(),["SSJ","UltraEgo"])
	eq(g.toggle_favorite_form("SSJ"),null)
	eq(g.favorite_forms(),["UltraEgo"])
	ok(g.toggle_favorite_form("Beast")!=null,"can't favourite a locked form")
	ok(g.toggle_favorite_form("nope")!=null)
	var code: String = g.schema.export_code({"version":RuleSchema.SCHEMA_VERSION,"slots":[g.slot,null,null]})
	var back: Dictionary = g.schema.import_code(code)
	ok(back.ok)
	eq(back.profile.slots[0].loadout.favoriteForms,["UltraEgo"])
func test_bad_favourites_are_cleaned_on_load() -> void:
	var g := _saiyan()
	g.slot.loadout.favoriteForms = ["UltraEgo",3,"Nope","UltraEgo"]
	var s: Dictionary = g.schema.normalize(g.slot)
	eq(s.loadout.favoriteForms,["UltraEgo"])
