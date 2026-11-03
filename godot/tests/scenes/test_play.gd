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
	Events.emit_named("travel", {"zone": "kame_island"})
	p.step(DT)
	eq(asked, ["kame_island"], "main is asked to rebuild in the new world")
	eq(SaveStore.load_slot(0).zone, "kame_island", "the save points at the new world")
	_end(p)

func test_autosave() -> void:
	var p := _session()
	p.game.add_zeni(123)
	p.save_timer = PlaySession.AUTOSAVE_SECONDS - DT * 0.5
	p.step(DT)
	eq(int(SaveStore.load_slot(0).zeni), int(p.game.slot.zeni), "autosaved after 60 s")
	_end(p)
