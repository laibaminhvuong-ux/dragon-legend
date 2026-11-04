extends TestCase
# Stage 7 Task 1: the play session steps the rules from intents, freezes on pause/dialogue/cutscene, rebuilds the
# player when the look changes, autosaves, and travel saves the destination before asking for a rebuild.

const DT := 1.0 / 60.0
var _old_path := ""

func _session() -> PlaySession:
	_old_path = SaveStore.path
	SaveStore.path = "user://test_play_profile.json"
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0, RuleSchema.new().default_look("Saiyan"))
	var gi := GameInput.new()
	var p := PlaySession.new()
	p.add_child(gi)
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	ok(p.start(0, gi, "low"), "session starts")
	return p

func _end(p: PlaySession) -> void:
	p.shutdown()
	p.get_parent().remove_child(p)
	p.free()
	SaveStore.delete_slot(0)
	SaveStore.path = _old_path

func test_steps_move_the_player() -> void:
	var p := _session()
	var start: Vector3 = p.game.player.pos
	p.forced = {"move_z": 1.0}
	for i in 90:
		p.step(DT)
		p.render(DT, 1.0)
	var moved: Vector3 = p.game.player.pos
	ok(Vector2(moved.x - start.x, moved.z - start.z).length() > 2.0, "walked %.1f m" % Vector2(moved.x - start.x, moved.z - start.z).length())
	near(p.player.position.x, moved.x, 0.01, "model follows the rules position")
	_end(p)

func test_pause_and_freezes_stop_the_simulation() -> void:
	var p := _session()
	p.forced = {"move_z": 1.0}
	p.paused = true
	var a: Vector3 = p.game.player.pos
	for i in 30: p.step(DT)
	eq(p.game.player.pos, a, "paused: no movement")
	p.paused = false
	p.freeze("dialogue", true)
	for i in 30: p.step(DT)
	eq(p.game.player.pos, a, "dialogue open: no movement")
	p.freeze("dialogue", false)
	for i in 30: p.step(DT)
	ok(p.game.player.pos != a, "moves again")
	_end(p)

func test_look_change_rebuilds_the_player() -> void:
	var p := _session()
	p.render(DT, 1.0)
	var before := p.player
	p.game.slot.appearance["outfit"] = "SaiyanArmor"
	p.render(DT, 1.0)
	ok(p.player != before and is_instance_valid(p.player), "new model for the new outfit")
	eq(p.get_children().filter(func(c: Node) -> bool: return c is Fighter and not c.is_queued_for_deletion()).size(), 1, "only one player model")
	_end(p)

func test_travel_saves_the_destination() -> void:
	var p := _session()
	var asked := []
	p.travel_requested.connect(func(z: String) -> void: asked.append(z))
	Events.emit_named("travel", {"zone": "namek"})
	p.step(DT)
	eq(asked, ["namek"], "main is asked to rebuild on the other planet")
	eq(SaveStore.load_slot(0).zone, "namek", "the save points at the new world")
	_end(p)

func test_travel_on_the_same_planet_moves_without_loading() -> void:
	var p := _session()
	var asked := []
	p.travel_requested.connect(func(z: String) -> void: asked.append(z))
	Events.emit_named("travel", {"zone": "kame_island"})
	p.step(DT)
	eq(asked, [], "no rebuild: Kama House is on Earth's map")
	eq(p.game.current_region(), "kame_island", "the player is at Kama House now")
	eq(SaveStore.load_slot(0).zone, "kame_island", "and the save says so")
	_end(p)

func test_autosave() -> void:
	var p := _session()
	p.game.add_zeni(123)
	p.save_timer = PlaySession.AUTOSAVE_SECONDS - DT * 0.5
	p.step(DT)
	eq(int(SaveStore.load_slot(0).zeni), int(p.game.slot.zeni), "autosaved after 60 s")
	_end(p)

