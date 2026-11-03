class_name RpgMenu
extends Control
# Dialogue and the fighter menu (port of web/src/ui/rpg.js): NPC lines, quest offers with rewards, the travel
# guide, the Training Guide shop, and the fighter tabs (Character, Accessories, Stats with +1/+10/+100/All,
# Forms with paths and mastery, Techniques, Kaiyoken). Every command goes to the rules; errors become toasts.

signal opened
signal closed

const TABS := ["Character", "Accessories", "Stats", "Forms", "Techniques"]
const PATHS := {
	"beast": ["Beast", "Unleash your potential through Gohan and Piccolo training."],
	"instinct": ["Ultra Instinct", "Sign/Omen -> Perfected Ultra Instinct -> True Ultra Instinct, with Moro-era mastery training."],
	"ego": ["Ultra Ego", "Learn the power of Destruction from Beerus and Vegeta."],
}
var play: PlaySession
var is_open := false
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _preview: SubViewportContainer
var save: Callable

func _init(p: PlaySession) -> void:
	play = p
	name = "RpgMenu"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.05, 0.07, 0.12, 0.94), 14))
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.08; _panel.anchor_bottom = 0.92
	_panel.offset_left = -360; _panel.offset_right = 360
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	_scroll.add_child(_box)
	_panel.visible = false
	Events.dialogue.connect(show_dialogue)

func _exit_tree() -> void:
	if Events.dialogue.is_connected(show_dialogue):
		Events.dialogue.disconnect(show_dialogue)

func _tell(err: Variant) -> void:
	if err is String and err != "":
		Events.emit_named("notify", {"text": err})
	elif save.is_valid():
		save.call()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	_clear()
	Voices.stop()
	closed.emit()

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c); c.queue_free()
	_preview = null

func _open(speaker: String, text: String) -> void:
	_clear()
	if not is_open:
		is_open = true
		opened.emit()
	_panel.visible = true
	_box.add_child(UiKit.label(speaker, "HeaderLarge"))
	if text != "":
		var l := UiKit.label(text, "", true); l.custom_minimum_size.x = 660
		_box.add_child(l)

func _card() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.1, 0.13, 0.2, 0.9), 10))
	var v := VBoxContainer.new()
	p.add_child(v)
	_box.add_child(p)
	return v

func _focus_first() -> void:
	for c in _box.find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			(c as Button).grab_focus.call_deferred()
			return

## Activates the focused (or first) button: the interact key / gamepad A while a dialogue is open.
func activate() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and _box.is_ancestor_of(f):
		(f as Button).pressed.emit()
		return
	for c in _box.find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			(c as Button).pressed.emit()
			return

func show_dialogue(d: Dictionary) -> void:
	_open(str(d.get("speaker", "")), str(d.get("text", "")))
	Voices.say(str(d.get("speaker", "")), str(d.get("text", "")))
	var kind := str(d.get("kind", ""))
	if kind == "choice":
		for q: Dictionary in d.get("choices", []):
			var v := _card()
			v.add_child(UiKit.label("%s · Lv. %d" % [q.title, int(q.get("level", 1))], "HeaderMedium"))
			var t := UiKit.label(str(q.get("text", "")), "", true); t.custom_minimum_size.x = 620; v.add_child(t)
			var o := UiKit.label(str(q.get("objective", "")), "Muted", true); o.custom_minimum_size.x = 620; v.add_child(o)
			v.add_child(UiKit.label(_rewards(q.get("rewards", {})), "Muted", true))
			var qid := str(q.id)
			v.add_child(UiKit.button("Accept quest", func() -> void:
				if play.story.accept_quest(qid):
					_tell(null); close()
				else:
					close(); Events.emit_named("notify", {"text": "Move closer to the quest giver and try again."}), true))
	if kind == "travel":
		for o: Dictionary in d.get("options", []):
			var zone := str(o.zone)
			var text := ("★ %s · next in the story" % o.name) if o.get("story", false) else ("%s · %s" % [o.name, o.get("planet", "")])
			_box.add_child(UiKit.button(text, func() -> void:
				if play.story.travel_to(zone): close()
				else:
					close(); Events.emit_named("notify", {"text": "Stand next to the pilot and try again."}), o.get("story", false)))
	if str(d.get("speaker", "")) == "Training Guide":
		_box.add_child(UiKit.button("Shop", show_shop))
	_box.add_child(UiKit.button("Not now" if kind in ["choice", "travel"] else "Continue", close))
	_focus_first()

