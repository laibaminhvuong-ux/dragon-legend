extends Node
# Entry scene (port of web/src/main.js): switches between the menu and play, owns the input and the UI layer,
# and runs the fixed-step loop. User args:
#   -- --smoke            run a few frames, print autoload status, quit (automated launch check)
#   -- --play=N           skip the menu and play save slot N (creates a default Saiyan if it's empty), like ?dev
#      --zone=<id>        (with --play) start that slot at the world's arrival point (GPU checks of a world)
#      --forms=1          (with --play) a level-2000 dev fighter with every race form unlocked
#      --noui=1 --walk=<s>  hide the play UI / move forward for s seconds (GPU screenshots); --sprint=1 holds
#                         Shift, --fly=1 takes off first
#   -- --shot=<png> --frames=<n>   save a screenshot after n frames and quit (GPU checks)

var input: GameInput
var ui: CanvasLayer
var play: PlaySession
var play_ui: PlayUi
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
	if _args.has("shot"):
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if _args.has("smoke"):
		return
	if _args.has("play"):
		var i := int(_args.play)
		if not (SaveStore.load_slot(i) is Dictionary):
			SaveStore.create_slot(i, RuleSchema.new().default_look("Saiyan"))
		if _args.has("rift"):   # dev: --rift=<mission id> unlocks Rift Patrol, starts in the Nexus and launches the mission
			var dr: Dictionary = SaveStore.load_slot(i)
			dr.zone = "time_nexus"; dr.position = null; dr.level = 2000
			dr.quests["m34_super_hero"] = {"status": "done", "step": 0, "completions": 1}
			SaveStore.save_slot(i, dr)
		if _args.has("zone") or _args.has("forms"):
			var dev: Dictionary = SaveStore.load_slot(i)
			if _args.has("zone"):
				dev.zone = str(_args.zone)
				dev.position = null
			if _args.has("forms"):
				dev.level = 2000
				dev.forms = (Data.races.get(str(dev.race), {}).get("forms", []) as Array).duplicate()
				dev.loadout.testAllPaths = true
			SaveStore.save_slot(i, dev)
		start_game(i)
	else:
		go_menu()
	if _args.has("noui") or _args.has("walk"):
		_dev_shot_setup()
	if _args.has("rift"):
		_dev_rift()
	match str(_args.get("screen", "")):   # GPU checks of each screen
		"creator": open_creator(2)
		"server":   # dev: the co-op Server screen over the title menu
			await get_tree().create_timer(1.0).timeout
			if menu != null:
				var sel := ui.find_children("*", "SlotSelect", true, false)
				if not sel.is_empty(): sel[0].add_child(ServerMenu.new(self))
		"forms":
			await get_tree().create_timer(2.0).timeout
			if play != null: play_ui.forms.open()
		"map":
			await get_tree().create_timer(2.0).timeout
			if play != null: play_ui.map.open()
		"pause", "menu", "dialogue":
			await get_tree().create_timer(2.0).timeout
			if play != null:
				if _args.screen == "pause": set_paused(true)
				elif _args.screen == "menu": play_ui.rpg.open_tab(str(_args.get("tab", "Stats")))
				elif _args.screen == "dialogue": Events.emit_named("dialogue", {"speaker": "Gokan", "text": "You came! Let's see how strong you've got.", "kind": "line"})
		"fight":
			await get_tree().create_timer(1.5).timeout
			if play != null and not play.game.combat.enemies.is_empty():
				var e: Dictionary = play.game.combat.enemies[0]
				var ep: Vector3 = e.pos
				play.game.player.pos = Vector3(ep.x + 9.0, play.game.zone.height_at(ep.x + 9.0, ep.z), ep.z)
				play.prev_pos = play.game.player.pos
				play.game.slot.level = 50
				play.forced = {"lock_on": true}
				await get_tree().create_timer(0.1).timeout
				play.forced = {"ki_blast": true}
				await get_tree().create_timer(0.6).timeout
				play.forced = {"beam": true}
				await get_tree().create_timer(float(_args.get("hold", 1.2))).timeout
				play.forced = {"beam": false}
		"house":   # dev: stand in front of a walk-in house's doorway and walk in (cutaway / collision checks)
			await get_tree().create_timer(1.2).timeout
			if play != null:
				var g: RuleGame = play.game
				var px: Vector3 = g.player.pos
				var best: Dictionary = {}
				var bd := INF
				for l: Dictionary in g.zone.landmarks:
					if str(l.get("type", "")) != "town": continue
					for b: Dictionary in RuleTown.layout(l).buildings:
						if str(b.kind) not in RuleTown.WALK_IN: continue
						var f := RuleTown._frame(l, b)
						var dd := Vector2(float(f.x) - px.x, float(f.z) - px.z).length()
						if dd < bd: bd = dd; best = f
				if not best.is_empty():
					var r := float(best.rot)
					var front := float(best.hd) * (0.78 if best.round else 1.0) + 5.0
					var sx := float(best.x) + sin(r) * front
					var sz := float(best.z) + cos(r) * front
					g.player.pos = Vector3(sx, g.zone.height_at(sx, sz) + 0.1, sz)
					play.prev_pos = g.player.pos
					g.player.yaw = r + PI
					play.follow.set_yaw(r + PI)
					await get_tree().create_timer(0.4).timeout
					play.forced = {"move_x": sin(r + PI), "move_z": cos(r + PI)}
					await get_tree().create_timer(float(_args.get("walkfor", 2.4))).timeout
					play.forced = {}
					if _args.has("turn"):   # look around inside (the camera must stay in the room)
						play.follow.set_yaw(play.follow.yaw + float(_args.turn))
		"boost":   # dev: rocket boost from the ground, then steer (recordings)
			await get_tree().create_timer(1.5).timeout
			if play != null:
				play.game.player.flying = true
				play.forced = {"boost": true}
				await get_tree().process_frame
				await get_tree().create_timer(0.5).timeout
				play.forced = {"move_x": sin(play.follow.yaw), "move_z": cos(play.follow.yaw)}
				await get_tree().create_timer(6.0).timeout
				play.forced = {}
		"brawl":   # dev: walk up to the first enemy, lock on and throw a few full combos (style recordings)
			await get_tree().create_timer(1.5).timeout
			if play != null and not play.game.combat.enemies.is_empty():
				var e: Dictionary = play.game.combat.enemies[0]
				var ep: Vector3 = e.pos
				play.game.player.pos = Vector3(ep.x + 2.2, play.game.zone.height_at(ep.x + 2.2, ep.z), ep.z)
				play.prev_pos = play.game.player.pos
				play.game.slot.level = 50
				play.forced = {"lock_on": true}
				await get_tree().create_timer(0.1).timeout
				play.forced = {}
				for rep in 3:
					for hit in 5:
						play.forced = {"melee": true}
						await get_tree().create_timer(0.12).timeout
						play.forced = {"melee": false}
						await get_tree().create_timer(0.3 if str(_args.get("style", "turtle")) != "speedster" else 0.16).timeout
					await get_tree().create_timer(0.9).timeout
		"fx":
			await get_tree().create_timer(1.5).timeout
			for rep in 20:
				if play == null: break
				var pp: Vector3 = play.game.player.pos
				var fwd := Vector3(sin(play.follow.yaw), 0, cos(play.follow.yaw))
				var side := Vector3(fwd.z, 0, -fwd.x)
				Events.emit_named("beam", {"from": pp + Vector3.UP * 1.2 + fwd, "to": pp + Vector3.UP * 1.5 + fwd * 30.0 + side * 6.0, "color": 0x63cfff})
				if rep == 0:
					for k in 3:
						play.game.combat.projectiles.append({"id": 900 + k, "pos": pp + Vector3.UP * 1.3 + fwd * (4.0 + k * 3.0) - side * (2.0 + k),
							"dir": Vector3.ZERO, "life": 99.0, "damage": 0.0, "owner": {"id": "fx"}, "color": [0xffd24a, 0x63cfff, 0xff5a8a][k]})
				Events.emit_named("damage", {"id": "e1", "amount": 128 + rep, "pos": pp + fwd * 6.0 + Vector3.UP * 2.0})
				Events.emit_named("damage", {"id": "player", "amount": 12, "blocked": true, "pos": pp + Vector3.UP * 2.2})
				await get_tree().create_timer(0.25).timeout
		"cutscene":
			await get_tree().create_timer(2.0).timeout
			if play != null:
				for e: Dictionary in play.game.combat.enemies:
					var ep: Vector3 = e.pos
					play.game.player.pos = Vector3(ep.x + 5.0, play.game.zone.height_at(ep.x + 5.0, ep.z), ep.z)
					play.prev_pos = play.game.player.pos
					play_ui.play_scene({"kind": "before", "enemy": e.key, "lines": play.scenes.scene_lines(str(e.key), "before", e.get("name"))})
					break

