class_name PauseMenu
extends Control
# The pause menu (port of web/src/ui/pause.js): Fighter summary, Settings (graphics, volumes, mouse, voices,
# fullscreen, FPS), Controls (rebind any action: click Change, press a key or mouse button; Esc cancels) and Save
# code. From the title screen it opens as a settings-only panel.

const ACTIONS := [["jump", "Jump"], ["melee", "Melee attack"], ["block", "Block"], ["dash", "Dash (on the ground) / rocket boost (flying, 20 s)"], ["flight", "Toggle flight"],
	["ascend", "Fly up"], ["descend", "Fly down"], ["charge", "Charge ki"], ["ki_blast", "Ki blast"], ["beam", "Beam (hold to charge)"],
	["transform", "Transform"], ["kaioken", "Toggle Kaiyoken overlay"], ["lock_on", "Lock on"], ["interact", "Talk / interact"],
	["menu", "Fighter menu (stats, forms...)"], ["radar", "Dragon Radar on/off"], ["map", "World map"], ["style", "Fighting style"], ["sprint", "Run / fly fast (tap to switch)"], ["base", "Back to base form"], ["pause", "Pause menu"],
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"]]
var main: Node
var title_mode := false
var tab := "game"
var _box: VBoxContainer
var _listening := ""

func _init(m: Node, settings_only := false) -> void:
	main = m
	title_mode = settings_only
	tab = "settings" if settings_only else "game"
	name = "Pause"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new(); shade.color = Color(0.0, 0.0, 0.03, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.05, 0.07, 0.12, 0.95), 14))
	panel.anchor_left = 0.5; panel.anchor_right = 0.5; panel.anchor_top = 0.06; panel.anchor_bottom = 0.94
	panel.offset_left = -400; panel.offset_right = 400
	add_child(panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_box = VBoxContainer.new(); _box.add_theme_constant_override("separation", 10)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	draw()

func _play() -> PlaySession:
	return main.get("play") as PlaySession

func draw() -> void:
	for c in _box.get_children():
		_box.remove_child(c); c.queue_free()
	_box.add_child(UiKit.label("Settings" if title_mode else "Paused", "HeaderLarge"))
	var nav := HBoxContainer.new()
	var tabs := [["settings", "Settings"], ["controls", "Controls"]] if title_mode else [["game", "Fighter"], ["settings", "Settings"], ["controls", "Controls"], ["codes", "Save code"]]
	for t: Array in tabs:
		var id: String = t[0]
		nav.add_child(UiKit.button(t[1], func() -> void: tab = id; draw(), tab == id))
	_box.add_child(nav)
	match tab:
		"game": _fighter()
		"settings": _settings()
		"controls": _controls()
		"codes": _box.add_child(SlotSelect.SaveCodePanel.new(Callable()))
	var actions := HBoxContainer.new()
	if title_mode:
		actions.add_child(UiKit.button("Close", func() -> void: queue_free(), true))
	else:
		actions.add_child(UiKit.button("Resume", func() -> void: main.call("set_paused", false), true))
		actions.add_child(UiKit.button("Save and quit", func() -> void: main.call("go_menu")))
	_box.add_child(actions)

func _fighter() -> void:
	var p := _play()
	if p == null or p.game == null:
		return
	var s: Dictionary = p.game.hud()
	for row: Array in [["Race", s.raceName], ["Level", int(s.level)], ["Power level", Hud._grouped(int(s.powerLevel))], ["Zeni", Hud._grouped(int(s.zeni))],
			["Played", SlotSelect._duration(float(p.game.slot.get("playTime", 0.0)))], ["World", s.zoneName]]:
		var h := HBoxContainer.new()
		var k := UiKit.label(str(row[0]), "Muted"); k.custom_minimum_size.x = 160
		h.add_child(k); h.add_child(UiKit.label(str(row[1])))
		_box.add_child(h)
	var n := int(s.statPoints)
	_box.add_child(UiKit.label("No stat points to spend. Level up to earn more." if n == 0 else "%d point%s to spend" % [n, "" if n == 1 else "s"], "HeaderMedium"))
	var tabs := HFlowContainer.new()
	for t: String in RpgMenu.TABS:
		tabs.add_child(UiKit.button(t, func() -> void:
			main.call("set_paused", false)
			var ui: Node = main.get("play_ui")
			if ui != null: ui.rpg.open_tab(t)))
	_box.add_child(tabs)

func _settings() -> void:
	var q := HBoxContainer.new()
	q.add_child(_row_label("Graphics"))
	for o: String in ["low", "medium", "high"]:
		q.add_child(UiKit.button(o.capitalize(), func() -> void:
			Settings.set_value("quality", o); draw()
			Events.emit_named("notify", {"text": "Graphics change applies when the world reloads (travel or restart)."}), Settings.get_value("quality") == o))
	_box.add_child(q)
	for s: Array in [["masterVolume", "Master volume", 0.0, 1.0], ["musicVolume", "Music", 0.0, 1.0], ["sfxVolume", "Effects", 0.0, 1.0],
			["voiceVolume", "Voices", 0.0, 1.0], ["mouseSensitivity", "Mouse sensitivity", 0.1, 3.0]]:
		var row := HBoxContainer.new()
		row.add_child(_row_label(s[1]))
		var sl := HSlider.new(); sl.min_value = s[2]; sl.max_value = s[3]; sl.step = 0.05; sl.value = float(Settings.get_value(s[0]))
		sl.custom_minimum_size.x = 360; sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = s[0]
		var val := UiKit.label("%.2f" % sl.value, "Muted")
		sl.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v); val.text = "%.2f" % v)
		row.add_child(sl); row.add_child(val)
		_box.add_child(row)
	for s: Array in [["invertY", "Invert look"], ["showFps", "Show FPS"], ["voices", "Character voices"], ["fullscreen", "Fullscreen"]]:
		var cb := CheckButton.new(); cb.text = s[1]; cb.button_pressed = bool(Settings.get_value(s[0]))
		var key: String = s[0]
		cb.toggled.connect(func(on: bool) -> void:
			Settings.set_value(key, on)
			if key == "fullscreen" and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		_box.add_child(cb)
	_box.add_child(UiKit.button("Reset settings", func() -> void: Settings.reset(); draw()))

func _row_label(t: String) -> Label:
	var l := UiKit.label(t); l.custom_minimum_size.x = 190
	return l

func _controls() -> void:
	_box.add_child(UiKit.label("Pick an action, then press the key or mouse button you want. Escape cancels.", "Muted", true))
	for a: Array in ACTIONS:
		var row := HBoxContainer.new()
		row.add_child(_row_label(a[1]))
		var k := UiKit.label("Press a key…" if _listening == a[0] else UiKit.key_name(a[0]))
		k.custom_minimum_size.x = 160
		row.add_child(k)
		var id: String = a[0]
		row.add_child(UiKit.button("Change", func() -> void: _listening = id; draw()))
		_box.add_child(row)
	_box.add_child(UiKit.button("Reset controls", func() -> void: Settings.set_value("bindings", {}); draw()))

func _input(e: InputEvent) -> void:
	if _listening == "":
		return
	if not ((e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed)):
		return
	get_viewport().set_input_as_handled()
	if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
		_listening = ""
		draw()
		return
	var b: Dictionary = (Settings.get_value("bindings") as Dictionary).duplicate(true)
	b[_listening] = [Controls.code_for(e)]
	_listening = ""
	Settings.set_value("bindings", b)
	Events.emit_named("notify", {"text": "Controls saved."})
	draw()
