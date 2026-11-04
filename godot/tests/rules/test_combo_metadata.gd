extends "res://tests/rules/game_case.gd"
const STRIKES := ["jab","cross","hook","uppercut","knee","spin_kick","axe_kick","palm_strike"]
func test_seeded_combo_covers_strikes_and_is_reproducible() -> void:
	var seen := {}
	for seed_value in 32:
		for step in range(1,5):
			var first := RuleCombat.combo_metadata("Melee",step,seed_value)
			eq(first,RuleCombat.combo_metadata("Melee",step,seed_value))
			eq(first.combo_step,step); eq(first.combo_length,4); eq(first.finisher,step==4)
			ok(first.strike in STRIKES); seen[first.strike] = true
	for strike: String in STRIKES: ok(seen.has(strike),strike)
func test_four_melee_releases_and_impacts_keep_damage_and_finisher_in_sync() -> void:
	var g := fresh(); var enemy := target(g)
	enemy.health = 1000000000.0; enemy.maxHealth = enemy.health
	for step in range(1,5):
		enemy.pos = g.player.pos+Vector3(0,0,1.8); enemy.stun = 100.0
		g.combat.melee_cd = 0; g.player.stun = 0
		var before: float = enemy.health
		g.combat.update(.34,{"melee":true})
		var release: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="attack" and row.value.get("phase")=="release").back().value
		var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
		eq(release.combo_step,step); eq(release.combo_length,4); eq(release.finisher,step==4)
		for key: String in ["combo_step","combo_length","strike","finisher","seed"]: eq(impact[key],release[key],key)
		near(before-enemy.health,maxi(1,RuleRuntime.js_round(g.combat.c.meleeDamage*g.player.strength*(g.combat.c.comboFinish if step==4 else 1))),.001)
	g.combat.clock += g.combat.c.comboWindow+1
	g.combat.melee_cd = 0; g.combat.update(.01,{"melee":true})
	eq(g.combat.skill.combo_step,1)
func test_wolf_chain_is_visual_only_and_keeps_existing_guard_break_damage() -> void:
	var g := fresh(); var enemy := target(g)
	enemy.health = 1000000000.0; enemy.maxHealth = enemy.health
	for step in range(1,7):
		g.player.ki = g.player.maxKi; enemy.blocking = true; enemy.ki = 100.0
		var before: float = enemy.health
		ok(g.combat.fire("WolfFangFist"))
		eq(g.combat.skill.combo_step,step); eq(g.combat.skill.combo_length,6); eq(g.combat.skill.finisher,step==6)
		var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
		ok(impact.guard_breaker); eq(impact.finisher,step==6); ok(not enemy.blocking)
		near(before-enemy.health,maxi(1,RuleRuntime.js_round(g.combat.c.meleeDamage*g.player.kiPower*g.combat.moves.WolfFangFist.power)),.001)
		g.combat.clock += g.combat.c.beamCooldown
	g.combat.clock += g.combat.c.comboWindow+1; g.player.ki = g.player.maxKi
	ok(g.combat.fire("WolfFangFist")); eq(g.combat.skill.combo_step,1)
func test_quick_tap_keeps_damage_immediate_and_exports_visual_envelopes() -> void:
	var g := fresh(); var enemy := target(g,8)
	tick(g,{"beam":true}); tick(g)
	ok(enemy.health<enemy.maxHealth)
	ok(g.combat.skill.hold_elapsed<g.combat.skill.hold_min)
	for id: String in SkillCatalog.all():
		var profile := SkillCatalog.get_skill(id)
		ok(float(profile.hold_min)>=0); ok(float(profile.release_window)>0); ok(float(profile.recovery)>0)
		near(float(profile.recovery),float(profile.phases.recovery.duration))
