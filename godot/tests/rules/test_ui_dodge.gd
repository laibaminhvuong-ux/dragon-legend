extends "res://tests/rules/game_case.gd"
# User request 2026-11-03: Ultra Instinct forms dodge automatically 20 times, then go on cooldown.
func _ui() -> RuleGame:
	var g := fresh("Saiyan", 2000)
	g.slot.loadout.testAllPaths = true
	g.slot.forms = ["UIOmen"]
	g.player.ki = g.player.maxKi
	eq(g.select_form("UIOmen"), null)
	return g

func test_twenty_sure_dodges_then_cooldown_then_back() -> void:
	var g := _ui()
	var foe: Dictionary = target(g)
	var hp: float = g.player.health
	for i in RuleCombat.UI_DODGES:
		g.combat.hit(g.player, 50.0, foe)
	near(g.player.health, hp, 0.001, "all %d hits dodged" % RuleCombat.UI_DODGES)
	g.combat.hit(g.player, 50.0, foe)
	ok(g.player.health < hp, "the 21st hit lands: on cooldown")
	g.combat.clock += RuleCombat.UI_COOLDOWN + 0.1
	var before: float = g.player.health
	g.combat.hit(g.player, 50.0, foe)
	near(g.player.health, before, 0.001, "dodges are back after the cooldown")

func test_base_form_never_auto_dodges() -> void:
	var g := fresh("Saiyan", 2000)
	var foe: Dictionary = target(g)
	var hp: float = g.player.health
	g.combat.hit(g.player, 50.0, foe)
	ok(g.player.health < hp)
