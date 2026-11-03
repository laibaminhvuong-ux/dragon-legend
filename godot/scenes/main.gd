extends Node
# Entry scene (port of web/src/main.js): switches between the menu and play, owns the input and the UI layer,
# and runs the fixed-step loop. User args:
#   -- --smoke            run a few frames, print autoload status, quit (automated launch check)
#   -- --play=N           skip the menu and play save slot N (creates a default Saiyan if it's empty), like ?dev
#   -- --shot=<png> --frames=<n>   save a screenshot after n frames and quit (GPU checks)

var input: GameInput
var ui: CanvasLayer
var play: PlaySession
var menu: Node3D
var _frames := 0
var _args := {}
var _menu_t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq := a.find("=")
			_args[a.substr(2, eq - 2) if eq > 0 else a.substr(2)] = a.substr(eq + 1) if eq > 0 else "1"
	input = GameInput.new()
	input.name = "Input"
	add_child(input)
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	if _args.has("smoke"):
		return
	if _args.has("play"):
		var i := int(_args.play)
		if not (SaveStore.load_slot(i) is Dictionary):
			SaveStore.create_slot(i, RuleSchema.new().default_look("Saiyan"))
		start_game(i)
	else:
		go_menu()

func go_menu() -> void:
	_end_play()
	input.capture = false
	if menu == null:
		menu = Node3D.new()
		menu.name = "Menu"
		var w := WorldView.build("earth_plains", str(Settings.get_value("quality")))
		menu.add_child(w)
		var cam := Camera3D.new(); cam.name = "Camera"; cam.far = 4000.0
		menu.add_child(cam)
		add_child(menu)
		cam.make_current()
	var ss: GDScript = load("res://ui/slot_select.gd") if ResourceLoader.exists("res://ui/slot_select.gd") else null
	if ss != null:
		var screen: Control = ss.new(self)
		ui.add_child(screen)

func start_game(i: int) -> void:
	_end_play()
	if menu != null:
		menu.queue_free()
		menu = null
	for c in ui.get_children():
		c.queue_free()
	play = PlaySession.new()
	play.name = "Play"
	add_child(play)
	if not play.start(i, input, str(Settings.get_value("quality"))):
		play.queue_free()
		play = null
		go_menu()
		return
	play.travel_requested.connect(func(_z: String) -> void: start_game.call_deferred(i))
	play.quit_requested.connect(go_menu)
	input.capture = true

func _end_play() -> void:
	if play != null:
		play.save_now()
		play.shutdown()
		remove_child(play)
		play.queue_free()
		play = null

func _process(delta: float) -> void:
	_frames += 1
	var steps := Clock.advance(delta)
	if play != null:
		if input.pressed("pause"):
			play.paused = not play.paused
			input.capture = not play.paused
			if play.paused: play.save_now()
		for k in steps:
			play.step(Clock.STEP)
			input.end_tick()
			if play == null: break
		if play != null:
			play.render(delta, Clock.alpha)
	elif menu != null:
		_menu_t += delta
		var cam: Camera3D = menu.get_node("Camera")
		var zone: RefCounted = menu.get_child(0).get_meta("zone")
		var a := _menu_t * 0.025 + 0.8
		var x := sin(a) * 120.0; var z := cos(a) * 120.0
		var wl: float = zone.water.level if zone.water != null and zone.water is Dictionary and zone.water.has("level") else -1e9
		cam.global_position = Vector3(x, maxf(zone.height_at(x, z), wl) + 14.0, z)
		cam.look_at(Vector3(sin(a + 0.9) * 60.0, 10.0, cos(a + 0.9) * 60.0))
		input.end_tick()
	if _args.has("smoke") and _frames >= 30:
		print("smoke ok: Data errors=%d, slots=%d, actions=%s" % [Data.errors.size(), SaveStore.list_slots().size(), InputMap.has_action("flight")])
		get_tree().quit(0)
	if _args.has("shot") and _frames >= int(_args.get("frames", "120")):
		get_viewport().get_texture().get_image().save_png(str(_args.shot))
		print("shot fps %d" % Engine.get_frames_per_second())
		get_tree().quit(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if play != null:
			play.save_now()