static func _n(v: Variant) -> int:
	return int(v) if v != null else 0

static func _rewards(r: Dictionary) -> String:
	var parts: Array[String] = []
	if r.get("xp"): parts.append("%d XP" % int(r.xp))
	if r.get("zeni"): parts.append("%d zeni" % int(r.zeni))
	if r.get("statPoints"): parts.append("%d stat points" % int(r.statPoints))
	if r.get("restore"): parts.append("Health and Ki restored")
	for id: String in r.get("moves", []): parts.append(str(Data.moves.get(id, {}).get("name", id)))
	for id: String in r.get("forms", []): parts.append(str(Data.forms.get(id, {}).get("name", id)))
	return " · ".join(parts) if not parts.is_empty() else "Training progress"

func show_shop() -> void:
	_open("Training Guide shop", "You have %d zeni. Earn more from patrols and story quests." % int(play.game.hud().zeni))
	for item: Dictionary in play.story.shop():
		var v := _card()
		v.add_child(UiKit.label("%s · %d zeni" % [item.name, int(item.price)], "HeaderMedium"))
		v.add_child(UiKit.label(str(item.get("description", "")), "Muted", true))
		var id := str(item.id)
		var b := UiKit.button("Owned" if item.get("owned", false) else "Buy", func() -> void:
			var err: Variant = play.story.buy(id)
			if err is String and err != "": Events.emit_named("notify", {"text": err})
			else:
				_tell(null); show_shop())
		b.disabled = item.get("owned", false)
		v.add_child(b)
	_box.add_child(UiKit.button("Continue", close))
	_focus_first()

func _picker(label_text: String, options: Array, value: Variant, command: Callable) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label(label_text); l.custom_minimum_size.x = 170
	row.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in options.size():
		var o: Array = options[i]
		ob.add_item(str(o[1]), i)
		if o.size() > 2:
			ob.set_item_icon(i, o[2])
		if str(o[0]) == str(value):
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: command.call(options[i][0]))
	row.add_child(ob)
	_box.add_child(row)

static func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func open_tab(tab: String) -> void:
	var slot: Dictionary = play.game.slot
	var race: Dictionary = Data.races.get(str(slot.race), {})
	_open("Fighter · " + tab, "Level %d / %d · %s" % [int(slot.level), int(Data.stats.MAX_LEVEL), race.get("name", slot.race)])
	var nav := HBoxContainer.new()
	for t: String in TABS:
		nav.add_child(UiKit.button(t, func() -> void: open_tab(t), t == tab))
	_box.add_child(nav)
	match tab:
		"Character": _tab_character(slot, race)
		"Accessories": _tab_accessories(slot)
		"Stats": _tab_stats(slot)
		"Forms": _tab_forms(slot, race)
		"Techniques": _tab_techniques()
	if tab in ["Forms", "Techniques"]:
		_kaioken(slot, tab)
	_box.add_child(UiKit.button("Continue", close))
	_focus_first()

