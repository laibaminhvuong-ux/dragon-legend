extends Node
# Entry scene. Stage 1: a title card proving the project and autoloads start. Later stages add the menu and play.
# `-- --smoke` runs a few frames, prints the autoload status and quits (used by automated launch checks).

var _frames := 0
var _smoke := false

func _ready() -> void:
	_smoke = "--smoke" in OS.get_cmdline_user_args()
	var label := Label.new()
	label.text = "Dragon Legend\nGodot foundation ready"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 48)
	add_child(label)

func _process(delta: float) -> void:
	Clock.advance(delta)
	_frames += 1
	if _smoke and _frames >= 30:
		print("smoke ok: Data errors=%d, slots=%d, actions=%s" % [Data.errors.size(), SaveStore.list_slots().size(), InputMap.has_action("flight")])
		get_tree().quit(0)