func go_menu() -> void:
	_end_play()
	_clear_ui()
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
	Music.play("menu")
	var ss: GDScript = load("res://ui/slot_select.gd") if ResourceLoader.exists("res://ui/slot_select.gd") else null
	if ss != null:
		var screen: Control = ss.new(self)
		ui.add_child(screen)

func open_creator(i: int) -> void:
	for c in ui.get_children():
		c.queue_free()
	ui.add_child(Creator.new(self, i))

func _clear_ui() -> void:
	for c in ui.get_children():
		ui.remove_child(c)
		c.queue_free()

## A full-screen card while a world builds (port of the JS travel card).
func loading_card(zone_id: String) -> void:
	var z: Dictionary = Data.zones.get(zone_id, {})
	var card := ColorRect.new()
	card.name = "Loading"
	card.color = Color(0.02, 0.03, 0.06)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UiKit.label(str(z.get("name", zone_id)), "HeaderLarge"); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.theme = UiKit.theme()
	var s := UiKit.label("%s · %s" % [z.get("planet", ""), z.get("saga", "")], "Muted"); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.theme = UiKit.theme()
	v.add_child(t); v.add_child(s)
	card.add_child(v)
	ui.add_child(card)

func start_game(i: int) -> void:
	_end_play()
	if menu != null:
		menu.queue_free()
		menu = null
	_clear_ui()
	var slot: Variant = SaveStore.load_slot(i)
	if slot is Dictionary:
		loading_card(str(slot.get("zone", "earth_plains")))
		await get_tree().process_frame
		await get_tree().process_frame
	_clear_ui()
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
	play_ui = PlayUi.new(play, input)
	ui.add_child(play_ui)
	input.capture = true

