extends "res://tests/scenes/test_story_play.gd"
# Every main quest played like a player would (user report 2026-11-05: a bug in Origins VII at Kamu's Lookout;
# "go through every quest again"). Unlike story-play, nothing is faked inside a world: the bot walks to NPCs and
# presses interact, trains with real inputs for the real time, walks to reach points, and fights bosses with melee
# until the rules count the kill. Only long hops between worlds/areas use the pilot/teleport like story-play.
# Every problem is logged with quest, step and position, and the run continues with a shortcut so one bug doesn't
# hide the rest. Runs with `tools/godot_test.sh quests-real` (QUESTS_ONLY=<quest id prefix> to play just those for real).

var problems: Array[String] = []
var only := ""
func _in_filter(id: String) -> bool:
	if only == "": return true
	for pre in only.split(","):
		if id.begins_with(pre): return true
	return false

func opt_in() -> Dictionary:
	# the inherited story-play test stays under its own token
	return {"test_every_main_quest_like_a_player": "quests-real", "test_whole_main_story_through_the_play_scene": "never"}

func _real_step(n: int = 1) -> void:
	for i in n:
		p.step(DT)
		if p == null: return
		if i % 6 == 0: p.render(DT * 6.0, 1.0)

func _pos() -> Vector3:
	return p.game.player.pos

func _where() -> String:
	var v := _pos()
	return "%s (%.0f, %.1f, %.0f)" % [p.game.zone.id, v.x, v.y, v.z]

func _problem(q: Dictionary, s: Variant, msg: String) -> void:
	var line := "%s step %d [%s]: %s at %s" % [q.id, int(p.game.slot.quests.get(q.id, {}).get("step", -1)) if p.game.slot.quests.has(q.id) else -1,
		str(s.get("type", "")) if s is Dictionary else "-", msg, _where()]
	problems.append(line)
	print("PROBLEM ", line)

func _keep_alive() -> void:
	var pl: Dictionary = p.game.player
	pl.health = float(pl.get("maxHealth", pl.health))
	if pl.has("ki") and pl.has("maxKi"): pl.ki = pl.maxKi

## Gets within r of (x, z) like a player: walks (jumping when blocked); far away, over water or when stuck it flies
## over and lands. Returns false if it couldn't get there.
func walk_to(x: float, z: float, r: float, limit := 90.0) -> bool:
	var best := INF
	var since := 0.0
	var t := 0.0
	var flying := false
	while t < limit:
		var v := _pos()
		var d := Vector2(x - v.x, z - v.z)
		if d.length() < r:
			if flying:
				_land()
				p.forced = {}
				_real_step(2)
				if Vector2(x - _pos().x, z - _pos().z).length() >= r + 1.5:
					flying = false; since = 0.0; continue
			p.forced = {}
			_real_step(2)
			return true
		if d.length() < best - 0.3:
			best = d.length(); since = 0.0
		var want_fly := d.length() > 80.0 or since > 2.5
		var it := {}
		if want_fly and not flying:
			it.flight = true; flying = true
		var dir := d.normalized()
		it.merge({"move_x": dir.x, "move_z": dir.y, "sprint": true})
		if flying:
			var ground := p.game.zone.height_at(v.x, v.z)
			it.ascend = v.y < maxf(ground, p.game.zone.height_at(v.x + dir.x * 8.0, v.z + dir.y * 8.0)) + 6.0
		else:
			it.jump = since > 1.0 and int(t * 10) % 10 == 0
		p.forced = it
		_keep_alive()
		_real_step(1)
		t += DT; since += DT
		if since > 12.0:
			break
	p.forced = {}
	return false

## A player sees someone up on a ledge and flies up to them: climb above them, move over, land beside them.
func _fly_onto(x: float, y: float, z: float) -> void:
	if not p.game.player.flying:
		p.forced = {"flight": true}; _real_step(1)
	for i in 600:
		var v := _pos()
		var d := Vector2(x - v.x, z - v.y if false else z - v.z)
		if v.y > y + 3.0 and d.length() < 1.5:
			break
		var it := {"ascend": v.y < y + 4.0}
		if v.y > y + 2.0 and d.length() >= 1.5:
			it.merge({"move_x": d.normalized().x, "move_z": d.normalized().y})
		p.forced = it
		_keep_alive()
		_real_step(1)
	_land()

