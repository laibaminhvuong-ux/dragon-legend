extends "res://tests/rules/story_case.gd"
# User request 2026-11-03: small (non-boss) fighting quests spawn at least 10 enemies spread around the map.
func _start(s: Session, id: String) -> void:
	var q: Dictionary = s.story.quest[id]
	s.slot.level = maxi(int(q.get("level", 1)), int(s.slot.level))
	for after: String in q.get("after", []):
		s.slot.quests[after] = {"status": "done", "step": 0, "completions": 1}
	if q.has("unlock"): pass
	s.story.accept(q)
	ok(s.story.is_active(id), id + " active")

func _quest_enemies(s: Session, key: String) -> Array:
	s.game.combat.sync()
	return s.game.combat.enemies.filter(func(e: Dictionary) -> bool: return e.key == key)

func test_a_group_quest_spawns_ten_spread_out() -> void:
	var s := Session.new()
	s.enter("gizard_wasteland")
	_start(s, "m05_saibamen")
	var foes := _quest_enemies(s, "saibamen")
	ok(foes.size() >= 10, "%d Saibamen-style foes" % foes.size())
	var closest := INF
	for i in foes.size():
		for j in range(i + 1, foes.size()):
			closest = minf(closest, (foes[i].pos as Vector3).distance_to(foes[j].pos))
	ok(closest > 12.0, "spread out (closest pair %.0f m)" % closest)
	var area := s.game.zone.region_at(foes[0].pos.x, foes[0].pos.z)
	ok(foes.all(func(e: Dictionary) -> bool: return s.game.zone.region_at(e.pos.x, e.pos.z) == "gizard_wasteland"), "all in the quest's area (%s)" % area)
	for i in 6:
		s.story.enemy_defeated("saibamen", "gizard_wasteland")
	ok(not s.story.is_active("m05_saibamen") or s.story.step_of(s.story.quest.m05_saibamen).type != "defeat", "six kills finish the step")

func test_bosses_stay_single() -> void:
	var s := Session.new()
	_start(s, "m02_raditz")
	eq(_quest_enemies(s, "raditz").size(), 1)

func test_hunts_work_on_planet_maps_with_ten_trainees() -> void:
	var s := Session.new()
	ok(s.game.zone is RulePlanet)
	eq(_quest_enemies(s, "patrol_earth_plains").size(), 3, "each area has its own trainees")
	ok(not _quest_enemies(s, "patrol_west_city").is_empty(), "including other areas on the map")
	_start(s, "hunt_earth_plains")
	ok(_quest_enemies(s, "patrol_earth_plains").size() >= 10, "a hunt brings 10 to fight")
	for i in 3:
		s.story.enemy_defeated("patrol_earth_plains", "earth")
	ok(not s.story.is_active("hunt_earth_plains") or s.story.step_of(s.story.quest.hunt_earth_plains).type != "defeat", "hunt kills count on the planet map")
	s.slot.quests.hunt_earth_plains = {"status": "done", "step": 0, "completions": 1}
	eq(_quest_enemies(s, "patrol_earth_plains").size(), 3, "back to the usual three after the hunt")
