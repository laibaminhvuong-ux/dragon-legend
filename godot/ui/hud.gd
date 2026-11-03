class_name Hud
extends Control
# The play HUD (port of web/src/ui/hud.js + the rpg overlay's tracker/prompt/actions): health, ki and XP bars,
# level, power level, zeni, zone and form, toasts, the lock-on target, the interact prompt, quest tracker, action
# hints, cooldown/charge progress, the respawn notice and the aim reticle. Reads rules state only.

const TOAST_SECONDS := 3.4
const MAX_TOASTS := 4
var play: PlaySession
var _name: Label
var _hp: ProgressBar
var _ki: ProgressBar
var _xp: ProgressBar
var _hp_text: Label
var _ki_text: Label
var _meta: Label
var _points: Button
var _toasts: VBoxContainer
var _target: Label
var _prompt: Label
var _tracker: VBoxContainer
var _next: Label
var _actions: Label
var _progress: Label
var _death: Label
var _fps: Label
var direction: QuestDirection
var _reticle: Control
var _stamp := ""
var _quest_stamp := ""
var _timer := 0.0
var open_menu: Callable   # set by main: opens the fighter menu on a tab

func _init(p: PlaySession) -> void:
	play = p
	name = "Hud"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top-left: the fighter
	var left := PanelContainer.new()
	left.position = Vector2(18, 16)
	add_child(left)
	var lv := VBoxContainer.new(); lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	_name = UiKit.label("", "HeaderMedium")
	lv.add_child(_name)
	for spec: Array in [["hp", Color("#e8524a")], ["ki", Color("#4fb6ff")], ["xp", Color("#f2c94c")]]:
		var holder := Control.new(); holder.custom_minimum_size = Vector2(320, 20 if spec[0] != "xp" else 10)
		var b := UiKit.bar(spec[1], 20.0 if spec[0] != "xp" else 10.0)
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(b)
		if spec[0] != "xp":
			var t := UiKit.label(""); t.set_anchors_preset(Control.PRESET_FULL_RECT); t.add_theme_font_size_override("font_size", 14)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t.add_theme_constant_override("outline_size", 4)
			holder.add_child(t)
			if spec[0] == "hp": _hp_text = t
			else: _ki_text = t
		lv.add_child(holder)
		match spec[0]:
			"hp": _hp = b
			"ki": _ki = b
			"xp": _xp = b
	_meta = UiKit.label("", "Muted")
	lv.add_child(_meta)
	_points = UiKit.button("", func() -> void: if open_menu.is_valid(): open_menu.call("Stats"), true)
	_points.visible = false
	lv.add_child(_points)
	# top-right: quests
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-380, 16)
	right.custom_minimum_size = Vector2(360, 0)
	right.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(right)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	rv.add_child(UiKit.label("QUESTS · hold Alt to click", "HeaderMedium"))
	_tracker = VBoxContainer.new()
	rv.add_child(_tracker)
	_next = UiKit.label("", "Muted", true)
	rv.add_child(_next)
	# toasts (top centre), target, prompt, bottom hints
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 20); _toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_target = _centered_label(Vector2(0, 0.17), 22, Color("#ffd9a8"))
	_prompt = _centered_label(Vector2(0, 0.66), 24, Color.WHITE)
	_death = _centered_label(Vector2(0, 0.42), 40, Color("#ff7a6a"))
	_progress = _centered_label(Vector2(0, 0.88), 17, UiKit.ACCENT.lightened(0.3))
	_actions = _centered_label(Vector2(0, 0.92), 16, UiKit.MUTED)
	_fps = UiKit.label("", "Muted")
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); _fps.position = Vector2(18, -32)
	add_child(_fps)
	direction = QuestDirection.new(p)
	add_child(direction)
	_reticle = Reticle.new()
	add_child(_reticle)
	Events.notify.connect(toast)
	Events.levelup.connect(func(level: int, _g: int) -> void: toast("Level up! Level %d" % level))

func _exit_tree() -> void:
	if Events.notify.is_connected(toast):
		Events.notify.disconnect(toast)

