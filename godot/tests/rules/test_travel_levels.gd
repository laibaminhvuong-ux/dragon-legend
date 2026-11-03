extends "res://tests/rules/story_case.gd"
# User request 2026-11-03: even after an area's quests, you need a set level to travel to the next map.
func _pilot(s: Session) -> void:
	s.story.state.unlocked.append("namek")
	for q: Dictionary in s.story.quests:   # no local story tasks, so the pilot offers trips
		if q.get("main", false): s.slot.quests[q.id] = {"status": "done", "step": 0, "completions": 1}
	var guide: Variant = s.story.travel_guide()
	ok(guide != null, "a pilot is here")
	if guide != null: s.at(guide)

func test_pilot_needs_the_destination_level() -> void:
	var s := Session.new()
	_pilot(s)
	var need: int = s.story.travel_level("namek")
	eq(need, int(RuleTables.table("rpg").ZONE_LEVELS.namek))
	s.slot.level = need - 1
	var opt: Array = s.story.travel_options().filter(func(o: Dictionary) -> bool: return o.zone == "namek")
	ok(not opt.is_empty() and opt[0].locked and int(opt[0].level) == need, "shown as locked with its level")
	ok(not s.story.travel_to("namek"), "can't go below the level")
	ok(s.bus.log.any(func(e: Dictionary) -> bool: return e.event == "notify" and str(e.value.text).contains("Lv. %d" % need)), "says which level")
	eq(s.bus.count("travel"), 0)
	s.slot.level = need
	ok(s.story.travel_to("namek"), "goes at the level")

func test_open_towns_have_no_gate() -> void:
	var s := Session.new()
	eq(s.story.travel_level("amber_city"), 0)

func test_king_kae_planet_portal_needs_its_level_too() -> void:
	var s := Session.new()
	s.enter("snake_way")
	s.story.state.unlocked.append("king_kai")
	s.slot.level = s.story.travel_level("king_kai") - 1
	var p: Dictionary = s.game.zone.def.portals[0]
	var at: Dictionary = s.game.zone.place(float(p.x), float(p.z))
	s.game.player.pos = Vector3(at.x, float(p.y), at.z)
	s.story.update(1.0 / 60)
	eq(s.bus.count("travel"), 0, "too low")
	s.slot.level = s.story.travel_level("king_kai")
	s.game.time += 5.0
	s.story.update(1.0 / 60)
	eq(s.bus.count("travel"), 1, "lands at the level")
