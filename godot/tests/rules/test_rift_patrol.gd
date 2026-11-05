extends "res://tests/rules/game_case.gd"
func postgame(zone_id: String="time_nexus") -> RuleGame:
	var schema:=RuleSchema.new()
	var slot:=schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.zone=zone_id;slot.level=2000;slot.story.flags.originsRequired=false
	for q: Dictionary in RuleTables.table("quests"):
		if q.get("main",false):slot.quests[q.id]={"status":"done","completions":1}
	return RuleGame.new(0,slot,Recorder.new())
func launch(g: RuleGame,id: String) -> RuleGame:
	var saved:=g.to_save().duplicate(true)
	saved.zone="time_nexus";saved.position=null;saved.rift.erase("pending")
	g=RuleGame.new(0,saved,Recorder.new())
	eq(g.start_rift_mission(id),null,id+" launch")
	if not g.rift.active():g=RuleGame.new(0,g.to_save(),g.events)
	ok(g.rift.active(),"active mission "+id)
	return g
func clear(g: RuleGame) -> void:
	for guard: int in 8:
		if not g.rift.active():return
		g.combat.sync()
		for e: Dictionary in g.combat.enemies.duplicate():
			if e.health>0:g.combat.hit(e,e.maxHealth+100,g.player,true)
	ok(not g.rift.active(),"mission cannot stall")
func test_rift_unlock_recruiter_and_legacy_save_handoff() -> void:
	var g:=fresh()
	ok(not g.rift.available())
	ok(g.enter_rift_hub() is String)
	ok(g.start_rift_mission("rp01_dark_crystal") is String)
	var story:=RuleStory.new(g,g.events)
	eq(story.rift_recruiter(),null)
	g.slot.quests[RuleTables.table("rift_missions").unlock_quest]={"status":"done","completions":1}
	ok(g.rift.available())
	var n: Dictionary=story.rift_recruiter()
	eq(n.name,"Archivist Tem")
	g.player.pos=RuleRuntime.vector(n)
	eq(story.interact(),"rift")
	eq(g.leaving_to,"time_nexus")
	var copy:=RuleGame.new(0,g.to_save(),g.events)
	eq(copy.current_region(),"time_nexus")
	ok(copy.rift_missions()[0].unlocked)
	ok(not copy.rift_missions()[1].unlocked)
	ok(copy.start_rift_mission("bogus") is String)
	ok(copy.start_rift_mission("rp15_zero_origin") is String)
func test_rift_entire_catalogue_actual_combat_rewards_cards_and_unlocks() -> void:
	var g:=postgame()
	for m: Dictionary in RuleTables.table("rift_missions").missions:
		g=launch(g,m.id)
		ok(g.combat.enemies.all(func(e: Dictionary)->bool:return str(e.key).begins_with("rift:")),"ordinary patrols are isolated")
		var wallet: float=g.slot.zeni
		clear(g)
		eq(g.active_rift_mission().status,"complete",m.id)
		eq(g.active_rift_mission().stars,3)
		near(g.slot.zeni,wallet+50000)
		ok(m.rewards.card in g.slot.rift.cards)
		ok(m.rewards.three_star_card in g.slot.rift.cards)
		eq(int(g.slot.rift.results[m.id].clears),1)
		eq(g.events.count("riftMissionComplete"),1)
		eq(g.active_rift_mission().objectives[0].progress,4)
		eq(int(g.active_rift_mission().objectives[1].progress),m.waves[1].spawns.size())
	eq(g.slot.rift.cards.size(),30)
	g=launch(g,"rp01_dark_crystal")
	var wallet: float=g.slot.zeni
	clear(g)
	near(g.slot.zeni,wallet+15000)
	eq(g.slot.rift.cards.size(),30)
	eq(int(g.slot.rift.results.rp01_dark_crystal.clears),2)
