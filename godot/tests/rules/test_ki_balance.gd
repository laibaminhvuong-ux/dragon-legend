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
	ok(g.player.ki>=after,"no drain in form: %s < %s" % [g.player.ki,after])
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
func test_ki_regenerates_while_flying_and_in_a_form() -> void:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJ"]
	g.slot.quests.m02_raditz = {"status":"done"}
	g.player.ki = g.player.maxKi
	g.select_form("SSJ")
	g.player.ki = 10.0
	tick(g,{"flight":true})
	tick(g,{},120)
	ok(g.player.ki>10.0,"ki %s" % g.player.ki)
func test_remaining_ki_costs_are_a_quarter_lower() -> void:
	var g := fresh()
	tick(g,{"dash":true,"move_x":1})
	near(g.player.ki,g.player.maxKi-g.movement.tuning.dashCost*RuleGame.KI_COST_EASE,0.01)
