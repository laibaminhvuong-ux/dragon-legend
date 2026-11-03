class_name PlayUi
extends Control
# Everything on screen while playing: HUD, dialogue + fighter menu, Dragon Radar, tutorial panel. Also the play
# keys the JS game handled outside the rules (menu, radar, base form) and dialogue input.

var play: PlaySession
var input: GameInput
var hud: Hud
var rpg: RpgMenu
var radar: DragonRadar
var tutorial: TutorialPanel
var cutscene: CutscenePlayer

func _init(p: PlaySession, gi: GameInput) -> void:
	play = p
	input = gi
	name = "PlayUi"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = Hud.new(p)
	add_child(hud)
	radar = DragonRadar.new()
	add_child(radar)
	tutorial = TutorialPanel.new()
	tutorial.tut = p.tutorial
	tutorial.on_skip = p.save_now
	add_child(tutorial)
	rpg = RpgMenu.new(p)
	rpg.save = p.save_now
	add_child(rpg)
	cutscene = CutscenePlayer.new()
	add_child(cutscene)
	p.cutscene_requested.connect(play_scene)
	hud.open_menu = func(tab: String) -> void: rpg.open_tab(tab)
	rpg.opened.connect(func() -> void:
		play.freeze("dialogue", true)
		input.capture = false)
	rpg.closed.connect(func() -> void:
		play.freeze("dialogue", false)
		input.capture = not play.paused)
	p.tutorial_step_done.connect(tutorial.flash)

func play_scene(sc: Dictionary) -> void:
	if cutscene.active:
		return
	rpg.close()
	play.face_for_scene(sc)
	play.freeze("cutscene", true)
	hud.visible = false
	cutscene.play(sc, play.actor, func() -> void:
		play.freeze("cutscene", false)
		hud.visible = true
		play.save_now())

## Keys handled by the UI; returns true when the step's input was used by a menu.
func handle_input() -> bool:
	if cutscene.active:
		cutscene.handle_input(input)
		return true
	if rpg.is_open:
		if input.pressed("pause") or input.pressed("menu") or (input.last_device == "gamepad" and input.pressed("dash")):
			rpg.close()
		elif input.pressed("interact") or (input.last_device == "gamepad" and input.pressed("jump")):
			rpg.activate()
		return true
	if play.paused:
		return false
	if input.pressed("menu"):
		rpg.open_tab("Stats")
		return true
	if input.pressed("radar"):
		radar.toggle()
	if input.pressed("base") and str(play.game.player.form) != "":
		var err: Variant = play.game.select_form("")
		Events.emit_named("notify", {"text": err if err is String else "Back to base form."})
	return false

func refresh(dt: float) -> void:
	cutscene.drive_camera(play.camera, dt)
	hud.update_hud(dt)
	radar.refresh(play.story, play.game.player.pos, play.follow.yaw, dt, play.is_frozen())
	tutorial.refresh(dt, rpg.is_open or play.paused or cutscene.active)
