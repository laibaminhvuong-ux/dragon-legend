extends "res://tests/rules/game_case.gd"
# User request 2026-11-04: trainees don't attack unless the player attacks first.
func _trainee(g: RuleGame) -> Dictionary:
	return g.combat.enemies.filter(func(e: Dictionary) -> bool: return String(e.key).begins_with("patrol_"))[0]

func test_trainees_leave_you_alone_until_you_hit_them() -> void:
	var g := fresh("Saiyan", 50)
	var t := _trainee(g)
	g.player.pos = t.pos + Vector3(2.0, 0, 0)
	g.player.onGround = true
	var hp: float = g.player.health
	var spot: Vector3 = t.pos
	tick(g, {}, 300)
	near(g.player.health, hp, 0.001, "five seconds next to a trainee: no attack")
	ok((t.pos as Vector3).distance_to(spot) < 0.6, "it stays at its spot")
	g.combat.hit(t, 5.0, g.player)
	ok(t.get("provoked", false), "hitting it makes it fight back")
	var buddies: Array = g.combat.enemies.filter(func(e: Dictionary) -> bool: return e.key == t.key and e != t and (e.pos as Vector3).distance_to(t.pos) < 18.0)
	ok(buddies.all(func(e: Dictionary) -> bool: return e.get("provoked", false)), "trainees right next to it join in")
	tick(g, {}, 240)
	ok(g.player.health < hp, "now it attacks")

func test_they_calm_down_once_you_leave() -> void:
	var g := fresh("Saiyan", 50)
	var t := _trainee(g)
	g.player.pos = t.pos + Vector3(2.0, 0, 0)
	g.combat.hit(t, 5.0, g.player)
	g.player.pos = t.home + Vector3(300.0, 0, 0)
	g.player.pos.y = g.zone.height_at(g.player.pos.x, g.player.pos.z)
	tick(g, {}, 600)
	eq(t.get("provoked", false), false, "back home and calm")

func test_quest_enemies_still_attack_on_sight() -> void:
	var g := fresh("Saiyan", 50)
	var story := RuleStory.new(g)
	var q: Dictionary = story.quest["m05_saibamen"]
	for after: String in q.get("after", []):
		g.slot.quests[after] = {"status": "done", "step": 0, "completions": 1}
	story.accept(q)
	var fight: int = (q.steps as Array).map(func(st: Dictionary) -> String: return st.type).find("defeat")
	g.slot.quests[q.id].step = fight   # start at the Saibamen fight
	g.combat.sync()
	var foe: Dictionary = g.combat.enemies.filter(func(e: Dictionary) -> bool: return e.key == "saibamen")[0]
	g.player.pos = foe.pos + Vector3(2.0, 0, 0)
	var hp: float = g.player.health
	tick(g, {}, 240)
	ok(g.player.health < hp, "an enemy brought by a quest attacks without being hit")
