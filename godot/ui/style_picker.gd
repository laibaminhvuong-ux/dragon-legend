class_name StylePicker
extends Control
# The style key (Y) opens this: the four fighting styles (Turtle School, Brawler, Speedster, Crane), each with a
# one-line feel description. Click a row or press 1-4; the change goes to the rules (RuleGame.set_style), which may
# refuse it mid-strike; refusals become toasts. The game pauses while it is open.

signal opened
signal closed

const BLURB := {
	"turtle": "Balanced classic martial arts: solid straight punches and kicks.",
	"brawler": "Slow, heavy swings that knock foes back and crush guards.",
	"speedster": "Fast, light flurries, spins and blinks; weaker single hits.",
	"crane": "Calm and precise: long-reaching palms and high kicks.",
}

var play: PlaySession
var is_open := false
var _panel: PanelContainer
var _list: VBoxContainer

func _init(p: PlaySession) -> void:
	play = p
	name = "StylePicker"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color(0.05, 0.07, 0.12, 0.94), 14))
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -260; _panel.offset_right = 260
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_panel.add_child(_list)
	_panel.visible = false

## Style ids in display order.
func rows() -> Array:
	var order: Array = RuleTables.table("fighting_styles").get("order", [])
	return order.duplicate() if not order.is_empty() else FightStyles.IDS.duplicate()

func current() -> String:
	var s := str(play.game.player.get("style", ""))
	return s if s != "" else "turtle"

func open() -> void:
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
	if id == current():
		close()
		return
	var err: Variant = play.game.set_style(id)
	if err is String:
		Events.emit_named("notify", {"text": err})
		_build()
		return
	Events.emit_named("notify", {"text": "Fighting style: %s" % FightStyles.NAMES.get(id, id)})
	close()

func pick_number(n: int) -> void:
	var r := rows()
	if n >= 1 and n <= r.size():
		pick(str(r[n - 1]))

func _input(e: InputEvent) -> void:
	if not is_open or not e is InputEventKey or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9:
		pick_number(k - KEY_0)
		get_viewport().set_input_as_handled()

func _build() -> void:
	for c in _list.get_children():
		_list.remove_child(c); c.queue_free()
	_list.add_child(UiKit.label("Fighting style", "HeaderLarge"))
	_list.add_child(UiKit.label("Changes how your punches, kicks and combos look and flow · click or press a number", "Muted"))
	var first: Button = null
	var r := rows()
	for i in r.size():
		var id: String = r[i]
		var active := id == current()
		var b := UiKit.button("%d  %s%s" % [i + 1, FightStyles.NAMES.get(id, id), "  · current" if active else ""], pick.bind(id), active)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = BLURB.get(id, "")
		_list.add_child(b)
		_list.add_child(UiKit.label("     " + str(BLURB.get(id, "")), "Muted"))
		if first == null:
			first = b
	if first != null and is_inside_tree():
		first.grab_focus.call_deferred()

## Gamepad / keyboard confirm on the focused row.
func activate() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and _list.is_ancestor_of(f):
		(f as Button).pressed.emit()
