extends "res://tests/rules/game_case.gd"
# Story data fixes (2026-11-13): tournament bouts on the ring, no quest point or quest giver under water, Rift boss
# phases that transform (display form on the enemy row), Kaiyoken form looks.

const RING := Rect2(-20, 0, 40, 40)   # Tournament Island's ring (budokaihall at 0,20): x -20..20, z 0..40

func test_tournament_bouts_stand_on_the_ring() -> void:
	var npcs: Dictionary = {}
	for n: Dictionary in RuleTables.table("npcs"):
		npcs[n.id] = n
	var bouts := 0
	for q: Dictionary in RuleTables.table("quests"):
		for s: Dictionary in q.steps:
			if s.type != "defeat" or str(s.get("zone", "")) != "tournament_island" or s.enemy == "tambourine":
				continue   # Tamburin ambushes the grounds, not a ring bout
			bouts += 1
			var p := Vector2(float(s.x), float(s.z))
			ok(RING.grow(-3.0).has_point(p), "%s %s fights on the ring, 3 m in from its edge (%s)" % [q.id, s.enemy, p])
			var n: Dictionary = npcs.get(s.enemy, {})
			ok(not n.is_empty() and str(n.zone) == "tournament_island", s.enemy + " is staged on Tournament Island")
			if not n.is_empty():
				eq(Vector2(float(n.x), float(n.z)), p, s.enemy + " stands where the quest marker is")
			ok(float(s.r) >= 7.0, "the bout's reach covers the fighter's spot")
	eq(bouts, 7, "seven tournament bouts (Gyran, Namu, Jackie Chung, Chaozo, Cyborg Tau, Tenzo, Piccor Jr.)")

func _water_level(zone: RuleZone, x: float, z: float) -> float:
	var lvl := -INF
	if zone.water is Dictionary:
		var w: Dictionary = zone.water
		if w.get("ocean", false) or Vector2(x - float(w.x), z - float(w.z)).length() < float(w.radius):
			lvl = float(w.level)
	if zone is RulePlanet:
		for l: Dictionary in (zone as RulePlanet).lakes():
			if Vector2(x - float(l.x), z - float(l.z)).length() < float(l.radius):
				lvl = maxf(lvl, float(l.level))
	return lvl

## Every quest point (reach / defeat / collect / train area) and every NPC stands above the water of its world.
func test_no_quest_point_or_npc_under_water() -> void:
	var worlds := {}
	var zones: Dictionary = RuleTables.table("zones")
	var points: Array = []
	for q: Dictionary in RuleTables.table("quests"):
		for i: int in q.steps.size():
			var s: Dictionary = q.steps[i]
			if s.type in ["reach", "defeat", "train"] and s.has("x"):
				points.append(["%s#%d %s" % [q.id, i, s.type], str(s.zone), float(s.x), float(s.z)])
			elif s.type == "collect":
				for sp: Dictionary in s.get("spots", []):
					points.append(["%s#%d collect" % [q.id, i], str(sp.get("zone", s.get("zone", ""))), float(sp.x), float(sp.z)])
	for n: Dictionary in RuleTables.table("npcs"):
		if not n.has("y"):
			points.append(["npc " + str(n.id), str(n.zone), float(n.x), float(n.z)])
	var checked := 0
	for pt: Array in points:
		if not zones.has(pt[1]):
			continue
		var pid := RulePlanet.planet_of(pt[1])
		var key: String = pid if pid != "" else pt[1]
		if not worlds.has(key):
			worlds[key] = RulePlanet.open(pt[1])
		var zone: RuleZone = worlds[key]
		var w: Dictionary = zone.place_in(pt[1], pt[2], pt[3]) if zone is RulePlanet else {"x": pt[2], "z": pt[3]}
		var lvl := _water_level(zone, float(w.x), float(w.z))
		if lvl == -INF:
			continue
		checked += 1
		var h := zone.height_at(float(w.x), float(w.z))
		ok(h > lvl + 0.2, "%s in %s (%s, %s) is above the water (ground %.2f, water %.2f)" % [pt[0], pt[1], pt[2], pt[3], h, lvl])
	ok(checked > 100, "checked %d points in worlds with water" % checked)

