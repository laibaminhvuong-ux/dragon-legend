extends "res://tests/rules/story_case.gd"
func test_all_four_dragons_collect_summon_and_rewards_once() -> void:
	var s := Session.new()
	# Isolate all hunts after their story prerequisites; full campaign travel is tested separately.
	for q: Dictionary in s.story.quests:
		if q.get("main",false):
			s.slot.quests[q.id] = {"status":"done","completions":1}
	s.slot.level = 2000
	s.slot.story.unlocked = RuleTables.table("zone_order").duplicate()
	var hunt_ids: Array = ["s_dragon_radar","s_namek_dragon","s_super_dragon","s_cereal_dragon"]
	for id: String in hunt_ids:
		var q: Dictionary = s.story.quest[id]
		play(s,q)
		ok(s.story.is_done(id),id+" summoned")
		var count_before: int = s.bus.count("questCompleted")
		s.story.update(1.0)
		s.story.interact()
		eq(s.bus.count("questCompleted"),count_before,"no duplicate wishes")
		ok(not s.story.accept_quest(id))
func test_collected_orbs_persist_and_radar_excludes_them() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quest.s_super_dragon
	for id: String in q.get("after",[]):
		s.slot.quests[id] = {"status":"done","completions":1}
	s.slot.level = 2000
	s.slot.story.unlocked = RuleTables.table("zone_order").duplicate()
	s.enter(s.story.npc[q.giver].zone)
	s.at(s.story.npc_pos(s.story.npc[q.giver]))
	ok(s.story.accept_quest(q.id))
	var step: Dictionary = s.story.step_of(q)
	var spot: Dictionary = step.spots[0]
	s.enter(spot.get("zone",step.get("zone")))
	var radar_before: int = s.story.radar().here.size()
	s.at(spot_at(s,spot,step))
	s.story.update(1.0/60)
	eq(s.story.radar().here.size(),radar_before-1)
	var saved: Dictionary = RuleSchema.new().normalize(s.game.to_save().duplicate(true))
	s.slot = saved
	s.enter(saved.zone)
	eq(s.slot.quests[q.id].collected.size(),1)
	s.at(spot_at(s,spot,step))
	s.story.update(1.0/60)
	eq(s.slot.quests[q.id].collected.size(),1)
	ok(not s.story.radar().elsewhere.is_empty())
