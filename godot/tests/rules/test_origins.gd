extends "res://tests/rules/story_case.gd"
const Scenes = preload("res://rules/cutscene_rules.gd")
func test_fresh_fighters_start_with_origins_for_every_race() -> void:
	var schema := RuleSchema.new()
	for race: String in RuleTables.table("race_order"):
		var slot := schema.new_slot(schema.default_look(race),1000)
		eq(slot.zone,"mt_paozu")
		eq(slot.story.flags.originsRequired,true)
		ok(slot.quests.is_empty(),"offered normally, never silently accepted")
	var s := Session.new("Saiyan",true)
	var q: Dictionary = s.story.quest.k01_emperor_pilav
	eq(s.story.next_main().title,q.title)
	eq(s.story.navigation().questId,q.id)
	ok(not s.story.can_accept(s.story.quest.m01_arrival))
	var n: Dictionary = s.story.npc.goku_kid
	s.at(s.story.npc_pos(n))
	eq(s.story.interact(),"accept")
	ok(s.story.is_active(q.id))
	ok(s.story.tracker()[0].main)
	ok(s.story.track_quest(q.id))
	eq(s.story.navigation().questId,q.id)

func test_all_seven_chapters_with_actual_boss_damage_and_natural_rewards() -> void:
	# Human proves the full-moon story never requires the player's Saiyan forms.
	var s := Session.new("Human",true)
	var kills := 0
	var ids: Array = RuleTables.table("origins").chapters
	for id: String in ids:
		var q: Dictionary = s.story.quest[id]
		ok(s.slot.level>=q.level,"natural rewards unlock "+id+" at level "+str(s.slot.level))
		if s.slot.level<q.level: return
		var giver: Dictionary = s.story.npc[q.giver]
		if not go(s,giver.zone): return
		s.at(s.story.npc_pos(giver))
		ok(s.story.accept_quest(q.id),"accept "+id)
		if not s.story.is_active(id): return
		for guard: int in 80:
			if not s.story.is_active(id): break
			var step: Dictionary = s.story.step_of(q)
			match step.type:
				"talk":
					var n: Dictionary = s.story.npc[step.npc]
					if not go(s,n.zone): return
					s.at(s.story.npc_pos(n))
					ok(s.story.visible(n),"visible speaker "+n.id)
					eq(s.story.interact(),"talk",id+" "+n.id)
				"travel":
					if not go(s,step.zone): return
					s.story.update(1.0/60)
				"reach":
					if not go(s,step.zone): return
					s.at(s.story.at(step))
					s.story.update(1.0/60)
				"collect":
					for spot: Dictionary in step.spots:
						if not go(s,spot.get("zone",step.zone)): return
						s.at(spot_at(s,spot,step))
						s.story.update(1.0/60)
				"train":
					if not go(s,step.zone): return
					s.at(s.game.zone.region_spawn(step.zone))
					var intents: Dictionary = {}
					match step.mode:
						"move": s.game.player.vel.x=4
						"fly": s.game.player.flying=true
						"charge": intents.charge=true
					s.story.update(step.seconds+0.01,intents)
				"defeat":
					if not go(s,step.zone): return
					s.game.combat.sync()
					var enemies: Array = s.game.combat.enemies.filter(func(e: Dictionary) -> bool:return e.key==step.enemy)
					eq(enemies.size(),1,"one staged boss "+step.enemy)
					if enemies.is_empty(): return
					var e: Dictionary = enemies[0]
					eq(int(e.level),int(step.enemyLevel))
					s.at({"x":e.pos.x,"y":e.pos.y,"z":e.pos.z})
					var director := Scenes.new(s.slot)
					ok(director.before_for(s.story.encounters(),s.game.player.pos)!=null,step.enemy+" before scene")
					var index := int(s.slot.quests[id].step)
					s.story.interact()
					eq(int(s.slot.quests[id].step),index,"talk cannot win "+step.enemy)
					s.game.combat.hit(e,e.maxHealth+100,s.game.player,true)
					eq(e.health,0.0,step.enemy+" was killed by actual damage")
					ok(int(s.slot.quests[id].step)>index,step.enemy+" kill advances chapter")
					var wallet: float = s.slot.zeni
					s.game.combat.hit(e,100,s.game.player)
					near(s.slot.zeni,wallet)
					ok(director.after_for(step.enemy)!=null,step.enemy+" after scene")
					kills+=1
		ok(s.story.is_done(id),"completed "+id)
		if not s.story.is_done(id): return
		ok(not s.story.accept_quest(id),"no repeated chapter rewards")
		eq(int(s.slot.quests[id].completions),1)
		s.slot = RuleSchema.new().normalize(s.game.to_save())
		s.enter(str(s.slot.zone))
	eq(kills,23)
	ok(s.slot.level>=9 and s.slot.level<15,"childhood stays within the adult opening level range")
	ok(s.story.can_accept(s.story.quest.m01_arrival))
	eq(s.story.next_main().title,s.story.quest.m01_arrival.title)
	ok(not s.slot.story.flags.get("shenron",false),"childhood orbs never complete the adult summon")
	ok(s.slot.forms.is_empty(),"no forced race transformation")
	for id: String in ids: ok(s.story.is_done(id),"saved completion "+id)

