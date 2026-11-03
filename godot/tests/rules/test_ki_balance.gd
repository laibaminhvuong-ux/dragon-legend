extends "res://tests/rules/game_case.gd"
# User request 2026-11-03: flight and forms don't drain Ki; transforming costs a one-time amount;
# the remaining Ki costs are 25% lower.
func test_flight_does_not_drain_ki_and_works_with_empty_ki() -> void:
	var g := fresh()
	g.player.ki = 50.0
	tick(g,{"flight":true})
	ok(g.player.flying)
	tick(g,{"move_z":1},120)
	ok(g.player.flying)
	ok(g.player.ki>=50.0,"ki %s" % g.player.ki)
	tick(g,{"flight":true})
	g.player.ki = 0.0
	tick(g,{"flight":true})
	ok(g.player.flying,"can take off with no ki")
	tick(g,{},60)
	ok(g.player.flying,"stays up with no ki")
func test_transform_costs_ki_once_and_the_form_does_not_drain() -> void:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJ","SSJ3"]
	g.slot.quests.m02_raditz = {"status":"done"}
	g.player.ki = g.player.maxKi
	var cost: float = g.transform_cost("SSJ")
	near(cost,g.forms.forms.SSJ.kiDrain*RuleGame.TRANSFORM_COST_SECONDS*g.player.kiCostScale)
	eq(g.select_form("SSJ"),null)
	near(g.player.ki,minf(g.player.maxKi,g.player.maxKi)-cost,0.01)
	var after: float = g.player.ki
	tick(g,{},300)
	eq(g.player.form,"SSJ")
	near(g.player.ki,after,0.0001,"no drain in form")
	g.player.ki = g.transform_cost("SSJ3")-1
	ok(g.select_form("SSJ3")!=null,"not enough ki to transform")
	eq(g.player.form,"SSJ")
	var before_base: float = g.player.ki
	eq(g.select_form(""),null)
	near(g.player.ki,before_base,0.0001)
func test_transform_key_spends_the_cost() -> void:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJ"]
	g.slot.quests.m02_raditz = {"status":"done"}
	g.player.ki = g.player.maxKi
	tick(g,{"transform":true})
	eq(g.player.form,"SSJ")
	ok(g.player.ki<g.player.maxKi-g.transform_cost("SSJ")*0.9)
func test_ki_regenerates_while_flying_in_base_form() -> void:
	var g := fresh("Saiyan",2000)
	g.player.ki = 10.0
	tick(g,{"flight":true})
	tick(g,{},120)
	ok(g.player.ki>10.0,"ki %s" % g.player.ki)
func test_no_ki_regen_in_a_form_only_charging() -> void:
	# User request 2026-11-03: after transforming, Ki stays where it is until the player charges.
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJ"]
	g.slot.quests.m02_raditz = {"status":"done"}
	g.player.ki = g.player.maxKi
	g.select_form("SSJ")
	var after: float = g.player.ki
	tick(g,{},300)
	near(g.player.ki,after,0.0001)
	tick(g,{"flight":true})
	tick(g,{},120)
	near(g.player.ki,after,0.0001)
	tick(g,{"flight":true})
	tick(g,{},60)
	tick(g,{"charge":true},60)
	ok(g.player.ki>after,"charging refills in a form")
	eq(g.player.form,"SSJ")
func test_remaining_ki_costs_are_a_quarter_lower() -> void:
	var g := fresh()
	tick(g,{"dash":true,"move_x":1})
	near(g.player.ki,g.player.maxKi-g.movement.tuning.dashCost*RuleGame.KI_COST_EASE,0.01)
func test_every_race_and_every_form_follows_the_same_ki_rules() -> void:
	# User request 2026-11-03: the form rules apply to every race, not just Saiyans.
	var races: Dictionary = RuleTables.table("races")
	var checked := 0
	for race: String in races:
		var list: Array = races[race].get("forms",[])
		if list.is_empty():
			continue
		var g := fresh(race,2000)
		g.slot.loadout.testAllPaths = true
		var shuffled: Array = list.duplicate()
		shuffled.reverse()
		g.slot.forms = shuffled
		eq(g.form_order(),list,race+": forms listed in the race's order")
		for id: String in list:
			g.select_form("")
			g.player.ki = g.player.maxKi
			var cost: float = g.transform_cost(id)
			ok(cost>0,"%s %s costs ki" % [race,id])
			eq(g.select_form(id),null,"%s %s" % [race,id])
			eq(g.player.form,id)
			near(g.player.ki,g.player.maxKi-cost,0.01,"%s %s paid once" % [race,id])
			var after: float = g.player.ki
			tick(g,{},120)
			near(g.player.ki,after,0.0001,"%s %s: no drain, no refill" % [race,id])
			tick(g,{"flight":true})
			tick(g,{"move_z":1},60)
			near(g.player.ki,after,0.0001,"%s %s: flight is free" % [race,id])
			tick(g,{"flight":true})
			tick(g,{},90)
			tick(g,{"charge":true},30)
			ok(g.player.ki>after,"%s %s: charging refills" % [race,id])
			ok(g.player.form==id or id in ["Oozaru","GoldenOozaru"] or g.slot.forms.has(g.player.form),"%s %s still transformed" % [race,id])
			g.player.ki = cost-0.5
			g.select_form("")
			ok(g.select_form(id)!=null,"%s %s: can't transform without the ki" % [race,id])
			checked += 1
	ok(checked>=40,"forms checked: %d" % checked)
