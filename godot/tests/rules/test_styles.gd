extends "res://tests/rules/game_case.gd"
func releases(g: RuleGame) -> Array:
	return g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="attack" and row.value.get("phase")=="release")
func test_style_catalogue_resolves_all_combo_dash_finisher_moves() -> void:
	eq(RuleTables.table("fighting_styles").order,["turtle","brawler","speedster","crane"])
	var ids := {}
	for id: String in RuleStyles.all():
		var tuning := RuleStyles.get_style(id)
		eq(tuning.combo.size(),4); ok(float(tuning.chain_window)>float(tuning.cadence.max()))
		for move: Dictionary in tuning.combo+[tuning.dash_in,tuning.finisher]:
			ok(str(move.id).begins_with(id+"_")); ok(not ids.has(move.id)); ids[move.id] = true
			ok(float(move.lunge)>=.2 and float(move.lunge)<=1.2)
			ok(float(move.blend)>=.08 and float(move.blend)<=.2)
		for step in range(1,5):
			var first := RuleStyles.move(id,step)
			eq(first,RuleStyles.move(id,step)); eq(first.combo_step,step); eq(first.combo_move,tuning.combo[step-1].id)
			eq(first.move,tuning.finisher.id if step==4 else tuning.combo[step-1].id)
			eq(first.finisher,step==4); near(first.strike_duration,float(tuning.cadence[step-1]))
		eq(RuleStyles.move(id,1,true).move,tuning.dash_in.id)
		var reaction := RuleStyles.reaction(id,true)
		ok(reaction.hitstop>=.04 and reaction.hitstop<=.09)
	eq(ids.size(),24)
func test_style_switch_persists_and_refuses_melee_channel_and_technique_strikes() -> void:
	var g := fresh()
	eq(g.player.style,"turtle"); eq(g.slot.style,"turtle")
	for id: String in RuleStyles.all():
		eq(g.set_style(id),null); eq(g.player.style,id); eq(g.to_save().style,id)
	eq(g.set_style("unknown"),"Unknown fighting style."); eq(g.slot.style,"crane")
	tick(g,{"melee":true})
	ok(g.set_style("brawler") is String); eq(g.player.style,"crane")
	tick(g,{},40); eq(g.set_style("brawler"),null); eq(g.combat.combo,0)
	tick(g,{"beam":true}); ok(g.set_style("speedster") is String)
	g.player.blocking = true; g.combat.update(.01,{})
	eq(g.set_style("speedster"),null)
	g.player.blocking = false; g.player.ki = g.player.maxKi
	ok(g.combat.fire("EnergyWave")); ok(g.set_style("crane") is String)
	tick(g,{},50); eq(g.set_style("crane"),null)
func test_style_reach_guard_pressure_and_horizontal_impulse_are_authoritative() -> void:
	for id: String in RuleStyles.all():
		var g := fresh(); var e := target(g,3.0); eq(g.set_style(id),null)
		var tuning := RuleStyles.get_style(id)
		var before: float = e.health
		g.combat.update(.01,{"melee":true})
		eq(e.health<before,id=="crane",id+" reach")
		e.pos = g.player.pos+Vector3(0,0,1.8); e.health = 100.0; e.maxHealth = 100.0
		e.vel = Vector3.ZERO; e.blocking = true; e.ki = 100.0
		var context := RuleStyles.move(id,1).merged({"move_id":"Melee","actor_id":g.player.id})
		g.combat.hit(e,12,g.player,false,context)
		near(e.ki,100-g.combat.c.guardCost*float(tuning.guard_pressure))
		near(e.vel.z,g.combat.c.knockback*float(tuning.knockback_scale))
		var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
		for key: String in ["style","move","chain_window","knockback","launch","stagger","hitstop"]: ok(impact.has(key),key)
		ok(impact.blocked); ok(not impact.launch)
		near(e.vel.y,0,.00001,"visual launch does not move physics")