func test_legacy_v7_fighters_keep_progress_and_origins_is_optional() -> void:
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.story.flags.erase("originsRequired")
	slot.zone="namek";slot.position={"x":19,"y":24,"z":-31}
	slot.level=1275;slot.xp=1234;slot.zeni=456789;slot.forms=["SSJ","SSJ4"]
	slot.formMastery={"SSJ":88};slot.style="brawler"
	slot.quests={"m01_arrival":{"status":"done","completions":1},"m09_ginyu":{"status":"active","step":2,"count":1,"t":3.5,"collected":[0]}}
	slot.story.flags.scenes={"before:raditz":true}
	var before := slot.duplicate(true)
	var migrated := schema.migrate({"version":7,"slots":[slot],"lastSlot":0})
	var result: Dictionary = migrated.slots[0]
	eq(migrated.version,8)
	eq(result.story.flags.originsRequired,false)
	for key: String in ["zone","position","level","xp","zeni","quests","forms","formMastery","appearance","loadout","style"]:
		eq(result[key],before[key],"preserve "+key)
	eq(result.story.flags.scenes,before.story.flags.scenes)
	ok(not slot.story.flags.has("originsRequired"),"migration does not mutate input")
	eq(schema.migrate(migrated),migrated,"idempotent migration")
	var s := Session.new()
	var q: Dictionary = s.story.quest.k01_emperor_pilav
	ok(s.story.can_accept(s.story.quest.m01_arrival),"adult opening stays available")
	ok(s.story.can_accept(q),"legacy may choose Origins")
	ok(not s.story.is_main(q))
	ok(s.story.is_main(s.story.quest.m01_arrival))
	eq(s.story.required_after(s.story.quest.m01_arrival),[])
	eq(s.story.next_main().title,s.story.quest.m01_arrival.title)
	ok(go(s,"mt_paozu"))
	s.at(s.story.npc_pos(s.story.npc[q.giver]))
	ok(s.story.accept_quest(q.id))
	ok(not s.story.tracker()[0].main)
	ok(s.story.track_quest(q.id))
	eq(s.story.navigation().questId,q.id,"optional chapters still track when chosen")
	ok(s.story.can_accept(s.story.quest.m01_arrival),"optional quest cannot block adult progress")

