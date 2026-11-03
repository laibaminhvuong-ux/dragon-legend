class_name TutorialPanel
extends PanelContainer
# The tutorial panel (port of web/src/ui/tutorial.js): the current step with the player's own key names,
# progress, and a Skip button.

var tut: RuleTutorialRules
var _count: Label
var _text: Label
var _flash := 0.0
var on_skip: Callable

func _init() -> void:
	name = "Tutorial"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(560, 0)
	position = Vector2(-280, 130)
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiKit.label("Tutorial", "HeaderMedium")
	head.add_child(title)
	_count = UiKit.label("", "Muted")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_count)
	head.add_child(UiKit.button("Skip tutorial", func() -> void:
		if tut != null: tut.skip()
		if on_skip.is_valid(): on_skip.call()))
	_text = UiKit.label("", "", true)
	_text.custom_minimum_size.x = 520
	v.add_child(_text)
	visible = false

func flash() -> void:
	_flash = 0.9

func refresh(dt: float, hidden: bool) -> void:
	if tut == null or not tut.get("active"):
		visible = false
		return
	visible = not hidden
	_flash = maxf(0.0, _flash - dt)
	self_modulate = Color(0.6, 1.0, 0.6) if _flash > 0.0 else Color.WHITE
	_count.text = "  %d / %d" % [int(tut.get("index")) + 1, int(tut.get("total"))]
	_text.text = tut.text(UiKit.key_labels())
