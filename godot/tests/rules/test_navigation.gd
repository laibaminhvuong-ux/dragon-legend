extends "res://tests/rules/story_case.gd"
func activate(s: Session,id: String,index: int = 0) -> void:
	s.slot.quests[id] = {"status":"active","step":index,"count":0,"t":0.0,"collected":[],"completions":0}
func test_selection_persists_and_advances_to_next_objective() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quests[0]
	activate(s,q.id)
	ok(s.story.track_quest(q.id))
	eq(s.story.navigation().questId,q.id)
	eq(s.slot.story.flags.trackedQuest,q.id)
	s.enter("earth_plains")
	eq(s.story.tracked_id,q.id)
	var before: String = s.story.navigation().text
	s.story.advance(q)
	if s.story.is_active(q.id):
		eq(s.story.navigation().text,s.story.step_of(q).text)
		ok(s.story.navigation().text!=before)
	ok(not s.story.track_quest("missing"))
	ok(s.story.abandon_quest(q.id))
	s.story.navigation()
	eq(s.story.tracked_id,"")
	ok(not s.slot.story.flags.has("trackedQuest"))
func test_same_planet_target_uses_planet_coordinates_and_selection_wins() -> void:
	var s := Session.new()
	var found: bool = false
	for q: Dictionary in s.story.quests:
		for i: int in q.steps.size():
			var step: Dictionary = q.steps[i]
			if step.type!="reach" or not s.game.zone.has_region(step.get("zone","")) or step.zone=="earth_plains": continue
			activate(s,s.story.quests[0].id)
			activate(s,q.id,i)
			ok(s.story.track_quest(q.id))
			var route: Dictionary = s.story.navigation()
			var expected: Dictionary = s.game.zone.place_in(step.zone,step.x,step.z)
			near(route.x,expected.x)
			near(route.z,expected.z)
			eq(s.story.waypoint().questId,q.id)
			found = true
			break
		if found: break
	ok(found,"a cross-region reach objective exists")
func test_remote_world_routes_to_pilot_and_level_goal_stays_non_spatial() -> void:
	var s := Session.new()
	# Clear local main tasks so travel pilot is offered.
	for q: Dictionary in s.story.quests:
		if q.get("main",false): s.slot.quests[q.id] = {"status":"done","completions":1}
	s.slot.story.unlocked.append("namek")
	var remote: bool = false
	for q: Dictionary in s.story.quests:
		for i: int in q.steps.size():
			var step: Dictionary = q.steps[i]
			if step.type!="defeat" or step.get("zone")!="namek": continue
			activate(s,q.id,i)
			s.story.track_quest(q.id)
			var route: Dictionary = s.story.navigation()
			eq(route.kind,"travel")
			var guide: Dictionary = s.story.travel_guide()
			near(route.x,guide.x)
			near(route.z,guide.z)
			remote = true
			break
		if remote: break
	ok(remote)
	var q := {"id":"test_level","title":"Training","steps":[{"type":"level","level":2000,"text":"Reach level 2000"}]}
	s.story.quests = s.story.quests.duplicate()
	s.story.quests.append(q)
	s.story.quest[q.id] = q
	activate(s,q.id)
	s.story.track_quest(q.id)
	eq(s.story.navigation().kind,"training")
	eq(s.story.waypoint(),null)