func set_paused(p: bool) -> void:
	if play == null or play.paused == p:
		return
	play.paused = p
	input.capture = not p
	if p:
		play.save_now()
	var pm: GDScript = load("res://ui/pause_menu.gd") if ResourceLoader.exists("res://ui/pause_menu.gd") else null
	if pm != null:
		if p:
			var m: Control = pm.new(self)
			m.name = "Pause"
			ui.add_child(m)
		elif ui.has_node("Pause"):
			ui.get_node("Pause").queue_free()

func _end_play() -> void:
	if play_ui != null:
		play_ui.queue_free()
		play_ui = null
	if play != null:
		play.save_now()
		play.shutdown()
		remove_child(play)
		play.queue_free()
		play = null

## Dev: launch a Rift mission from the Nexus (recordings of the corrupted arena, allies and bosses).
func _dev_rift() -> void:
	while play == null or play_ui == null:
		await get_tree().process_frame
	if str(play.game.zone.id) != "time_nexus":
		return
	await get_tree().create_timer(1.0).timeout
	print("RIFT launch: ", play.game.start_rift_mission(str(_args.rift)))

func _dev_shot_setup() -> void:
	while play == null or play_ui == null:
		await get_tree().process_frame

	if _args.has("noui"):
		play_ui.visible = false
	if _args.has("style"):   # dev: --style=<id> picks the fighting style (GPU recordings of the combos)
		play.game.set_style(str(_args.style))
	if _args.has("form"):   # dev: --form=<id> transforms the dev fighter (with --forms=1) for screenshots
		await get_tree().create_timer(0.8).timeout
		play.game.player.ki = play.game.player.maxKi
		play.game.select_form(str(_args.form))
	if _args.has("at"):   # dev: --at=<road z> on a road world, or x,z: stand there (and --pitch=<rad> to look up)
		var c: PackedStringArray = str(_args.at).split(",")
		var p: Dictionary = play.game.zone.place(float(c[0]) if c.size() > 1 else 0.0, float(c[-1]))
		play.game.player.pos = Vector3(p.x, play.game.zone.height_at(p.x, p.z) + 0.1, p.z)
		play.prev_pos = play.game.player.pos
	if _args.has("face"):   # dev: --face=x,z turns the camera toward a point
		var fc: PackedStringArray = str(_args.face).split(",")
		var pp: Vector3 = play.game.player.pos
		play.follow.set_yaw(atan2(float(fc[0]) - pp.x, float(fc[1]) - pp.z))
		play.game.player.yaw = play.follow.yaw
	if _args.has("pitch"):
		await get_tree().create_timer(0.5).timeout
		play.follow.pitch = float(_args.pitch)
	if _args.has("walk"):
		_dev_walk(float(_args.walk))