func test_rift_stars_protection_defeat_abandon_and_no_partial_rewards() -> void:
	var g:=launch(postgame(),"rp01_dark_crystal")
	var wallet: float=g.slot.zeni
	g.rift.run.timer=241.0
	var a: Dictionary=g.combat.allies[0]
	g.combat.hit(a,a.maxHealth+100,g.combat.enemies[0],true)
	clear(g)
	eq(g.rift.run.stars,1)
	ok(not g.slot.rift.cards.has("rp01_dark_crystal_prismatic"))
	g=launch(g,"rp01_dark_crystal");clear(g)
	eq(int(g.slot.rift.results.rp01_dark_crystal.stars),3,"replay improves best stars")
	g=launch(g,"rp02_shattered_landing");clear(g)
	g=launch(g,"rp03_nameck_storm")
	wallet=g.slot.zeni;a=g.combat.allies[0]
	g.combat.hit(a,a.maxHealth+100,g.combat.enemies[0],true)
	g.rift.update(0.01)
	eq(g.rift.run.status,"failed");near(g.slot.zeni,wallet)
	ok(not g.slot.rift.results.has("rp03_nameck_storm"))
	g=launch(g,"rp01_dark_crystal")
	wallet=g.slot.zeni;g.player.health=0
	g.rift.update(.01)
	eq(g.rift.run.status,"failed");near(g.slot.zeni,wallet)
	g.player.health=g.player.maxHealth
	g=launch(g,"rp01_dark_crystal")
	eq(g.abandon_rift_mission(),null)
	eq(g.rift.run.status,"failed");near(g.slot.zeni,wallet)
func test_rift_ally_ai_targets_hits_and_enemy_retaliates_with_boss_phases() -> void:
	var g:=launch(postgame(),"rp01_dark_crystal")
	var a: Dictionary=g.combat.allies[0]
	var e: Dictionary=g.combat.enemies[0]
	a.pos=e.pos+Vector3(0,0,1)
	var hp: float=e.health
	g.rift.update(.01)
	ok(e.health<hp,"ally actual damage")
	ok(a.attackSerial>0)
	eq(g.rift.target(e,g.player).id,a.id)
	e.stun=0.0;e.cooldown=0.0;e.vel=Vector3.ZERO
	var ally_hp: float=a.health
	g.combat.update(.01,{})
	g.combat.update(1,{})
	ok(a.health<ally_hp,"enemy can knock down the ally")
	for enemy: Dictionary in g.combat.enemies.duplicate():g.combat.hit(enemy,enemy.maxHealth+100,g.player,true)
	g.combat.sync()
	e=g.combat.enemies[0]
	e.health=e.maxHealth*.3
	g.rift.update(0)
	eq(e.riftPhase,2)
	ok(e.damageMultiplier>float(e.damageScale))
	ok(g.events.count("riftBossPhase")>0)
func test_rift_save_restart_and_hero_card_validation_passives() -> void:
	var g:=launch(postgame(),"rp01_dark_crystal")
	g.combat.hit(g.combat.enemies[0],1e9,g.player,true)
	g.rift.run.timer=80.0
	var schema:=RuleSchema.new()
	var profile:=schema.new_profile();profile.slots[0]=g.to_save()
	var decoded:=schema.import_code(schema.export_code(profile))
	ok(decoded.ok)
	var resumed:=RuleGame.new(0,decoded.profile.slots[0],Recorder.new())
	eq(resumed.rift.run.wave,0);eq(resumed.rift.run.timer,0.0)
	eq(resumed.combat.enemies.size(),4,"interruption restarts the full encounter")
	clear(resumed)
	var card: String="rp01_dark_crystal_hero"
	eq(resumed.equip_hero_card(card,0),null)
	ok(resumed.equip_hero_card(card,1) is String)
	ok(resumed.equip_hero_card("unowned",1) is String)
	for index: Variant in [-1,3,1.5,"0",true,NAN]:ok(resumed.equip_hero_card("",index) is String)
	near(RuleHeroCards.bonus(resumed.slot,"ki_regen"),.02)
	var baseline:=RuleGame.new(0,resumed.slot.duplicate(true),Recorder.new())
	baseline.slot.rift.equipped=["","",""]
	baseline.player.ki=0;resumed.player.ki=0
	baseline.update(1,{});resumed.update(1,{})
	near(resumed.player.ki,baseline.player.ki*1.02,.001)
	profile.slots[0]=resumed.to_save()
	decoded=schema.import_code(schema.export_code(profile))
	ok(decoded.ok);ok(card in decoded.profile.slots[0].rift.cards)
	eq(decoded.profile.slots[0].rift.equipped[0],card)
	resumed=launch(resumed,"rp01_dark_crystal")
	ok(resumed.equip_hero_card("",0) is String)