## Stops flying (pressing the flight key only while actually flying) and waits to touch the ground.
func _land() -> void:
	for i in 360:
		if p.game.player.onGround and not p.game.player.flying:
			break
		p.forced = {"flight": true} if p.game.player.flying and i % 20 == 0 else {"descend": p.game.player.flying}
		_real_step(1)
	p.forced = {}

func _quest_step(q: Dictionary) -> int:
	return int(p.game.slot.quests.get(q.id, {}).get("step", -1)) if p.story.is_active(q.id) else 999

func _talk(q: Dictionary, s: Dictionary, n: Dictionary) -> void:
	var np: Dictionary = p.story.npc_pos(n)
	if not walk_to(float(np.x), float(np.z), RuleStory.TALK_RANGE * 0.7):
		_problem(q, s, "could not walk up to %s at (%.0f, %.0f)" % [n.id, float(np.x), float(np.z)])
		at(np)
	_land()
	if absf(float(np.get("y", _pos().y)) - _pos().y) > 3.5:
		_fly_onto(float(np.x), float(np.y), float(np.z))
	if absf(float(np.get("y", _pos().y)) - _pos().y) > 3.5:
		_problem(q, s, "%s stands %.1f m above/below where you can stand" % [n.id, float(np.get("y", 0)) - _pos().y])
	var before := _quest_step(q)
	p.forced = {"interact": true}
	_real_step(1)
	p.forced = {}
	_real_step(2)
	if _quest_step(q) == before and p.story.is_active(q.id):
		var who: Variant = p.story.interaction()
		_problem(q, s, "pressing interact next to %s did nothing (interaction target: %s)" % [n.id, str(who.get("id", who)) if who is Dictionary else str(who)])
		at(np)
		p.story.interact()

func _train(q: Dictionary, s: Dictionary) -> void:
	var c: Dictionary = p.story.at(s) if s.has("x") else {"x": p.game.zone.spawn.x, "z": p.game.zone.spawn.z}
	if s.has("x") and not walk_to(float(c.x), float(c.z), maxf(2.0, float(s.r) * 0.3)):
		_problem(q, s, "could not walk to the training spot (%.0f, %.0f)" % [float(c.x), float(c.z)])
		at(c)
	if s.has("requiredForms"):
		p.game.player.form = s.requiredForms[0]
	var before := _quest_step(q)
	var t := 0.0
	var limit := float(s.seconds) * 1.6 + 3.0
	var mode := str(s.get("mode", ""))
	if mode == "fly":
		p.forced = {"flight": true}; _real_step(1)
	while t < limit and _quest_step(q) == before:
		match mode:
			"move":
				var a := t * 0.8
				p.forced = {"move_x": cos(a), "move_z": sin(a), "sprint": true}
			"charge":
				p.forced = {"charge": true}
			"fly":
				p.forced = {"ascend": t < 1.0, "move_x": cos(t * 0.5), "move_z": sin(t * 0.5)}
			_:
				p.forced = {}
		_keep_alive()
		_real_step(1)
		t += DT
	p.forced = {}
	if mode == "fly":
		p.game.player.flying = false
	if _quest_step(q) == before:
		_problem(q, s, "%s training for %.0f s (needs %s s) did not finish; progress %.1f s" % [mode, t, s.seconds,
			float(p.game.slot.quests.get(q.id, {}).get("t", 0.0))])
		p.story.update(float(s.seconds) + 0.01, {"charge": mode == "charge"})