func _dev_walk(secs: float) -> void:
	await get_tree().create_timer(1.0).timeout
	if play == null: return
	var yaw: float = play.follow.yaw
	if _args.has("fly"):   # take off first (dev: --fly=1), then climb a little (set directly: a forced press
		play.game.player.flying = true   # would toggle twice when a frame runs two steps, e.g. while recording)
		play.game.player.onGround = false
		play.forced = {"ascend": true}
		await get_tree().create_timer(1.2).timeout
	play.forced = {"charge": true} if _args.has("charge") else {"move_x": sin(yaw), "move_z": cos(yaw), "sprint": _args.has("sprint")}
	await get_tree().create_timer(secs).timeout
	if play != null: play.forced = {}

var _worst := 0.0   # dev: longest frame after loading (printed with --shot)
var _hitches := 0
func _process(delta: float) -> void:
	_frames += 1
	if _frames > 120:
		_worst = maxf(_worst, delta)
		if delta > 0.05:
			_hitches += 1
			if _args.has("shot"): print("hitch at frame %d: %.0f ms" % [_frames, delta * 1000.0])
	var steps := Clock.advance(delta)
	if play != null:
		var used := play_ui.handle_input() if play_ui != null else false
		if not used and input.pressed("pause"):
			set_paused(not play.paused)
		if used: input.end_tick()
		for k in steps:
			play.step(Clock.STEP)
			input.end_tick()
			if play == null: break
		if play != null:
			play.render(delta, Clock.alpha)
			if play_ui != null: play_ui.refresh(delta)
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
		var img := get_viewport().get_texture().get_image()
		var out := str(_args.shot)
		if out.ends_with(".webp"): img.save_webp(out, true, 0.86)   # website images
		elif out.ends_with(".jpg"): img.save_jpg(out, 0.88)
		else: img.save_png(out)
		var vrid := get_viewport().get_viewport_rid()
		print("WORST frame %.1f ms · hitches over 50 ms: %d" % [_worst * 1000.0, _hitches])
		print("RENDER gpu %.2f ms · cpu %.2f ms" % [RenderingServer.viewport_get_measured_render_time_gpu(vrid), RenderingServer.viewport_get_measured_render_time_cpu(vrid)])
		if play != null and play.prof_frames > 0:
			var parts: PackedStringArray = []
			for k: String in play.prof:
				parts.append("%s %.2f" % [k, float(play.prof[k]) / play.prof_frames / 1000.0])
			print("PROF ms/frame: ", " · ".join(parts), " (enemies %d)" % play.game.combat.enemies.size())
		print("shot fps %d · draws %d · objects %d · tris %dk · nodes %d · lights %d · frame %.1f ms" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			get_tree().root.find_children("*", "Light3D", true, false).size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		get_tree().quit(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if play != null:
			play.save_now()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_watchdog()

## Safety net (user report 2026-11-03: the window hung "Not Responding" after closing): once the game has saved,
## if shutting down takes longer than a few seconds, the process ends itself.
var _watchdog: Thread
func _exit_watchdog() -> void:
	if _watchdog != null or OS.has_feature("editor"):
		return
	_watchdog = Thread.new()
	_watchdog.start(func() -> void:
		OS.delay_msec(6000)
		OS.kill(OS.get_process_id()))
