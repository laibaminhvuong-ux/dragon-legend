extends TestCase
# Stage 7 Task 7: the whole main story played through the real play session. Every world is built with its
# views (terrain, NPCs, enemies, HUD state), every travel goes through save -> rebuild exactly as main.gd does,
# and each quest step runs a few rendered frames. Adapted from Codex's rules bot (tests/rules/story_case.gd).

const DT := 1.0 / 60.0
var p: PlaySession

## ~8 minutes: runs only with `tools/godot_test.sh story-play`.
func opt_in() -> Dictionary:
	return {"test_whole_main_story_through_the_play_scene": "story-play"}

var gi: GameInput
var _old := ""
var worlds := {}
var travels := 0

func _open() -> void:
	gi = GameInput.new()
	p = PlaySession.new()
	p.add_child(gi)
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	ok(p.start(0, gi, "low"), "session in " + str(SaveStore.load_slot(0).get("zone", "?")))
	worlds[str(p.game.zone.id)] = true
	_frames(2)

func _close() -> void:
	p.shutdown()
	p.get_parent().remove_child(p)
	p.free()
	p = null

func _frames(n: int) -> void:
	for i in n:
		p.step(DT)
		if p == null: return
		p.render(DT, 1.0)

func at(pos: Variant) -> void:
	var x := float(pos.x); var z := float(pos.z)
	p.game.player.pos = Vector3(x, float(pos.get("y", p.game.zone.height_at(x, z))) if pos is Dictionary else float(pos.y), z)
	p.game.player.vel = Vector3.ZERO
	p.game.player.flying = false
	p.game.player.onGround = true

func go(id: String) -> bool:
	if str(p.game.zone.id) == id:
		return true
	var guide: Variant = p.story.travel_guide()
	ok(guide != null, "a pilot in %s to reach %s" % [p.game.zone.id, id])
	if guide == null:
		return false
	at(guide)
	var asked := []
	p.travel_requested.connect(func(z: String) -> void: asked.append(z))
	if not p.story.travel_to(id):
		ok(false, "travel offered: " + id)
		return false
	p.step(DT)   # the travel event is handled inside the step: save, then ask main to rebuild
	eq(asked, [id], "rebuild requested for " + id)
	eq(str(SaveStore.load_slot(0).zone), id, "saved in " + id)
	_close()
	_open()
	travels += 1
	return str(p.game.zone.id) == id

func grind(level: int) -> void:
	while int(p.game.slot.level) < level:
		p.game.add_xp(p.game.progression.xp_to_next(int(p.game.slot.level)))

func play_quest(q: Dictionary) -> void:
	for id: String in q.get("after", []):
		if not p.story.is_done(id):
			play_quest(p.story.quest[id])
	if q.get("automatic", false):
		var form: Dictionary = RuleTables.table("forms")[str(q.id).substr(5)]
		var edge: Dictionary = form.mastery
		if edge.from not in p.game.slot.forms:
			play_quest(p.story.quest["Form_" + edge.from])
		grind(int(q.level))
		p.game.select_form(edge.from)
		p.game.add_form_mastery(edge.required + 1)
		return
	grind(int(q.get("level", 1)))
	var giver: Dictionary = p.story.npc[q.giver]
	if not go(giver.zone):
		return
	at(p.story.npc_pos(giver))
	ok(p.story.accept_quest(q.id), "accept " + q.id)
	_frames(2)
	if not p.story.is_active(q.id):
		return
	for guard in 60:
		if not p.story.is_active(q.id):
			break
		var step: Dictionary = p.story.step_of(q)
		match str(step.type):
			"talk":
				var n: Dictionary = p.story.npc[step.npc]
				if not go(n.zone): return
				at(p.story.npc_pos(n))
				p.story.interact()
			"travel":
				if not go(step.zone): return
				p.story.update(DT)
			"reach":
				if not go(step.zone): return
				at(p.story.at(step))
				p.story.update(DT)
			"defeat":
				if not go(step.zone): return
				var w: Variant = p.story.waypoint()
				if w != null: at(w)
				_frames(2)   # the boss and its views exist here
				for i in int(step.get("count", 1)):
					p.story.enemy_defeated(step.enemy, step.zone)
			"collect":
				for spot: Dictionary in step.spots:
					if not go(spot.get("zone", step.get("zone"))): return
					at(spot)
					p.story.update(DT)
			"train":
				if not go(step.zone): return
				at(p.story.at(step) if step.has("x") else p.game.zone.spawn)
				var it: Dictionary = {}
				p.game.player.charging = false
				match str(step.get("mode", "")):
					"move": p.game.player.vel.x = 4
					"charge": it.charge = true
					"fly": p.game.player.flying = true
				if step.has("requiredForms"):
					p.game.player.form = step.requiredForms[0]
				p.story.update(float(step.seconds) + 0.01, it)
			"level":
				grind(int(step.level))
				p.story.update(DT)
		_frames(1)
	ok(not p.story.is_active(q.id), "finished " + q.id)

func test_whole_main_story_through_the_play_scene() -> void:
	_old = SaveStore.path
	SaveStore.path = "user://test_story_play_profile.json"
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0, RuleSchema.new().default_look("Saiyan"))
	_open()
	var mains := 0
	for q: Dictionary in p.story.quests:
		if q.get("main", false):
			play_quest(q)
			mains += 1
	eq(mains, 41, "every main quest played")
	eq((p.game.slot.story.unlocked as Array).size(), (RuleTables.table("zones") as Dictionary).size(), "every world unlocked")
	ok(worlds.size() >= 20, "%d worlds built and played in (%d travels)" % [worlds.size(), travels])
	p.save_now()
	var saved: Dictionary = SaveStore.load_slot(0)
	eq(int(saved.level), int(p.game.slot.level), "progress saved")
	_close()
	SaveStore.delete_slot(0)
	SaveStore.path = _old