func _defeat(q: Dictionary, s: Dictionary) -> void:
	var w: Variant = p.story.waypoint()
	if w != null and not walk_to(float(w.x), float(w.z), 3.0):
		_problem(q, s, "could not walk to the fight at (%.0f, %.0f)" % [float(w.x), float(w.z)])
		at(w)
	_real_step(10)
	var before := _quest_step(q)
	var t := 0.0
	var seen := false
	var fight_times: Array = []
	var since_kill := 0.0
	var last_count := int(p.game.slot.quests.get(q.id, {}).get("count", 0))
	while t < 900.0 and since_kill < 300.0 and _quest_step(q) == before:
		var c_now := int(p.game.slot.quests.get(q.id, {}).get("count", 0))
		if c_now != last_count:
			fight_times.append(since_kill); last_count = c_now; since_kill = 0.0
		since_kill += DT
		var target: Dictionary = {}
		var bd := INF
		for e: Dictionary in p.game.combat.enemies:
			if float(e.health) <= 0: continue
			if str(e.get("key", "")) == str(s.enemy) or str(e.id).begins_with("enemy:%s:" % s.enemy):
				var d := (e.pos as Vector3).distance_to(_pos())
				if d < bd: bd = d; target = e
		if target.is_empty():
			if t > 3.0 and not seen:
				break
			_real_step(1); t += DT
			continue
		seen = true
		var to: Vector3 = (target.pos as Vector3) - _pos()
		if OS.get_environment("QUESTS_DEBUG") != "" and int(t * 60) % 120 == 0:
			print("    fight t=%.0f me %s target %s hp %d lock %s attacking %s style %s onGround %s flying %s" % [t, str(_pos().snapped(Vector3.ONE * 0.1)),
				str((target.pos as Vector3).snapped(Vector3.ONE * 0.1)), int(target.health), str(p.game.player.get("lockTarget")),
				str(p.game.player.get("attackSerial")), str(p.game.player.get("style")), str(p.game.player.onGround), str(p.game.player.flying)])
		var flat := Vector2(to.x, to.z)
		var it := {"lock_on": int(t * 60) % 120 == 0 and p.game.player.get("lockTarget", "") != target.id}
		if flat.length() > 2.2 or absf(to.y) > 2.5:
			it.merge({"move_x": flat.normalized().x, "move_z": flat.normalized().y, "sprint": true})
			if to.y > 2.5 and not p.game.player.flying: it.flight = true
			if to.y < -2.5 and p.game.player.flying: it.descend = true
		elif to.y < -2.5 and p.game.player.flying:
			it.descend = true
		else:
			p.game.player.yaw = atan2(to.x, to.z)
			it.melee = int(t * 60) % 4 < 2
			it.ki_blast = int(t * 60) % 30 == 15   # mix in Ki blasts like a player
		p.forced = it
		_keep_alive()
		_real_step(1)
		t += DT
	p.forced = {}
	if _quest_step(q) != before:
		fight_times.append(since_kill)
	var slowest: float = fight_times.max() if not fight_times.is_empty() else 0.0
	print("  FIGHT %s x%s: %.0f s total, slowest kill %.0f s" % [s.enemy, s.get("count", 1), t, slowest])
	if slowest > 60.0:
		_problem(q, s, "SLOW: one '%s' took %.0f s to defeat at quest level +2 (%s needed)" % [s.enemy, slowest, s.get("count", 1)])
	if _quest_step(q) == before:
		if not seen:
			_problem(q, s, "the boss '%s' never appeared (enemies here: %s)" % [s.enemy, ", ".join(p.game.combat.enemies.map(func(e: Dictionary) -> String: return str(e.id)))])
		else:
			var alive: Array = p.game.combat.enemies.filter(func(e: Dictionary) -> bool: return str(e.id).begins_with("enemy:%s:" % s.enemy))
			_problem(q, s, "fought '%s' for %.0f s: %d / %s counted; %d of them on the map, health %s, at %s" % [s.enemy, t,
				int(p.game.slot.quests.get(q.id, {}).get("count", 0)), s.get("count", 1), alive.size(),
				str(alive.map(func(e: Dictionary) -> int: return int(e.health))), str(alive.map(func(e: Dictionary) -> String: return "(%.0f,%.0f,%.0f)" % [e.pos.x, e.pos.y, e.pos.z]))])
		for i in int(s.get("count", 1)):
			p.story.enemy_defeated(s.enemy, s.zone)

func _reach(q: Dictionary, s: Dictionary) -> void:
	var a: Dictionary = p.story.at(s)
	var before := _quest_step(q)
	if not walk_to(float(a.x), float(a.z), maxf(1.0, float(s.r) * 0.5)):
		_problem(q, s, "could not walk to (%.0f, %.0f)" % [float(a.x), float(a.z)])
		at(a)
	_real_step(2)
	if _quest_step(q) == before:
		_problem(q, s, "standing at the reach point did not advance")
		at(a); p.story.update(DT)

