class_name UiKit
extends RefCounted
# Shared UI look and small builders: dark glass panels with an orange accent, readable type, button styles,
# and the player's own key names for prompts.

const ACCENT := Color("#ff9a2e")
const ACCENT_DARK := Color("#c76a12")
const PANEL := Color(0.05, 0.07, 0.12, 0.82)
const PANEL_LIGHT := Color(0.1, 0.13, 0.2, 0.9)
const TEXT := Color("#f2f4f8")
const MUTED := Color("#a8b3c7")
static var _theme: Theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", panel_box(PANEL))
	t.set_stylebox("panel", "Panel", panel_box(PANEL))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.16, 0.19, 0.28, 0.95), "hover": Color(0.24, 0.28, 0.4, 0.98), "pressed": ACCENT_DARK,
			"disabled": Color(0.12, 0.13, 0.17, 0.7), "focus": Color(0, 0, 0, 0)}[state]
		b.set_corner_radius_all(8)
		b.content_margin_left = 14; b.content_margin_right = 14; b.content_margin_top = 7; b.content_margin_bottom = 7
		if state == "focus":
			b.draw_center = false; b.set_border_width_all(2); b.border_color = ACCENT
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.63, 0.7))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	var primary := StyleBoxFlat.new(); primary.bg_color = ACCENT; primary.set_corner_radius_all(8)
	primary.content_margin_left = 14; primary.content_margin_right = 14; primary.content_margin_top = 7; primary.content_margin_bottom = 7
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", primary)
	var ph := primary.duplicate(); ph.bg_color = ACCENT.lightened(0.15)
	t.set_stylebox("hover", "PrimaryButton", ph)
	t.set_color("font_color", "PrimaryButton", Color("#1a1006"))
	t.set_color("font_hover_color", "PrimaryButton", Color("#1a1006"))
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.08, 0.09, 0.13, 0.9); bg.set_corner_radius_all(5)
	t.set_stylebox("background", "ProgressBar", bg)
	var fill := StyleBoxFlat.new(); fill.bg_color = ACCENT; fill.set_corner_radius_all(5)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "HeaderLarge", 30)
	t.set_type_variation("HeaderLarge", "Label")
	t.set_font_size("font_size", "HeaderMedium", 22)
	t.set_type_variation("HeaderMedium", "Label")
	t.set_color("font_color", "HeaderMedium", ACCENT.lightened(0.25))
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_font_size("font_size", "Muted", 15)
	_theme = t
	return t

static func panel_box(c: Color, radius := 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(radius)
	b.border_color = Color(1, 1, 1, 0.08)
	b.set_border_width_all(1)
	b.content_margin_left = 16; b.content_margin_right = 16; b.content_margin_top = 12; b.content_margin_bottom = 12
	b.shadow_color = Color(0, 0, 0, 0.35); b.shadow_size = 8
	return b

static func label(text: String, variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "": l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 200
	return l

static func button(text: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	if primary: b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(on_press)
	b.focus_mode = Control.FOCUS_ALL
	return b

static func bar(color: Color, height := 18.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(300, height)
	p.max_value = 1.0
	p.step = 0.0
	var fill := StyleBoxFlat.new(); fill.bg_color = color; fill.set_corner_radius_all(5)
	p.add_theme_stylebox_override("fill", fill)
	return p

## The player's key for an action ("G", "Left click", "Space"): the first keyboard/mouse binding.
static func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: int = (e as InputEventKey).physical_keycode
			var code := DisplayServer.keyboard_get_keycode_from_physical(k) if DisplayServer.get_name() != "headless" else k
			return OS.get_keycode_string(code if code != 0 else k)
		if e is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get((e as InputEventMouseButton).button_index, "Mouse")
	return action

## Key names by the JS camelCase binding ids (for the rules' tutorial text placeholders).
static func key_labels() -> Dictionary:
	var out := {}
	for pair: Array in [["jump", "jump"], ["melee", "melee"], ["block", "block"], ["dash", "dash"], ["flight", "flight"], ["ascend", "ascend"],
			["descend", "descend"], ["charge", "charge"], ["kiBlast", "ki_blast"], ["beam", "beam"], ["transform", "transform"], ["kaioken", "kaioken"],
			["lockOn", "lock_on"], ["interact", "interact"], ["menu", "menu"], ["radar", "radar"], ["base", "base"], ["pause", "pause"]]:
		out[pair[0]] = key_name(pair[1])
	out["move"] = "%s%s%s%s" % [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]
	return out
