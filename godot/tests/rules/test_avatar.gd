extends "res://tests/rules/game_case.gd"
func powered() -> RuleGame:
	var g := fresh("Saiyan",2000)
	g.slot.forms = ["UIPerfected","UITrue","UIOmen"]
	g.slot.moves = ["UltraInstinctAvatar","GodKi"]
	g.slot.loadout.formPath = "instinct"
	g.slot.story.items.instinctMastery = 1
	g.select_form("UIPerfected")
	g.combat.set_technique("UltraInstinctAvatar")
	return g
func test_avatar_requirements_and_low_ki_dont_start_cooldown() -> void:
	var g := powered()
	ok(g.forms.can_manifest_avatar(g.slot,g.player))
	g.select_form("UIOmen")
	ok(not g.combat.fire("UltraInstinctAvatar"))
	near(g.combat.avatar_info().cooldown,0)
	g.select_form("UIPerfected")
	g.player.ki = 0
	ok(not g.combat.fire("UltraInstinctAvatar"))
	near(g.combat.avatar_info().cooldown,0)
func test_avatar_forward_area_hits_and_form_cancellation() -> void:
	var g := powered()
	var front: Dictionary = target(g,8)
	var rear: Dictionary = g.combat.enemies[1]
	rear.pos = g.player.pos+Vector3(0,0,-8)
	rear.home = rear.pos
	var before: float = rear.health
	ok(g.combat.fire("UltraInstinctAvatar"))
	tick(g)
	ok(front.health<front.maxHealth)
	near(rear.health,before)
	g.select_form("")
	tick(g)
	ok(not g.combat.avatar_info().active)
func test_sixty_second_duration_and_independent_120_second_cooldown() -> void:
	var g := powered()
	ok(g.combat.fire("UltraInstinctAvatar"))
	tick(g,{"charge":true},59*60)
	ok(g.combat.avatar_info().active)
	g.combat.set_technique("EnergyWave")
	tick(g,{"charge":true},61)
	ok(not g.combat.avatar_info().active)
	ok(g.combat.avatar_info().cooldown>59)
	ok(not g.combat.fire("UltraInstinctAvatar"))
	tick(g,{"charge":true},60*60)
	ok(g.combat.fire("UltraInstinctAvatar"))