func test_checkpoint_code_preserves_collection_training_and_new_save_gate() -> void:
	var schema := RuleSchema.new()
	var s := Session.new("Saiyan",true)
	var q: Dictionary = s.story.quest.k01_emperor_pilav
	s.at(s.story.npc_pos(s.story.npc[q.giver]))
	ok(s.story.accept_quest(q.id))
	s.at(s.story.npc_pos(s.story.npc.bulma_young));s.story.interact()
	var step: Dictionary = s.story.step_of(q)
	eq(step.type,"collect")
	s.at(spot_at(s,step.spots[0],step));s.story.update(0.1)
	eq(s.slot.quests[q.id].collected,[0])
	ok(s.story.track_quest(q.id))
	var profile := schema.new_profile();profile.slots[0]=s.game.to_save()
	var decoded := schema.import_code(schema.export_code(profile))
	ok(decoded.ok)
	s.slot=decoded.profile.slots[0];s.enter(str(s.slot.zone))
	eq(s.story.tracked_id,q.id)
	eq(s.slot.story.flags.originsRequired,true)
	eq(s.slot.quests[q.id].collected,[0.0])
	s.at(spot_at(s,step.spots[1],step));s.story.update(0.1)
	eq(s.story.step_of(q).npc,"oolong")
	eq(s.slot.quests[q.id].collected,[],"next collection step starts empty")
	ok(not s.story.can_accept(s.story.quest.m01_arrival))
	# An incomplete training timer and fight counter survive exactly; normalization grants no completion.
	s.slot.quests[q.id]={"status":"done","completions":1}
	s.slot.quests.k02_world_tournament_21={"status":"active","step":2,"t":5.75,"count":0,"collected":[],"completions":0}
	profile.slots[0]=s.slot
	decoded=schema.import_code(schema.export_code(profile))
	ok(decoded.ok)
	near(decoded.profile.slots[0].quests.k02_world_tournament_21.t,5.75)
	eq(decoded.profile.slots[0].quests.k02_world_tournament_21.status,"active")

func test_training_stays_local_and_bosses_stage_only_at_their_objective() -> void:
	var s := Session.new("Saiyan",true)
	var q: Dictionary = s.story.quest.k02_world_tournament_21
	s.slot.quests[q.id]={"status":"active","step":2,"t":0.0,"count":0,"collected":[],"completions":0}
	var step: Dictionary = s.story.step_of(q)
	eq(step.type,"train")
	s.game.player.vel.x=4
	s.story.update(20)
	eq(int(s.slot.quests[q.id].step),2,"running at Paozu cannot finish Kame House training")
	eq(s.slot.quests[q.id].t,0.0)
	s.at(s.story.at(step));s.game.player.vel.x=4
	s.story.update(12.1)
	eq(int(s.slot.quests[q.id].step),3)
	s.slot.quests.erase(q.id)
	q=s.story.quest.k03_red_ribbon
	s.slot.quests[q.id]={"status":"active","step":0,"t":0.0,"count":0,"collected":[],"completions":0}
	ok(not s.story.visible(s.story.npc.silver),"boss hidden before objective")
	ok(s.story.encounters().is_empty())
	s.slot.quests[q.id].step=1
	ok(s.story.visible(s.story.npc.silver))
	eq(s.story.encounters().size(),1)
	eq(s.story.encounters()[0].key,"silver")
	s.story.enemy_defeated("silver",s.game.zone.id)
	ok(s.story.encounters().is_empty(),"no repeat spawn after the fight step")
	s.slot.quests[q.id].status="done"
	ok(not s.story.visible(s.story.npc.silver),"completed chapter removes its hostile actor")

func test_childhood_transport_reaches_reused_adult_areas_without_changing_difficulty() -> void:
	var s := Session.new("Saiyan",true)
	var q: Dictionary = s.story.quest.k01_emperor_pilav
	s.slot.quests[q.id]={"status":"active","step":8,"t":0.0,"count":0,"collected":[],"completions":0}
	eq(s.story.step_of(q).zone,"kame_island")
	eq(s.story.travel_level("kame_island"),1)
	eq(s.story.travel_level("red_ribbon"),1900)
	var guide: Variant = s.story.travel_guide()
	ok(guide!=null)
	if guide!=null:
		s.at(guide)
		ok(s.story.travel_to("kame_island"),"Lv1 story pilot reaches Roshu")
	s.slot.quests[q.id].status="done"
	q=s.story.quest.k03_red_ribbon
	s.slot.quests[q.id]={"status":"active","step":0,"t":0.0,"count":0,"collected":[],"completions":0}
	eq(s.story.travel_level("red_ribbon"),4,"army chapter transport")
	s.slot.story.flags.originsRequired=false
	eq(s.story.travel_level("red_ribbon"),4,"optional legacy chapter transport")
	s.slot.quests[q.id].status="done"
	eq(s.story.travel_level("red_ribbon"),1900,"adult requirement restored")
	eq(int(RuleTables.table("rpg").ZONE_LEVELS.red_ribbon),1900,"global difficulty untouched")
