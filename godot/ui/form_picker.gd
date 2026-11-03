class_name FormPicker
extends Control
# The transform key opens this: base form, then the player's favourite forms, then every other unlocked form in
# the race's own order. Click a row or press its number (0 = base); the star pins a favourite. The game pauses
# while it is open. Every command goes to the rules; errors become toasts.

signal opened
signal closed

var play: PlaySession
var is_open := false
var _panel: PanelContainer
var _list: VBoxContainer
var _rows: Array = []   # form ids in display order ("" = base form)

func _init(p: PlaySession) -> void:
	play = p
	name = "FormPicker"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.05, 0.07, 0.12, 0.94), 14))
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -230; _panel.offset_right = 230
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_panel.add_child(_list)
	_panel.visible = false

## Row ids in display order: "" (base), favourites, then the rest.
func rows() -> Array:
	return _rows.duplicate()

func open() -> void:
	if play.game.form_order().is_empty():
		Events.emit_named("notify", {"text": "Complete your race's transformation quests to unlock a form."})
		return
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

func pick(id: String) -> void:
	var g := play.game
	if id == str(g.player.form):
		close()
		return
	var err: Variant = g.select_form(id)
	if err is String:
		Events.emit_named("notify", {"text": err})
		_build()
		return
	Events.emit_named("notify", {"text": str(g.forms.forms[id].name) if id != "" else "Back to base form."})
	close()

func pick_number(n: int) -> void:
	if n >= 0 and n < _rows.size():
		pick(str(_rows[n]))

func toggle_favorite(id: String) -> void:
	var err: Variant = play.game.toggle_favorite_form(id)
	if err is String:
		Events.emit_named("notify", {"text": err})
	_build()

func _input(e: InputEvent) -> void:
	if not is_open or not e is InputEventKey or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).keycode
	if k >= KEY_0 and k <= KEY_9:
		pick_number(k - KEY_0)
		get_viewport().set_input_as_handled()

func _build() -> void:
	for c in _list.get_children():
		_list.remove_child(c); c.queue_free()
	var g := play.game
	var favs: Array = g.favorite_forms()
	_rows = [""] + favs + g.form_order().filter(func(id: String) -> bool: return id not in favs)
	_list.add_child(UiKit.label("Transform", "HeaderLarge"))
	_list.add_child(UiKit.label("Ki %d / %d · click or press a number · ☆ pins a favourite" % [floori(g.player.ki), floori(g.player.maxKi)], "Muted"))
	var first: Button = null
	for i in _rows.size():
		var id: String = _rows[i]
		if i == 1 and not favs.is_empty():
			_list.add_child(UiKit.label("Favourites", "Muted"))
		if i == 1 + favs.size() and i < _rows.size():
			_list.add_child(UiKit.label("All forms", "Muted"))
		var row := HBoxContainer.new()
		var active: bool = id == str(g.player.form)
		var cost: float = g.transform_cost(id)
		var name_txt: String = "Base form" if id == "" else str(g.forms.forms[id].name)
		var cost_txt: String = "free" if id == "" else "%d ki" % ceili(cost)
		var label: String = "%s  %s%s" % [str(i) if i <= 9 else " ", name_txt, "  · active" if active else "  · " + cost_txt]
		var b := UiKit.button(label, pick.bind(id), active)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id != "" and not active and g.player.ki < cost:
			b.modulate = Color(1, 1, 1, 0.5)
			b.tooltip_text = "Charge more ki first."
		row.add_child(b)
		if id != "":
			var star := UiKit.button("★" if id in favs else "☆", toggle_favorite.bind(id))
			star.tooltip_text = "Unpin favourite" if id in favs else "Pin as favourite"
			star.custom_minimum_size.x = 44
			row.add_child(star)
		_list.add_child(row)
		if first == null:
			first = b
	if first != null and is_inside_tree():
		first.grab_focus.call_deferred()

## Gamepad / keyboard confirm on the focused row.
func activate() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and _list.is_ancestor_of(f):
		(f as Button).pressed.emit()
