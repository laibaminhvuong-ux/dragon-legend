class_name SlotSelect
extends Control
# The title menu (port of web/src/ui/slotSelect.js): three fighter slots (play, delete with confirm, create),
# save codes, the version and a controls hint, over the flyover of the plains.

var main: Node
var _confirming := -1
var _codes := false
var _root: VBoxContainer

func _init(m: Node) -> void:
	main = m
	name = "SlotSelect"
	UiKit.ensure_data()
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 18)
	center.add_child(_root)
	draw()

func draw() -> void:
	for c in _root.get_children():
		_root.remove_child(c); c.queue_free()
	var title := UiKit.label("Dragon Legend", "HeaderLarge")
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", UiKit.ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	var tag := UiKit.label("Create a fighter, then take on the story.")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(row)
	var slots: Array = SaveStore.list_slots()
	for i in 3:
		row.add_child(_card(slots[i] if i < slots.size() else null, i))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(UiKit.button("Save codes", func() -> void: _codes = not _codes; draw()))
	foot.add_child(UiKit.button("Settings", func() -> void:
		var pm := PauseMenu.new(main, true)
		pm.name = "Settings"
		add_child(pm)))
	foot.add_child(UiKit.button("Quit", func() -> void: main.get_tree().quit()))
	var ver := UiKit.label("   v" + GameVersion.VERSION, "Muted")
	foot.add_child(ver)
	_root.add_child(foot)
	var hint := UiKit.label("WASD move · mouse look · Space jump · Esc pause", "Muted")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)
	if _codes:
		_root.add_child(SaveCodePanel.new(func() -> void: _codes = false; draw()))

func _card(slot: Variant, i: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(260, 220)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.label("Slot %d" % (i + 1), "Muted"))
	if not (slot is Dictionary):
		v.add_child(UiKit.label("Empty slot", "HeaderMedium"))
		v.add_child(UiKit.label("—", "Muted"))
		var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sp)
		v.add_child(UiKit.button("Create fighter", func() -> void: main.call("open_creator", i), true))
		return p
	var race: Dictionary = Data.races.get(str(slot.get("race", "")), {})
	v.add_child(UiKit.label(str(race.get("name", slot.get("race", "?"))), "HeaderMedium"))
	v.add_child(UiKit.label("Level %d" % int(slot.get("level", 1))))
	v.add_child(UiKit.label("Played %s" % _duration(float(slot.get("playTime", 0.0))), "Muted"))
	var sp2 := Control.new(); sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sp2)
	var actions := HBoxContainer.new()
	v.add_child(actions)
	if _confirming == i:
		v.add_child(UiKit.label("Delete this fighter for good?", "", true))
		actions.add_child(UiKit.button("Delete", func() -> void:
			_confirming = -1; SaveStore.delete_slot(i); draw()))
		actions.add_child(UiKit.button("Cancel", func() -> void: _confirming = -1; draw()))
	else:
		actions.add_child(UiKit.button("Play", func() -> void: main.call("start_game", i), true))
		actions.add_child(UiKit.button("Delete", func() -> void: _confirming = i; draw()))
	return p

static func _duration(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%d min" % m

class SaveCodePanel extends PanelContainer:
	var _edit: TextEdit
	var _msg: Label
	var _confirm := false
	var _done: Callable
	func _init(done: Callable) -> void:
		_done = done
		var v := VBoxContainer.new(); add_child(v)
		v.add_child(UiKit.label("Save codes", "HeaderMedium"))
		v.add_child(UiKit.label("A save code carries all three fighters. Copy it somewhere safe, or paste one in to restore. Codes from the web version work too.", "Muted", true))
		_edit = TextEdit.new(); _edit.custom_minimum_size = Vector2(760, 90); _edit.placeholder_text = "Paste a save code here…"
		_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		v.add_child(_edit)
		var row := HBoxContainer.new(); v.add_child(row)
		row.add_child(UiKit.button("Show my code", func() -> void:
			_edit.text = SaveStore.export_code(); _edit.select_all(); _msg.text = "Code ready. Copy it somewhere safe."))
		row.add_child(UiKit.button("Copy", func() -> void:
			DisplayServer.clipboard_set(_edit.text); _msg.text = "Copied to the clipboard."))
		var imp := UiKit.button("Import", func() -> void: pass)
		imp.pressed.connect(func() -> void:
			if not _confirm:
				_confirm = true; imp.text = "Import anyway"; _msg.text = "Importing replaces all three slots. Click again to confirm."
				return
			var r := SaveStore.import_code(_edit.text)
			_msg.text = "Save restored." if r.get("ok", false) else str(r.get("error", "That code didn't work."))
			if r.get("ok", false) and _done.is_valid(): _done.call())
		row.add_child(imp)
		_msg = UiKit.label("", "Muted"); v.add_child(_msg)