func test_views_follow_the_rules() -> void:
	var p := _session()
	p.render(DT, 1.0)
	var cv: Node = p.combat_view
	var sv: Node = p.story_view
	eq(cv.views.size(), p.game.combat.enemies.size(), "a view per enemy")
	ok(sv.npcs.size() > 0, "NPCs drawn (%d)" % sv.npcs.size())
	var before: int = cv.effects.size()
	var fx_before: int = cv.skill_fx.effects.size()
	Events.emit_named("damage", {"id": "e1", "amount": 42, "pos": Vector3(0, 1, 0)})
	Events.emit_named("beam", {"from": Vector3(0, 1, 0), "to": Vector3(0, 1, 20), "color": 0x63cfff})
	eq(cv.effects.size(), before + 1, "damage number shown")
	ok(cv.skill_fx.effects.size() >= fx_before + 2, "hit impact and beam drawn by the skill director")
	p.game.combat.projectiles.append({"id": 999, "pos": Vector3(1, 2, 3), "color": 0xff0000})
	cv.update_view(DT)
	ok(cv.skill_fx.shots.has("999"), "ki blast drawn")
	p.game.combat.projectiles.clear()
	cv.update_view(DT)
	ok(not cv.skill_fx.shots.has("999"), "and removed when it ends")
	for i in 120:
		cv.update_view(DT)
	eq(cv.effects.size(), before, "effects expire")
	_end(p)

func test_travel_survives_the_save_on_exit() -> void:
	var p := _session()
	Events.emit_named("travel", {"zone": "kame_island"})
	p.step(DT)
	p.save_now()   # main saves again while tearing the session down
	eq(str(SaveStore.load_slot(0).zone), "kame_island", "still saved in the destination")
	_end(p)

func test_travel_to_another_world_survives_the_save_on_close() -> void:
	# Regression (user report 2026-11-03: couldn't enter King Kae's planet): main saves the old session again while
	# tearing it down after travel; that save must keep the destination, not the spot the player left.
	var p := _session()
	Events.emit_named("travel", {"zone": "namek"})
	p.step(DT)
	p.save_now()
	var saved: Dictionary = SaveStore.load_slot(0)
	eq(str(saved.zone), "namek", "still saved in the destination")
	eq(saved.get("position"), null, "arrives at the destination's spawn")
	_end(p)

func test_shift_toggles_running_and_fast_flight() -> void:
	# User request 2026-11-03: tap Shift to switch between walking and running (and slow / fast flight); no holding.
	var p := _session()
	var gi: GameInput = p.input
	eq(p.intents().sprint, false, "starts walking")
	gi.press("sprint")
	ok(p.intents().sprint, "one tap: running")
	gi.end_tick()
	ok(p.intents().sprint, "stays running without holding")
	gi.press("sprint")
	eq(p.intents().sprint, false, "tap again: walking")
	gi.end_tick()
	eq(p.intents().sprint, false)
	_end(p)

func test_style_moves_and_reactions_reach_the_fighters() -> void:
	var p := _session()
	p.render(DT, 1.0)
	var cv: Node = p.combat_view
	var e: Dictionary = p.game.combat.enemies[0]
	var player_fighter: Fighter = p.get_node("Player")
	p.game.player.attackSerial = int(p.game.player.get("attackSerial", 0)) + 1
	Events.emit_named("attack", {"id": "player", "kind": "melee", "phase": "release", "style": "brawler", "move": "brawler_hammer_fist",
		"combo_step": 2, "lunge": 0.4})
	p.render(DT, 1.0)
	eq(player_fighter.anim.current_move, "brawler_combo2", "the player's style clip plays")
	var victim: Fighter = cv.views[str(e.id)].fighter
	e.hurtUntil = p.game.combat.clock + 0.5
	Events.emit_named("damage", {"id": str(e.id), "source_id": "player", "amount": 12, "pos": e.pos, "knockback": 0.6, "launch": false,
		"stagger": 0.22, "hitstop": 0.075})
	p.render(DT, 1.0)
	p.render(DT, 1.0)
	eq(victim.anim.current_move, "react_knockback", "the victim's knockback reaction plays")
	_end(p)