func test_rift_old_profile_migration_repairs_malformed_cards_without_grants() -> void:
	var schema:=RuleSchema.new()
	var g:=postgame()
	var slot:=g.slot.duplicate(true);slot.erase("rift")
	var p:=schema.migrate({"version":8,"slots":[slot],"lastSlot":0})
	eq(p.version,9);eq(p.slots[0].rift.cards,[])
	eq(p.slots[0].quests,slot.quests)
	slot.rift={"cards":["bogus",42,"rp01_dark_crystal_hero","rp01_dark_crystal_hero"],"equipped":["bogus","rp01_dark_crystal_hero","rp01_dark_crystal_hero"],"results":{"bogus":{"stars":3},"rp01_dark_crystal":{"stars":99,"clears":-4}},"pending":"bogus"}
	var clean:=schema.normalize(slot)
	eq(clean.rift.cards,["rp01_dark_crystal_hero"])
	eq(clean.rift.equipped,["","rp01_dark_crystal_hero",""])
	eq(clean.rift.results.rp01_dark_crystal.stars,3)
	eq(clean.rift.results.rp01_dark_crystal.clears,0)
	ok(not clean.rift.results.has("bogus"));ok(not clean.rift.has("pending"))
	eq(schema.normalize(clean),clean)
func test_rift_card_health_damage_and_protect_target_simultaneous_final_hit() -> void:
	var g:=postgame()
	g.slot.rift.cards=["rp02_shattered_landing_hero","rp03_nameck_storm_hero"]
	var hp: float=g.player.maxHealth
	eq(g.equip_hero_card("rp03_nameck_storm_hero",0),null)
	near(g.player.maxHealth,hp*1.02,.01)
	eq(g.equip_hero_card("rp02_shattered_landing_hero",1),null)
	g=launch(g,"rp01_dark_crystal")
	var e: Dictionary=g.combat.enemies[0]
	var before: float=e.health
	g.combat.hit(e,100,g.player)
	near(before-e.health,102)
	clear(g)
	g=launch(g,"rp02_shattered_landing");clear(g)
	g=launch(g,"rp03_nameck_storm")
	for enemy: Dictionary in g.combat.enemies.duplicate():g.combat.hit(enemy,1e9,g.player,true)
	g.combat.sync()
	var ally: Dictionary=g.combat.allies[0]
	g.combat.hit(ally,ally.maxHealth+100,g.combat.enemies[0],true)
	for enemy: Dictionary in g.combat.enemies.duplicate():g.combat.hit(enemy,1e9,g.player,true)
	eq(g.rift.run.status,"failed","last boss cannot hide a simultaneous protect knockout")
	ok(not g.slot.rift.results.has("rp03_nameck_storm"))
func test_rift_floating_arena_fall_fails_and_boss_phase_does_not_regress() -> void:
	var g:=postgame()
	for m: Dictionary in RuleTables.table("rift_missions").missions:g.slot.rift.results[m.id]={"stars":1,"clears":1}
	eq(g.start_rift_mission("rp15_zero_origin"),null)
	ok(g.rift.active())
	if not g.rift.active():return
	ok(g.zone.kill_y!=null,"Nexus has a void boundary")
	g.player.pos.y=float(g.zone.kill_y)-1
	g.rift.update(.01)
	eq(g.rift.run.status,"failed")
	g.player.health=g.player.maxHealth
	g=launch(g,"rp01_dark_crystal")
	for e: Dictionary in g.combat.enemies.duplicate():g.combat.hit(e,1e9,g.player,true)
	g.combat.sync()
	var boss: Dictionary=g.combat.enemies[0]
	boss.health=boss.maxHealth*.3;g.rift.update(0)
	eq(boss.riftPhase,2)
	var damage: float=boss.damageMultiplier
	boss.health=boss.maxHealth;g.rift.update(0)
	eq(boss.riftPhase,2);near(boss.damageMultiplier,damage)
