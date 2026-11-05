class_name RiftBoard
extends Control
# Rift Patrol Mission Board (Time Nexus terminal, interact key). Two tabs: Missions (the four arcs, each mission's map,
# level, best stars, locked/next) with Launch, and Hero Cards (your collection with rarity frames, three equip slots).
# Every command goes to the rules (start_rift_mission / equip_hero_card); refusals become toasts. Pauses the game.

signal opened
signal closed

const ARCS := {1: "The Fractured Timeline", 2: "Prison of Echoes", 3: "The Dark Crown War", 4: "The End of Time"}
const RARITY := {"rare": Color(0.45, 0.75, 1.0), "legendary": Color(1.0, 0.78, 0.3)}

var play: PlaySession
var is_open := false
var tab := "Missions"
var _panel: PanelContainer
var _list: VBoxContainer

func _init(p: PlaySession) -> void:
	play = p
	name = "RiftBoard"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.06, 0.04, 0.14, 0.95), 14))
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -380; _panel.offset_right = 380; _panel.offset_top = -300; _panel.offset_bottom = 300
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_panel.visible = false

func open(which := "Missions") -> void:
	tab = which
	if not is_open:
		is_open = true
		opened.emit()
	_panel.visible = true
	_build()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	closed.emit()

static func stars(n: int) -> String:
	return "★".repeat(clampi(n, 0, 3)) + "☆".repeat(3 - clampi(n, 0, 3))

func launch(id: String) -> void:
	var err: Variant = play.game.start_rift_mission(id)
	if err is String:
		Events.emit_named("notify", {"text": err})
		return
	close()

func equip(id: String, slot: int) -> void:
	var err: Variant = play.game.equip_hero_card(id, slot)
	if err is String:
		Events.emit_named("notify", {"text": err})
	_build()

func _build() -> void:
	for c in _list.get_children():
		_list.remove_child(c); c.queue_free()
	_list.add_child(UiKit.label("Rift Patrol · Mission Board", "HeaderLarge"))
	var nav := HBoxContainer.new()
	for t in ["Missions", "Hero Cards"]:
		nav.add_child(UiKit.button(t, func() -> void: open(t), t == tab))
	nav.add_child(UiKit.button("Close", close))
	_list.add_child(nav)
	if tab == "Missions":
		_missions()
	else:
		_cards()

func _missions() -> void:
	var rows: Array = play.game.rift_missions()
	var names: Dictionary = {}
	for z: String in RuleTables.table("zones"):
		names[z] = str(RuleTables.table("zones")[z].get("name", z))
	var arc := -1
	var next_marked := false
	for m: Dictionary in rows:
		if int(m.arc) != arc:
			arc = int(m.arc)
			_list.add_child(UiKit.label("Arc %d · %s" % [arc, ARCS.get(arc, "")], "HeaderMedium"))
		var row := HBoxContainer.new()
		var unlocked: bool = m.get("unlocked", false)
		var label := "%s  %s · %s" % [stars(int(m.get("stars", 0))), str(m.name), names.get(str(m.zone), str(m.zone))]
		if unlocked and not m.get("done", false) and not next_marked:
			label += "   · NEXT"
			next_marked = true
		var l := UiKit.label(label)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not unlocked:
			l.modulate = Color(1, 1, 1, 0.45)
		row.add_child(l)
		var b := UiKit.button("Launch" if unlocked else "Locked", launch.bind(str(m.id)), unlocked and not m.get("done", false))
		b.disabled = not unlocked
		row.add_child(b)
		_list.add_child(row)
	_list.add_child(UiKit.label("Stars: ★ clear · ★ under 4 minutes · ★ no ally knocked out. First clears give a Hero Card; three stars give its prismatic version.", "Muted", true))

func _cards() -> void:
	var cards: Array = play.game.hero_cards()
	var equipped: Array = ["", "", ""]
	for c: Dictionary in cards:
		var e := int(c.get("equipped", -1))
		if e >= 0 and e < 3:
			equipped[e] = str(c.name)
	_list.add_child(UiKit.label("Equipped: 1) %s   2) %s   3) %s" % [equipped[0] if equipped[0] != "" else "—", equipped[1] if equipped[1] != "" else "—",
		equipped[2] if equipped[2] != "" else "—"], "HeaderMedium"))
	var owned := cards.filter(func(c: Dictionary) -> bool: return c.get("owned", false))
	_list.add_child(UiKit.label("Collection: %d / %d" % [owned.size(), cards.size()], "Muted"))
	for c: Dictionary in cards:
		var row := HBoxContainer.new()
		var frame := ColorRect.new()
		frame.custom_minimum_size = Vector2(10, 34)
		frame.color = RARITY.get(str(c.get("rarity", "rare")), Color.WHITE) if c.get("owned", false) else Color(0.3, 0.3, 0.35)
		row.add_child(frame)
		var who := str(Fighter.Tables().characters.get(str(c.get("character", "")), {}).get("name", c.get("character", "")))
		var text := "%s  (%s · %s)" % [str(c.name), who, str(c.get("rarity", "")).capitalize()] if c.get("owned", false) else "???  (clear the mission to earn this card)"
		var l := UiKit.label(text)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var eff: Variant = c.get("effect")
		if c.get("owned", false) and eff is Dictionary:
			row.add_child(UiKit.label(_effect_text(eff), "Muted"))
		if c.get("owned", false):
			var e := int(c.get("equipped", -1))
			if e >= 0:
				row.add_child(UiKit.button("Unequip", equip.bind("", e)))
			else:
				for slot in 3:
					row.add_child(UiKit.button(str(slot + 1), equip.bind(str(c.id), slot)))
		_list.add_child(row)

static func _effect_text(e: Dictionary) -> String:
	if e.has("cosmetic"):
		return "Prismatic aura"
	var bits: PackedStringArray = []
	for k: String in e:
		if e[k] is float or e[k] is int:
			bits.append("+%d%% %s" % [roundi(float(e[k]) * 100.0) if absf(float(e[k])) < 1.0 else int(e[k]), k.replace("_", " ")])
	return ", ".join(bits)

## Gamepad / keyboard confirm on the focused button.
func activate() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and _list.is_ancestor_of(f):
		(f as Button).pressed.emit()