func _tab_character(slot: Dictionary, race: Dictionary) -> void:
	var a: Dictionary = slot.appearance
	var apply := func(key: String, value: Variant) -> void:
		_tell(play.game.customize_appearance({key: value}))
	var swatches := func(values: Array) -> Array:
		var out := []
		for i in values.size():
			var c := Color.hex((int(values[i]) << 8) | 0xff)
			out.append([i, "#" + c.to_html(false), _swatch(c)])
		return out
	_picker("Build", Data.appearance.BUILDS.map(func(x: Dictionary) -> Array: return [x.id, x.name]), a.get("build"), func(v: Variant) -> void: apply.call("build", v))
	_picker("Face", Data.appearance.FACES.map(func(x: Dictionary) -> Array: return [x.id, x.name]), a.get("face"), func(v: Variant) -> void: apply.call("face", v))
	_picker("Hair", (race.get("hairStyles", []) as Array).map(func(x: String) -> Array: return [x, x]), a.get("hair"), func(v: Variant) -> void: apply.call("hair", v))
	_picker("Skin colour", swatches.call(race.get("skins", [])), a.get("skin"), func(v: Variant) -> void: apply.call("skin", int(v)))
	_picker("Hair colour", swatches.call(Data.appearance.HAIR_COLORS), a.get("hairColor"), func(v: Variant) -> void: apply.call("hairColor", int(v)))
	_picker("Outfit tint", swatches.call(Data.appearance.TINTS), a.get("outfitTint"), func(v: Variant) -> void: apply.call("outfitTint", int(v)))
	var ki_opts := [["custom", "Custom hex"]]
	for i in (Data.appearance.KI_COLORS as Array).size():
		ki_opts.append([i, Data.appearance.KI_COLOR_NAMES[i], _swatch(Color.hex((int(Data.appearance.KI_COLORS[i]) << 8) | 0xff))])
	_picker("Ki colour", ki_opts, "custom" if a.get("kiColorHex") != null else a.get("kiColor", 0), func(v: Variant) -> void:
		if str(v) == "custom": return
		_tell(play.game.customize_appearance({"kiColor": int(v), "kiColorHex": null})); open_tab("Character"))
	var hex_row := HBoxContainer.new()
	hex_row.add_child(UiKit.label("Custom Ki hex"))
	var edit := LineEdit.new(); edit.placeholder_text = "#63CFFF"; edit.text = str(a.get("kiColorHex")) if a.get("kiColorHex") != null else ""
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_row.add_child(edit)
	hex_row.add_child(UiKit.button("Apply", func() -> void:
		_tell(play.game.customize_appearance({"kiColorHex": edit.text.strip_edges()})); open_tab("Character")))
	_box.add_child(hex_row)
	var outfits: Array = slot.get("outfits", [])
	_picker("Outfit", outfits.map(func(id: String) -> Array: return [id, Data.outfits.get(id, {}).get("name", id)]), a.get("outfit"), func(v: Variant) -> void:
		_tell(null if play.game.equip_outfit(str(v)) else "That outfit is unavailable."))
	_box.add_child(UiKit.label("Ki colour changes your charging aura, blasts and beams. Transformation auras keep their form colours.", "Muted", true))

func _tab_accessories(slot: Dictionary) -> void:
	for id: String in Data.accessories:
		var item: Dictionary = Data.accessories[id]
		var after: Variant = item.get("after")
		var available: bool = after == null or str(slot.get("quests", {}).get(str(after), {}).get("status", "")) in ["done", "repeatable"]
		var v := _card()
		v.add_child(UiKit.label(str(item.name), "HeaderMedium"))
		var equipped: bool = slot.loadout.get("accessory") == id
		var b := UiKit.button("Equipped" if equipped else "Equip", func() -> void: _tell(play.game.equip_accessory(id)); open_tab("Accessories"))
		b.disabled = not available or equipped
		v.add_child(b)
		if not available:
			v.add_child(UiKit.label("Unlock quest: %s" % after, "Muted"))

