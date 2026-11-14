extends "res://tests/rules/story_case.gd"
# Story boss phases (2026-11-13): story bosses transform mid-fight (npcs rows `phases`, RuleCombat.boss_phase), with the same
# row fields (riftPhase, form, damageMultiplier, runSpeed) and riftBossPhase event as the Rift Patrol bosses.

func _phased() -> Dictionary:
	var out := {}
	for n: Dictionary in RuleTables.table("npcs"):
		if n.has("phases"):
			out[str(n.id)] = n
	return out

func _boss_steps() -> Dictionary:
	var out := {}
	for q: Dictionary in RuleTables.table("quests"):
		for s: Dictionary in q.steps:
			if s.type == "defeat" and int(s.get("count", 1)) <= 1:
				out[str(s.enemy)] = q.id
	return out

func _canon_words() -> Array:
	var names: Dictionary = RuleTables.table("names")
	var out: Array = ["Saiyan", "Majin"]
	for pair: Array in names.NAMES + names.TERMS:
		out.append(str(pair[0]))
	return out

func test_phase_data_is_fair_monotonic_and_has_looks() -> void:
	var phased := _phased()
	var bosses := _boss_steps()
	var chars: Dictionary = RuleTables.table("characters")
	var looks: Dictionary = RuleTables.table("form_looks")
	ok(phased.size() >= 12, "%d story bosses have phases" % phased.size())
	for id: String in ["frieza", "frost", "imperfect_cell", "perfect_cell", "goku_black", "broly", "super_buu", "jiren", "toppo", "kefla",
			"vegeta_gizard", "majin_vegeta", "king_piccolo", "piccolo_jr", "gogeta_trial"]:
		ok(phased.has(id), id + " has phases")
	var canon := _canon_words()
	for id: String in phased:
		var n: Dictionary = phased[id]
		ok(bosses.has(id), id + " is a single story boss")
		var phases: Array = n.phases
		ok(phases.size() >= 2, id + " has a phase after the opening")
		eq(float(phases[0].at), 1.0, id + " phase 0 opens the fight")
		eq(float(phases[0].damage), 1.0, id + " opening damage is the base")
		var own: Variant = chars[n.who].get("look", {}).get("formLooks")
		for i: int in phases.size():
			var ph: Dictionary = phases[i]
			ok(float(ph.damage) >= 1.0 and float(ph.damage) <= 1.25, "%s phase %d damage %.2f within +25%%" % [id, i, float(ph.damage)])
			ok(float(ph.speed) >= 1.0 and float(ph.speed) <= 1.1, "%s phase %d speed %.2f modest" % [id, i, float(ph.speed)])
			if i > 0:
				ok(float(ph.at) < float(phases[i - 1].at), "%s phase %d comes at lower health" % [id, i])
				ok(float(ph.damage) >= float(phases[i - 1].damage), "%s phase %d never weaker" % [id, i])
				ok(str(ph.get("text", "")) != "", "%s phase %d announces itself" % [id, i])
			if ph.has("form"):
				var look_id: String = str((own as Dictionary).get(ph.form, ph.form)) if own is Dictionary else str(ph.form)
				ok(looks.has(look_id), "%s phase %d form %s has a look" % [id, i, ph.form])
			for word: String in canon:
				var text := " %s %s " % [str(ph.get("text", "")), str(ph.get("name", ""))]
				var hit := RegEx.create_from_string("\\b" + word.replace(".", "\\.") + "\\b")
				ok(hit.search(text) == null, "%s phase %d text has no canon name %s: %s" % [id, i, word, text])

func _boss(s: Session, npc_id: String, level: int = 160) -> Dictionary:
	var n: Dictionary = _phased()[npc_id]
	var c: Dictionary = RuleTables.table("characters")[n.who]
	s.game.combat.sync_at = INF   # no story quest owns this test boss: keep sync() from removing it
	var p := s.game.zone.free_position({"x": s.game.player.pos.x + 6, "z": s.game.player.pos.z})
	return s.game.combat.spawn({"key": npc_id, "uid": npc_id, "name": c.name, "look": c.look, "level": level, "boss": true, "x": p.x, "z": p.z, "phases": n.phases})

