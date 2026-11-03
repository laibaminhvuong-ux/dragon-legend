extends "res://tests/rules/game_case.gd"
func test_stacks_on_every_saiyan_form_and_never_replaces_equipped_beam() -> void:
	for race: String in ["Saiyan","HalfSaiyan"]:
		var g := fresh(race,2000)
		g.slot.loadout.testAllPaths = true
		g.slot.forms = g.progression.races[race].forms.duplicate()
		g.slot.moves.append("Kaioken")
		for id: String in g.slot.forms:
			if id in ["Kaioken","Kaioken10"]:
				continue
			g.kaioken.cooldown = 0
			eq(g.select_form(id),null,id)
			eq(g.kaioken.toggle(),null,id)
			near(g.kaioken.multiplier(),2)
			eq(g.player.form,id)
			eq(g.combat.technique,"EnergyWave")
			g.kaioken.stop()
func test_strain_cooldown_x10_and_death_cancellation() -> void:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJBlue","Kaioken10"]
	g.slot.moves = ["Kaioken"]
	g.select_form("SSJBlue")
	eq(g.kaioken.select(10),null)
	eq(g.kaioken.toggle(),null)
	near(g.kaioken.multiplier(),10)
	var health: float = g.player.health
	tick(g)
	ok(g.player.health<health)
	g.kaioken.stop()
	ok(g.kaioken.toggle()!=null)
	g.combat.set_technique("EnergyWave")
	g.select_form("")
	ok(g.kaioken.toggle()!=null)
	g.kaioken.cooldown = 0
	g.kaioken.select(2)
	g.kaioken.toggle()
	g.player.health = 0
	tick(g)
	ok(not g.kaioken.snapshot().active)
func test_cannot_double_stack_and_damage_boost_is_real() -> void:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["SSJBlue","Kaioken"]
	g.slot.moves = ["Kaioken"]
	g.select_form("Kaioken")
	ok(g.kaioken.toggle()!=null)
	g.select_form("SSJBlue")
	g.combat.fire("KiBlast")
	var normal: float = g.combat.projectiles.back().damage
	g.kaioken.toggle()
	g.combat.fire("KiBlast")
	near(g.combat.projectiles.back().damage,normal*2)