func _tab_stats(slot: Dictionary) -> void:
	var prog := play.game.progression
	var d: Dictionary = prog.derive(slot)
	var pct := func(x: float) -> String: return "+%d%%" % roundi((x - 1.0) * 100.0)
	_box.add_child(UiKit.label("Stats · %d unspent point%s · Power level %s" % [int(slot.statPoints), "" if int(slot.statPoints) == 1 else "s", Hud._grouped(int(d.powerLevel))], "HeaderMedium"))
	_box.add_child(UiKit.label("Earn %d stat points every level. Health and Ki raise your pools; Strength and Ki Power raise damage; Speed raises run speed." % int(Data.stats.POINTS_PER_LEVEL), "Muted", true))
	var rows := [["Health", "Health", "%d max health" % int(d.maxHealth)], ["Ki", "Ki", "%d max ki" % int(d.maxKi)],
		["Strength", "Strength", "%s melee damage" % pct.call(float(d.strength))], ["KiPower", "Ki Power", "%s ki attack damage" % pct.call(float(d.kiPower))],
		["Speed", "Speed", "%.1f run speed" % float(d.runSpeed)]]
	for r: Array in rows:
		var row := HBoxContainer.new()
		var n := UiKit.label(r[1]); n.custom_minimum_size.x = 100; row.add_child(n)
		var pts := UiKit.label(str(prog.points(slot, r[0]))); pts.custom_minimum_size.x = 60; row.add_child(pts)
		var eff := UiKit.label(r[2], "Muted"); eff.custom_minimum_size.x = 200; row.add_child(eff)
		var stat: String = r[0]
		for k: int in [1, 10, 100]:
			var b := UiKit.button("+%d" % k, func() -> void: _tell(play.game.spend_stat_point(stat, k)); open_tab("Stats"))
			b.disabled = int(slot.statPoints) < k
			row.add_child(b)
		var all := UiKit.button("All", func() -> void: _tell(play.game.spend_stat_point(stat, int(play.game.slot.statPoints))); open_tab("Stats"))
		all.disabled = int(slot.statPoints) < 1
		row.add_child(all)
		_box.add_child(row)
	_box.add_child(UiKit.label("Skills", "HeaderMedium"))
	var j: Dictionary = play.story.journal()
	for id: String in j.get("moves", []):
		_box.add_child(UiKit.label("%s: %s" % [Data.moves.get(id, {}).get("name", id), Data.moves.get(id, {}).get("desc", "")], "Muted", true))
	_box.add_child(UiKit.button("Use Recovery Capsule (%d)" % int(j.get("items", {}).get("capsule", 0)), func() -> void:
		if play.story.use_item("capsule"):
			_tell(null); open_tab("Stats")
		else: _tell("A capsule requires missing health or ki.")))
	var inter: Variant = play.story.interaction()
	if inter is Dictionary and str(inter.get("id", "")).begins_with("guide_"):
		_box.add_child(UiKit.button("Guide shop", show_shop))

func _tab_techniques() -> void:
	var c: Dictionary = play.game.combat.snapshot()
	_box.add_child(UiKit.label("Select a learned technique, then hold/release its skill action. The learnable UI Sign technique has no form stat multiplier and a much smaller dodge benefit.", "", true))
	_box.add_child(UiKit.label(str(Data.moves.get(str(c.get("technique", "")), {}).get("desc", "Starter Energy Wave.")), "Muted", true))
	var opts: Array = play.game.combat.available_techniques().map(func(id: String) -> Array:
		return [id, "Energy Wave (starter)" if id == "EnergyWave" else str(Data.moves.get(id, {}).get("name", id))])
	_picker("Equipped technique", opts, c.get("technique"), func(v: Variant) -> void:
		play.game.combat.set_technique(str(v)); _tell(null); open_tab("Techniques"))