func test_boss_steps_through_phases_and_never_goes_back() -> void:
	var s := Session.new()
	var e := _boss(s, "frieza")
	eq(int(e.riftPhase), 0, "opening phase")
	eq(str(e.form), "SecondForm", "Frigor opens in his second form")
	near(float(e.damageMultiplier), 1.0)
	e.health = e.maxHealth * 0.6
	s.game.combat.update(0, {})
	eq(int(e.riftPhase), 1)
	eq(str(e.form), "ThirdForm")
	var events: Array = s.bus.log.filter(func(ev: Dictionary) -> bool: return ev.event == "riftBossPhase")
	eq(events.size(), 1, "one phase announce")
	if not events.is_empty():
		eq(str(events[0].value.text), "Frigor sheds his horns: Third Form!")
		eq(str(events[0].value.form), "ThirdForm", "the event carries the form")
		eq(str(events[0].value.character), "Frigor", "renamed name, not the id")
	e.health = e.maxHealth * 0.1   # a big hit skips straight to the last phase
	s.game.combat.update(0, {})
	eq(int(e.riftPhase), 3)
	eq(str(e.form), "FullPower")
	near(float(e.damageMultiplier), 1.25, 1e-6, "last phase +25% damage")
	near(float(e.runSpeed), float(s.game.combat.c.enemySpeed) * 1.1, 1e-6)
	e.health = e.maxHealth   # regenerated (it walked home): the phase stays
	s.game.combat.update(0, {})
	eq(int(e.riftPhase), 3, "phases never go backwards")
	eq(str(e.form), "FullPower")
	s.game.combat.reset_boss_phase(e)   # a full reset (the player was knocked out) starts the fight over
	eq(int(e.riftPhase), 0)
	eq(str(e.form), "SecondForm")
	near(float(e.damageMultiplier), 1.0)

func test_boss_without_opening_form_returns_to_base_look_on_reset() -> void:
	var s := Session.new()
	var e := _boss(s, "broly", 780)
	ok(not e.has("form") or str(e.form) == "", "Brolo opens in his base look")
	e.health = e.maxHealth * 0.7
	s.game.combat.boss_phase(e)
	eq(str(e.form), "Wrathful", "80% reached: Wrathful")
	e.health = e.maxHealth * 0.5
	s.game.combat.boss_phase(e)
	eq(str(e.form), "SSJRestrained", "60% reached: Restrained Super Saiyar")
	e.health = e.maxHealth * 0.3
	s.game.combat.boss_phase(e)
	eq(str(e.form), "SSJ", "Brolo's Super Saiyar (his SSJBroly look)")
	e.health = e.maxHealth * 0.1
	s.game.combat.boss_phase(e)
	eq(str(e.form), "LegendarySSJ", "the last phase is the Legendary Super Saiyar")
	near(float(e.damageMultiplier), 1.25, 1e-6)
	e.health = e.maxHealth
	s.game.combat.reset_boss_phase(e)
	eq(str(e.form), "", "back to the base look (empty, so the view clears the form)")

func test_rift_bosses_are_left_to_rift_patrol() -> void:
	var s := Session.new()
	var e := _boss(s, "jiren", 720)
	e.key = "rift:jiren"
	e.erase("riftPhase")
	e.health = e.maxHealth * 0.1
	s.game.combat.boss_phase(e)
	ok(not e.has("riftPhase"), "story phases skip rift rows")

func test_story_encounter_row_carries_the_phases() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quest.m19_perfect_cell
	var step := -1
	for i: int in q.steps.size():
		if q.steps[i].type == "defeat":
			step = i
	s.enter(str(q.steps[step].zone))
	s.slot.level = int(q.level)
	s.slot.quests[q.id] = {"status": "active", "step": step, "t": 0.0, "count": 0, "collected": [], "completions": 0}
	var rows: Array = s.story.encounters().filter(func(r: Dictionary) -> bool: return r.key == "perfect_cell")
	eq(rows.size(), 1, "Cel's boss row")
	if rows.is_empty():
		return
	ok((rows[0].phases as Array).size() == 2, "phases on the row")
	s.game.combat.sync()
	var cel: Array = s.game.combat.enemies.filter(func(e: Dictionary) -> bool: return e.key == "perfect_cell")
	eq(cel.size(), 1)
	if cel.is_empty():
		return
	eq(str(cel[0].form), "CellPerfect", "Cel spawns perfect")
	cel[0].health = cel[0].maxHealth * 0.3
	s.game.combat.update(0, {})
	eq(str(cel[0].form), "CellSuperPerfect", "and turns Super Perfect at low health")
	ok(float(cel[0].damageMultiplier) <= 1.25)

# --- task E (2026-11-13): phases for forms no playable race shows on a boss, size forms, the fusion trial ---

func _look_of(npc_id: String, form: String) -> String:
	var own: Variant = RuleTables.table("characters")[_phased()[npc_id].who].get("look", {}).get("formLooks")
	return str((own as Dictionary).get(form, form)) if own is Dictionary else form

func test_story_only_form_looks_are_used_by_boss_phases() -> void:
	var used := {}
	for id: String in _phased():
		for ph: Dictionary in _phased()[id].phases:
			if ph.has("form"):
				used[_look_of(id, str(ph.form))] = id
	for look: String in ["Oozaru", "Giant", "Orange", "NamekFusion", "SSJ4Gogeta", "SSJ2Majin", "SSJRestrained", "LegendarySSJ",
			"FrostAssault", "FinalFormFrost", "FullPowerFrost", "SSJRose"]:
		ok(used.has(look), "a boss phase shows " + look)
	eq(str(_phased().vegeta_gizard.phases[-1].form), "Oozaru", "Vegara turns Great Ape at the Gizard fight")
	eq(str(_phased().king_piccolo.phases[-1].form), "Giant", "King Piccor ends as a giant")
	eq(str(_phased().piccolo_jr.phases[-1].form), "Giant", "Piccor Jr. ends as a giant")
	eq(str(_phased().broly.phases[-1].form), "LegendarySSJ", "Brolo ends Legendary")
	eq(_look_of("gogeta_trial", str(_phased().gogeta_trial.phases[-1].form)), "SSJ4Gogeta", "Gogeto ends in his own SSJ4 look")
	eq(_look_of("majin_vegeta", str(_phased().majin_vegeta.phases[-1].form)), "SSJ2Majin")

