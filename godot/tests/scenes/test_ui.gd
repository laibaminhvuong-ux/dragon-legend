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

func _unlock_forms(u: PlayUi) -> void:
	var g := u.play.game
	g.slot.level = 2000
	g.slot.quests.m02_raditz = {"status": "done"}
	g.slot.forms = ["SSJ3", "SSJ", "SSJ2"]
	g.refresh_derived(true)

func _picker_buttons(u: PlayUi) -> Array:
	return u.forms._list.find_children("*", "Button", true, false)

func test_transform_key_opens_the_form_picker_in_order() -> void:
	var u := _setup()
	_unlock_forms(u)
	u.input.press("transform")
	ok(u.handle_input(), "the key is used by the picker, not sent to the rules")
	ok(u.forms.is_open and u.play.is_frozen(), "picker open, game paused")
	eq(u.forms.rows(), ["", "SSJ", "SSJ2", "SSJ3"], "base, then the race's order")
	u.forms.pick("SSJ2")
	ok(not u.forms.is_open and not u.play.is_frozen(), "closes after a pick")
	eq(str(u.play.game.player.form), "SSJ2")
	ok(u.play.game.player.ki < u.play.game.player.maxKi, "transforming cost ki")
	_done(u)

func test_favourites_go_first_and_number_keys_pick() -> void:
	var u := _setup()
	_unlock_forms(u)
	u.forms.open()
	u.forms.toggle_favorite("SSJ3")
	eq(u.forms.rows(), ["", "SSJ3", "SSJ", "SSJ2"], "favourite pinned on top")
	eq(u.play.game.slot.loadout.favoriteForms, ["SSJ3"], "saved in the slot")
	eq(_picker_buttons(u).size(), 7, "a pick button per row, a star on every form")
	u.forms.pick_number(1)
	eq(str(u.play.game.player.form), "SSJ3", "key 1 is the first favourite")
	u.forms.open()
	u.forms.pick_number(0)
	eq(str(u.play.game.player.form), "", "key 0 is base form")
	_done(u)

func test_picker_closes_without_change_and_says_when_nothing_is_unlocked() -> void:
	var u := _setup()
	u.input.press("transform")
	u.handle_input()
	ok(not u.forms.is_open, "no forms: no picker")
	u.input.end_tick()
	_unlock_forms(u)
	u.forms.open()
	u.input.press("pause")
	ok(u.handle_input())
	ok(not u.forms.is_open and not u.play.is_frozen(), "Esc closes")
	eq(str(u.play.game.player.form), "")
	u.input.end_tick()
	u.play.game.player.ki = 0.0
	u.forms.open()
	u.forms.pick("SSJ3")
	eq(str(u.play.game.player.form), "", "not enough ki: no change")
	ok(u.forms.is_open, "stays open so you can pick another")
	u.forms.close()
	_done(u)

func test_world_map_opens_shows_the_map_and_closes() -> void:
	var u := _setup()
	u.input.press("map")
	ok(u.handle_input(), "N opens the map")
	ok(u.map.is_open and u.play.is_frozen(), "map open, game paused")
	var tex: Texture2D = u.map._image.texture
	ok(tex != null and tex.get_width() == WorldMap.SIZE, "map picture drawn")
	var img := tex.get_image()
	var c := img.get_pixel(WorldMap.SIZE / 2, WorldMap.SIZE - 4)
	ok(c.b > c.g and c.b > c.r, "the southern sea is blue: %s" % c)
	u.input.end_tick()
	u.input.press("map")
	u.handle_input()
	ok(not u.map.is_open and not u.play.is_frozen(), "N closes it")
	_done(u)

func test_style_key_opens_the_style_picker() -> void:
	var u := _setup()
	u.input.press("style")
	ok(u.handle_input(), "Y opens the style menu")
	ok(u.styles.is_open and u.play.is_frozen(), "style menu open, game paused")
	eq(u.styles.rows(), ["turtle", "brawler", "speedster", "crane"], "the four styles in order")
	var labels := u.styles._list.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(labels.any(func(t: String) -> bool: return t.contains("Turtle School") and t.contains("current")), "current style marked (%s)" % [labels])
	ok(labels.any(func(t: String) -> bool: return t.contains("Crane")), "display names shown")
	u.styles.pick("brawler")
	ok(not u.styles.is_open and not u.play.is_frozen(), "closes after a pick")
	eq(str(u.play.game.player.style), "brawler", "style changed in the rules")
	u.styles.open()
	u.styles.pick_number(4)
	eq(str(u.play.game.player.style), "crane", "number keys pick")
	_done(u)