func _centered_label(anchor: Vector2, size: int, color: Color) -> Label:
	var l := UiKit.label("")
	l.anchor_left = 0.0; l.anchor_right = 1.0; l.anchor_top = anchor.y; l.anchor_bottom = anchor.y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func toast(text: String) -> void:
	if text == "":
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.06, 0.08, 0.14, 0.88), 10))
	var l := UiKit.label(RuleRuntime.rename_text(text), "", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_meta("life", TOAST_SECONDS)
	_toasts.add_child(p)
	while _toasts.get_child_count() > MAX_TOASTS:
		var first := _toasts.get_child(0)
		_toasts.remove_child(first); first.queue_free()

func update_hud(dt: float) -> void:
	for t in _toasts.get_children():
		var life := float(t.get_meta("life")) - dt
		t.set_meta("life", life)
		t.modulate.a = clampf(life / 0.4, 0.0, 1.0)
		if life <= 0.0:
			_toasts.remove_child(t); t.queue_free()
	var g := play.game
	if g == null:
		return
	var s := g.hud()
	var form := "" if str(s.formName) == "Base" else " · " + str(s.formName)
	_name.text = "%s · Lv %d%s · %s" % [s.raceName, int(s.level), form, s.zoneName]
	_hp.value = clampf(float(s.health) / maxf(1.0, float(s.maxHealth)), 0.0, 1.0)
	_hp_text.text = "HP %d / %d" % [ceili(float(s.health)), int(s.maxHealth)]
	_ki.value = clampf(float(s.ki) / maxf(1.0, float(s.maxKi)), 0.0, 1.0)
	_ki_text.text = "Ki %d / %d" % [int(s.ki), int(s.maxKi)]
	_xp.value = clampf(float(s.xp) / maxf(1.0, float(s.xpNext)), 0.0, 1.0)
	_meta.text = "PL %s · %s zeni" % [_grouped(int(s.powerLevel)), _grouped(int(s.zeni))]
	_points.visible = int(s.statPoints) > 0
	_points.text = "%d stat point%s · %s" % [int(s.statPoints), "" if int(s.statPoints) == 1 else "s", UiKit.key_name("menu")]
	_fps.visible = bool(Settings.get_value("showFps"))
	if _fps.visible: _fps.text = "%d fps" % Engine.get_frames_per_second()
	(_reticle as Reticle).refresh(play)
	direction.refresh()
	_timer += dt
	if _timer < 0.1:
		return
	_timer = 0.0
	_slow_update()

func _slow_update() -> void:
	var story := play.story
	var c: Dictionary = play.game.combat.snapshot()
	var inter: Variant = story.interaction()
	var rows: Array = story.tracker()
	var w: Variant = story.waypoint()
	var p: Dictionary = play.game.player
	var frozen := play.is_frozen()
	_prompt.visible = inter is Dictionary and not frozen
	_prompt.text = "[%s] %s · %s" % [UiKit.key_name("interact"), inter.action, inter.name] if inter is Dictionary else ""
	_actions.text = "%s Melee · %s Ki blast · %s %s · %s Guard · %s Charge · %s Lock-on · %s Flight · %s Run/fast · %s Dash · %s Kaiyoken · %s Base form · %s Menu" % [
		UiKit.key_name("melee"), UiKit.key_name("ki_blast"), UiKit.key_name("beam"), str(c.get("techniqueName", "Energy Wave")), UiKit.key_name("block"),
		UiKit.key_name("charge"), UiKit.key_name("lock_on"), UiKit.key_name("flight"), UiKit.key_name("sprint"), UiKit.key_name("dash"), UiKit.key_name("kaioken"), UiKit.key_name("base"), UiKit.key_name("menu")]
	var tgt: Variant = c.get("target")
	_target.visible = tgt is Dictionary
	if tgt is Dictionary:
		_target.text = "%s%s · Lv. %d · %d / %d HP" % ["BOSS · " if tgt.get("boss", false) else "", tgt.name, int(tgt.level), ceili(float(tgt.health)), ceili(float(tgt.maxHealth))]
	var bits: Array[String] = []
	if float(c.get("beamCharge", 0.0)) > 0.0: bits.append("charging %d%%" % roundi(float(c.beamCharge) * 100.0))
	if float(c.get("beamCd", 0.0)) > 0.0: bits.append("%s cooldown %.1fs" % [c.get("techniqueName", ""), float(c.beamCd)])
	if float(c.get("instinctFocus", 0.0)) > 0.0: bits.append("UI focus %.1fs" % float(c.instinctFocus))
	var av: Dictionary = c.get("avatar", {})
	if av.get("active", false): bits.append("Avatar %.1fs" % float(av.get("remaining", 0.0)))
	elif float(av.get("cooldown", 0.0)) > 0.0: bits.append("Avatar cooldown %.1fs" % float(av.cooldown))
	var kai: Dictionary = c.get("kaioken", {})
	if kai.get("active", false): bits.append("Kaiyoken x%d: %.1fs" % [int(kai.get("rank", 2)), float(kai.get("remaining", 0.0))])
	elif float(kai.get("cooldown", 0.0)) > 0.0: bits.append("Kaiyoken cooldown %.1fs" % float(kai.cooldown))
	_progress.text = " · ".join(bits)
	var respawn := float(c.get("respawn", 0.0))
	_death.visible = respawn > 0.0
	_death.text = "Defeated · respawning in %ds" % ceili(respawn)
	var rows_key := JSON.stringify(rows)
	if rows_key != _quest_stamp:
		_quest_stamp = rows_key
		for ch in _tracker.get_children():
			_tracker.remove_child(ch)
			ch.queue_free()
		for row: Dictionary in rows:
			var box := VBoxContainer.new()
			var id: String = row.id
			var select := UiKit.button(("◆ " if row.get("tracked",false) else "")+str(row.title),func() -> void: select_quest(id))
			select.tooltip_text = "Track this quest and show the next direction"
			box.add_child(select)
			var obj := UiKit.label("%s%s" % [row.get("objective", ""), (" · " + str(row.progress)) if str(row.get("progress", "")) != "" else ""], "Muted", true)
			obj.custom_minimum_size.x = 320
			box.add_child(obj)
			if str(row.get("where", "")) != "":
				box.add_child(UiKit.label(str(row.where), "Muted"))
			_tracker.add_child(box)
	var n: Variant = story.next_main()
	if w is Dictionary:
		_next.text = "%s · %d m" % [w.get("text", ""), roundi(Vector2(float(w.x) - p.pos.x, float(w.z) - p.pos.z).length())]
	elif story.navigation()!=null:
		_next.text = story.navigation().text
	elif n is Dictionary and n.get("locked", false):
		_next.text = "Next story: %s · requires Lv. %d. Take a Training Guide patrol to level up." % [n.title, int(n.level)]
	elif n is Dictionary and n.get("giver") != null:
		_next.text = "Next story: %s · %s · %s" % [n.title, n.giver, n.get("zone", "")]
	else:
		_next.text = "Speak to a Training Guide for repeatable combat quests."

func select_quest(id: String) -> void:
	if play.story.track_quest(id):
		play.save_now()
		_quest_stamp = ""
		_slow_update()
		direction.refresh()
		toast("Quest tracked. Follow the gold objective marker.")

static func _grouped(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

class Reticle extends Control:
	var on := false
	var locked := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(28, 28)
	func refresh(p: PlaySession) -> void:
		on = false
		if p.game == null or float(p.game.player.health) <= 0.0 or p.is_frozen() or p.camera == null or not p.camera.is_inside_tree():
			visible = false
			return
		var aim: Dictionary = p.game.combat.aim_state()
		var pt: Vector3 = RuleRuntime.vector(aim.get("point", Vector3.ZERO))
		if p.camera.is_position_behind(pt):
			visible = false
			return
		var sp := p.camera.unproject_position(pt)
		visible = true
		locked = aim.get("locked", false)
		position = sp - size * 0.5
		queue_redraw()
	func _draw() -> void:
		var c := Color("#ff6a4a") if locked else Color(1, 1, 1, 0.85)
		var m := size * 0.5
		draw_arc(m, 7.0 if locked else 4.0, 0, TAU, 24, c, 2.0, true)
		if locked:
			for a in 4:
				var d := Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
				draw_line(m + d * 10.0, m + d * 14.0, c, 2.0, true)