func _tab_forms(slot: Dictionary, race: Dictionary) -> void:
	if str(slot.race) in ["Saiyan", "HalfSaiyan"]:
		var path: Variant = slot.loadout.get("formPath")
		var pname: String = PATHS[path][0] if path != null and PATHS.has(path) else ("All three (test save)" if slot.loadout.get("testAllPaths", false) == true else "Not chosen")
		_box.add_child(UiKit.label("Level %d path · %s" % [int(Data.stats.MAX_LEVEL), pname], "HeaderMedium"))
		_box.add_child(UiKit.label("Choose one endgame path for this character. Other paths remain locked.", "Muted", true))
		var row := HBoxContainer.new()
		for p: String in PATHS:
			var b := UiKit.button(PATHS[p][0], func() -> void: _tell(play.game.choose_form_path(p)); open_tab("Forms"))
			b.tooltip_text = RuleRuntime.rename_text(PATHS[p][1])
			b.disabled = int(slot.level) < int(Data.stats.MAX_LEVEL) or path != null
			row.add_child(b)
		_box.add_child(row)
	_box.add_child(UiKit.button("Return to Base", func() -> void: _tell(play.game.select_form("")); open_tab("Forms")))
	for id: String in race.get("forms", []):
		var form: Dictionary = Data.forms.get(id, {})
		if form.is_empty(): continue
		var m: Dictionary = play.game.mastery.mastery_progress(slot, id)
		var owned: bool = (slot.get("forms", []) as Array).has(id)
		var v := _card()
		v.add_child(UiKit.label(str(form.name), "HeaderMedium"))
		v.add_child(UiKit.label("Lv. %d · %s× stats · %d base ki to transform" % [int(form.unlockLevel), str(form.multiplier), roundi(float(form.kiDrain)*RuleGame.TRANSFORM_COST_SECONDS*RuleGame.KI_COST_EASE)], "Muted"))
		if form.get("mastery") is Dictionary:
			var fm: Dictionary = form.mastery
			v.add_child(UiKit.label("Requires %s Mastery Lv. %d: %d / %d points%s" % [Data.forms.get(str(fm.from), {}).get("name", fm.from), int(fm.required) / 10,
				floori(float(slot.get("formMastery", {}).get(str(fm.get("key", "")), 0))), int(fm.required), " · story prerequisite required" if fm.get("after") else ""], "", true))
		if owned:
			var next_txt := ""
			if m.get("next") != null:
				next_txt = " · Next: %s at Mastery Lv. %d" % [Data.forms.get(str(m.next), {}).get("name", m.next), _n(m.get("required")) / 10]
			v.add_child(UiKit.label("Mastery Lv. %d · %d points%s" % [int(m.get("level", 0)), floori(float(m.get("points", 0))), next_txt], "Muted", true))
			if _n(m.get("required")) > 0:
				var bar := UiKit.bar(UiKit.ACCENT, 10.0)
				bar.value = clampf(float(m.points) / float(_n(m.required)), 0.0, 1.0)
				v.add_child(bar)
		var active: bool = str(play.game.player.form) == id
		var b := UiKit.button("Active" if active else "Transform", func() -> void: _tell(play.game.select_form(id)); open_tab("Forms"), not active)
		b.disabled = not owned or not play.game.forms.form_available(slot, id)
		v.add_child(b)
		if not owned:
			v.add_child(UiKit.label("Mastery evolution" if form.get("mastery") is Dictionary else "Complete its unlock quest", "Muted"))
	if RuleForms.has_form_path(slot, "instinct"):
		_box.add_child(UiKit.label("Ultra Intuition Energy Avatar", "HeaderMedium"))
		_box.add_child(UiKit.label(RuleRuntime.rename_text("Advanced ability: learn from Meros after Morro mastery. Use it in Perfected or True UI; equip it under Techniques."), "", true))
		var eb := UiKit.button("Equip Energy Avatar", func() -> void:
			play.game.combat.set_technique("UltraInstinctAvatar"); _tell(null); open_tab("Techniques"))
		eb.disabled = not (slot.get("moves", []) as Array).has("UltraInstinctAvatar")
		_box.add_child(eb)

func _kaioken(slot: Dictionary, tab: String) -> void:
	var k: Dictionary = play.game.kaioken.snapshot()
	var ranks: Array = play.game.kaioken.ranks()
	var K: Dictionary = Data.kaioken
	_box.add_child(UiKit.label("Kaiyoken overlay", "HeaderMedium"))
	_box.add_child(UiKit.label("Keep your Saiyan form and equipped attack. Toggle with %s or here. x2: %s seconds; x10: %s seconds. Extra Ki and health drain; %s-second cooldown after stopping. Ends at %d%% health." % [
		UiKit.key_name("kaioken"), str(K.tiers.get("2", K.tiers.get(2, {})).get("duration", "?")), str(K.tiers.get("10", K.tiers.get(10, {})).get("duration", "?")), str(K.cooldown), roundi(float(K.minHealth) * 100.0)], "Muted", true))
	if ranks.is_empty():
		_box.add_child(UiKit.label("Learn Kaiyoken through King Kae training. Complete the x10 form training to unlock its intensity.", "Muted", true))
		return
	_picker("Kaiyoken intensity", ranks.map(func(r: Variant) -> Array: return [int(r), "x%d" % int(r)]), slot.loadout.get("kaiokenRank", 2), func(v: Variant) -> void:
		_tell(play.game.kaioken.select(int(v))); open_tab(tab))
	_box.add_child(UiKit.button("Stop Kaiyoken" if k.get("active", false) else "Activate Kaiyoken", func() -> void:
		_tell(play.game.kaioken.toggle()); open_tab(tab)))