func test_earth_dragon_orb_on_papaya_island_is_on_dry_land() -> void:
	var hunt: Dictionary = {}
	for q: Dictionary in RuleTables.table("quests"):
		if q.id == "s_dragon_radar":
			hunt = q
	var spots: Array = hunt.steps[0].spots.filter(func(s: Dictionary) -> bool: return s.zone == "papaya_island")
	eq(spots.size(), 1)
	var earth := RulePlanet.open("papaya_island")
	var w: Dictionary = earth.place_in("papaya_island", float(spots[0].x), float(spots[0].z))
	ok(earth.height_at(w.x, w.z) > 1.5, "the orb lies on the island, not 4 m under the sea")
	eq(earth.region_at(w.x, w.z), "papaya_island")

func _postgame() -> RuleGame:
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look("Saiyan"), 1000)
	slot.zone = "time_nexus"; slot.level = 2000; slot.story.flags.originsRequired = false
	for q: Dictionary in RuleTables.table("quests"):
		if q.get("main", false): slot.quests[q.id] = {"status": "done", "completions": 1}
	for m: Dictionary in RuleTables.table("rift_missions").missions:
		slot.rift.results[m.id] = {"stars": 1, "clears": 1}
	return RuleGame.new(0, slot, Recorder.new())

func test_rift_boss_phases_transform_through_form_looks() -> void:
	var g := _postgame()
	eq(g.start_rift_mission("rp08_prison_tournament"), null, "launch")
	if not g.rift.active():
		g = RuleGame.new(0, g.to_save(), g.events)
	ok(g.rift.active(), "mission active")
	if not g.rift.active():
		return
	g.combat.sync()
	for e: Dictionary in g.combat.enemies.duplicate():   # the Shardling wave
		g.combat.hit(e, e.maxHealth + 100, g.player, true)
	g.combat.sync()
	var bosses := {}
	for e: Dictionary in g.combat.enemies:
		bosses[str(e.character)] = e
	ok(bosses.has("hollow_gokan") and bosses.has("hollow_vegara"), "both Hollow bosses spawned: %s" % [bosses.keys()])
	if not bosses.has("hollow_gokan"):
		return
	var gokan: Dictionary = bosses.hollow_gokan
	g.rift.update(0)
	eq(str(gokan.get("form", "")), "", "Breach: base look")
	gokan.health = gokan.maxHealth * 0.5
	g.rift.update(0)
	eq(gokan.form, "SSJ", "Fracture: Super Saiyar")
	gokan.health = gokan.maxHealth * 0.2
	g.rift.update(0)
	eq(gokan.form, "SSJ3", "Collapse: Super Saiyar 3")
	var vegara: Dictionary = bosses.hollow_vegara
	vegara.health = vegara.maxHealth * 0.1   # skips straight to Collapse
	g.rift.update(0)
	eq(vegara.form, "SSJ2")
	var phase_forms: Array = g.events.log.filter(func(ev: Dictionary) -> bool: return ev.event == "riftBossPhase").map(func(ev: Dictionary) -> String: return str(ev.value.get("form", "")))
	ok("SSJ3" in phase_forms, "the phase event carries the form: %s" % [phase_forms])
	# every phase form names a form look that exists (directly or through the character's look.formLooks)
	var looks: Dictionary = RuleTables.table("form_looks")
	var chars: Dictionary = RuleTables.table("characters")
	for m: Dictionary in RuleTables.table("rift_missions").missions:
		for wave: Dictionary in m.waves:
			for sp: Dictionary in wave.spawns:
				for ph: Dictionary in sp.get("phases", []):
					if ph.has("form"):
						var own: Variant = chars[sp.character].get("look", {}).get("formLooks")
						var id: String = str(own.get(ph.form, ph.form)) if own is Dictionary else str(ph.form)
						ok(looks.has(id), "%s %s phase form %s has a look" % [m.id, sp.character, ph.form])

func test_kaioken_on_super_saiyar_and_blue_shows_the_kaioken_look() -> void:
	eq(Fighter.shown_form("SSJBlue", 2), "SSJBlueKaioken")
	eq(Fighter.shown_form("SSJ", 10), "SuperKaioken")
	eq(Fighter.shown_form("SSJBlue", 0), "SSJBlue")
	eq(Fighter.shown_form("SSJ3", 2), "SSJ3", "other forms keep their look")
	eq(Fighter.shown_form("", 2), "")
	var looks: Dictionary = RuleTables.table("form_looks")
	for id: String in Fighter.KAIOKEN_LOOKS.values():
		ok(looks.has(id), id + " form look exists")