func test_dash_and_finisher_release_metadata_never_apply_visual_root_motion() -> void:
	for id: String in RuleStyles.all():
		var g := fresh(); eq(g.set_style(id),null)
		var original: Vector3 = g.player.pos
		g.player.dashing = true
		g.combat.update(.01,{"melee":true})
		var first: Dictionary = releases(g).back().value
		eq(first.move,RuleStyles.get_style(id).dash_in.id); eq(first.dash_move,first.move)
		eq(g.player.pos,original)
		g.player.dashing = false
		for step in range(2,5):
			g.combat.melee_cd = 0; g.combat.update(.1,{"melee":true})
		var last: Dictionary = releases(g).back().value
		eq(last.combo_step,4); ok(last.finisher); eq(last.move,RuleStyles.get_style(id).finisher.id)
		eq(last.finisher_move,last.move); eq(last.combo_move,RuleStyles.get_style(id).combo[3].id)
		eq(g.player.pos,original)
		g.combat.melee_cd = 0; g.combat.update(float(last.chain_window)+.01,{"melee":true})
		eq(g.combat.skill.combo_step,1)
func test_measured_sixty_hz_dps_is_within_four_percent_between_styles() -> void:
	var measured := {}
	for id: String in RuleStyles.all():
		var g := fresh(); eq(g.set_style(id),null)
		var e := target(g,1.5); e.health = 1000000000.0; e.maxHealth = e.health
		var count := 0; var first_at := 0.0; var previous := 0
		for frame in 2200:
			e.pos = g.player.pos+Vector3(0,0,1.5); e.home = e.pos; e.vel = Vector3.ZERO; e.stun = 10000.0
			g.combat.update(1.0/60,{"melee":true})
			if g.player.attackSerial!=previous:
				previous = g.player.attackSerial; count += 1
				if count==1: first_at = g.combat.clock
				if count==40: break
		eq(count,40)
		measured[id] = (1000000000.0-e.health)/(g.combat.clock+g.combat.melee_cd-first_at)
		near(float(RuleStyles.get_style(id).balance.ideal_dps),43.59375,.0001)
	print("STYLE_DPS_60HZ ",JSON.stringify(measured))
	for id: String in measured:
		ok(absf(float(measured[id])/float(measured.turtle)-1)<.04,"60 Hz DPS "+id+": "+str(measured[id]))
func test_named_fighters_and_patrols_receive_their_data_style() -> void:
	var characters: Dictionary = RuleTables.table("characters")
	for id: String in characters: ok(RuleStyles.valid(characters[id].style),id)
	for id: String in ["nappa","broly","recoome"]: eq(characters[id].style,"brawler")
	eq(characters.hit.style,"speedster"); eq(characters.tien.style,"crane"); eq(characters.roshi.style,"turtle")
	var g := fresh()
	for e: Dictionary in g.combat.enemies: eq(e.style,"turtle")
	var enemy: Dictionary = g.combat.spawn({"key":"nappa","name":"Nappo","level":10,"x":20,"z":20,"boss":true})
	eq(enemy.style,"brawler")
func test_npc_release_reaction_metadata_keeps_original_damage_and_cadence() -> void:
	var g := fresh(); var enemy := target(g,1.5)
	enemy.style = "brawler"; enemy.windup = .001; enemy.provoked = true
	var before: float = g.player.health
	g.combat.update(.01,{})
	var event: Dictionary = releases(g).back().value
	eq(event.actor_id,enemy.id); eq(event.style,"brawler"); eq(event.move,"brawler_wide_hook")
	near(before-g.player.health,maxi(1,RuleRuntime.js_round((g.combat.c.enemyDamage+(enemy.level-1)*g.combat.c.enemyDamagePerLevel)*(g.combat.c.bossDamage if enemy.boss else 1))))
	var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
	eq(impact.actor_id,enemy.id); ok(impact.has("hitstop"))
	enemy.cooldown = 0; enemy.windup = 0; g.player.stun = 0; g.combat.update(.01,{})
	near(enemy.cooldown,g.combat.c.enemyCooldown); near(enemy.windup,g.combat.c.enemyWindup)
func test_projectile_keeps_cast_style_when_the_player_switches_after_recovery() -> void:
	var g := fresh(); var enemy := target(g,30)
	ok(g.combat.fire("KiBlast"))
	var shot: Dictionary = g.combat.projectiles[0].duplicate(true)
	g.combat.clock += .4; eq(g.set_style("brawler"),null)
	g.combat.hit(enemy,5,g.player,false,shot.presentation)
	var impact: Dictionary = g.events.log.filter(func(row: Dictionary) -> bool: return row.event=="damage").back().value
	eq(impact.style,"turtle"); eq(impact.move_id,"KiBlast"); eq(impact.action_sequence,shot.presentation.action_sequence)
