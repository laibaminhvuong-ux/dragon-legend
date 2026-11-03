extends TestCase
# Stage 7 Task 4: the play UI builds and refreshes against real rules state, every fighter tab and dialogue kind
# opens without errors, and menu commands reach the rules.

const DT := 1.0 / 60.0
var _old := ""

func _setup() -> PlayUi:
	_old = SaveStore.path
	SaveStore.path = "user://test_ui_profile.json"
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0, RuleSchema.new().default_look("Saiyan"))
	var gi := GameInput.new()
	var p := PlaySession.new()
	p.add_child(gi)
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	ok(p.start(0, gi, "low"), "session")
	var u := PlayUi.new(p, gi)
	p.add_child(u)
	return u

func _done(u: PlayUi) -> void:
	var p := u.play
	p.shutdown()
	p.get_parent().remove_child(p)
	p.free()
	SaveStore.delete_slot(0)
	SaveStore.path = _old

func test_hud_refreshes() -> void:
	var u := _setup()
	u.play.render(DT, 1.0)
	for i in 10:
		u.refresh(0.05)
	ok(u.hud._name.text.contains("Lv 1"), "name row: %s" % u.hud._name.text)
	Events.emit_named("notify", {"text": "Hello"})
	eq(u.hud._toasts.get_child_count(), 1, "toast shown")
	for i in 100:
		u.hud.update_hud(0.05)
	eq(u.hud._toasts.get_child_count(), 0, "toast expires")
	_done(u)

func test_every_tab_and_dialogue_opens() -> void:
	var u := _setup()
	var froze := []
	for tab: String in RpgMenu.TABS:
		u.rpg.open_tab(tab)
		ok(u.rpg.is_open and u.play.is_frozen(), "%s tab open and the game frozen" % tab)
	u.rpg.show_dialogue({"speaker": "Gokan", "text": "Hi", "kind": "line"})
	u.rpg.show_dialogue({"speaker": "Training Guide", "text": "Pick one", "kind": "choice", "choices": [{"id": "q1", "title": "Patrol", "level": 1, "text": "t", "objective": "o", "rewards": {"xp": 10, "zeni": 5}}]})
	u.rpg.show_dialogue({"speaker": "Pilot", "text": "Where to?", "kind": "travel", "options": [{"zone": "kame_island", "name": "Kame Island", "planet": "Earth", "story": true}]})
	u.rpg.show_shop()
	u.rpg.close()
	ok(not u.play.is_frozen(), "closing unfreezes")
	_done(u)

func test_menu_commands_reach_the_rules() -> void:
	var u := _setup()
	u.play.game.slot.statPoints = 12
	u.rpg.open_tab("Stats")
	var plus10: Button = null
	for b: Button in u.rpg._box.find_children("*", "Button", true, false):
		if b.text == "+10" and plus10 == null:
			plus10 = b
	ok(plus10 != null, "a +10 button")
	plus10.pressed.emit()
	eq(int(u.play.game.slot.statPoints), 2, "10 points spent")
	_done(u)

func test_cutscene_plays_and_unfreezes() -> void:
	var u := _setup()
	var sc := {"kind": "before", "enemy": "nobody", "lines": [{"speaker": "you", "name": "You", "text": "Here I come."}, {"speaker": "nobody", "name": "Rival", "text": "Finally."}]}
	u.play_scene(sc)
	ok(u.cutscene.active and u.play.is_frozen(), "scene on, game frozen")
	u.cutscene.drive_camera(u.play.camera, 0.05)   # unknown actor: camera untouched, no crash
	u.cutscene.next()   # finish typing
	u.cutscene.next()   # line 2
	eq(u.cutscene.i, 1, "second line")
	u.cutscene.next(); u.cutscene.next()
	ok(not u.cutscene.active and not u.play.is_frozen(), "ended, game resumes")
	u.play_scene(sc)
	u.input.press("pause")
	u.handle_input()
	ok(not u.cutscene.active, "pause skips the scene")
	u.cutscene.play({"lines": []}, u.play.actor)
	ok(not u.cutscene.active, "an empty scene does nothing")
	_done(u)
