extends "res://tests/rules/story_case.gd"
func test_complete_main_story_and_side_quests_through_real_travel() -> void:
	var s := Session.new()
	ok(s.story.waypoint().text.contains("Gokan"))
	var main_count: int = 0
	for q: Dictionary in s.story.quests:
		if q.get("main",false):
			play(s,q)
			main_count += 1
	eq(main_count,41)
	# every story area unlocks through the story; open-world towns unlock when you find them
	var story_areas: Array = RuleTables.table("zones").keys().filter(func(z: String) -> bool: return RuleTables.table("zones")[z].get("kind","") not in ["town","interior"])
	eq(s.slot.story.unlocked.size(),story_areas.size())
	for q: Dictionary in s.story.quests:
		if not q.get("main",false) and not q.has("path") and not q.id.begins_with("Form_") and (not q.has("races") or "Saiyan" in q.races):
			play(s,q)
	ok("InstantTransmission" in s.slot.moves)
	ok("SpiritBomb" in s.slot.moves)
	ok(s.slot.story.flags.get("shenron",false))
	var q: Dictionary = s.story.quest.r_kingkai_gravity
	var before: int = int(s.slot.quests[q.id].completions)
	play(s,q)
	eq(int(s.slot.quests[q.id].completions),before+1)
	var copy: Dictionary = RuleSchema.new().normalize(s.game.to_save().duplicate(true))
	eq(copy.story,s.slot.story)
func test_accept_abandon_distance_death_and_shop_validation() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quests[0]
	s.game.player.pos = Vector3(100,100,100)
	ok(not s.story.accept_quest(q.id))
	s.at(s.story.npc_pos(s.story.npc[q.giver]))
	s.game.player.health = 0
	ok(not s.story.accept_quest(q.id))
	s.game.player.health = s.game.player.maxHealth
	ok(s.story.accept_quest(q.id))
	ok(s.story.abandon_quest(q.id))
	ok(not s.story.abandon_quest(q.id))
	ok(s.story.accept_quest(q.id))
	s.game.player.pos = Vector3(100,100,100)
	var item: Dictionary = s.story.shop()[0]
	ok(s.story.buy(item.id)!=null)
	for n: Dictionary in s.story.npcs():
		if n.id.begins_with("guide_"):
			s.at(n)
			break
	s.slot.zeni = 0
	ok(s.story.buy(item.id)!=null)
	s.slot.zeni = item.price
	eq(s.story.buy(item.id),null)
	ok(not s.story.use_item(item.id))
	s.game.player.health = 1
	ok(s.story.use_item(item.id))
	ok(s.game.player.health>1)
	ok(not s.story.use_item(item.id))
func test_void_rescue_and_tracker() -> void:
	var s := Session.new()
	s.enter("snake_way")
	s.game.player.pos.y = s.game.zone.kill_y-10
	s.game.player.vel = Vector3.ONE
	s.story.update(1.0/60)
	near(s.game.player.pos.x,s.game.zone.spawn.x,0.001)
	eq(s.game.player.vel,Vector3.ZERO)
	ok(s.story.next_main()!=null)
	ok(not s.story.track_quest("missing"))

func test_every_race_form_quests_and_endgame_paths() -> void:
	for race: String in RuleTables.table("race_order"):
		var s := Session.new(race)
		# Campaign prerequisites are exercised by the complete-story test above.
		for q: Dictionary in s.story.quests:
			if q.get("main",false):
				s.slot.quests[q.id] = {"status":"done","completions":1}
		s.slot.story.unlocked = RuleTables.table("zone_order").duplicate()
		s.slot.level = 2000
		for q: Dictionary in s.story.quests:
			if not q.id.begins_with("Form_") or q.get("legacy",false) or q.get("automatic",false) or q.has("path") or race not in q.get("races",[]):
				continue
			play(s,q)
			for id: String in q.get("rewards",{}).get("forms",[]):
				ok(id in s.slot.forms,race+" unlock "+id)
		for id: String in s.slot.forms:
			ok(s.game.forms.form_for_race(id,race),race+" compatible "+id)
		if race not in ["Saiyan","HalfSaiyan"]:
			continue
		for path: String in ["beast","instinct","ego"]:
			# Separate characters choose each exclusive branch.
			var branch := Session.new(race)
			branch.slot = s.slot.duplicate(true)
			branch.slot.loadout.formPath = null
			branch.enter(s.story.here())
			eq(branch.game.choose_form_path(path),null)
			for q: Dictionary in branch.story.quests:
				if q.get("path")==path and not q.get("automatic",false) and (not q.has("races") or race in q.races):
					play(branch,q)
					ok(branch.story.is_done(q.id),race+" "+path+" "+q.id)
func test_real_combat_death_credits_current_quest_once() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quests[0]
	play(s,q)
	# Find a single-boss step and isolate its current objective.
	for candidate: Dictionary in s.story.quests:
		var found: bool = false
		for i: int in candidate.steps.size():
			var step: Dictionary = candidate.steps[i]
			if step.type!="defeat" or step.get("count",1)!=1 or step.enemy.begins_with("patrol_"):
				continue
			s.slot.quests[candidate.id] = {"status":"active","step":i,"t":0,"count":0,"collected":[],"completions":0}
			s.enter(step.zone)
			s.game.combat.sync()
			var boss: Dictionary = {}
			for e: Dictionary in s.game.combat.enemies:
				if e.key==step.enemy:
					boss = e
			ok(not boss.is_empty())
			if boss.is_empty(): return
			s.game.combat.hit(boss,boss.maxHealth+1,s.game.player,true)
			ok(int(s.slot.quests[candidate.id].step)>i)
			var after: int = int(s.slot.quests[candidate.id].step)
			s.game.combat.hit(boss,99999,s.game.player,true)
			eq(int(s.slot.quests[candidate.id].step),after)
			found = true
			break
		if found: break
func test_avatar_training_requires_active_eligible_form() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quest.t_ui_avatar
	for i: int in q.steps.size():
		var step: Dictionary = q.steps[i]
		if step.type!="train" or not step.has("requiredForms"):
			continue
		s.slot.quests[q.id] = {"status":"active","step":i,"t":0.0,"count":0,"collected":[],"completions":0}
		s.enter(step.zone)
		s.at(s.story.at(step) if step.has("x") else s.game.zone.spawn)
		s.game.player.form = "SSJ"
		s.story.update(step.seconds+1,{"charge":true})
		eq(int(s.slot.quests[q.id].step),i)
		near(s.slot.quests[q.id].t,0)
		s.game.player.form = step.requiredForms[0]
		s.story.update(step.seconds+1,{"charge":true})
		ok(int(s.slot.quests[q.id].step)>i)
		return
	ok(false,"avatar training has required forms")