func play_real(q: Dictionary) -> void:
	for id: String in p.story.required_after(q):
		if not p.story.is_done(id):
			if not _in_filter(str(id)):
				play_quest(p.story.quest[id])   # fast path for quests outside the filter
			else:
				play_real(p.story.quest[id])
	if q.get("automatic", false) or p.story.is_done(q.id):
		if not p.story.is_done(q.id): play_quest(q)
		return
	print("REAL ", q.id, " from ", _where())
	grind(int(q.get("level", 1)) + 2)
	var giver: Dictionary = p.story.npc[q.giver]
	if not go(giver.zone):
		_problem(q, null, "could not reach the giver's world " + str(giver.zone)); return
	var gp: Dictionary = p.story.npc_pos(giver)
	if not walk_to(float(gp.x), float(gp.z), RuleStory.TALK_RANGE * 0.7):
		_problem(q, null, "could not walk up to quest giver %s" % giver.id)
		at(gp)
	if not p.story.accept_quest(q.id):
		_problem(q, null, "could not accept"); return
	_real_step(2)
	for guard in 60:
		if not p.story.is_active(q.id):
			break
		var s: Dictionary = p.story.step_of(q)
		var before := _quest_step(q)
		print("  step %d %s %s · %s" % [before, s.type, str(s.get("text", "")), _where()])
		match str(s.type):
			"talk":
				var n: Dictionary = p.story.npc[s.npc]
				if not go(n.zone): _problem(q, s, "could not reach " + str(n.zone)); return
				_talk(q, s, n)
			"travel":
				if not go(s.zone): _problem(q, s, "could not travel to " + str(s.zone)); return
				_real_step(3)
				if _quest_step(q) == before: _problem(q, s, "arriving did not advance"); p.story.update(DT)
			"reach":
				if not go(s.zone): _problem(q, s, "could not reach " + str(s.zone)); return
				_reach(q, s)
			"defeat":
				if not go(s.zone): _problem(q, s, "could not reach " + str(s.zone)); return
				_defeat(q, s)
			"collect":
				for spot: Dictionary in s.spots:
					var sz: String = str(spot.get("zone", s.get("zone")))
					if not go(sz): _problem(q, s, "could not reach " + sz); return
					var a: Dictionary = p.game.zone.place_in(sz, spot.x, spot.z) if p.game.zone is RulePlanet else spot
					var got := int((p.game.slot.quests.get(q.id, {}).get("collected", []) as Array).size())
					if not walk_to(float(a.x), float(a.z), 1.2):
						_problem(q, s, "could not walk to a pickup at (%.0f, %.0f)" % [float(a.x), float(a.z)])
						at(a)
					_real_step(2)
					if p.story.is_active(q.id) and _quest_step(q) == before and int((p.game.slot.quests.get(q.id, {}).get("collected", []) as Array).size()) == got:
						_problem(q, s, "standing on the pickup at (%.0f, %.0f) did not pick it up (ground %.1f)" % [float(a.x), float(a.z), p.game.zone.height_at(float(a.x), float(a.z))])
						at(a); p.story.update(DT)
			"train":
				if not go(s.zone): _problem(q, s, "could not reach " + str(s.zone)); return
				_train(q, s)
			"level":
				grind(int(s.level)); _real_step(2)
		_real_step(1)
		if p.story.is_active(q.id) and _quest_step(q) == before:
			_problem(q, s, "step did not advance even after the shortcut")
			return
	if p.story.is_active(q.id):
		_problem(q, null, "quest still active after all steps")

func test_every_main_quest_like_a_player() -> void:
	only = OS.get_environment("QUESTS_ONLY")
	_old = SaveStore.path
	SaveStore.path = "user://test_quests_real_profile.json"
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0, RuleSchema.new().default_look("Saiyan"))
	_open()
	for q: Dictionary in p.story.quests:
		if q.get("main", false) and p != null:
			if not _in_filter(str(q.id)):
				if not p.story.is_done(q.id): play_quest(q)
				continue
			play_real(q)
	print("QUESTS-REAL: %d problems" % problems.size())
	for line in problems: print("  - ", line)
	eq(problems, [] as Array[String], "every main quest plays like a player")
	_close()
	SaveStore.delete_slot(0)
	SaveStore.path = _old