func test_giant_phase_grows_reach_and_hitbox() -> void:
	var s := Session.new()
	var cb: RefCounted = s.game.combat
	var e := _boss(s, "king_piccolo", 40)
	near(float(cb.body_size(e)), 1.0, 1e-6, "normal size before the giant phase")
	var p: Dictionary = s.game.player
	var d: float = float(cb.c.enemyRange) * 2.0   # out of a normal fighter's reach, inside a giant's
	e.pos = (p.pos as Vector3) + Vector3(d, 0, 0)
	e.home = e.pos
	cb.update(0.0, {})
	ok(float(e.windup) <= 0.0, "a normal-size boss does not swing from %.1f m" % d)
	e.health = e.maxHealth * 0.2
	cb.boss_phase(e)
	eq(str(e.form), "Giant")
	near(float(cb.body_size(e)), 3.0, 1e-6, "Giant Form size 3")
	e.pos = (p.pos as Vector3) + Vector3(d, 0, 0)
	e.cooldown = 0.0; e.stun = 0.0
	cb.update(0.0, {})
	ok(float(e.windup) > 0.0, "the giant swings from %.1f m" % d)
	# the player reaches the giant's body from further away (melee) and hits its raised chest (ki)
	e.pos = (p.pos as Vector3) + Vector3(0, 0, 3.4)
	p.yaw = 0.0
	p.lockTarget = null
	ok(not cb.target_in_front(2.8).is_empty(), "melee reaches a giant's body 3.4 m away")
	e.form = ""
	ok(cb.target_in_front(2.8).is_empty(), "but not a normal fighter's")
	e.form = "Giant"
	near((cb.body_center(e) as Vector3).y - (e.pos as Vector3).y, 3.0, 1e-6, "chest 3 m up")
	near(float(cb.segment_distance(cb.body_center(e), (e.pos as Vector3) + Vector3(-5, 3.0, 0), (e.pos as Vector3) + Vector3(5, 3.0, 0))), 0.0, 1e-6)
	ok(cb.segment_distance(cb.body_center(e), (e.pos as Vector3) + Vector3(-5, 4.2, 0), (e.pos as Vector3) + Vector3(5, 4.2, 0)) < float(cb.c.projectileRadius) + float(cb.body_reach(e)),
		"a ki blast at the giant's shoulders hits")

func test_great_ape_phase_is_a_size_form() -> void:
	var s := Session.new()
	var e := _boss(s, "vegeta_gizard", 70)
	ok(not e.has("form") or str(e.form) == "", "Vegara opens in his base look")
	e.health = e.maxHealth * 0.3
	s.game.combat.boss_phase(e)
	eq(str(e.form), "Oozaru")
	near(float(s.game.combat.body_size(e)), 3.2, 1e-6, "Great Ape size 3.2")
	ok(float(s.game.combat.body_reach(e)) > 1.0, "its body is reached from further away")
	e.health = e.maxHealth   # knocked-out player: the boss is back at full health and starts over
	s.game.combat.reset_boss_phase(e)
	near(float(s.game.combat.body_size(e)), 1.0, 1e-6, "a reset shrinks him back")

func test_fusion_trial_is_an_optional_quest_with_gogeto() -> void:
	var s := Session.new()
	var q: Dictionary = s.story.quest.trial_gogeta
	ok(not q.get("main", false), "optional")
	eq(str(q.giver), "cheelai")
	ok("m33_broly" in (q.after as Array), "after Brolo's fight")
	var n: Dictionary = s.story.npc.gogeta_trial
	eq(str(n.who), "gogeta")
	eq(str(n.zone), str(q.steps[0].zone), "he waits where the fight is")
	ok(not s.story.visible(n), "not there before Brolo's fight")
	s.slot.quests.m33_broly = {"status": "done", "step": 0, "t": 0.0, "count": 0, "collected": [], "completions": 1}
	ok(s.story.visible(n) or not s.game.zone.has_region(str(n.zone)), "there after it (when his area is loaded)")
	s.slot.quests.trial_gogeta = {"status": "done", "step": 0, "t": 0.0, "count": 0, "collected": [], "completions": 1}
	ok(not s.story.visible(n), "gone once beaten")
	var e := _boss(s, "gogeta_trial", 820)
	e.health = e.maxHealth * 0.1
	s.game.combat.boss_phase(e)
	eq(str(e.form), "SSJ4")
	near(float(e.damageMultiplier), 1.25, 1e-6)
